_YOUTUBE_SEARCH.LUA_ _MPV_ _SCRIPT_

__INTRODUCTION__
----------------

Mpv's lua script for convenient youtube searching from within mpv. Please note this is a fork/modified version of https://github.com/CogentRedTester/mpv-scripts/blob/master/youtube-search.lua script written with help of GPT-5 AI.

__REQUIREMENTS__
----------------

- mpv
- yt-dlp
- REMEMBER to adjust config settings to your liking
(insert your YT API KEY/set preferred font sizes/yt search results number/word wrap max characters number/etc.)

__INSTALLATION__
----------------

1. Git clone repo 

```git clone https://github.com/fidodido48/mpv-youtube-search-lua.git $HOME/.config/mpv/scripts```

2. Make sure to put the script in the proper mpv's scripts in their proper respective dirs! (some needs to go to ~~/script-modules, where '~~' is your mpv's config dir):

$HOME/.config/mpv/scripts:
- user-input.lua
- youtube-search.lua

$HOME/.config/mpv/script-modules:
- scroll-list.lua
- user-input-module.lua


3. Find and edit those env vars with your preffered settings (DON'T CHANGE THEIR PLACEMENT, JUST EDIT THEM!): 

[~/.config/mpv/scripts/youtube-search.lua]

```
-- REMEMBER TO INSERT YOUR YT API KEY HERE!
    API_key = "",

--number of search results to show in the list
    num_results = 100,

-- Control/set font size for yt search list table entries
-- HEADER FONT SIZE
local header_fs = 28
-- TABLE ITEMS ENTRY FONT SIZE
local entry_fs  = 48
-- TABLE CHANNELS FONT SIZE
local channel_fs = 38

-- HOW MANY ENTRIES TO SHOW AT ONCE/PER PAGE
-- *** WARNING: DON'T SET IT TOO HIGH OR THE RESULTS TABLE WILL BE CLIPPED DUE TO NOT FITTING ON THE SCREEN! SET SMALLER FONT SIZE IF YOU WANT MORE RESULTS OR BIGGER FONT WITH LESS RESULTS! BEST TO LEAVE AS IS SINCE YOU CAN SCROLL FREELY ANYWAY... 
list.num_entries = 4

-- Configuration: choose wrap widths appropriate for your font/OSD size.
-- *** WARNING: USE EITHER CHARS-/PIXELS-WRAPPING, BUT NOT BOTH! ***
-- characters per line for titles (word-wrap)
local TITLE_WRAP_CHARS = 65
-- characters per line for channel text   
local CHANNEL_WRAP_CHARS = 60

-- uncomment if using pixel wrapper
-- local TITLE_WRAP_PIXELS = 600 
-- local CHANNEL_WRAP_PIXELS = 900
```

__USAGE__
-----------------

![mpv-youtube-search-lua-screen1](images/mpv-youtube-search-lua-screen1.gif)

IVE CHANGED DEFAULT ORIGINAL SCRIPT'S KEYBINDINGS TO:
- open the search page with F5
- press F5 again to open a search. 
(Alternatively, F6 can be used at any time to open a search.)
- Esc can be used to close the page.
- Enter will open the selected item
- Shift+Enter will append the item to the playlist.
- Ctrl+Enter will play selection in new window

Just cause old ones weren't working for me, but you can set as you wish by changing those:

[~/.config/mpv/scripts/youtube-search.lua]
```
-- 'ENTER' PLAYS SELECTED ITEM INSTANTLY, RESETTING THE PLAYLIST
table.insert(list.keybinds, {"ENTER", "play", function() play_result("replace") end, {}})

-- 'SHIFT+ENTER' APPENDS SELECTION TO THE PLAYLIST
table.insert(list.keybinds, {"Shift+ENTER", "play_append", function() play_result("append-play") end, {}})

-- 'CTRL+ENTER' PLAYS VIDEO IN NEW WINDOW 
table.insert(list.keybinds, {"Ctrl+ENTER", "play_new_window", function() play_result("new_window") end, {}})

-- OPEN NEW SEARCH QUERY
mp.add_key_binding("F6", "yt", open_search_input)

-- SHOW RECENT SEARCH RESULTS LIST / PRESS AGAIN TO OPEN NEW SEARCH QUERY
mp.add_key_binding("F5", "youtube-search", function()
```

__DISCLAIMER__
--------------

© 2026 fidodido48. This project is licensed under the the MIT License - see the LICENSE file for details.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-----------------------------------------------------------------------
