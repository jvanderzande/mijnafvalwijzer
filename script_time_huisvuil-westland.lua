-----------------------------------------------------------------------------------------------------------------
-- WestlandAfval module gemeente Westland
-----------------------------------------------------------------------------------------------------------------
-- curl in os required!!
-- create dummy text device from dummy hardware with the name defined for: myAfvalDevice
-- Check the below defined config fields
-- based on script by zicht @ http://www.domoticz.com/forum/viewtopic.php?t=17963
local myAfvalDevice='Afval Kalender'
local Postcode = "229???"                    -- Specif your postcode
 -- define a line for each afvaltype_cfg retuned by the webrequest:
 -- hour & min ==> the time the check needs to be performed and notification send when daysbefore is true
 -- daysbefore ==> 0 means that the notification is send the day of the planned garbage collection
 -- daysbefore ==> X means that the notification is send X day(s) before the day of the planned garbage collection
local afvaltype_cfg = {
   ["grijs"] ={hour=21,min=0,daysbefore=1},	-- get notification at 21:00 the day before for grijs
   ["groen"] ={hour=21,min=0,daysbefore=1},	-- get notification at 21:00 the day before for groen
   ["papier"]={hour=12,min=0,daysbefore=0}}  -- get notification at 12:00 the same day for papier
local debug = false                          -- get debug info in domoticz console/log
--==== end of config =================================================================

-- Functions =========================================================================
-- round
function Round(num, idp)
   return tonumber(string.format("%." ..(idp or 0).. "f", num))
end
-- daysdiff calculation
function DaysDiff(sdate)
   local MON={jan=1,feb=2,maa=3,apr=4,mei=5,jun=6,jul=7,aug=8,sep=9,okt=10,nov=11,dec=12}
   local curTime = os.time{day=timenow.day,month=timenow.month,year=timenow.year}
   local afvalday,s_afvalmonth,afvalyear=sdate:match("%a- (%d+) (%a+) (%d+)")
   local afvalmonth = MON[s_afvalmonth:sub(1,3)]
   local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
   return Round(os.difftime(afvalTime, curTime)/86400,0)   -- 1 day = 86400 seconds
end
-- debug print
function dprint(text)
   if debug then print("@WAD:"..text) end
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
-- get information from website, update device and send notofication when required
function getdata()
   print('WestlandAfval --> module start')

   -- get data from afvalWijzer
   local commando = "curl -k 'https://huisvuilkalender.gemeentewestland.nl/huisvuilkalender/Huisvuilkalender/get-huisvuilkalender-ajax' -H 'Origin: https://huisvuilkalender.gemeentewestland.nl' -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H 'Accept: application/json, text/javascript, */*; q=0.01' -H 'Referer: https://huisvuilkalender.gemeentewestland.nl/huisvuilkalender?dummy=0.9778403611955824' -H 'X-Requested-With: XMLHttpRequest' -H 'Connection: keep-alive' --data 'postcode=" .. Postcode .. "&query=' --compressed"
   local Webdata = os.capture(commando, 5)
   local planning = ""
   local logtxt = ""
   dprint("Curl URL:"..commando)
   dprint("Curl returned Webdata:"..Webdata)
   if Webdata == "" then
      print("! WestlandAfval -->: Error Webdata is empty.")
      return
   elseif string.find(Webdata,'{"error":true}') ~= nil then
      print("! WestlandAfval -->: Error returned ... check postcode   Webdata:" .. Webdata )
      return
   end
   -- Read from the data table, and extract duration and distance in value. Divide distance by 1000 and duration_in_traffic by 60
   local web_afvaltype=""
   local web_afvaltype_date=""
   local web_afvaltype_changed=""
   local i = 0
   -- loop through returned result
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- voorbeeld normale melding
-- <li class=\"soort-groen clearfix\">\r\n\t\t\t\t<span class=\"afvalicon\"><\/span>\r\n\t\t\t\t
-- <span class=\"text dag\">Vrijdag 20 april 2018<\/span>\r\n\t\t\t\t\t\t\t\t\t
-- <span class=\"text info\">In de even weken op vrijdag<\/span>\r\n\t\t\t\t\t\t\t<\/li>\r\n\t\t\t\t\t

-- voorbeeld uitzonderings melding
-- <li class=\"soort-grijs clearfix\">\r\n\t\t\t\t<span class=\"afvalicon\"><\/span>\r\n\t\t\t\t
-- <span class=\"text dag uitzondering\">Vrijdag 27 april 2018<\/span>\r\n\t\t\t\t\t\t\t\t\t<span class=\"text info\">
-- <span class=\"uitzondering-tekst\">Let op: \u00e9\u00e9nmalig verschoven naar zaterdag 28 april 2018<\/span><br>In de oneven weken op vrijdag<\/span>\r\n\t\t\t\t\t\t\t<\/li>\r\n\t\t\t\t\t
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

   for web_afvaltype,web_afvaltype_date in string.gmatch(Webdata, '.-soort.(.-)%sclearfix.-text dag.-\\">(.-)<\\/span') do

      if (web_afvaltype == nil) then
         print ('! WestlandAfval -->: "web_afvaltype" not found Webdata ... Stopping process' )
         dprint("web_afvaltype:nil")
         break
      end
      if (web_afvaltype_date == nil) then
         print ('! WestlandAfval -->: "text dag" not found in Webdata for ' .. web_afvaltype)
         print ('! WestlandAfval -->: Webdata: ' .. Webdata)
         break
      end
      -- get deviating pickup due to holidays
      local web_afvaltype_date_real=web_afvaltype_date
      for web_afvaltype_date_tmp in string.gmatch(Webdata, '.-soort.'..web_afvaltype..'%sclearfix.-uitzondering.tekst\\">(.-)<\\/span') do
         web_afvaltype_date_tmp = string.gsub(web_afvaltype_date_tmp,"\\u00e9","é")
         dprint('afwijkende datum voor '..tostring(web_afvaltype).."  ==> "..tostring(web_afvaltype_date_tmp))
         web_afvaltype_date_real=web_afvaltype_date_tmp
      end
      -- replace \uxxxx characters
      i=i+1
      dprint("web_afvaltype:"..tostring(web_afvaltype).."   web_afvaltype_date:"..tostring(web_afvaltype_date).."   web_afvaltype_date_real:"..tostring(web_afvaltype_date_real))
      logtxt = logtxt .. web_afvaltype .. " - " .. web_afvaltype_date.. " ; "
      planning = planning .. web_afvaltype .. "-" .. web_afvaltype_date_real.. "\r\n"
      -- Calculate the daysdifference between found date and Now and send notification is required
      local daysdifference = DaysDiff(web_afvaltype_date)
      local daysdifference_real = DaysDiff(web_afvaltype_date_real)
      if (afvaltype_cfg[web_afvaltype] == nil) then
         print ('! WestlandAfval -->: Afvalsoort not defined in afvaltype_cfg for found Afvalsoort Webdata: ' .. web_afvaltype)
      end
      dprint("i:"..i.." daysdifference:"..tostring(daysdifference).." daysdifference_real:"..tostring(daysdifference_real).."   afvaltype_cfg[web_afvaltype].daysbefore:"..tostring(afvaltype_cfg[web_afvaltype].daysbefore))
      -- Original date notification of change
      if (timenow.hour==afvaltype_cfg[web_afvaltype].hour
      and timenow.min==afvaltype_cfg[web_afvaltype].min
      and daysdifference == afvaltype_cfg[web_afvaltype].daysbefore
      and daysdifference ~= daysdifference_real) then
         local notificationtext = "WestlandAfval -->: ".. web_afvaltype .. " - " .. web_afvaltype_date_real
         commandArray['SendNotification']='WestlandAfval -->#'..notificationtext
      end
      -- first notification
      if (timenow.hour==afvaltype_cfg[web_afvaltype].hour
         and timenow.min==afvaltype_cfg[web_afvaltype].min
         and daysdifference_real == afvaltype_cfg[web_afvaltype].daysbefore)
      or (afvaltype_cfg[web_afvaltype.."2"] ~= nil
         and timenow.hour==afvaltype_cfg[web_afvaltype.."2"].hour
         and timenow.min==afvaltype_cfg[web_afvaltype.."2"].min
         and daysdifference_real == afvaltype_cfg[web_afvaltype.."2"].daysbefore)
      then
         print ('WestlandAfval --> Notification send for ' .. web_afvaltype)
         local dagtext = ""
         if daysdifference_real == 0 then
            dagtext = "vandaag"
         elseif daysdifference_real == 1 then
            dagtext = "morgen"
         elseif daysdifference_real == 2 then
            dagtext = "overmorgen"
         else
            dagtext = "over " .. daysdifference_real .. " dagen"
         end
         local notificationtext = "WestlandAfval -->: " .. dagtext .. " wordt ".. web_afvaltype .. " afval opgehaald!"
         commandArray['SendNotification']='WestlandAfval -->#'..notificationtext
      end
   end
   if (i == 0) then
      print ('! WestlandAfval -->: No valid information found in Webdata:' .. tostring(Webdata) )
   end
   -- update device when text changed
   dprint("=======================================================")
   dprint("== planning:"..planning)

   commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. planning
   print ('WestlandAfval --> update: ' .. logtxt)
end

-- End Functions =========================================================================

-- Start of logic ========================================================================
commandArray = {}

timenow = os.date("*t")
-- check for notification times and run update only when we at one of these defined times
local needupdate = false
for avtype,get in pairs(afvaltype_cfg) do
   dprint("- afvaltype_cfg :"..tostring(avtype)..";"..tostring(afvaltype_cfg[avtype].hour)..";"..tostring(afvaltype_cfg[avtype].min))
   if timenow.hour==afvaltype_cfg[avtype].hour
   and timenow.min==afvaltype_cfg[avtype].min then
      needupdate = true
   end
end
if needupdate then
   getdata()
else
   dprint("Not time to run update.")
end

return commandArray
