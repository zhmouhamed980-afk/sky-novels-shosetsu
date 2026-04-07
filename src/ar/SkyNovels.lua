-- {"id":7001,"ver":"1.0.0","libVer":"1.0.0","author":"You","repo":"https://raw.githubusercontent.com/YOUR_USERNAME/sky-novels-shosetsu/main/","dep":[]}

--- سماء الروايات — Shosetsu Extension
--- API Base: http://62.171.141.197:5007
---
--- ملاحظة: السيرفر يحتاج Bearer token للبحث وقراءة الفصول.
--- أضف token في إعدادات المصدر (Settings → Sources → سماء الروايات → ⚙).

-- ─── معلومات المصدر ──────────────────────────────────────────
local id       = 7001
local name     = "سماء الروايات"
local baseURL  = "http://62.171.141.197:5007"
local imageURL = "https://raw.githubusercontent.com/YOUR_USERNAME/sky-novels-shosetsu/main/icons/SkyNovels.png"

-- ─── الإعدادات الداخلية ──────────────────────────────────────
-- token يُحفظ هنا بعد إدخاله من المستخدم في settingsModel
local settings = {
    [1] = ""   -- Bearer token
}

local settingsModel = {
    TextFilter(1, "Bearer Token (من حساب سماء الروايات)")
}

local chapterType        = ChapterType.HTML
local hasSearch          = true
local isSearchIncrementing = false   -- البحث لا يرجع صفحات متعددة
local startIndex         = 1

-- ─── دوال مساعدة ─────────────────────────────────────────────

--- بناء headers الطلب مع token إذا توفّر
local function buildHeaders(requireAuth)
    local headers = {
        ["Content-Type"]  = "application/json",
        ["Accept"]        = "application/json"
    }
    local token = settings[1]
    if requireAuth and token ~= nil and token ~= "" then
        headers["Authorization"] = "Bearer " .. token
    end
    return headers
end

--- GET طلب JSON وإرجاع جدول Lua
local function getJSON(url, requireAuth)
    local headers = buildHeaders(requireAuth)
    local response = RequestDocument(GET(url, headers))
    -- RequestDocument يُرجع document HTML, نحتاج النص الخام
    -- في Shosetsu نستخدم Request() للحصول على string
    local raw = Request(GET(url, headers)):body()
    return JSON:decode(raw)
end

--- POST طلب JSON وإرجاع جدول Lua
local function postJSON(url, body)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"]       = "application/json"
    }
    local raw = Request(POST(url, headers, RequestBody(JSON:encode(body), MEDIATYPE_JSON))):body()
    return JSON:decode(raw)
end

--- تحويل كائن رواية من API إلى NovelItem لـ Shosetsu
local function toNovelItem(novel)
    local cover = novel["coverImage"] or ""
    -- السيرفر قد يُرجع base64 — Shosetsu لا يدعمها مباشرة، نتركها فارغة
    local coverURL = ""
    if cover ~= "" and cover:sub(1, 4) == "http" then
        coverURL = cover
    end

    -- نستخدم _id كجزء من الـ URL المُختصر
    local novelId = novel["_id"] or ""
    return Novel(novelId, novel["title"] or "بدون عنوان", coverURL)
end

-- ─── shrinkURL / expandURL ────────────────────────────────────

local function shrinkURL(url, type)
    -- نحذف baseURL من الأمام ونبقي المسار فقط
    -- مثال: "http://62.171.141.197:5007/novels/abc123" → "/novels/abc123"
    return url:gsub(baseURL, "")
end

local function expandURL(url, type)
    return baseURL .. url
end

-- ─── القوائم (Listings) ───────────────────────────────────────

local listings = {

    --- قائمة "جميع الروايات" — تجلب 20 رواية لكل صفحة
    Listing("جميع الروايات", true, function(data)
        local page = data[PAGE_INDEX] or 1
        local url  = baseURL .. "/novels?page=" .. page .. "&limit=20"

        local ok, result = pcall(getJSON, url, false)
        if not ok or result == nil then return {} end

        local novels = {}
        local list = result["data"] or {}
        for _, novel in ipairs(list) do
            novels[#novels + 1] = toNovelItem(novel)
        end
        return novels
    end),

    --- قائمة "مترجمة" — تصفية على الجانب بعد جلب الصفحة
    Listing("مترجمة", true, function(data)
        local page = data[PAGE_INDEX] or 1
        local url  = baseURL .. "/novels?page=" .. page .. "&limit=100"

        local ok, result = pcall(getJSON, url, false)
        if not ok or result == nil then return {} end

        local novels = {}
        local list = result["data"] or {}
        for _, novel in ipairs(list) do
            if novel["category"] == "مترجمة" then
                novels[#novels + 1] = toNovelItem(novel)
            end
        end
        return novels
    end),

    --- قائمة "مؤلفة"
    Listing("مؤلفة", true, function(data)
        local page = data[PAGE_INDEX] or 1
        local url  = baseURL .. "/novels?page=" .. page .. "&limit=100"

        local ok, result = pcall(getJSON, url, false)
        if not ok or result == nil then return {} end

        local novels = {}
        local list = result["data"] or {}
        for _, novel in ipairs(list) do
            if novel["category"] == "مؤلفة" then
                novels[#novels + 1] = toNovelItem(novel)
            end
        end
        return novels
    end),

}

-- ─── parseNovel ───────────────────────────────────────────────

local function parseNovel(novelURL)
    -- novelURL هنا هو المسار المُختصر: "/novels/abc123"
    local url = expandURL(novelURL, KEY_NOVEL_URL)

    local ok, result = pcall(getJSON, url, false)
    if not ok or result == nil then
        return NovelInfo()
    end

    local novel = result["data"] or result
    local novelId = novel["_id"] or ""

    -- بناء قائمة الفصول
    local totalChapters = tonumber(novel["totalChapters"]) or 0
    local chapters = {}
    for i = 1, totalChapters do
        local chPath = "/novels/" .. novelId .. "/chapters/" .. i
        chapters[#chapters + 1] = NovelChapter(
            shrinkURL(baseURL .. chPath, KEY_CHAPTER_URL),  -- URL مُختصر
            "الفصل " .. i,                                  -- الاسم
            i,                                              -- الترتيب
            false                                           -- لم يُقرأ
        )
    end

    -- معالجة الوصف
    local desc = (novel["description"] or ""):gsub("\r\n", "\n"):gsub("\r", "\n")

    -- معالجة الغلاف
    local cover = novel["coverImage"] or ""
    local coverURL = ""
    if cover ~= "" and cover:sub(1, 4) == "http" then
        coverURL = cover
    end

    -- الحالة
    local status = NovelStatus.UNKNOWN
    local statusStr = novel["status"] or ""
    if statusStr == "مكتملة" then
        status = NovelStatus.COMPLETED
    elseif statusStr == "مستمرة" then
        status = NovelStatus.PUBLISHING
    end

    -- التاجز
    local tags = novel["tags"] or {}
    local tagsStr = table.concat(tags, ", ")

    return NovelInfo(
        novel["title"] or "بدون عنوان",   -- title
        coverURL,                           -- imageURL
        desc,                               -- description
        tagsStr,                            -- tags (string)
        status,                             -- status
        chapters                            -- chapters
    )
end

-- ─── getPassage ───────────────────────────────────────────────

local function getPassage(chapterURL)
    -- chapterURL مثال: "/novels/abc123/chapters/5"
    local url = expandURL(chapterURL, KEY_CHAPTER_URL)

    local token = settings[1]
    if token == nil or token == "" then
        return [[<html><body dir="rtl" style="font-family:serif;padding:20px">
            <p style="color:red;font-size:1.2em">⚠️ يجب إضافة Bearer Token في إعدادات المصدر لقراءة الفصول.</p>
            <p>اذهب إلى: Sources ← سماء الروايات ← ⚙ ← Bearer Token</p>
        </body></html>]]
    end

    local ok, result = pcall(getJSON, url, true)
    if not ok or result == nil then
        return "<html><body dir='rtl'><p>تعذّر تحميل الفصل. تأكد من صحة الـ Token والاتصال بالإنترنت.</p></body></html>"
    end

    local data = result["data"] or result
    local title   = data["title"]   or ""
    local content = data["content"] or ""

    if title == "" and content == "" then
        return "<html><body dir='rtl'><p>⚠️ بيانات فارغة لهذا الفصل.</p></body></html>"
    end

    -- تحويل النص إلى HTML: كل سطر غير فارغ → <p>
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    local paragraphs = ""
    for line in content:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$") -- trim
        if line ~= "" then
            paragraphs = paragraphs .. "<p>" .. line .. "</p>\n"
        end
    end

    return string.format([[<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<style>
  body {
    font-family: 'Amiri', 'Traditional Arabic', serif;
    font-size: 1.1em;
    line-height: 1.9;
    padding: 16px;
    max-width: 720px;
    margin: auto;
    background: #0d0d14;
    color: #e8e8e8;
    direction: rtl;
  }
  h2 {
    color: #f5a623;
    text-align: center;
    margin-bottom: 1.5em;
  }
  p { margin-bottom: 0.8em; }
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

    local token = settings[1]
    if token == nil or token == "" then return {} end

    local url = baseURL .. "/novels/search?q=" .. query
    local ok, result = pcall(getJSON, url, true)
    if not ok or result == nil then return {} end

    -- السيرفر يُرجع { success, data: [...] } أو مصفوفة مباشرة
    local list = result["data"] or result
    if type(list) ~= "table" then return {} end

    local novels = {}
    for _, novel in ipairs(list) do
        novels[#novels + 1] = toNovelItem(novel)
    end
    return novels
end

-- ─── updateSetting ────────────────────────────────────────────

local function updateSetting(settingId, value)
    settings[settingId] = value
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
    settings             = settingsModel,
    search               = search,
    updateSetting        = updateSetting,
}
