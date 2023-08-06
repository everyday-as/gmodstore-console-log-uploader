local console_log_raw
if (file.Exists("logs/latest.log", "GAME")) then
    console_log_raw = file.Read("logs/latest.log", "GAME")
else
    console_log_raw = file.Read("console.log", "GAME")
end

if !console_log_raw then
  MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "You either need to enable condebug on your server, or your console log is empty.", "\n")
  return
end

MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "Plucking your console log...", "\n")

local console_log_lines = string.Explode("\n", console_log_raw)
local latest_console_log_rev = {}

for i = #console_log_lines, 1, -1 do
    local v = console_log_lines[i]
    latest_console_log_rev[#latest_console_log_rev + 1] = v
    if (v == "WS: No +host_workshop_collection or it is invalid!" or v:sub(1,34) == "WS: Waiting for Steam to log us in") then
        break
    end
end

local console_log = ""
for i = #latest_console_log_rev, 1, -1 do
    console_log = console_log .. latest_console_log_rev[i] .. "\n"
end

-- Get some useful information
local ip_address = game.GetIPAddress()
local server_name = GetConVar("hostname"):GetString()
local gamemode = (GM or GAMEMODE).Name
if ((GM or GAMEMODE).BaseClass) then
    gamemode = gamemode .. " (derived from " .. (GM or GAMEMODE).BaseClass.Name .. ")"
end
local avg_ping = 0
for _,v in ipairs(player.GetHumans()) do
    avg_ping = avg_ping + v:Ping()
end
avg_ping = tostring(math.Round(avg_ping / #player.GetHumans()))

-- Add the useful information at the top of the console log
local console_log_header = "[[ Server details ]]\n"
console_log_header = console_log_header .. "Server name: ".. server_name .."\n"
console_log_header = console_log_header .. "IP Address: ".. ip_address .."\n"
console_log_header = console_log_header .. "Gamemode: ".. gamemode .."\n"
console_log_header = console_log_header .. "Average ping: ".. avg_ping .."\n"
console_log_header = console_log_header .. "\n[[ Console log ]]\n\n"

console_log = console_log_header .. console_log

MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "Sending your console log to GmodStore...", "\n")

-- Prepare and send a multipart/form-data HTTP request to the GmodStore API
local boundary = "abcd"
local header_b = 'Content-Disposition: form-data; name="file"; filename="console.log"\r\nContent-Type: application/octet-stream\r\n'
local file_content =  "--" ..boundary .. "\r\n" ..header_b .."\r\n".. console_log .. "\r\n--" .. boundary .."--\r\n"

local request = {
    url = "https://www.gmodstore.com/api/v3/tickets/{{ticketId}}/attachments",
    method = "POST",
    headers = {
        ["Content-Length"] = file_content:len(),
        ["Authorization"] = "Bearer {{bearerToken}}"
    },
    success = function(status_code, body)
        if (status_code ~= 201) then
            MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "HTTP Error " .. status_code .. " " .. body, "\n")
        else
            MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "Successfully uploaded your console log to your GmodStore support ticket ", "\n")
        end
    end,
    type = "multipart/form-data; boundary=" .. boundary,
    body = file_content
}

HTTP(request)
