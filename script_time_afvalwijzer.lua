-----------------------------------------------------------------------------------------------------------------
-- MijnAfvalWijzer huisvuil script: script_time_afvalwijzer.lua
----------------------------------------------------------------------------------------------------------------
ver="20200205-16:10"
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the timing when to get a notification for each Afvaltype in the afvaltype_cfg table
-- Check forumtopic:       https://www.domoticz.com/forum/viewtopic.php?f=61&t=17963
-- Check source updates:   https://github.com/jvanderzande/mijnafvalwijzer
-- Link to WebSite:        http://json.mijnafvalwijzer.nl/?method=postcodecheck&postcode=6137LP&street=&huisnummer=15&toevoeging
--
myAfvalDevice = 'Container'         -- The Text devicename in Domoticz
ShowNextEvents = 3                  -- indicate the next x events to show in the TEXT Sensor in Domoticz
Postcode = 'your-zip-here'          -- Your postalcode
Huisnummer = 'your-housenr-here'    -- Your housnr
NotificationEmailAdress = ""        -- Specify your Email Address for the notifications. Leave empty to skip email notification
--NotificationEmailAdress = {"",""} -- Specify multiple Email Addresses for the notifications. Leave empty to skip email notification
Notificationsystem = ""             -- Specify notification system eg "telegram/pushover/gcm/http/kodi/lms/nma/prowl/pushalot/pushbullet/pushsafer" leave empty to skip

-- Switch on Debugging in case of issues => set to true/false=======
debug = false

-- ### define format for text device
   -- date options:
   --    wd  = weekday in 3 characters   eg Zon;Maa;Din
   --    dd  = day in 2 digits   eg 31
   --    mm  = month in 2 digits eg 01
   --    mmm = month abbreviation in 3 characters eg : jan
   --    yy   = year in 2 digits eg 19
   --    yyyy = year in 4 digits eg 2019
   -- Afvaltype description options
   --    sdesc = short afvaltype description from Website  eg pmd
   --    ldesc = Long afvaltype description from Website   eg Plastic, Metalen en Drankkartons
   --    tdesc = Use the description available in the table text field
textformat = "dd mmm yy ldesc"

-- ### define a line for each afvaltype_cfg returned by the webrequest:
   -- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
   -- daysbefore ==> 0 means that the notification is send on the day of the planned garbage collection
   -- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
   -- reminder   ==> Will send a second reminder after x hours. 0=no reminder (needs to be in the same day!)
   -- text       ==> define the text for the notification.

afvaltype_cfg = {
   ["restafval"]     ={hour=19,min=01,daysbefore=1,reminder=0,text="Grijze Container met Restafval"},
   ["gft"]           ={hour=19,min=01,daysbefore=1,reminder=0,text="Groene Container met Tuinafval"},
   ["pmd"]           ={hour=19,min=01,daysbefore=1,reminder=0,text="Oranje Container met Plastic en Metalen"},
   ["kca"]           ={hour=19,min=01,daysbefore=1,reminder=0,text="kca"},
   ["kerstbomen"]    ={hour=19,min=01,daysbefore=1,reminder=0,text="Kerstbomen"},
   ["takken"]        ={hour=19,min=01,daysbefore=1,reminder=0,text="snoeiafval"},
   ["papier"]        ={hour=12,min=05,daysbefore=0,reminder=0,text="Blauwe Container met Oud papier"},
   ["plastic"]       ={hour=19,min=01,daysbefore=1,reminder=0,text="plastic en drankenkartons"},
   ["grofvuil"]      ={hour=19,min=01,daysbefore=1,reminder=0,text="grofvuil/oud ijzer"},
   ["tuinafval"]     ={hour=19,min=01,daysbefore=1,reminder=0,text="tuinafval"},
-- Add any missing records above this line
   ["dummy1"]        ={hour=02,min=10,daysbefore=0,reminder=0,text="dummy to trigger update for testing"},
   ["dummy2"]        ={hour=02,min=10,daysbefore=0,reminder=0,text="dummy to trigger update of text sensor at night"}}

-- Define the Notification Title and body text. there are 3 variables you can include:
-- @DAG@ = Will be replaced by (vandaag/morgen/over x dagen)
-- @AFVALTYPE@ = Will be replaced by the AfvalType found on the internet
-- @AFVALTEXT@ = Will be replaced by the content of the text field for the specific AfvalType in afvaltype_cfg
-- @AFVALDATE@ = Will be replaced by the pickup date found on the internet
notificationtitle = '@AFW: @DAG@ de @AFVALTEXT@ aan de weg zetten!'
notificationtext  = '@DAG@ wordt de @AFVALTEXT@ opgehaald!'
--==== end of config ========================================================================================================================

-- General conversion tables
local nMON={"jan","feb","maa","apr","mei","jun","jul","aug","sep","okt","nov","dec"}
-- debug print
function dprint(text)
   if debug then print("@AFW:"..text) end
end

-------------------------------------------------------
-- try to load JSON default library
function loaddefaultjson()
   if unexpected_condition then error() end
   JSON = require "JSON"     -- use generic JSON.lua
end
-- try to load JSON.lua from the domoticz setup
function loaddomoticzjson()
   if unexpected_condition then error() end
   JSON = (loadfile "/home/pi/domoticz/scripts/lua/JSON.lua")()  -- Use default Domoticz JSON.lua
end
-- Load JSON.lua
if pcall(loaddefaultjson) then
   dprint('Loaded default JSON.lua.' )
else
   dprint('Failed loading default JSON.lua... trying /home/pi/domoticz/scripts/lua/JSON.lua' )
   if pcall(loaddomoticzjson) then
      dprint('Loaded JSON.lua.' )
   else
      print('@AFW Error: failed loading default JSON.lua and /home/pi/domoticz/scripts/lua/JSON.lua.')
      print('@AFW Error: Please check your setup and try again.' )
      return
   end
end
-------------------------------------------------------
-- round function
function Round(num, idp)
   return tonumber(string.format("%." ..(idp or 0).. "f", num))
end
-- run program and return captured output
function os.capture(cmd, rep)  -- execute command to get site
   -- rep is nr of repeats if result is empty
   local r = rep or 1
   local s = ""
   while ( s == "" and r > 0) do
      r = r-1
      local f = assert(io.popen(cmd, 'r'))
      s = assert(f:read('*a'))
      f:close()
   end
   if ( rep - r > 1 ) then
      print("os.capture needed more than 1 call: " .. rep-r)
   end
   return s
end
-- get days between today and provided date
function getdaysdiff(i_afvaltype_date, stextformat)
   local curTime = os.time{day=timenow.day,month=timenow.month,year=timenow.year}
   -- check if date in variable i_afvaltype_date contains "vandaag" in stead of a valid date -> use today's date
   afvalyear,afvalmonth,afvalday=i_afvaltype_date:match("(%d-)-(%d-)-(%d-)$")
   if (afvalday == nil or afvalmonth == nil or afvalyear == nil) then
      print ('@AFW Error: No valid date found in i_afvaltype_date: ' .. i_afvaltype_date)
      return
   end
   local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
   local daysoftheweek={"Zon","Maa","Din","Woe","Don","Vri","Zat"}
   local wday=daysoftheweek[os.date("*t", afvalTime).wday]
   stextformat = stextformat:gsub('wd',wday)
   stextformat = stextformat:gsub('dd',afvalday)
   stextformat = stextformat:gsub('mmm',nMON[tonumber(afvalmonth)])
   stextformat = stextformat:gsub('mm',afvalmonth)
   stextformat = stextformat:gsub('yyyy',afvalyear)
   stextformat = stextformat:gsub('yy',afvalyear:sub(3,4))
   dprint("...gerd-> diff:"..Round(os.difftime(afvalTime, curTime)/86400,0).. "  afvalyear:"..tostring(afvalyear).."  afvalmonth:"..tostring(afvalmonth).."  afvalday:"..tostring(afvalday))   --
   -- return number of days diff
   return stextformat, Round(os.difftime(afvalTime, curTime)/86400,0)   -- 1 day = 86400 seconds
end

function notification(s_afvaltype,s_afvaltype_date,i_daysdifference)
   dprint("...Noti-> i_daysdifference:"..tostring(i_daysdifference).."  afvaltype_cfg[s_afvaltype].daysbefore:"..tostring(afvaltype_cfg[s_afvaltype].daysbefore).."  hour:"..tostring(afvaltype_cfg[s_afvaltype].hour).."  min:"..tostring(afvaltype_cfg[s_afvaltype].min))
   if afvaltype_cfg[s_afvaltype] ~= nil
   and (timenow.hour==afvaltype_cfg[s_afvaltype].hour or timenow.hour==afvaltype_cfg[s_afvaltype].hour+afvaltype_cfg[s_afvaltype].reminder)
   and timenow.min==afvaltype_cfg[s_afvaltype].min
   and i_daysdifference == afvaltype_cfg[s_afvaltype].daysbefore then
      local dag = ""
      if afvaltype_cfg[s_afvaltype].daysbefore == 0 then
         dag = "vandaag"
      elseif afvaltype_cfg[s_afvaltype].daysbefore == 1 then
         dag = "morgen"
      else
         dag = "over " .. tostring(afvaltype_cfg[s_afvaltype].daysbefore) .. " dagen"
      end
      notificationtitle = notificationtitle:gsub('@DAG@',dag)
      notificationtitle = notificationtitle:gsub('@AFVALTYPE@',s_afvaltype)
      notificationtitle = notificationtitle:gsub('@AFVALTEXT@',tostring(afvaltype_cfg[s_afvaltype].text))
      notificationtitle = notificationtitle:gsub('@AFVALDATE@',s_afvaltype_date)
      notificationtext = notificationtext:gsub('@DAG@',dag)
      notificationtext = notificationtext:gsub('@AFVALTYPE@',s_afvaltype)
      notificationtext = notificationtext:gsub('@AFVALTEXT@',tostring(afvaltype_cfg[s_afvaltype].text))
      notificationtext = notificationtext:gsub('@AFVALDATE@',s_afvaltype_date)
      if type(NotificationEmailAdress) == 'table' then
         for x,emailaddress in pairs(NotificationEmailAdress) do
            if emailaddress ~= "" then
               commandArray[x] = {['SendEmail'] = notificationtitle .. '#' .. notificationtext .. '#' .. emailaddress}
               dprint ('Notification Email send for ' .. s_afvaltype.. " |"..notificationtitle .. '#' .. notificationtext .. '#' .. emailaddress.."|")
            end
         end
      else
         if NotificationEmailAdress ~= "" then
            commandArray['SendEmail'] = notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress
            dprint ('Notification Email send for ' .. s_afvaltype.. " |"..notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress.."|")
         end
      end

      if Notificationsystem ~= "" then
         commandArray['SendNotification']=notificationtitle .. '#' .. notificationtext .. '####'..Notificationsystem
         dprint ('Notification send for '.. s_afvaltype.. " |"..notificationtitle .. '#' .. notificationtext .. '####'..Notificationsystem)
      end
   end
end

-- Do the actual update retrieving data from the website and processing it
function Perform_Update()
   local missingrecords=""
   local txt=""
   local txtcnt = 0
   -- function to process ThisYear and Lastyear JSON data
   function processdata(ophaaldata)
      for i = 1, #ophaaldata do
         record = ophaaldata[i]
         if type(record) == "table" then
            wnameType = record["nameType"]
            web_afvaltype = record["type"]
            web_afvaldate = record["date"]
            -- first match for each Type we save the date to capture the first next dates
            if afvaltype_cfg[web_afvaltype] == nil then
               print ('@AFW Error: Afvalsoort not defined in the "afvaltype_cfg" table for found Afvalsoort : ' .. web_afvaltype.."  desc:"..wnameType)
               missingrecords = missingrecords .. '   ["' .. web_afvaltype..'"]        ={hour=19,min=22,daysbefore=1,reminder=0,text="'..wnameType..'"},\n'
               afvaltype_cfg[web_afvaltype] = {hour=0,min=0,daysbefore=0,reminder=0,text="dummy"}
            else
               -- check whether the first nextdate for this afvaltype is already found to get only one next date per AfvalType
               if afvaltype_cfg[web_afvaltype].nextdate == nil and txtcnt < ShowNextEvents then
                  -- get the long description from the JSON data
                  dprint("web_afvaltype:"..tostring(web_afvaltype).."   web_afvaldate:"..tostring (web_afvaldate))
                  local stextformat = textformat
                  -- Get days diff
                  stextformat, daysdiffdev = getdaysdiff(web_afvaldate, stextformat)
                  -- When days is 0 or greater the date is today or in the future. Ignore any date in the past
                  if daysdiffdev == nil then
                     dprint ('Invalid date from web for : ' .. web_afvaltype..'   date:'..web_afvaldate)
                  elseif daysdiffdev >= 0 then
                     -- Set the nextdate for this afvaltype
                     afvaltype_cfg[web_afvaltype].nextdate = web_afvaldate
                     -- fill the text with the next defined number of events
                     if txtcnt < ShowNextEvents then
                        stextformat = stextformat:gsub('ldesc',rdesc[web_afvaltype:upper().."_L"])
                        stextformat = stextformat:gsub('sdesc',web_afvaltype)
                        stextformat = stextformat:gsub('tdesc', afvaltype_cfg[web_afvaltype].text)
                        txt = txt..stextformat.."\r\n"
                        txtcnt = txtcnt + 1
                     end
                     notification(web_afvaltype,web_afvaldate,daysdiffdev)  -- check notification for new found info
                  end
               end
            end
         end
      end
   end
   --
   print('AfvalWijzer module start update (v'..ver..')')
   dprint('=== web update ================================')
   local sQuery	= 'curl "https://json.mijnafvalwijzer.nl/?method=postcodecheck&postcode='..Postcode..'&street=&huisnummer='..Huisnummer..'&toevoeging" 2>nul'
   local handle=assert(io.popen(sQuery))
   local jresponse = handle:read('*all')
   handle:close()
   if ( jresponse == "" ) then
      print("@AFW Error: Empty result from curl command. Please check whether curl.exe is installed.")
      return
   end
   if ( jresponse:sub(1,3) == "NOK" ) then
      print("@AFW Error: Check your Postcode and Huisnummer as we get an NOK response.")
      return
   end
   -- strip bulk data from "ophaaldagenNext" till the end, because this is causing some errors for some gemeentes
   if ( jresponse:find('ophaaldagenNext')  == nil ) then
      print("@AFW Error: returned information does not contain the ophaaldagenNext section. stopping process.")
      return
   end
   jresponse=jresponse:match('(.-),\"mededelingen\":')
   jresponse=jresponse.."}}"
   --
   -- Decode JSON table
   decoded_response = JSON:decode(jresponse)
   rdata = decoded_response["data"]
   if type(rdata) ~= "table" then
      print("@AFW: Empty data table in JSON data...  stopping execution.")
      return
   end
   -- get the description records into rdesc to retrieve the long description
   rdesc = rdata["langs"]
   rdesc = rdesc["data"]
   -- get the ophaaldagen tabel for the coming scheduled pickups for this year
   rdataty = rdata["ophaaldagen"]
   if type(rdataty) ~= "table" then
      print("@AFW: Empty data.ophaaldagen table in JSON data...  stopping execution.")
      return
   end
   rdataty = rdataty["data"]
   if type(rdataty) ~= "table" then
      print("@AFW: Empty data.ophaaldagen.data table in JSON data...  stopping execution.")
      return
   end
   dprint("- start looping through this year received data -----------------------------------------------------------")
   processdata(rdataty)
   -- only process nextyear data in case we do not have the requested number of next events
   if txtcnt < ShowNextEvents then
      -- get the ophaaldagen tabel for next year when needed
      rdataly = rdata["ophaaldagenNext"]
      if type(rdataly) ~= "table" then
         print("@AFW: Empty data.ophaaldagen table in JSON data...  stopping execution.")
      else
         rdataly = rdataly["data"]
         if type(rdataly) ~= "table" then
            print("@AFW: Empty data.ophaaldagen.data table in JSON data...  stopping execution.")
         else
            -- get the next number of ShowNextEvents
            dprint("- start looping through next year received data -----------------------------------------------------------")
            processdata(rdataly)
         end
      end
   end
   dprint("-End   --------------------------------------------------------------------------------------------")
   if missingrecords ~= "" then
      print('#### -- start -- Add these records to local afvaltype_cfg = {')
      print(missingrecords)
      print('#### -- end ----------------------------')
   end
   if (cnt==0) then
      print ('@AFW Error: No valid data found in returned webdata.  skipping the rest of the logic.')
      return
   end
   -- always update the domoticz device so one can see it is updating and when it was ran last.
   print ('@AFW: Found:'..txt:gsub('\r\n', ' ; '))
   if otherdevices_idx == nil or otherdevices_idx[myAfvalDevice] == nil then
      print ("@AFW Error: Couldn't get the current data from Domoticz text device "..myAfvalDevice )
   else
      commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. txt
      if (otherdevices[myAfvalDevice] ~= txt) then
         print ('@AFW: Update device from: \n'.. otherdevices[myAfvalDevice] .. '\n replace with:\n' .. txt)
      else
         print ('@AFW: No updated text for TxtDevice.')
      end
   end
end

-- End Functions =========================================================================

-- Start of logic ========================================================================
commandArray = {}
timenow = os.date("*t")

-- check for notification times and run update only when we are at one of these defined times
dprint('AfvalWijzer module start check')
local needupdate = false
for avtype,get in pairs(afvaltype_cfg) do
   if afvaltype_cfg[avtype].reminder == nil then
      afvaltype_cfg[avtype].reminder = 0
   end
   dprint("afvaltype_cfg :"..tostring(avtype)..";"..tostring(afvaltype_cfg[avtype].hour)..";"..tostring(afvaltype_cfg[avtype].min))
   if (timenow.hour==afvaltype_cfg[avtype].hour
   or  timenow.hour==afvaltype_cfg[avtype].hour+afvaltype_cfg[avtype].reminder)
   and timenow.min==afvaltype_cfg[avtype].min then
      needupdate = true
   end
end
-- Always update when debugging
if debug then needupdate = true end
-- get information from website, update device and send notification when required
if needupdate then
   Perform_Update()
else
   dprint("Scheduled time(s) not reached yet, so nothing to do!")
end

return commandArray