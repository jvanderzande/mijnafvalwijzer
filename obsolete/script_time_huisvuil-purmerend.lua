--
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the timing when to get a notification for each Afvaltype in the afvaltype_cfg table
-- based on script by zicht @ http://www.domoticz.com/forum/viewtopic.php?t=17963
-- based on script by nf999 @ http://www.domoticz.com/forum/viewtopic.php?f=61&t=17963&p=174908#p169637
--
-- Link to WebSite:  https://afvalkalender.purmerend.nl/adres/postcode:housenr
myAfvalDevice = 'Purmerend'         -- The Text devicename in Domoticz
ShowNextEvents = 3                  -- indicate the next x events to show in the TEXT Sensor in Domoticz
Postcode = 'your-zip-here'          -- Your postalcode
Housenr = 'your-housenr-here'       -- Your housnr
NotificationEmailAdress = ""        -- Specify your Email Address for the notifications. Leave empty to skip email notification
Notificationsystem = ""             -- Specify notification system eg "telegram/pushover/.." leave empty to skip


-- Define the Notification Title and body text. there are 3 variables you can include:
-- @DAG@ = Will be replaced by (vandaag/morgen/over x dagen)
-- @AFVALTYPE@ = Will be replaced by the AfvalType found on the internet
-- @AFVALTEXT@ = Will be replaced by the content of the text field for the specific AfvalType
-- @AFVALDATE@ = Will be replaced by the pickup date found on the internet
local notificationtitle = 'AF-PUR: @DAG@ de @AFVALTEXT@ aan de weg zetten!'
local notificationtext  = '@DAG@ wordt de @AFVALTEXT@ opgehaald!'

-- Switch on Debugging in case of issues => set to true/false=======
local debug = false  -- get debug info in domoticz console/log

-- define a line for each afvaltype_cfg retuned by the webrequest:
-- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
-- daysbefore ==> 0 means that the notification is send on the day of the planned garbage collection
-- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
-- text       ==> define the text for the notification.
local afvaltype_cfg = {
   ["Restafval"]              ={hour=19,min=22,daysbefore=1,text="Grijze Container met Restafval"},
   ["GFT"]                    ={hour=19,min=22,daysbefore=1,text="Bruine Container met Tuinfval"},
   ["Kerstbomen"]             ={hour=19,min=22,daysbefore=1,text="Kerstboom"},
   ["Papier en karton"]       ={hour=19,min=22,daysbefore=1,text="Blauwe Container met Oud papier"},
   ["Dummy1"]                 ={hour=02,min=22,daysbefore=0,text="dummy"},   -- dummy is used to update the textsensor
   ["Dummy2"]                 ={hour=02,min=22,daysbefore=0,text="dummy"}}   -- dummy is used to update the textsensor at night for that day
--==== end of config ========================================================================================================================

-- General conversion tables
local MON={jan=1,feb=2,maa=3,apr=4,mei=5,jun=6,jul=7,aug=8,sep=9,okt=10,nov=11,dec=12}

-- round
function Round(num, idp)
   return tonumber(string.format("%." ..(idp or 0).. "f", num))
end
-- debug print
function dprint(text)
   if debug then print("@AF-PUR:"..text) end
end
-- run curl and capture output
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
   -- Calculate the daysdifference between found date and Now and send notification is required
   local afvalyear =timenow.year
   local afvalday  =timenow.day
   local afvalmonth=timenow.month
   local s_afvalmonth="vandaag"
   -- check if date in variable i_afvaltype_date contains "vandaag" in stead of a valid date -> use today's date
   if i_afvaltype_date == "vandaag" then
     -- use the set todays info
   else
      -- Get day and month from the webdate found
      afvalday, s_afvalmonth=i_afvaltype_date:match("%a- (%d+) (%a+)")
      if (afvalday == nil or s_afvalmonth == nil) then
         print ('@AF-PUR error: No valid date found in i_afvaltype_date: ' .. i_afvaltype_date)
         return
      end
     -- translate the month name to the month number
      afvalmonth = MON[s_afvalmonth]
   end
   dprint("...gerd-> afvalyear:"..tostring(afvalyear).."  s_afvalmonth:"..tostring(s_afvalmonth).."  afvalmonth:"..tostring(afvalmonth).."  afvalday:"..tostring(afvalday))
   --
   local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
   -- return number of days diff
   return Round(os.difftime(afvalTime, curTime)/86400,0)   -- 1 day = 86400 seconds
end

function notification(s_afvaltype,s_afvaltype_date,i_daysdifference)
   dprint("...Noti-> i_daysdifference:"..tostring(i_daysdifference).."  afvaltype_cfg[s_afvaltype].daysbefore:"..tostring(afvaltype_cfg[s_afvaltype].daysbefore).."  hour:"..tostring(afvaltype_cfg[s_afvaltype].hour).."  min:"..tostring(afvaltype_cfg[s_afvaltype].min))
   if afvaltype_cfg[s_afvaltype] ~= nil
   and timenow.hour==afvaltype_cfg[s_afvaltype].hour
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
      if NotificationEmailAdress ~= "" then
         commandArray['SendEmail'] = notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress
         dprint ('Notification Email send for ' .. s_afvaltype.. " |"..notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress.."|")
      end
      if Notificationsystem ~= "" then
         commandArray['SendNotification']=notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress.."###"..Notificationsystem
         dprint ('Notification '..Notificationsystem..' send for '.. s_afvaltype.. " |"..notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress.."|")
      end
   end
end

-- Do the actual update retrieving data from the website and processing it
function Perform_Update()
   print('AF-PUR module start check')
   dprint('=== web update ================================')
   -- get data from the website
   local commando = "curl --max-time 5 -s \"https://afvalkalender.purmerend.nl/adres/"..Postcode..":"..Housenr.."\""
   dprint(commando)
   local tmp = os.capture(commando, 5)
   if ( tmp == "" ) then
      print("@AF-PUR error: Empty result from curl command, skipping run.")
      return
   else
--~       dprint("website data tmp="..tmp)
   end
   -- Retrieve part with the dates for pickup
   tmp=tmp:match('.-<ul id="ophaaldata" class="line">(.-)</div>')
   if tmp == nil or tmp == "" then
      print('@AF-PUR error: Unable to find the part for "ophaaldata" stpping script.')
      return
   else
--~    dprint("! Stripped data tmp="..tmp)
   end
   dprint("- start looping through received data -----------------------------------------------------------")
   local web_afvaltype=""
   local web_afvaldate=""
   local txt = ""
   local cnt = 0

--   Loop through all dates
--~    for web_afvaldate, web_afvaltype in string.gmatch(tmp, '<td>.-%s(.-)</td><td>(.-)</td>') do
   for web_afvaltype, web_afvaldate in string.gmatch(tmp, 'alt="(.-)".-<i class="date">(.-)</i>') do
      if web_afvaltype~= nil and web_afvaldate ~= nil then
         -- first match for each Type we save the date to capture the first next dates
         dprint(web_afvaltype,web_afvaldate)
         if afvaltype_cfg[web_afvaltype] ~= nil then
            -- check whether the first nextdate for this afvaltype is already found
            if afvaltype_cfg[web_afvaltype].nextdate == nil then
               dprint("web_afvaltype:"..tostring(web_afvaltype).."   web_afvaldate:"..tostring (web_afvaldate))
               daysdiffdev = getdaysdiff(web_afvaldate)
               -- When days is 0 or greater the date is today or in the future. Ignore any date in the past
               if daysdiffdev == nil then
                  dprint ('Invalid date from web for : ' .. web_afvaltype..'   date:'..web_afvaldate)
               elseif daysdiffdev >= 0 then
                  -- Set the nextdate for this afvaltype
                  afvaltype_cfg[web_afvaltype].nextdate = web_afvaldate
                  -- fill the text with the next defined number of events
                  if cnt < ShowNextEvents then
                     txt = txt..web_afvaldate .. "=" .. web_afvaltype .. "\r\n"
                     cnt=cnt+1
                  end
               end
               notification(web_afvaltype,web_afvaldate,daysdiffdev)  -- check notification for new found info
            end
         else
            print ('@AF-PUR error: Afvalsoort not defined in the "afvaltype_cfg" table for found Afvalsoort : ' .. web_afvaltype)
         end
      end
   end
   dprint("-End   --------------------------------------------------------------------------------------------")
   if (cnt==0) then
     print ('@AF-PUR error: No valid data found in returned webdata.  skipping the rest of the logic.')
     return
   end
   print ('@AF-PUR: Found:'..txt:gsub('\r\n', ' ; '))
   -- always update the domoticz device so one can see it is updating and when it was ran last.
   if otherdevices_idx == nil or otherdevices_idx[myAfvalDevice] == nil then
      print ("@AF-PUR Error: Couldn't get the current data from Domoticz text device "..myAfvalDevice )
   else
      commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. txt
      if (otherdevices[myAfvalDevice] ~= txt) then
         print ('@AF-PUR: Update device from: \n'.. otherdevices[myAfvalDevice] .. '\n replace with:\n' .. txt)
      else
         print ('@AF-PUR: No updated text for TxtDevice.')
      end
   end
end

-- End Functions =========================================================================

-- Start of logic ========================================================================
commandArray = {}
timenow = os.date("*t")

-- check for notification times and run update only when we are at one of these defined times
local needupdate = false
for avtype,get in pairs(afvaltype_cfg) do
   dprint("afvaltype_cfg :"..tostring(avtype)..";"..tostring(afvaltype_cfg[avtype].hour)..";"..tostring(afvaltype_cfg[avtype].min))
   if timenow.hour==afvaltype_cfg[avtype].hour
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
