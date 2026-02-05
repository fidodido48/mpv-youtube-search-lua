--[[]
    Author: fidodido48 (2026)
    A fork/modified mpv-youtube-search code to improve yt search list font size issue written with the GPT-5 AI help. Original code by 'CogentRedTester' and is available below:
    -----------------------ORIGINAL----------------
    This script allows users to search and open youtube results from within mpv.
    Available at: https://github.com/CogentRedTester/mpv-scripts

    Users can open the search page with Y, and use Y again to open a search.
    Alternatively, Ctrl+y can be used at any time to open a search.
    Esc can be used to close the page.
    Enter will open the selected item, Shift+Enter will append the item to the playlist.

    This script requires that my other scripts `scroll-list` and `user-input` be installed.
    scroll-list.lua and user-input-module.lua must be in the ~~/script-modules/ directory,
    while user-input.lua should be loaded by mpv normally.

    https://github.com/CogentRedTester/mpv-scroll-list
    https://github.com/CogentRedTester/mpv-user-input

    This script also requires a youtube API key to be entered.
    The API key must be passed to the `API_key` script-opt.
    A personal API key is free and can be created from:
    https://console.developers.google.com/apis/api/youtube.googleapis.com/

    The script also requires that curl be in the system path.

    An alternative to using the official youtube API is to use Invidious.
    This script has experimental support for Invidious searches using the 'invidious',
    'API_path', and 'frontend' options. API_path refers to the url of the API the
    script uses, Invidious API paths are usually in the form:
        https://domain.name/api/v1/
    The frontend option is the url to actualy try to load videos from. This
    can probably be the same as the above url:
        https://domain.name
    Since the url syntax seems to be identical between Youtube and Invidious,
    it should be possible to mix these options, a.k.a. using the Google
    API to get videos from an Invidious frontend, or to use an Invidious
    API to get videos from Youtube.
    The 'invidious' option tells the script that the API_path is for an
    Invidious path. This is to support other possible API options in the future.
    ---------------- END OF ORIGINAL ----------------------
]]--

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
local opts = require "mp.options"

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) .. package.path
local ui = require "user-input-module"
local list = require "scroll-list"

local o = {
    -- REMEMBER TO INSERT YOUR YT API KEY HERE!
    API_key = "",

    --number of search results to show in the list
    num_results = 100,

    --the url to send API calls to
    API_path = "https://www.googleapis.com/youtube/v3/",

    --attempt this API if the default fails
    fallback_API_path = "",

    --the url to load videos from
    frontend = "https://www.youtube.com",

    --use invidious API calls
    invidious = false,

    --whether the fallback uses invidious as well
    fallback_invidious = false
}

opts.read_options(o)

--ensure the URL options are properly formatted
local function format_options()
    if o.API_path:sub(-1) ~= "/" then o.API_path = o.API_path.."/" end
    if o.fallback_API_path:sub(-1) ~= "/" then o.fallback_API_path = o.fallback_API_path.."/" end
    if o.frontend:sub(-1) == "/" then o.frontend = o.frontend:sub(1, -2) end
end

-- Control/set font size for yt search list table entries
-- HEADER FONT SIZE
local header_fs = 28
-- TABLE ITEMS ENTRY FONT SIZE
local entry_fs  = 48
-- TABLE CHANNELS FONT SIZE
local channel_fs = 38

format_options()

list.header = ("%s Search: \\N-------------------------------------------------"):format(o.invidious and "Invidious" or "Youtube")
-- HOW MANY ENTRIES TO SHOW AT ONCE/PER PAGE
-- *** WARNING: DON'T SET IT TOO HIGH OR THE RESULTS TABLE WILL BE CLIPPED DUE TO TOO BIG FONT VS. TOO MANY SEARCH ITEMS TO FIT THE SCREEN! SET SMALLER FONT SIZE IF YOU WANT MORE RESULTS! BEST TO LEAVE AS IS SINCE YOU CAN SCROLL FREELY ANYWAY... 
list.num_entries = 4
list.list_style = [[{\fs20}\N{\q2\fs45\c&Hffffff&}]]
list.empty_text = "enter search query"

local ass_escape = list.ass_escape

--encodes a string so that it uses url percent encoding
--this function is based on code taken from here: https://rosettacode.org/wiki/URL_encoding#Lua
local function encode_string(str)
    if type(str) ~= "string" then return str end
	local output, t = str:gsub("[^%w]", function(char)
        return string.format("%%%X",string.byte(char))
    end)
	return output
end

--convert HTML character codes to the correct characters
local function html_decode(str)
    if type(str) ~= "string" then return str end

    return str:gsub("&(#?)(%w-);", function(is_ascii, code)
        if is_ascii == "#" then return string.char(tonumber(code)) end
        if code == "amp" then return "&" end
        if code == "quot" then return '"' end
        if code == "apos" then return "'" end
        if code == "lt" then return "<" end
        if code == "gt" then return ">" end
        return nil
    end)
end

-- ===========================
-- 1) Simple word-wrap helper
-- ===========================
-- Usage: local wrapped = wrap_text_words(ass_escape(item.title), 40)
local function wrap_text_words(s, width)
    if not s then return "" end
    width = width or 40
    local words = {}
    for w in s:gmatch("%S+") do table.insert(words, w) end
    local lines = {}
    local cur = ""
    for _, w in ipairs(words) do
        if cur == "" then
            cur = w
        elseif #cur + 1 + #w <= width then
            cur = cur .. " " .. w
        else
            table.insert(lines, cur)
            cur = w
        end
    end
    if cur ~= "" then table.insert(lines, cur) end
    return table.concat(lines, "\\N")
end

-- ==============================================
-- 2) (Optional) Approx pixel-width wrapper helper
--    - Uses simple per-character width table to better match ASS rendering
--    - Max_pixels should be chosen from your OSD width and font size
--    - This is conservative/approximate; keep wrap_text_words if simpler.
-- ==============================================
local function build_char_width_table()
    -- approximate relative widths (monospace-ish baseline).
    -- Adjust values for your font if needed.
    local t = {}
    for i = 32, 126 do
        local c = string.char(i)
        if c:match("[%w]") then t[c] = 7
        elseif c:match("%s") then t[c] = 4
        else t[c] = 6 end
    end
    return t
end

local char_widths = build_char_width_table()

local function text_pixel_width(s)
    if not s then return 0 end
    local w = 0
    for i = 1, #s do
        local c = s:sub(i, i)
        w = w + (char_widths[c] or 6)
    end
    return w
end

local function wrap_text_pixels(s, max_pixels)
    if not s then return "" end
    max_pixels = max_pixels or 600
    local words = {}
    for w in s:gmatch("%S+") do table.insert(words, w) end
    local lines = {}
    local cur = ""
    for _, w in ipairs(words) do
        local try = (cur == "" and w) or (cur .. " " .. w)
        if text_pixel_width(try) <= max_pixels then
            cur = try
        else
            if cur ~= "" then table.insert(lines, cur) end
            cur = w
        end
    end
    if cur ~= "" then table.insert(lines, cur) end
    return table.concat(lines, "\\N")
end

-- ============================================================
-- 3) Replacement insert_* functions that create wrapped ASS
--    - These replace the existing insert_video/playlist/channel
--    - They use wrap_text_words by default; switch to wrap_text_pixels if desired
-- ============================================================
-- Configuration: choose wrap widths appropriate for your font/OSD size.
-- *** WARNING: USE EITHER CHARS-/PIXELS-WRAPPING, BUT NOT BOTH! ***
-- characters per line for titles (word-wrap)
local TITLE_WRAP_CHARS = 70
-- characters per line for channel text
local CHANNEL_WRAP_CHARS = 60

-- uncomment if using pixel wrapper
-- local TITLE_WRAP_PIXELS = 600
-- local CHANNEL_WRAP_PIXELS = 900


--creates a formatted results table from an invidious API call
function format_invidious_results(response)
    if not response then return nil end
    local results = {}

    for i, item in ipairs(response) do
        if i > o.num_results then break end

        local t = {}
        table.insert(results, t)

        t.title = html_decode(item.title)
        t.channelTitle = html_decode(item.author)
        if item.type == "video" then
            t.type = "video"
            t.id = item.videoId
        elseif item.type == "playlist" then
            t.type = "playlist"
            t.id = item.playlistId
        elseif item.type == "channel" then
            t.type = "channel"
            t.id = item.authorId
            t.title = t.channelTitle
        end
    end

    return results
end

--creates a formatted results table from a youtube API call
function format_youtube_results(response)
    if not response or not response.items then return nil end
    local results = {}

    for _, item in ipairs(response.items) do
        local t = {}
        table.insert(results, t)

        t.title = html_decode(item.snippet.title)
        t.channelTitle = html_decode(item.snippet.channelTitle)

        if item.id.kind == "youtube#video" then
            t.type = "video"
            t.id = item.id.videoId
        elseif item.id.kind == "youtube#playlist" then
            t.type = "playlist"
            t.id = item.id.playlistId
        elseif item.id.kind == "youtube#channel" then
            t.type = "channel"
            t.id = item.id.channelId
        end
    end

    return results
end

--sends an API request
local function send_request(type, queries, API_path)
    local url = (API_path or o.API_path)..type
    url = url.."?"

    for key, value in pairs(queries) do
        msg.verbose(key, value)
        url = url.."&"..key.."="..encode_string(value)
    end

    msg.debug(url)
    local request = mp.command_native({
        name = "subprocess",
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
        args = {"curl", url}
    })

    local response = utils.parse_json(request.stdout)
    msg.trace(utils.to_string(request))

    if request.status ~= 0 then
        msg.error(request.stderr)
        return nil
    end
    if not response then
        msg.error("Could not parse response:")
        msg.error(request.stdout)
        return nil
    end
    if response.error then
        msg.error(request.stdout)
        return nil
    end

    return response
end

--sends a search API request - handles Google/Invidious API differences
local function search_request(queries, API_path, invidious)
    list.header = ("%s Search: %s\\N-------------------------------------------------"):format(invidious and "Invidious" or "Youtube", ass_escape(queries.q, true))
    list.list = {}
    list.empty_text = "~"
    -- adjust visible rows based on average lines per entry (2 means title+channel)
    --[[local avg_lines_per_entry = 2
    local orig_visible = 9 -- previous list.num_entries
    list.num_entries = math.max(3, math.floor(orig_visible / avg_lines_per_entry))]]
    list:update()
    local results = {}

    --we need to modify the returned results so that the rest of the script can read it
    if invidious then

        --Invidious searches are done with pages rather than a max result number
        local page = 1
        while #results < o.num_results do
            queries.page = page

            local response = send_request("search", queries, API_path)
            response = format_invidious_results(response)
            if not response then msg.warn("Search did not return a results list") ; return end
            if #response == 0 then break end

            for _, item in ipairs(response) do
                table.insert(results, item)
            end

            page = page + 1
        end
    else
        local response = send_request("search", queries, API_path)
        results = format_youtube_results(response)
    end

    --print error messages to console if the API request fails
    if not results then
        msg.warn("Search did not return a results list")
        return
    end

    list.empty_text = "no results"
    return results
end

-- insert_video: wrapped title and channel
local function insert_video(item)
    local title_raw = ass_escape(item.title)
    local channel_raw = ass_escape(item.channelTitle)
    -- Choose wrapper: word-based (simple) or pixel-based (comment/uncomment)
    local title_wrapped = wrap_text_words(title_raw, TITLE_WRAP_CHARS)
    local channel_wrapped = wrap_text_words(channel_raw, CHANNEL_WRAP_CHARS)
    -- local title_wrapped = wrap_text_pixels(title_raw, TITLE_WRAP_PIXELS)
    -- local channel_wrapped = wrap_text_pixels(channel_raw, CHANNEL_WRAP_PIXELS)

    list:insert({
        ass = ("{\\fs%d}%s\\N{\\c&aaaaaa&\\fs%d}%s"):format(entry_fs, title_wrapped, channel_fs, channel_wrapped),
        url = ("%s/watch?v=%s"):format(o.frontend, item.id)
    })
end

-- insert_playlist: wrapped title and channel
local function insert_playlist(item)
    local title_raw = ass_escape(item.title)
    local channel_raw = ass_escape(item.channelTitle)
    local title_wrapped = wrap_text_words(title_raw, TITLE_WRAP_CHARS)
    local channel_wrapped = wrap_text_words(channel_raw, CHANNEL_WRAP_CHARS)
    -- local title_wrapped = wrap_text_pixels(title_raw, TITLE_WRAP_PIXELS)
    -- local channel_wrapped = wrap_text_pixels(channel_raw, CHANNEL_WRAP_PIXELS)

    list:insert({
        ass = ("{\\fs%d}🖿 %s\\N{\\c&aaaaaa&\\fs%d}%s"):format(entry_fs, title_wrapped, channel_fs, channel_wrapped),
        url = ("%s/playlist?list=%s"):format(o.frontend, item.id)
    })
end

-- insert_channel: wrapped channel/title (channel entries usually shorter)
local function insert_channel(item)
    local title_raw = ass_escape(item.title)
    local title_wrapped = wrap_text_words(title_raw, TITLE_WRAP_CHARS)
    -- local title_wrapped = wrap_text_pixels(title_raw, TITLE_WRAP_PIXELS)

    list:insert({
        ass = ("{\\fs%d}👤 %s"):format(entry_fs, title_wrapped),
        url = ("%s/channel/%s"):format(o.frontend, item.id)
    })
end

local function reset_list()
    list.selected = 1
    list:clear()
end

--creates the search request queries depending on what API we're using
local function get_search_queries(query, invidious)
    if invidious then
        return {
            q = query,
            type = "all",
            page = 1
        }
    else
        return {
            key = o.API_key,
            q = query,
            part = "id,snippet",
            maxResults = o.num_results
        }
    end
end

local function search(query)
    local response = search_request(get_search_queries(query, o.invidious), o.API_path, o.invidious)
    if not response and o.fallback_API_path ~= "/" then
        msg.info("search failed - attempting fallback")
        response = search_request(get_search_queries(query, o.fallback_invidious), o.fallback_API_path, o.fallback_invidious)
    end

    if not response then return end
    reset_list()

    for _, item in ipairs(response) do
        if item.type == "video" then
            insert_video(item)
        elseif item.type == "playlist" then
            insert_playlist(item)
        elseif item.type == "channel" then
            insert_channel(item)
        end
    end
    list:update()
    list:open()
end

local function play_result(flag)
    if not list[list.selected] then return end
    if flag == "new_window" then mp.commandv("run", "mpv", list[list.selected].url) ; return end

    mp.commandv("loadfile", list[list.selected].url, flag)
    if flag == "replace" then list:close() end
end

table.insert(list.keybinds, {"ENTER", "play", function() play_result("replace") end, {}})
table.insert(list.keybinds, {"Shift+ENTER", "play_append", function() play_result("append-play") end, {}})
table.insert(list.keybinds, {"Ctrl+ENTER", "play_new_window", function() play_result("new_window") end, {}})

local function open_search_input()
    ui.get_user_input(function(input)
        if not input then return end
        search( input )
    end, { request_text = "Enter Query:" })
end

mp.add_key_binding("F6", "yt", open_search_input)

mp.add_key_binding("F5", "youtube-search", function()
    if not list.hidden then open_search_input()
    else
        list:open()
        if #list.list == 0 then open_search_input() end
    end
end)
