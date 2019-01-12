-----------------------------------------------------------------------------------------------------------------
-- MijnAfvalWijzer huisvuil script: script_time_afvalwijzer.lua
-----------------------------------------------------------------------------------------------------------------
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the timing when to get a notification for each Afvaltype in the afvaltype_cfg table
-- Check forumtopic:       https://www.domoticz.com/forum/viewtopic.php?f=61&t=17963
-- Check source updates:   https://github.com/jvanderzande/mijnafvalwijzer
-- Link to WebSite:        http://json.mijnafvalwijzer.nl/?method=postcodecheck&postcode=6137LP&street=&huisnummer=15&toevoeging
-- The following information can also be saved to alvalwijzerconfig.lua to avoid having to update it each time, your choice :)
--
myAfvalDevice='Container'                                -- The Text devicename in Domoticz
ShowNextEvents = 3                                       -- indicate the next x events to show in the TEXT Sensor in Domoticz
Postcode='your-zip-here'                                 -- Your postalcode
Huisnummer='your-housenr-here'                           -- Your housnr
NotificationEmailAdress = "your-email-address(es)-here"  -- Specify your Email Address for the notifications

-- Switch on Debugging in case of issues => set to true/false=======
debug = false  -- get debug info in domoticz console/log

-- ### define a line for each afvaltype_cfg retuned by the webrequest:
   -- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
   -- daysbefore ==> 0 means that the notification is send on the day of the planned garbage collection
   -- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
   -- reminder   ==> Will send a second reminder after x hours. 0=no reminder (needs to be in the same day!)
   -- text       ==> define the text for the notification.

afvaltype_cfg = {
   ["restafval"]     ={hour=19,min=01,daysbefore=1,reminder=0,text="Grijze Container met Restafval"},
   ["gft"]           ={hour=19,min=01,daysbefore=1,reminder=0,text="Groene Container met Tuinfval"},
   ["pmd"]           ={hour=19,min=01,daysbefore=1,reminder=0,text="Oranje Container met Plastic en Metalen"},
   ["kerstbomen"]    ={hour=19,min=01,daysbefore=1,reminder=0,text="Kerstbomen"},
   ["takken"]        ={hour=19,min=01,daysbefore=1,reminder=0,text="snoeiafval"},
   ["papier"]        ={hour=12,min=05,daysbefore=0,reminder=0,text="Blauwe Container met Oud papier"},
   ["plastic"]       ={hour=19,min=01,daysbefore=1,reminder=0,text="plastic en drankenkartons"},
   ["grofvuil"]      ={hour=19,min=01,daysbefore=1,reminder=0,text="grofvuil/oud ijzer"},
   ["tuinafval"]     ={hour=19,min=01,daysbefore=1,reminder=0,text="tuinafval"},
-- Add any missing records above this line
   ["dummy1"]        ={hour=12,min=16,daysbefore=0,reminder=0,text="dummy to trigger update for testing"},
   ["dummy2"]        ={hour=02,min=10,daysbefore=0,reminder=0,text="dummy to trigger update of text sensor at night"}}

-- Define the Notification Title and body text. there are 3 variables you can include:
-- @DAG@ = Will be replaced by (vandaag/morgen/over x dagen)
-- @AFVALTYPE@ = Will be replaced by the AfvalType found on the internet
-- @AFVALTEXT@ = Will be replaced by the content of the text field for the specific AfvalType in afvaltype_cfg
-- @AFVALDATE@ = Will be replaced by the pickup date found on the internet
notificationtitle = '@AFW: @DAG@ de @AFVALTEXT@ aan de weg zetten!'
notificationtext  = '@DAG@ wordt de @AFVALTEXT@ opgehaald!'
--==== end of config ========================================================================================================================
local nMON={"jan","feb","maa","apr","mei","jun","jul","aug","sep","okt","nov","dec"}
-- debug print
function dprint(text)
   if debug then print("@AFW:"..text) end
end
-- FileExits
function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end
-- check if Userconfig file exists and include that when it does.
if (file_exists("alvalwijzerconfig.lua")) then
   dofile("alvalwijzerconfig.lua")
   dprint("Using user config file: alvalwijzerconfig.lua")
end
-- load JSON lib
JSON = require "JSON";
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
function getdaysdiff(i_afvaltype_date)
   local curTime = os.time{day=timenow.day,month=timenow.month,year=timenow.year}
   -- check if date in variable i_afvaltype_date contains "vandaag" in stead of a valid date -> use today's date
   afvalyear,afvalmonth,afvalday=i_afvaltype_date:match("(%d-)-(%d-)-(%d-)$")
   if (afvalday == nil or afvalmonth == nil or afvalyear == nil) then
      print ('@AFW Error: No valid date found in i_afvaltype_date: ' .. i_afvaltype_date)
      return
   end
   local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
   local fdate =  afvalday.." "..nMON[tonumber(afvalmonth)].." "..afvalyear

   dprint("...gerd-> diff:"..Round(os.difftime(afvalTime, curTime)/86400,0).. "  afvalyear:"..tostring(afvalyear).."  afvalmonth:"..tostring(afvalmonth).."  afvalday:"..tostring(afvalday))   --
   -- return number of days diff
   return fdate,Round(os.difftime(afvalTime, curTime)/86400,0)   -- 1 day = 86400 seconds
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
      commandArray['SendEmail'] = notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress
      dprint ('Notification send for ' .. s_afvaltype.. "  title:|"..notificationtitle.. "|  body:|"..notificationtext.."|")
   end
end

-- Do the actual update retrieving data from the website and processing it
function Perform_Update()
   dprint('=== web update ================================')
   local sQuery	= 'curl "https://json.mijnafvalwijzer.nl/?method=postcodecheck&postcode='..Postcode..'&street=&huisnummer='..Huisnummer..'&toevoeging" 2>nul'
   local handle=assert(io.popen(sQuery))
   local jresponse = handle:read('*all')
   handle:close()
   --~ print(jresponse)
   if ( jresponse == "" ) then
      print("@AFW Error: Empty result from curl command")
      return
   end
   if ( jresponse:sub(1,3) == "NOK" ) then
      print("@AFW Error: Check your Postcode and Huisnummer as we get an NOK response.")
      return
   end
   -- Decode JSON table
   decoded_response = JSON:decode(jresponse)
   rdata = decoded_response["data"]
   if type(rdata) ~= "table" then
      print("@AFW: Empty data table in JSON data...  stopping execution.")
      return
   end
   rdata = rdata["ophaaldagen"]
   if type(rdata) ~= "table" then
      print("@AFW: Empty data.ophaaldagen table in JSON data...  stopping execution.")
      return
   end
   rdata = rdata["data"]
   if type(rdata) ~= "table" then
      print("@AFW: Empty data.ophaaldagen.data table in JSON data...  stopping execution.")
      return
   end
   -- get the next number of ShowNextEvents
   dprint("- start looping through received data -----------------------------------------------------------")
--~    for i = 1, ShowNextEvents do
   local missingrecords=""
   local txt=""
   local txtcnt = 0
   for i = 1, #rdata-1 do
      record = rdata[i]
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
               dprint("web_afvaltype:"..tostring(web_afvaltype).."   web_afvaldate:"..tostring (web_afvaldate))
               -- Get days diff
               fdate,daysdiffdev = getdaysdiff(web_afvaldate)
               -- When days is 0 or greater the date is today or in the future. Ignore any date in the past
               if daysdiffdev == nil then
                  dprint ('Invalid date from web for : ' .. web_afvaltype..'   date:'..web_afvaldate)
               elseif daysdiffdev >= 0 then
                  -- Set the nextdate for this afvaltype
                  afvaltype_cfg[web_afvaltype].nextdate = web_afvaldate
                  -- fill the text with the next defined number of events
                  if txtcnt < ShowNextEvents then
                     txt = txt..fdate .. " -> " .. web_afvaltype .. "\r\n"
                     txtcnt = txtcnt + 1
                  end
                  notification(web_afvaltype,web_afvaldate,daysdiffdev)  -- check notification for new found info
               end
            end
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
   dprint("afvaltype_cfg :"..tostring(avtype)..";"..tostring(afvaltype_cfg[avtype].hour)..";"..tostring(afvaltype_cfg[avtype].min))
   if (timenow.hour==afvaltype_cfg[avtype].hour
   or  timenow.hour==afvaltype_cfg[avtype].hour+afvaltype_cfg[avtype].reminder)
   and timenow.min==afvaltype_cfg[avtype].min then
      needupdate = true
   end
end
-- get information from website, update device and send notification when required
if needupdate then
   Perform_Update()
else
   dprint("Scheduled time(s) not reached yet, so nothing to do!")
end

return commandArray
