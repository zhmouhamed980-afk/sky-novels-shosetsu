-- {"id":7001,"ver":"1.2.0","libVer":"1.0.0","author":"zhmouhamed980-afk","repo":"https://raw.githubusercontent.com/zhmouhamed980-afk/sky-novels-shosetsu/main/","dep":[]}

--- سماء الروايات — Shosetsu Extension v1.2
--- API Base: http://62.171.141.197:5007

local id      = 7001
local name    = "سماء الروايات"
local baseURL = "http://62.171.141.197:5007"
local imageURL = "https://raw.githubusercontent.com/zhmouhamed980-afk/sky-novels-shosetsu/main/icons/SkyNovels.png"

-- Token مدمج صالح حتى 2126
local TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI2OGY3NmM0MjY5ZmZlNDhhNTliZjg0MjkiLCJpYXQiOjE3NzU1NzI4MzAsImV4cCI6NDkyOTE3MjgzMH0.WFpmtBMLZnxSNV4JuV7c-4CPV04r4HSLomNHHKLJpG8"

local chapterType        = ChapterType.HTML
local hasSearch          = true
local isSearchIncrementing = false
local startIndex         = 1

-- ─── دوال مساعدة ─────────────────────────────────────────────

local function buildHeaders(auth)
    local b = HeadersBuilder()
    b:add("Content-Type", "application/json")
    b:add("Accept", "application/json")
    if auth then
        b:add("Authorization", "Bearer " .. TOKEN)
    end
    return b:build()
end

local function getJSON(url, auth)
    local req = _GET(url, buildHeaders(auth), DEFAULT_CACHE_CONTROL())
    local res = Request(req)
    local body = res:body()
    if body == nil or body == "" then return nil end
    return JSON:decode(body)
end

local function toNovelItem(novel)
    local title   = novel["title"] or "بدون عنوان"
    local cover   = novel["coverImage"] or ""
    local coverURL = ""
    -- Handle base64 encoded images - they won't work in Shosetsu, so skip them
    if cover ~= "" and cover:sub(1, 4) == "http" then
        coverURL = cover
    end
    -- Build the link from novel ID
    local link = ""
    if novel["_id"] then
        link = "/novels/" .. novel["_id"]
    end
    -- Novel constructor: Novel(title, imageURL, link)
    return Novel(title, coverURL, link)
end

-- ─── shrinkURL / expandURL ────────────────────────────────────

local function shrinkURL(url, type)
    return url:gsub(baseURL, "")
end

local function expandURL(url, type)
    if url:sub(1, 4) == "http" then return url end
    return baseURL .. url
end

-- ─── Listings ─────────────────────────────────────────────────

local listings = {
    Listing("جميع الروايات", true, function(data)
        local page = data[PAGE_INDEX] or 1
        local url  = baseURL .. "/novels?page=" .. page .. "&limit=20"
        local ok, result = pcall(getJSON, url, false)
        if not ok or result == nil then return {} end
        local novels = {}
        local list = result["data"] or {}
        for i, novel in ipairs(list) do
            local novelItem = toNovelItem(novel)
            novels[#novels + 1] = novelItem
        end
        return novels
    end),

    Listing("مترجمة", true, function(data)
        local page = data[PAGE_INDEX] or 1
        local url  = baseURL .. "/novels?page=" .. page .. "&limit=100"
        local ok, result = pcall(getJSON, url, false)
        if not ok or result == nil then return {} end
        local novels = {}
        for _, novel in ipairs(result["data"] or {}) do
            if novel["category"] == "مترجمة" then
                local novelItem = toNovelItem(novel)
                novels[#novels + 1] = novelItem
            end
        end
        return novels
    end),

    Listing("مؤلفة", true, function(data)
        local page = data[PAGE_INDEX] or 1
        local url  = baseURL .. "/novels?page=" .. page .. "&limit=100"
        local ok, result = pcall(getJSON, url, false)
        if not ok or result == nil then return {} end
        local novels = {}
        for _, novel in ipairs(result["data"] or {}) do
            if novel["category"] == "مؤلفة" then
                local novelItem = toNovelItem(novel)
                novels[#novels + 1] = novelItem
            end
        end
        return novels
    end),
}

-- ─── parseNovel ───────────────────────────────────────────────

local function parseNovel(novelURL)
    local url = expandURL(novelURL, KEY_NOVEL_URL)
    local ok, result = pcall(getJSON, url, false)
    if not ok or result == nil then return nil end

    local novel   = result["data"] or result
    local novelId = novel["_id"] or ""

    -- وصف
    local desc = (novel["description"] or ""):gsub("\r\n", "\n"):gsub("\r", "\n")

    -- غلاف
    local cover = novel["coverImage"] or ""
    local coverURL = ""
    if cover ~= "" and cover:sub(1, 4) == "http" then coverURL = cover end

    -- حالة
    local status = NovelStatus.UNKNOWN
    local st     = novel["status"] or ""
    if st == "مكتملة" then
        status = NovelStatus.COMPLETED
    elseif st == "مستمرة" then
        status = NovelStatus.PUBLISHING
    end

    -- تاجز
    local tags    = novel["tags"] or {}
    local tagsStr = table.concat(tags, ", ")

    -- Create NovelInfo object: NovelInfo(title, description, imageURL, author, genre, status)
    local info = NovelInfo(
        novel["title"] or "بدون عنوان",
        desc,
        coverURL,
        novel["author"] or "",
        tagsStr,
        status
    )

    -- فصول - load chapters if they exist
    local total    = tonumber(novel["totalChapters"]) or 0
    if total > 0 then
        local chapters = {}
        for i = 1, total do
            local chPath = "/novels/" .. novelId .. "/chapters/" .. i
            -- NovelChapter(order, title, link)
            chapters[#chapters + 1] = NovelChapter(i, "الفصل " .. i, chPath)
        end
        info:setChapters(AsList(chapters))
    end

    return info
end

-- ─── getPassage ───────────────────────────────────────────────

local function getPassage(chapterURL)
    local url = expandURL(chapterURL, KEY_CHAPTER_URL)
    local ok, result = pcall(getJSON, url, true)

    if not ok or result == nil then
        return "<html><body dir='rtl' style='padding:20px;color:#e8e8e8;background:#0d0d14'><p>⚠️ تعذّر تحميل الفصل. تأكد من الاتصال بالإنترنت.</p></body></html>"
    end

    local data    = result["data"] or result
    local title   = data["title"]   or ""
    local content = data["content"] or ""

    if title == "" and content == "" then
        return "<html><body dir='rtl' style='padding:20px;color:#e8e8e8;background:#0d0d14'><p>⚠️ بيانات فارغة لهذا الفصل.</p></body></html>"
    end

    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    local paragraphs = ""
    for line in content:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            paragraphs = paragraphs .. "<p>" .. line .. "</p>\n"
        end
    end

    return string.format([[<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<style>
  body { font-family: serif; font-size: 1.1em; line-height: 1.9;
         padding: 16px; max-width: 720px; margin: auto;
         background: #0d0d14; color: #e8e8e8; direction: rtl; }
  h2   { color: #f5a623; text-align: center; margin-bottom: 1.5em; }
  p    { margin-bottom: 0.8em; }
</style>
</head>
<body>
<h2>%s</h2>
%s
</body>
</html>]], title, paragraphs)
end

-- ─── search ───────────────────────────────────────────────────

local function search(data)
    local query = data[QUERY] or ""
    if query == "" then return {} end

    local url = baseURL .. "/novels/search?q=" .. query
    local ok, result = pcall(getJSON, url, true)
    if not ok or result == nil then return {} end

    local list = result["data"] or result
    if type(list) ~= "table" then return {} end

    local novels = {}
    for _, novel in ipairs(list) do
        local novelItem = toNovelItem(novel)
        novels[#novels + 1] = novelItem
    end
    return novels
end

-- ─── الإرجاع ─────────────────────────────────────────────────

return {
    id                   = id,
    name                 = name,
    baseURL              = baseURL,
    imageURL             = imageURL,
    listings             = listings,
    getPassage           = getPassage,
    parseNovel           = parseNovel,
    shrinkURL            = shrinkURL,
    expandURL            = expandURL,
    hasSearch            = hasSearch,
    isSearchIncrementing = isSearchIncrementing,
    chapterType          = chapterType,
    startIndex           = startIndex,
    search               = search,
}
