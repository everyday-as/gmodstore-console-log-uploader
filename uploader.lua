-- Helper functions
local function gms_ternary (cond, T, F)
    if cond then return T else return F end
end

-- Locate the console log
local console_log_raw

local latest_log_path = "logs/latest.log"
local latest_log_time = 0

local console_log_path = "console.log"
local console_log_time = 0

if (file.Exists(latest_log_path, "GAME")) then
    latest_log_time = file.Time(latest_log_path, "GAME")
end

if (file.Exists(console_log_path, "GAME")) then
    console_log_time = file.Time(console_log_path, "GAME")
end

-- Grab the last modified file
local log_path = gms_ternary(console_log_time >= latest_log_time, console_log_path, latest_log_path)

MsgC(Color(0,255,0), "[GMS] ", color_white, "Reading console log from " .. log_path .. "...", "\n")

console_log_raw = file.Read(log_path, "GAME")

if !console_log_raw then
  MsgC(Color(255,0,0), "[GMS] ", color_white, "Your console log does not exist. Are you sure condebug is enabled on your server?", "\n")
  return
end

if #console_log_raw == 0 then
  MsgC(Color(255,0,0), "[GMS] ", color_white, "Your console log is empty. There is nothing to upload.", "\n")
  return
end

MsgC(Color(0,255,0), "[GMS] ", color_white, "Plucking your console log...", "\n")

local console_log_lines = string.Explode("\n", console_log_raw)
local latest_console_log_rev = {}

for i = #console_log_lines, 1, -1 do
    local v = console_log_lines[i]
    latest_console_log_rev[#latest_console_log_rev + 1] = v
    if (v == "WS: No +host_workshop_collection or it is invalid!" or v:sub(1,34) == "WS: Waiting for Steam to log us in") then
        break
    end
end

-- Throw an error if we have too many lines since start-up
if #latest_console_log_rev > 20000 then
  MsgC(Color(255,0,0), "[GMS] ", color_white, "Your console log is too big. Please delete it and restart your server. Remember to trigger the error you are experiencing before retrying.", "\n")
  return
end

local console_log = ""
for i = #latest_console_log_rev, 1, -1 do
    console_log = console_log .. latest_console_log_rev[i] .. "\n"
end

-- Get some useful information
local gamemode = (GM or GAMEMODE).Name
if ((GM or GAMEMODE).BaseClass) then
    gamemode = gamemode .. " (derived from " .. (GM or GAMEMODE).BaseClass.Name .. ")"
end

local humans = player.GetHumans()
local avg_ping = 0
for _,v in ipairs(humans) do
    avg_ping = avg_ping + v:Ping()
end

avg_ping = tostring(math.Round(avg_ping / #humans))

local addons_raw = select(2, file.Find("addons/*", "MOD"))
local addons = "none"
if (addons_raw) then
    addons = table.concat(addons_raw, ", ")
end

-- Add the useful information at the top of the console log
local console_log_header = "--- [[ Server details ]] ---\n"
console_log_header = console_log_header .. "Log path: " .. log_path .. "\n"
console_log_header = console_log_header .. "Server name: ".. GetConVar("hostname"):GetString() .."\n"
console_log_header = console_log_header .. "Is dedicated: ".. gms_ternary(game.IsDedicated(), "yes", "no") .."\n"
console_log_header = console_log_header .. "IP Address: ".. game.GetIPAddress() .."\n"
console_log_header = console_log_header .. "Gamemode: ".. gamemode .."\n"
console_log_header = console_log_header .. "Workshop collection: ".. GetConVar("host_workshop_collection"):GetString() .."\n"
console_log_header = console_log_header .. "Map: ".. game.GetMap() .."\n"
console_log_header = console_log_header .. "Players: ".. #humans .."\n"
console_log_header = console_log_header .. "Average ping: ".. avg_ping .."\n"
console_log_header = console_log_header .. "Entity count: ".. ents.GetCount() .."\n"
console_log_header = console_log_header .. "Uptime (SysTime): ".. string.NiceTime(SysTime()) .."\n"
console_log_header = console_log_header .. "Addons: ".. addons .."\n"
console_log_header = console_log_header .. "\n--- [[ Console log ]] ---\n"

console_log = console_log_header .. console_log

MsgC(Color(0,255,0), "[GMS] ", color_white, "Sending your console log to GmodStore...", "\n")

-- Prepare and send a multipart/form-data HTTP request to the GmodStore API
local boundary = "abcd"
local header_b = 'Content-Disposition: form-data; name="file"; filename="console.log"\r\nContent-Type: application/octet-stream\r\n'
local file_content =  "--" ..boundary .. "\r\n" ..header_b .."\r\n".. console_log .. "\r\n--" .. boundary .."--\r\n"

local request = {
    url = "https://www.gmodstore.com/api/v3/tickets/log-requests/{{logRequestId}}",
    method = "POST",
    headers = {
        ["Content-Length"] = file_content:len()
    },
    success = function(status_code, body)
        if (status_code ~= 201) then
            MsgC(Color(255,0,0), "[GMS] ", color_white, "HTTP request failed with status code " .. status_code .. ", and response body: " .. body, "\n")
        else
            MsgC(Color(0,255,0), "[GMS] ", color_white, "Successfully uploaded your console log to your GmodStore support ticket", "\n")
        end
    end,
    failed = function(reason)
        MsgC(Color(255,0,0), "[GMS] ", color_white, "HTTP request failed with reason: ".. reason ..". Please try again later.", "\n")
    end,
    type = "multipart/form-data; boundary=" .. boundary,
    body = file_content
}

HTTP(request)