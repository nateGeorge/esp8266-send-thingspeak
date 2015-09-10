--ThingSpeak IP Address: 184.106.153.149

--POST /update HTTP/1.1
--Host: api.thingspeak.com
--Connection: close
--X-THINGSPEAKAPIKEY: (Write API Key)
--Content-Type: application/x-www-form-urlencoded
--Content-Length: (number of characters in message)

--field1=(Field 1 Data)&field2=(Field 2 Data)&field3=(Field 3 Data)&field4=(Field 4 Data)&field5=(Field 5 Data)&field6=(Field 6 Data)&field7=(Field 7 Data)&field8=(Field 8 Data)&lat=(Latitude in Decimal Degrees)&long=(Longitude in Decimal Degrees)&elevation=(Elevation in meters)&status=(140 Character Message);

-- ***************************************************************************
-- data.sparkfun posting module for ESP8266 with nodeMCU
--
-- Written by Nate George
--
-- MIT license, http://opensource.org/licenses/MIT
-- ***************************************************************************

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

function M.sendData(fileName, dataToSend, fields, debug, callback)
    -- dataToSend is a table of data to send, 
    -- each entry is a table, with names of fields as first value in each entrytable
    -- the second value is the data
    -- if you want to specify exact fields, use fields = true,
    -- and make the third value in each dataToSend table the field number
    -- callback is a file to run upon recieving a response from the server
    wifi.sta.connect()
    loadKeys(fileName)
    debug = debug or false
    fields = fields or false
    tmr.alarm(1,1000,1,function()
        if debug then
            print("connecting")
        end
        if (wifi.sta.status()==5) then
            if debug then
                print("connected")
            end
            sk = net.createConnection(net.TCP, 0)
            sk:on("reconnection",function(conn) print("socket reconnected") end)
            sk:on("disconnection",function(conn) print("socket disconnected") end)
            sk:on("receive", function(conn, msg)
                if debug then
                    print(msg)
                end
                local status
                _, _, status = string.find(msg, "Status: (.+)\r\n")
                print("status: "..status)
                print(status=='200 OK') -- having a problem - next message is recieved before the code gets here
                if (status=='200 OK') then
                    print('successful send')
                else
                    print('unsuccessful send')
                end
                collectgarbage()
                if callback~=nil then
                    print('running callback file')
                    dofile(callback)
                end
            end)
            sk:on("connection",function(conn)
                if debug then
                    print("socket connected")
                    print("sending...")
                end
                local dataStr = ""
                sendStr = "POST /update HTTP/1.1\r\n"
                if fields then
                    for num, arr in ipairs(dataToSend) do
                        print(num, arr[1], arr[2], "field "..tostring(arr[3]))
                        if (num>1) then
                            dataStr = dataStr.."&"
                        end
                        dataStr = dataStr.."field"..tostring(arr[3]).."="..arr[2];
                    end
                else
                    for num, arr in ipairs(dataToSend) do
                        print(num, arr[1], arr[2])
                        if (num>1) then
                            dataStr = dataStr.."&"
                        end
                        dataStr = dataStr.."field"..tostring(num).."="..arr[2];
                        print(node.heap())
                    end
                end
                sendStr = sendStr.."Host: "..address.."\r\n"
                sendStr = sendStr.."Connection: close\r\n"
                sendStr = sendStr.."X-THINGSPEAKAPIKEY: "..writeKey.."\r\n"
                sendStr = sendStr.."Content-Type: application/x-www-form-urlencoded\r\n"
                sendStr = sendStr.."Content-Length: "..string.len(dataStr).."\r\n\r\n"
                print(node.heap())
                sendStr = sendStr..dataStr.."\r\n"
                print(node.heap())
                conn:send(sendStr)
                if debug then
                    conn:on("sent",function() print("sent!") end)
                end
                print(sendStr)
            end)
            sk:connect(80, address)
            tmr.stop(1)
        end
    end)
end

return M
