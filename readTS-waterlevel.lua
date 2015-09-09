local moduleName = ...
local M = {}
_G[moduleName] = M

local address = "184.106.153.149" -- IP for api.thingspeak.com

local function loadKeys(fileName)
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

function M.readData(fileName, debug, numResults)
    -- dataToSend is a table of data to send, 
    -- each entry is a table, with names of fields as first value in each entrytable
    -- the second value is the data
    -- if you want to specify exact fields, use fields = true,
    -- and make the third value in each dataToSend table the field number
    -- fileName is name of file containing channelID and API keys
    wifi.sta.connect()
    loadKeys(fileName)
    debug = debug or false
    numResults = numResults or 100
        tmr.alarm(1, 1000, 1, function()
        if debug then
            print("connecting")
        end
        if (wifi.sta.status()==5) then
            if debug then
                print("connected")
            end
            sk = net.createConnection(net.TCP, 0)
            sk:on("reconnection", function(conn) 
            if debug then
                print("socket reconnected")
            end
            end)
            sk:on("disconnection", function(conn) 
            if debug then
                print("socket disconnected")
            end
            end)
            sk:on("connection", function(conn)
            if debug then
                print("socket connected")
            end
            end)
            sk:on("receive", function(conn, msg)
                if debug then
                    print(msg)
                end
                local i, j, at4ft = string.find(msg, "\"field4\":\"(%d)\",")
                print(at4ft)
                local i, j, at2ft = string.find(msg, "\"field2\":\"(%d)\",")
                print(at4ft)
                local i, j
                i, j, waterHeight = string.find(msg, "\"field6\":\"(%d)\",")
                print(waterHeight)
                waterHeight = tonumber(waterHeight)
                if (waterHeight<=2) then
                    waterEmpty = true
                    waterFull = false
                    print('water empty')
                elseif (waterHeight>=4) then
                    waterEmpty = false
                    waterFull = true
                    print('water full')
                end
                collectgarbage()
                dofile('managePump.lua')
            end)
            sk:on("connection", function(conn)
                if debug then
                    print("socket connected")
                    print("getting data...")
                    print(node.heap())
                    collectgarbage()
                    print(node.heap())
                end
                sendStr = "GET /channels/"..channelID.."/feed.json?key="..readkey
                print(node.heap())
                print('numresults: '..numResults)
                if (numResults~=100) then
                    print('num results set to '..numResults)
                    sendStr = sendStr.."&results="..tostring(numResults)
                end
                print(node.heap())
                sendStr = sendStr.."HTTP/1.1\r\n"
                print(node.heap())
                sendStr = sendStr.."Host: "..address.."\r\n"
                sendStr = sendStr.."Connection: close\r\n"
                sendStr = sendStr.."Accept: */*\r\n"
                sendStr = sendStr.."User-Agent: Mozilla/4.0 (compatible; ESP8266;)\r\n"
                sendStr = sendStr.."\r\n"
                print(node.heap())
                conn:send(sendStr)
                if debug then
                    conn:on("sent", function() print("sent!") end)
                end
                print(sendStr)
            end)
            sk:connect(80, address)
            tmr.stop(1)
        end
    end)
end

return M
