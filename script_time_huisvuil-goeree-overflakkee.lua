-----------------------------------------------------------------------------------------------------------------
-- huisvuil script: script_time_huisvuil-goeree-overflakkee.lua
-- Script to get garbage collection for gemeentes Goeree-Overflakkee
-- links used:
--   Get Calendar: https://webadapter.watsoftware.nl/widget.aspx?version=3.7&action=3000001&xml=%3Cpostcode%3E'..Postcode..'%3C/postcode%3E%3Chuisnummer%3E'..Housenr..'%3C/huisnummer%3E%3Cguid%3EBCE23C06-E248-4300-B97F-E308A451C6B4%3C/guid%3E')
--
----------------------------------------------------------------------------------------------------------------
ver="20200130-2030"
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the timing when to get a notification for each Afvaltype in the afvaltype_cfg table
-- Check forumtopic:       https://www.domoticz.com/forum/viewtopic.php?f=61&t=17963
-- Check source updates:   https://github.com/jvanderzande/mijnOphaalKalender
-- Link to WebSite:        http://Hostname/rest/adressen/.....
--

-- test member: Thuis
myAfvalDevice = 'Container'         -- The Text devicename in Domoticz
ShowNextEvents = 3                  -- indicate the next x events to show in the TEXT Sensor in Domoticz
Postcode = '1234AB'                 -- Your postalcode
Housenr = '9'                       -- Your housnr
NotificationEmailAdress = {"",""}   -- Specify multiple Email Addresses for the notifications. Leave empty to skip email notification
Notificationsystem = ""             -- Specify notification system eg "telegram/pushover/.." leave empty to skip
-----------------------------------------------------------------------------------------------------------------------------------------------
debug = false     -- get debug info in domoticz console/log to test the script. Will also update with each run!!!
domoticzjsonpath = '/home/pi/domoticz/scripts/lua' -- Directory containing the Domoticz JSON.lua include file

-- date options:
--    dd  = day in 2 digits   eg 31
--    mm  = month in 2 digits eg 01
--    mmm = month abbreviation in 3 characters eg : jan
--    yy   = year in 2 digits eg 19
--    yyyy = year in 4 digits eg 2019
-- Afvaltype description options
--    desc = afvaltype
textformat = "dd mmm yy desc"

-- ### define a line for each afvaltype_cfg returned by the webrequest:
   -- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
   -- daysbefore ==> 0 means that the notification is send on the day of the planned garbage collection
   -- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
   -- reminder   ==> Will send a second reminder after x hours. 0=no reminder (needs to be in the same day!)
   -- text       ==> define the text for the notification.

afvaltype_cfg = {
   ["Groente-, fruit- en tuinafval"]    ={hour=19,min=22,daysbefore=1,reminder=0,text="Groente-, fruit- en tuinafval"},
   ["Papier en karton"]                 ={hour=19,min=22,daysbefore=1,reminder=0,text="Papier en karton"},
   ["Restafval"]                        ={hour=19,min=22,daysbefore=1,reminder=0,text="Restafval"},
   -- Add any missing records above this line
   ["dummy1"]                           ={hour=02,min=02,daysbefore=0,reminder=0,text="dummy to trigger update of text sensor at night"},
   ["dummy2"]                           ={hour=16,min=25,daysbefore=0,reminder=0,text="dummy to trigger a test "}}

-- Define the Notification Title and body text. there are 3 variables you can include:
-- @DAG@ = Will be replaced by (vandaag/morgen/over x dagen)
-- @AFVALTYPE@ = Will be replaced by the AfvalType found on the internet
-- @AFVALTEXT@ = Will be replaced by the content of the text field for the specific AfvalType in afvaltype_cfg
-- @AFVALDATE@ = Will be replaced by the pickup date found on the internet
notificationtitle = '@Goeree: @DAG@ de @AFVALTEXT@ aan de weg zetten!'
notificationtext  = '@DAG@ wordt de @AFVALTEXT@ opgehaald!'
--==== end of config ========================================================================================================================
local nMON={"jan","feb","maa","apr","mei","jun","jul","aug","sep","okt","nov","dec"}
-------------------------------------------------------
-- debug print
function dprint(text)
   if debug then print("@Goeree:"..text) end
end
-------------------------------------------------------
-- try to load JSON library
function loaddefaultjson()
   if unexpected_condition then error() end
   -- add defined Domoticz path to the search path
   package.path = domoticzjsonpath..'/?.lua;' .. package.path
   JSON = require "JSON"     -- use generic JSON.lua
end

-- Load JSON.lua
if pcall(loaddefaultjson) then
   dprint('Loaded JSON.lua.' )
else
   print('@Goeree Error: failed loading default JSON.lua and Domoticz JSON.lua: ' .. domoticzjsonpath..'.')
   print('@Goeree Error: Please check your setup and try again.' )
   return
end
-------------------------------------------------------
-- round function
function Round(num, idp)
   return tonumber(string.format("%." ..(idp or 0).. "f", num))
end
-------------------------------------------------------
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
-------------------------------------------------------
-- get days between today and provided date
function getdaysdiff(i_afvaltype_date, stextformat)
   local curTime = os.time{day=timenow.day,month=timenow.month,year=timenow.year}
   -- check if date in variable i_afvaltype_date contains "vandaag" in stead of a valid date -> use today's date
   -- "Vrijdag 31 januari"
   local afvalyear =timenow.year
   local afvalday  =timenow.day
   local afvalmonth=timenow.month
   afvalday,s_afvalmonth=i_afvaltype_date:match("%a (%d-) (%a+)$")
   if (afvalday == nil or s_afvalmonth == nil or afvalyear == nil) then
      print ('@Goeree Error: No valid date found in i_afvaltype_date: ' .. i_afvaltype_date)
      return
   end
   local MON={jan=1,feb=2,maa=3,apr=4,mei=5,jun=6,jul=7,aug=8,sep=9,okt=10,nov=11,dec=12}
   local afvalmonth = MON[s_afvalmonth:sub(1,3)]
   local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
   stextformat = stextformat:gsub('dd',afvalday)
   stextformat = stextformat:gsub('mmm',nMON[tonumber(afvalmonth)])
   stextformat = stextformat:gsub('mm',afvalmonth)
   stextformat = stextformat:gsub('yyyy',afvalyear)
   stextformat = stextformat:gsub('yy',tostring(afvalyear):sub(3,4))
   dprint("...gerd-> diff:"..Round(os.difftime(afvalTime, curTime)/86400,0).. "  afvalyear:"..tostring(afvalyear).."  afvalmonth:"..tostring(afvalmonth).."  afvalday:"..tostring(afvalday))   --
   -- return number of days diff
   return stextformat, Round(os.difftime(afvalTime, curTime)/86400,0)   -- 1 day = 86400 seconds
end
-------------------------------------------------------
-- Send Notification when needed
function notification(s_afvaltype,s_afvaltype_date,i_daysdifference)
   dprint("...Noti-> i_daysdifference:"..tostring(i_daysdifference).."  afvaltype_cfg[s_afvaltype].daysbefore:"..tostring(afvaltype_cfg[s_afvaltype].daysbefore).."  hour:"..tostring(afvaltype_cfg[s_afvaltype].hour).."  min:"..tostring(afvaltype_cfg[s_afvaltype].min))
   if afvaltype_cfg[s_afvaltype] ~= nil
   and (timenow.hour==afvaltype_cfg[s_afvaltype].hour or timenow.hour==afvaltype_cfg[s_afvaltype].hour+afvaltype_cfg[s_afvaltype].reminder)
   and timenow.min==afvaltype_cfg[s_afvaltype].min
   and i_daysdifference == afvaltype_cfg[s_afvaltype].daysbefore then
      dag = ""
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
--------------------------------------------------------------------------
-- Do the actual update retrieving data from the website and processing it
function perform_restcall(url)
   local sQuery   = 'curl "'..url..'" 2>nul'
   dprint("sQuery="..sQuery)
   local handle=assert(io.popen(sQuery))
   local jresponse = handle:read('*all')
   handle:close()
   if ( jresponse == "" ) then
      print("@Goeree Error: Empty result from curl command")
      return ""
   end
   return jresponse
end
--------------------------------------------------------------------------
-- Function to process the JSON calendar table received for this address
function process_ophaaldatum_result(intable,inShowNextEvents,otextformat,otxtcnt,otxt,omissingrecords)
   -- loop through all the records in the calendar
--~    containers[0].container[0].soortnaam
--~ containers[0].container[0].soortnaam
--~    print(#intable.containers)
   for k = 1, #intable.containers do
      intable2 = intable.containers[k]
--~       print(#intable2.container)
      for i = 1, #intable2.container do
         record = intable2.container[i]
         stextformat=otextformat
         if type(record) == "table" then
            web_afvaltype = record["soortnaam"]
            web_afvaldate = record["datum"]
            dprint (' web_afvaltype : ' .. web_afvaltype .. '   web_afvaldate:'..web_afvaldate)
            -- first match for each Type we save the date to capture the first next dates
            if afvaltype_cfg[web_afvaltype] == nil then
               print ('@Goeree Error: Afvalsoort not defined in the "afvaltype_cfg" table for found Afvalsoort : ' .. web_afvaltype)
               omissingrecords = omissingrecords .. '   ["' .. web_afvaltype..'"]'..string.rep(" ", 32-string.len(web_afvaltype))..' ={hour=19,min=22,daysbefore=1,reminder=0,text="'..web_afvaltype..'"},\n'
               afvaltype_cfg[web_afvaltype] = {hour=0,min=0,daysbefore=0,reminder=0,text="dummy"}
            else
               -- check whether the first nextdate for this afvaltype is already found to get only one next date per AfvalType
               if afvaltype_cfg[web_afvaltype].nextdate == nil and otxtcnt < inShowNextEvents then
                  -- Get days diff
                  stextformat, daysdiffdev = getdaysdiff(web_afvaldate, stextformat)
                  -- When days is 0 or greater the date is today or in the future. Ignore any date in the past
                  if daysdiffdev == nil then
                     dprint ('Invalid date from web for : ' .. web_afvaltype..'   date:'..web_afvaldate)
                  elseif daysdiffdev >= 0 then
                     -- Set the nextdate for this afvaltype
                     afvaltype_cfg[web_afvaltype].nextdate = web_afvaldate
                     -- fill the text with the next defined number of events
                     if otxtcnt < inShowNextEvents then
                        stextformat = stextformat:gsub('desc',web_afvaltype)
                        otxt = otxt..stextformat.."\r\n"
                        otxtcnt = otxtcnt + 1
                     end
                     notification(web_afvaltype,web_afvaldate,daysdiffdev)  -- check notification for new found info
                  end
               end
            end
         end
      end
   end
   return otxtcnt, otxt, omissingrecords
end
--------------------------------------------------------------------------
-- Perform the actual update process for the given address
function Perform_Update()
   print('OphaalKalender module start update (v'..ver..')')
   dprint('=== web update ================================')
   local jresponse
--~    https://www.ophaalkalender.be/Calendar/findstreets/?query=gaverlanddam&zipcode=9120
--~ [{"Value":"Gaverlanddam","Id":6644,"Brussels":false}]
   jresponse=perform_restcall('https://webadapter.watsoftware.nl/widget.aspx?version=3.7&action=3000001&xml=%3Cpostcode%3E'..Postcode..'%3C/postcode%3E%3Chuisnummer%3E'..Housenr..'%3C/huisnummer%3E%3Cguid%3EBCE23C06-E248-4300-B97F-E308A451C6B4%3C/guid%3E')
   jresponse=jresponse:sub(1, -2)  -- stript ending )
   jresponse=jresponse:sub(2)      -- stript start  )
   if ( jresponse:sub(1,2) == "[]" ) then
      print("@Goeree Error: Unable to retrieve the Kalender information for this address...  stopping execution.")
      return
   end
   rdata = JSON:decode(jresponse)
   -- get the ophaaldagen tabel for the coming scheduled pickups
   if type(rdata) ~= "table" then
      print("@Goeree: Empty Kalender for "..cYear..".  stopping execution.")
      return
   end
   -- get the next number of ShowNextEvents
   dprint("- start looping through received data -----------------------------------------------------------")
   local missingrecords=""
   local txtcnt,txt,missingrecords = process_ophaaldatum_result(rdata,ShowNextEvents,textformat,0,"","")
   -- check whether we need to check next years events to get all ShowNextEvents
   dprint("-End   --------------------------------------------------------------------------------------")
   if missingrecords ~= "" then
      print('#### -- start -- Add these records to local afvaltype_cfg = {')
      print(missingrecords)
      print('#### -- end ----------------------------')
   end
   if (cnt==0) then
      print ('@Goeree Error: No valid data found in returned webdata.  skipping the rest of the logic.')
      return
   end
   -- always update the domoticz device so one can see it is updating and when it was ran last.
   print ('@Goeree: Found:'..txt:gsub('\r\n', ' ; '))
   if otherdevices_idx == nil or otherdevices_idx[myAfvalDevice] == nil then
      print ("@Goeree Error: Couldn't get the current data from Domoticz text device "..myAfvalDevice )
   else
      commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. txt
      if (otherdevices[myAfvalDevice] ~= txt) then
         print ('@Goeree: Update device from: \n'.. otherdevices[myAfvalDevice] .. '\n replace with:\n' .. txt)
      else
         print ('@Goeree: No updated text for TxtDevice.')
      end
   end
end

-- End Functions =========================================================================

-- Start of logic ========================================================================
commandArray = {}
timenow = os.date("*t")

-- check for notification times and run update only when we are at one of these defined times
print('OphaalKalender module start check')
local needupdate = false
for avtype,get in pairs(afvaltype_cfg) do
   dprint("afvaltype_cfg :"..tostring(avtype)..";"..tostring(afvaltype_cfg[avtype].hour)..";"..tostring(afvaltype_cfg[avtype].min))
   if (timenow.hour==afvaltype_cfg[avtype].hour
   or  timenow.hour==afvaltype_cfg[avtype].hour+afvaltype_cfg[avtype].reminder)
   and timenow.min==afvaltype_cfg[avtype].min then
      dprint('-> update needed.')
      needupdate = true
   end
end
-- get information from website, update device and send notification when required
if needupdate or debug then
   Perform_Update()
else
   print("Scheduled time(s) not reached yet, so nothing to do!")
end

return commandArray