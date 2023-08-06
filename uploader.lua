local console_log_raw
if (file.Exists("logs/latest.log", "GAME")) then
    console_log_raw = file.Read("logs/latest.log", "GAME")
else
    console_log_raw = file.Read("console.log", "GAME")
end

if !console_log_raw then
  MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "You either need to enable condebug on your server, or your console log is empty.", "\\n")
  return
end

MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "Plucking your console log...", "\\n")

local console_log_lines = string.Explode("\\n", console_log_raw)
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
    console_log = console_log .. latest_console_log_rev[i] .. "\\n"
end

MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "Sending your console log to GmodStore...", "\\n")

local boundary = "abcd"
local header_b = 'Content-Disposition: form-data; name="file"; filename="console.log"\\r\\nContent-Type: application/octet-stream\\r\\n'
local file_content =  "--" ..boundary .. "\\r\\n" ..header_b .."\\r\\n".. console_log .. "\\r\\n--" .. boundary .."--\\r\\n"

local request = {
    url = "https://www.gmodstore.com/api/v3/tickets/{{ticketId}}/attachments",
    method = "POST",
    headers = {
        ["Content-Length"] = file_content:len(),
        ["Authorization"] = "Bearer {{bearerToken}}"
    },
    success = function(status_code, body)
        if (status_code ~= 201) then
            MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "HTTP Error " .. status_code .. " " .. body, "\\n")
        else
            MsgC(Color(255,0,0), "[GMS] ", Color(255,255,255), "Successfully uploaded your console log to your GmodStore support ticket ", "\\n")
        end
    end,
    type = "multipart/form-data; boundary=" .. boundary,
    body = file_content
}

HTTP(request)
