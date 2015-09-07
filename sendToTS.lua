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

local function loadKeys()
    if file.open('keys') then
        local line = file.readline()
        readKey = string.sub(line,1,string.len(line)-1) -- hack to remove CR/LF
        line = file.readline()
        writeKey = string.sub(line,1,string.len(line)-1)
        file.close()
    end
end

function M.sendData(dataToSend, fields, debug, readkey, writekey)
    -- dataToSend is a table of data to send, 
    -- each entry is a table, with names of fields as first value in each entrytable
    -- the second value is the data
    -- if you want to specify exact fields, use fields = true,
    -- and make the third value in each dataToSend table the field number
    wifi.sta.connect()
    loadKeys()
    readkey = readkey or readKey
    writekey = writekey or writeKey
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
                --local success = nil
                --_,_,success = string.find(msg, "(success)")
                --print(success)
                --if (success==nil) then
                --    print('unsucessful send')
                --else
                --    print("great success, very nice, I like")
                --end
                --print(node.heap())
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
                    end
                end
                sendStr = sendStr.."Host: "..address.."\r\n"
                .."Connection: close\r\n"
                .."X-THINGSPEAKAPIKEY: "..writekey.."\r\n"
                .."Content-Type: application/x-www-form-urlencoded\r\n"
                .."Content-Length: "..string.len(dataStr).."\r\n\r\n"
                ..dataStr.."\r\n"
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
