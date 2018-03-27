-- afvalWijzer module
--
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the timing when to get a notification for each Afvaltype in the afvaltype_cfg table
-- based on script by zicht @ http://www.domoticz.com/forum/viewtopic.php?t=17963
-- based on script by nf999 @ http://www.domoticz.com/forum/viewtopic.php?f=61&t=17963&p=174908#p169637

local myAfvalDevice='Container'
local Postcode='your-zip-here'
local Huisnummer='your-housenr-here'
local NotificationEmailAdress = "your-email-address(es)-here"
-- Define the Notification Title and body text. there are 3 variables you can include:
-- @DAG@ = Will be replaced by (vandaag/morgen/over x dagen)
-- @AFVALTYPE@ = Will be replaced by the AfvalType found on the internet
-- @AFVALTEXT@ = Will be replaced by the content of the text field for the specific AfvalType
-- @AFVALDATE@ = Will be replaced by the pickup date found on the internet
local notificationtitle = '@DAG@ de @AFVALTEXT@ aan de weg zetten!'
local notificationtext  = '@DAG@ wordt de "@AFVALTEXT@" opgehaald!'

-- Switch on Debugging in case of issues => set to true/false=======
local debug = false  -- get debug info in domoticz console/log

-- define a line for each afvaltype_cfg retuned by the webrequest:
-- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
-- daysbefore ==> 0 means that the notification is send the day of the planned garbage collection
-- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
-- text       ==> define the text for the notification.
local afvaltype_cfg = {
   ["Restafval"]                          ={hour=19,min=22,daysbefore=1,text="Grijze Container met Restafval"},
   ["Groente, Fruit en Tuinafval"]        ={hour=19,min=22,daysbefore=1,text="Groene Container met Tuinfval"},
   ["Plastic, Metalen en Drankkartons"]   ={hour=19,min=22,daysbefore=1,text="Oranje Container met Plastic en Metalen"},
   ["Klein chemisch afval"]               ={hour=19,min=22,daysbefore=1,text="Blauwe Bak"},
   ["Papier en karton"]                   ={hour=12,min=00,daysbefore=0,text="Blauwe Container met Oud papier"}}
--==== end of config ======================================================================================================
-- General conversion tables
local MON_e_n={January="januari", February="februari", March="maart", April="april", May="mei", June="juni", July="juli", August="augustus", September="september", October="oktober", November="november", December="december"}
local WDAY_e_n={Sunday="zondag", Monday="maandag", Tuesday="dinsdag", Wednesday="woensdag", Thursday="donderdag", Friday="vrijdag", Saturday="zaterdag"}
local MON={januari=1,februari=2,maart=3,april=4,mei=5,juni=6,juli=7,augustus=8,september=9,oktober=10,november=11,december=12}

-- round
function Round(num, idp)
   return tonumber(string.format("%." ..(idp or 0).. "f", num))
end
-- debug print
function dprint(text)
   if debug then print("@AFW:"..text) end
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
      afvalday,s_afvalmonth=i_afvaltype_date:match("%a+ (%d+) (%a+)")
      if (afvalday == nil or s_afvalmonth == nil) then
         print ('! afvalWijzer: No valid date found in i_afvaltype_date: ' .. i_afvaltype_date)
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
   --
   dprint("...Noti-> i_daysdifference:"..tostring(i_daysdifference).."  afvaltype_cfg[s_afvaltype].daysbefore:"..tostring(afvaltype_cfg[s_afvaltype].daysbefore).."  hour:"..tostring(afvaltype_cfg[s_afvaltype].hour).."  min:"..tostring(afvaltype_cfg[s_afvaltype].min))
   if afvaltype_cfg[s_afvaltype] ~= nil
   and timenow.hour==afvaltype_cfg[s_afvaltype].hour
   and timenow.min==afvaltype_cfg[s_afvaltype].min
   and i_daysdifference == afvaltype_cfg[s_afvaltype].daysbefore then
      print ('afvalWijzer Notification send for ' .. s_afvaltype)
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
   end
end

-- Do the actual update retrieving data from the website and processing it
function Perform_Update()
   print('afvalWijzer module start check')
   dprint('=== web update ================================')
   -- get data from afvalWijzer
   local commando = "curl --max-time 5 -s 'http://www.mijnafvalwijzer.nl/nl/"..Postcode.."/"..Huisnummer.."/'"
   local tmp = os.capture(commando, 5)
   if ( tmp == "" ) then
      print("afvalWijzer: Empty result from curl command")
      return
   end
   -- strip html stuff and format for domoticz
   tmp=tmp:gsub('%c','')
   --~ <p class="firstDate">donderdag 22 maart</p>
   --~ <p class="firstDate">vandaag</p>
   --~ <p class="firstWasteType">Groente, Fruit en Tuinafval</p>
   -- get the data for these fields
   web_afvaldate,web_afvaltype=tmp:match('.-<p class="firstDate">(.-)</p>.-<p class="firstWasteType">(.-)</p>')
   dprint("web_afvaltype:"..tostring(web_afvaltype).."   web_afvaldate:"..tostring (web_afvaldate))
   if (web_afvaldate == nil or web_afvaltype == nil) then
      print ('! afvalWijzer: No valid data found in returned webdata.  skipping the rest of the logic.')
      return
   end
   -- set the date back to a real date to allow for future processing
   if web_afvaldate == "vandaag" then
      if WDAY_e_n[os.date("%A")] == nil then
         dprint(" Error: Not in table WDAY_e_n[]:"..os.date("%A"))
      end
      if MON_e_n[os.date("%B")] == nil then
         dprint(" Error: Not in table MON_e_n[]:"..os.date("%A"))
      end
      web_afvaldate = WDAY_e_n[os.date("%A")].." "..os.date("%d").." "..MON_e_n[os.date("%B")]
      dprint('Change web_afvaldate "vandaag" to :' .. web_afvaldate)
   end
   -- process new information from the web
   daysdifference = getdaysdiff(web_afvaldate)
   if (afvaltype_cfg[web_afvaltype] == nil) then
      print ('! afvalWijzer: Afvalsoort not defined in the "afvaltype_cfg" table for found Afvalsoort : ' .. web_afvaltype)
   end
   notification(web_afvaltype,web_afvaldate,daysdifference)  -- check notification for new found info

   dprint('=== device: ' .. myAfvalDevice .. ' check and update ========')
   -- update device when text changed
   local txt = ""
   curdevtext = otherdevices[myAfvalDevice]
   -- process each record in the device text first to check if still in future and notification needed
   for dev_date, dev_afvaltype in string.gmatch(curdevtext..'\r\n', '(.-)=(.-)\r\n+') do
      dprint("=> process:"..dev_date.."="..dev_afvaltype)
      if web_afvaltype == dev_afvaltype then
         dprint(".> skip same as Web  -> dev_afvaltype:"..dev_date.."="..dev_afvaltype)
      else
         -- Get DaysDiff
         daysdiffdev = getdaysdiff(dev_date)
         if daysdiffdev < 0  then
            dprint(".> skip old -> dev_afvaltype:"..dev_date.."="..dev_afvaltype.."   daysdiffdev:"..daysdiffdev)
         else
            dprint(".> Add back to TxtDev -> afvaltype:"..dev_date.."="..dev_afvaltype.."   daysdiffdev:"..daysdiffdev)
            notification(dev_afvaltype,dev_date,daysdiffdev)  -- check notification for new found info
            txt = txt..dev_date .. "=" .. dev_afvaltype .. "\r\n"
         end
      end
   end
   dprint('=== Update TxtDevice in Domoticz =============')
   dprint("=> Add Webinfo to TxtDev -> afvaltype:"..web_afvaltype.." - "..web_afvaldate)
   txt = txt..web_afvaldate .. "=" .. web_afvaltype
   -- always update the domoticz device so one can see it is updating and when it was ran last.
   if (curdevtext ~= txt) then
      commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. txt
      print ('afvalWijzer: Update device from: \n'.. otherdevices[myAfvalDevice] .. '\n replace with:\n' .. txt)
   else
      print ('afvalWijzer: No updated text for TxtDevice.')
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
   debug = true     -- activate debug here to only log the update process in detail
   Perform_Update()
else
   dprint("Scheduled time(s) not reached yet, so nothing to do!")
end

return commandArray
