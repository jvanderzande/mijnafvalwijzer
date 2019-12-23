-----------------------------------------------------------------------------------------------------------------
-- huisvuilkalender script: script_time_opzet.lua used for gemeentes using  http://www.opzet.nl/afvalkalender_digitaal
----------------------------------------------------------------------------------------------------------------
ver="20191223-1840"
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the timing when to get a notification for each Afvaltype in the afvaltype_cfg table
-- Check forumtopic:       https://www.domoticz.com/forum/viewtopic.php?f=61&t=17963
-- Check source updates:   https://github.com/jvanderzande/mijnafvalwijzer
-- Link to WebSite:        http://Hostname/rest/adressen/.....
--
myAfvalDevice = 'Container'         -- The Text devicename in Domoticz
hostname = ""                       -- Specify the hostname of your afvalwebsite. eg: "afvalkalender.purmerend.nl", "afvalkalender.sudwestfryslan.nl", "mijnblink.nl" ..etc
ShowNextEvents = 3                  -- indicate the next x events to show in the TEXT Sensor in Domoticz
Postcode = ''                       -- Postcode
Housenr = ''                        -- Huisnummer zonder toevoeging
Housenrtoev=''                      -- Huisnummer toevoeging
NotificationEmailAdress = ""        -- Specify your Email Address for the notifications. Leave empty to skip email notification
--NotificationEmailAdress = {"",""} -- Specify multiple Email Addresses for the notifications. Leave empty to skip email notification
Notificationsystem = ""             -- Specify notification system eg "telegram/pushover/.." leave empty to skip

-- Switch on Debugging in case of issues => set to true/false=======
local debug = false  -- get debug info in domoticz console/log

-- define a line for each afvaltype_cfg retuned by the webrequest:
   -- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
   -- daysbefore ==> 0 means that the notification is send on the day of the planned garbage collection
   -- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
   -- reminder   ==> Will send a second reminder after x hours. 0=no reminder (needs to be in the same day!)
   -- text       ==> define the text for the notification.
local afvaltype_cfg = {
   ["Restafval"]                        ={hour=19,min=02,daysbefore=1,reminder=0,text="Container met Restafval"},
   ["GFT"]                              ={hour=19,min=02,daysbefore=1,reminder=0,text="Container met Tuinafval"},
   ["Plastic, Metaal en Drankkartons"]  ={hour=19,min=02,daysbefore=1,reminder=0,text="PMD bak"},
   ["Papier en karton"]                 ={hour=12,min=01,daysbefore=0,reminder=0,text="Oud papier"},
   ["Kerstbomen"]                       ={hour=19,min=22,daysbefore=1,reminder=0,text="Kerstbomen"},
   ["Dummy1"]                           ={hour=02,min=02,daysbefore=0,reminder=0,text="dummy"},   -- dummy is used to force update while testing
   ["Dummy2"]                           ={hour=02,min=02,daysbefore=0,reminder=0,text="dummy"}}   -- dummy is used to update the textsensor at night for that day

-- Define the Notification Title and body text. there are 3 variables you can include:
-- @DAG@ = Will be replaced by (vandaag/morgen/over x dagen)
-- @AFVALTYPE@ = Will be replaced by the AfvalType found on the internet
-- @AFVALTEXT@ = Will be replaced by the content of the text field for the specific AfvalType in afvaltype_cfg
-- @AFVALDATE@ = Will be replaced by the pickup date found on the internet
notificationtitle = '@AFW: @DAG@ de @AFVALTEXT@ aan de weg zetten!'
notificationtext  = '@DAG@ wordt de @AFVALTEXT@ opgehaald!'
--==== end of config ========================================================================================================================

-- General conversion tables
local MON={jan=1,feb=2,mrt=3,apr=4,mei=5,jun=6,jul=7,aug=8,sep=9,okt=10,nov=11,dec=12}

-- debug print
function dprint(text)
   if debug then print("@AFOpzet:"..text) end
end

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
function getdaysdiff(i_afvaltype_date, prev_daysdiff)
   local curTime = os.time{day=timenow.day,month=timenow.month,year=timenow.year}
   -- Calculate the daysdifference between found date and Now and send notification is required
   local afvalyear =timenow.year
   local afvalday  =timenow.day
   local afvalmonth=timenow.month
   local s_afvalmonth="vandaag"
   -- check if date in variable i_afvaltype_date contains "vandaag" in stead of a valid date -> use today's date
   if i_afvaltype_date == "vandaag" then
      -- use the set todays info
   else
      --s_afvalmonth, afvalday=i_afvaltype_date:match("(%a-). (%d+), %d+")
      afvalday, s_afvalmonth=i_afvaltype_date:match("%a- (%d-) (%a+)$")
      if (afvalday == nil or s_afvalmonth == nil) then
         print ('@AFOpzet Error: No valid date found in i_afvaltype_date: ' .. i_afvaltype_date)
         return
      end
      afvalmonth = MON[s_afvalmonth]
      if afvalmonth == nil then
         print ('@AFOpzet Error: No valid month found for abbreviation: ' .. s_afvalmonth..' adapt the line: "local MON={" to correct it.')
         return 0
      end
   end
   local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
   daysdiff = Round(os.difftime(afvalTime, curTime)/86400,0)       -- 1 day = 86400 seconds
   if prev_daysdiff > daysdiff then
      afvalyear = afvalyear+1
      afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
      daysdiff = Round(os.difftime(afvalTime, curTime)/86400,0)
   end
   dprint("...gerd-> afvalyear:"..tostring(afvalyear).."  s_afvalmonth:"..tostring(s_afvalmonth).."  afvalmonth:"..tostring(afvalmonth).."  afvalday:"..tostring(afvalday))
   --
   -- return number of days diff
   return daysdiff
end

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

-- Do the actual update retrieving data from the website and processing it
function Perform_Update()
   print('@AFOpzet module start check for '..Postcode.."-"..Housenr)
   dprint('=== web update ================================')
   -- get data from the website
   local commando = "curl --max-time 5 -s \"https://"..hostname.."/adres/"..Postcode..":"..Housenr..":"..Housenrtoev.."\""
   dprint(commando)
   local tmp = os.capture(commando, 1)
   if ( tmp == "" ) then
      print("@AFOpzet Error: Empty result from curl command, skipping run.")
      return
   else
      --dprint("website data tmp="..tmp)
   end
   -- Retrieve part with the dates for pickup
   tmp=tmp:match('.<ul id="ophaaldata" class="line">(.-)<footer>')
   if tmp == nil or tmp == '' then
      print ('@AFOpzet Error: Could not find the ophaaldata section in the data.  skipping the rest of the logic.')
      return
   end
   dprint("- start looping through received data -----------------------------------------------------------")
   local web_afvaltype = ""
   local web_afvaldate = ""
   local missingrecords = ""
   local txt = ""
   local cnt = 0
   local prev_daysdiff = -250

--   Loop through all dates
   for web_afvaltype, web_afvaldate in string.gmatch(tmp, 'title="Naar afvalstroom (.-)">.-class="date">(.-)</i>') do
      if web_afvaltype~= nil and web_afvaldate ~= nil then
         -- first match for each Type we save the date to capture the first next dates
         dprint(web_afvaltype .. " " .. web_afvaldate)
         daysdiffdev = getdaysdiff(web_afvaldate,prev_daysdiff)
         prev_daysdiff = daysdiffdev
         -- When days is 0 or greater the date is today or in the future. Ignore any date in the past
         if daysdiffdev >= 0 then
            -- fill the text with the next defined number of events
            if cnt < ShowNextEvents then
               txt = txt..web_afvaldate .. "=" .. web_afvaltype .. "\r\n"
               cnt=cnt+1
            end
         end
         if afvaltype_cfg[web_afvaltype] ~= nil and afvaltype_cfg[web_afvaltype].daysbefore ~= nil then
            -- check if notification needs to be send
            notification(web_afvaltype,web_afvaldate,daysdiffdev)
         else
            print ('@AFOpzet Error: Afvalsoort not defined in the "afvaltype_cfg" table for found Afvalsoort : ' .. web_afvaltype)
            missingrecords = missingrecords .. '   ["' .. web_afvaltype..'"]'..string.rep(" ", 32-string.len(web_afvaltype))..' ={hour=19,min=22,daysbefore=1,reminder=0,text="'..web_afvaltype..'"},\n'
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
      print ('@AFOpzet Error: No valid data found in returned webdata.  skipping the rest of the logic.')
      return
   end
   -- always update the domoticz device so one can see it is updating and when it was ran last.
   print ('@AFOpzet Found: '..txt:gsub('\r\n', ' ; '))
   if otherdevices_idx == nil or otherdevices_idx[myAfvalDevice] == nil then
      print ("@AFOpzet Error: Couldn't get the current data from Domoticz text device "..myAfvalDevice )
   else
      commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. txt
      if (otherdevices[myAfvalDevice] ~= txt) then
         print ('@AFOpzet: Update device from: \n'.. otherdevices[myAfvalDevice] .. '\n replace with:\n' .. txt)
      else
         print ('@AFOpzet: No updated text for TxtDevice.')
      end
   end
end

-- End Functions =========================================================================

-- Start of logic ========================================================================
commandArray = {}
timenow = os.date("*t")

-- check for notification times and run update only when we are at one of these defined times
dprint('Opzet Afval module start check')
local needupdate = false
for avtype,get in pairs(afvaltype_cfg) do
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