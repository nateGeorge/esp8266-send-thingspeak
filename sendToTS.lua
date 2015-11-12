-- ***************************************************************************
-- data.sparkfun posting module for ESP8266 with nodeMCU
--
-- I have found with nodemcu devkits I sometimes need to compile the file
-- due to memory limitations
--
-- Written by Nate George
--
-- MIT license, http://opensource.org/licenses/MIT
--
-- Instructions:
-- 1. Load keys using either the loadKeys or setKey function.
-- 2. Get data ready to send using the setValue function.
-- 3. Send data using the sendData function.
-- 
-- Example:
-- sendToTS = require('sendToTS')
-- sendToTS.setKey('YOUR_API_WRITE_KEY')
-- valSet = sendToTS.setValue(1,12) -- channel, data.  sendToTS returns a boolean, true if set successfully
-- sendToTS.sendData(true, 'callbackfile.lua') -- show debug msgs, callback file
-- sendToTS = nil
-- package.loaded["sendToTS"]=nil -- these last two lines help free up memory
--
-- the file 'callbackfile.lua' will be run after the data has been sent
-- ***************************************************************************

local moduleName = ...
local M = {}
_G[moduleName] = M

local NUMBER_OF_FIELDS = 9
local values = {}
local address = "184.106.153.149" -- IP for api.thingspeak.com
local readKey
local writeKey
local channelID
local sk

function M.loadKeys(fileName)
    if file.open(fileName) then
        local line = file.readline()
        channelID = string.sub(line,1,string.len(line)-1) -- hack to remove CR/LF
        line = file.readline()
        readKey = string.sub(line,1,string.len(line)-1)
        line = file.readline()
        writeKey = string.sub(line,1,string.len(line)-1)
        file.close()
    end
end

function M.setKey(privateKey)
    writeKey = privateKey
end

function M.setAddr(addr)
    -- for setting an IP address other than thingspeak
    address = addr
end

function M.setValue(fieldId, fieldValue)
    if(fieldId < 1 or fieldId > NUMBER_OF_FIELDS) then
        return false;
    end
    values[fieldId] = fieldValue;
    return true;
end

local function composeQuery()
    local result = "/update?key=" .. writeKey
    local ct
    for ct=1, NUMBER_OF_FIELDS, 1 do
        if values[ct] ~= nil then
            local fieldParameter = "&field" .. tostring(ct) .. "=" .. tostring(values[ct]);
            result = result .. fieldParameter;
            values[ct] = nil;
        end
    end
    return result;
end

function M.sendData(debug, callback)
    -- dataToSend is a table of data to send, 
    -- each entry is a table, with names of fields as first value in each entrytable
    -- the second value is the data
    -- e.g.
    -- dataToSend = {}
    -- dataToSend[1] = {'water level', 5}
    --
    -- If you want to specify exact fields, use fields = true,
    -- and make the third value in each dataToSend table the field number
    --
    -- callback is a file to run upon recieving a response from the server
    if writeKey ==nil then
        print("The API write key hasn't been set yet! Use sendToTS.setKey('yourAPIreadkey') to set it before reading data.")
        return false
    end
    wifi.sta.connect()
    local debug = debug or false
    local fields = fields or false
    tmr.alarm(3,1000,1,function()
        if debug then
            print("connecting")
            print(node.heap())
        end
        if (wifi.sta.status()==5) then
            tmr.stop(3)
            -- timeout incase it can't connect for some reason
            tmr.alarm(1, 5*60*1000, 0, function()
                node.restart()
            end)
            if debug then
                print("connected")
            end
            sk = net.createConnection(net.TCP, 0)
            sk:on("reconnection",function(conn) if debug then print("socket reconnected") end end)
            sk:on("disconnection",function(conn) 
                if debug then
                    print("socket disconnected, running callback")
                end
                if callback~=nil then
                    dofile(callback)
                end
                return false
            end)
            sk:on("receive", function(conn, msg)
                if debug then
                    print(msg)
                end
                local status, status2, postStatus
                _, _, status = string.find(msg, "Status: (200 OK)")
                _, _, status2 = string.find(msg, "Status: (.+)\r\n")
                _, _, postStatus = string.find(msg, "%d+\r\n%d+\r\n0")
                if debug then
                    print(postStatus)
                    if postStatus~=0 and postStatus~=nil then
                        print('successfully updated')
                    end
                    if status=='200 OK' then
                        print('successful send')
                        print('checked status: '..status)
                    else
                        print('unsuccessful send')
                        print('checked status: '..status)
                    end
                end
                if status~=nil then
                    if debug then
                        print('successful send')
                    end
                    local result = true
                else
                    if debug then
                        print('no success')
                    end
                    local result = false
                end
                if debug then
                    print("found status: "..status)
                    print(status=='200 OK') -- having a problem - next message is recieved before the code gets here
                end
                collectgarbage()
                tmr.stop(1)
                if callback~=nil then
                    if debug then
                        print('running callback file')
                    end
                    collectgarbage()
                    dofile(callback)
                end
                return result
            end)
            sk:on("connection",function(conn)
                if debug then
                    print("socket connected")
                    print("sending...")
                end
                local sendStr
                local query = composeQuery()
                sendStr = "POST /update HTTP/1.1\r\n"
                sendStr = sendStr.."Host: "..address.."\r\n"
                sendStr = sendStr.."Connection: close\r\n"
                sendStr = sendStr.."X-THINGSPEAKAPIKEY: "..writeKey.."\r\n"
                sendStr = sendStr.."Content-Type: application/x-www-form-urlencoded\r\n"
                sendStr = sendStr.."Content-Length: "..string.len(query).."\r\n\r\n"
                sendStr = sendStr..query.."\r\n"
                conn:send(sendStr)
                if debug then
                    conn:on("sent",function() if debug then print("sent!") end end)
                end
                if debug then
                    print(sendStr)
                end
                collectgarbage()
            end)
            sk:connect(80, address)
        end
    end)
end

return M
