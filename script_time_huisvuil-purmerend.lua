-- AF-PUR module to get the Afval schedule for Purmerend
--
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the timing when to get a notification for each Afvaltype in the afvaltype_cfg table
-- based on script by zicht @ http://www.domoticz.com/forum/viewtopic.php?t=17963
-- based on script by nf999 @ http://www.domoticz.com/forum/viewtopic.php?f=61&t=17963&p=174908#p169637
--
-- Link to WebSite:  https://datalab.purmerend.nl/afvalkalender/?area=MyArea&kind=&date=
local myAfvalDevice='Purmerend'   -- Set to the TEXT sensor DeviceName from Domoticz
local ShowNextEvents = 3          -- indicate the next events to show in the TEXT Sensor in Domoticz
local MyArea='???????'            -- Set to the Wijknaam found on the Website
local NotificationEmailAdress = "??@??.??"  -- Set to the Notification EmailAddress

-- Define the Notification Title and body text. there are 3 variables you can include:
-- @DAG@ = Will be replaced by (vandaag/morgen/over x dagen)
-- @AFVALTYPE@ = Will be replaced by the AfvalType found on the internet
-- @AFVALTEXT@ = Will be replaced by the content of the text field for the specific AfvalType
-- @AFVALDATE@ = Will be replaced by the pickup date found on the internet
local notificationtitle = '@DAG@ de @AFVALTEXT@ aan de weg zetten!'
local notificationtext  = '@DAG@ wordt de @AFVALTEXT@ opgehaald!'

-- Switch on Debugging in case of issues => set to true/false=======
local debug = false  -- get debug info in domoticz console/log

-- define a line for each afvaltype_cfg retuned by the webrequest:
-- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
-- daysbefore ==> 0 means that the notification is send the day of the planned garbage collection
-- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
-- text       ==> define the text for the notification.
local afvaltype_cfg = {
   ["Rest"]       ={hour=19,min=22,daysbefore=1,text="Grijze Container met Restafval"},
   ["GFT"]        ={hour=19,min=22,daysbefore=1,text="Groene Container met Tuinfval"},
   ["Papier"]     ={hour=12,min=00,daysbefore=0,text="Blauwe Container met Oud papier"},
   ["Dummy"]      ={hour=2,min=01,daysbefore=0,text="dummy"}}
--==== end of config ======================================================================================================

-- General conversion tables
local MON_e_n={January="januari", February="februari", March="maart", April="april", May="mei", June="juni", July="juli", August="augustus", September="september", October="oktober", November="november", December="december"}
local WDAY_e_n={Sunday="zondag", Monday="maandag", Tuesday="dinsdag", Wednesday="woensdag", Thursday="donderdag", Friday="vrijdag", Saturday="zaterdag"}
local MON={Jan=1,Feb=2,March=3,April=4,May=5,June=6,July=7,Aug=8,Sept=9,Oct=10,Nov=11,Dec=12}

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
      s_afvalmonth, afvalday=i_afvaltype_date:match("(%a-). (%d+), %d+")
      if (afvalday == nil or s_afvalmonth == nil) then
         print ('! AF-PUR: No valid date found in i_afvaltype_date: ' .. i_afvaltype_date)
         return
      end
      afvalmonth = MON[s_afvalmonth]
   end
   dprint("...gerd-> afvalyear:"..tostring(afvalyear).."  s_afvalmonth:"..tostring(s_afvalmonth).."  afvalmonth:"..tostring(afvalmonth).."  afvalday:"..tostring(afvalday))
   --
   local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
   -- return number of days diff
   return Round(os.difftime(afvalTime, curTime)/86400,0)   -- 1 day = 86400 seconds
end

function notification(s_afvaltype,s_afvaltype_date,i_daysdifference)
   -- @AFW:...Noti-> i_daysdifference:0 afvaltype_cfg[s_afvaltype].daysbefore:0 hour:12 min:0
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
      commandArray['SendEmail'] = notificationtitle .. '#' .. notificationtext .. '#' .. NotificationEmailAdress
      dprint ('AF-PUR Notification send for ' .. s_afvaltype.. "  title:|"..notificationtitle.. "|  body:|"..notificationtext.."|")
   end
end

-- Do the actual update retrieving data from the website and processing it
function Perform_Update()
   print('AF-PUR module start check')
   dprint('=== web update ================================')
   -- get data from AF-PUR
   local commando = "curl --max-time 5 -s \"https://datalab.purmerend.nl/afvalkalender/?area="..MyArea.."\""
   local tmp = os.capture(commando, 5)
   if ( tmp == "" ) then
      print("AF-PUR: Empty result from curl command")
      return
   else
      -- dprint("website data tmp="..tmp)
   end
   -- Retrieve part with the dates for pickup dates
   tmp=tmp:match('.-<th scope="col">Waar</th>.-</tr>.-</thead>.-<tbody>(.-)</tbody>')
   dprint("- start looping through received data -----------------------------------------------------------")
   local web_afvaltype=""
   local web_afvaldate=""
   local txt = ""
   local cnt = 0

--   Loop through all dates
   for web_afvaldate, web_afvaltype in string.gmatch(tmp, '<td>(.-)</td>[\r\n%s]-<td>(.-)</td>[\r\n%s]-<td>.-</td>') do
      if web_afvaltype~= nil and web_afvaldate ~= nil then
         -- first match for each Type we save the date to capture the first next dates
         if afvaltype_cfg[web_afvaltype] ~= nil then
            if afvaltype_cfg[web_afvaltype].nextdate == nil then
               dprint("web_afvaltype:"..tostring(web_afvaltype).."   web_afvaldate:"..tostring (web_afvaldate))
               afvaltype_cfg[web_afvaltype].nextdate = web_afvaldate
               daysdiffdev = getdaysdiff(web_afvaldate)
               notification(web_afvaltype,web_afvaldate,daysdiffdev)  -- check notification for new found info
               if cnt < ShowNextEvents then
                  txt = txt..web_afvaldate .. "=" .. web_afvaltype .. "\r\n"
               end
               cnt=cnt+1
            end
         else
            print ('! AF-PUR: Afvalsoort not defined in the "afvaltype_cfg" table for found Afvalsoort : ' .. web_afvaltype)
         end
      end
   end
   dprint("-End   --------------------------------------------------------------------------------------------")
   if (cnt==0) then
      print ('! AF-PUR: No valid data found in returned webdata.  skipping the rest of the logic.')
      return
   end
   -- always update the domoticz device so one can see it is updating and when it was ran last.
   commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. txt
   if (otherdevices[myAfvalDevice] ~= txt) then
      print ('AF-PUR: Update device from: \n'.. otherdevices[myAfvalDevice] .. '\n replace with:\n' .. txt)
   else
      print ('AF-PUR: No updated text for TxtDevice.')
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