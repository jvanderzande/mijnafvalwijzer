-----------------------------------------------------------------------------------------------------------------
-- afvalWijzer module gemeente Westland
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
   ["grijs"] ={hour=21,min=0,daysbefore=1},	 -- get notification at 21:00 the day before for grijs
   ["groen"] ={hour=21,min=0,daysbefore=1},	 -- get notification at 21:00 the day before for groen
   ["papier"]={hour=12,min=0,daysbefore=0}}  -- get notification at 12:00 the same day for papier
local debug = false                          -- get debug info in domoticz console/log
--==== end of config =================================================================
-- Functions =========================================================================
-- round
function Round(num, idp)
   return tonumber(string.format("%." ..(idp or 0).. "f", num))
end
-- debug print
function dprint(text)
   if debug then print(" Afval debug:"..text) end
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
   print('afvalWijzer module start')

   -- get data from afvalWijzer
   local commando = "curl 'https://bijmijindebuurt.gemeentewestland.nl/huisvuilkalender/Huisvuilkalender/get-huisvuilkalender-ajax' -H 'Origin: https://bijmijindebuurt.gemeentewestland.nl' -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H 'Accept: application/json, text/javascript, */*; q=0.01' -H 'Referer: https://bijmijindebuurt.gemeentewestland.nl/huisvuilkalender?dummy=0.9778403611955824' -H 'X-Requested-With: XMLHttpRequest' -H 'Connection: keep-alive' --data 'postcode=" .. Postcode .. "&query=' --compressed"
   local Webdata = os.capture(commando, 5)
   local planning = ""
   local logtxt = ""
   dprint("Curl URL:"..commando)
   dprint("Curl returned Webdata:"..Webdata)
   if (Webdata == "") then
      print("! afvalWijzer: Error Webdata is empty.")
      return
   elseif (Webdata == "" or string.find(Webdata,'{"error":true}') ~= nil) then
      print("! afvalWijzer: Error returned ... check postcode   Webdata:" .. Webdata )
      return
   end
   -- Read from the data table, and extract duration and distance in value. Divide distance by 1000 and duration_in_traffic by 60
   local web_afvaltype=""
   local web_afvaltype_date=""
   local i = 0
   local curTime = os.time{day=timenow.day,month=timenow.month,year=timenow.year}
   local MON={jan=1,feb=2,maa=3,apr=4,mei=5,jun=6,jul=7,aug=8,sep=9,okt=10,nov=11,dec=12}
   -- loop through returned result
   while (string.find(Webdata, "soort-") ~= nil) do
      -- get next plan
      web_afvaltype,web_afvaltype_date=Webdata:match('.-soort.(.-)%sclearfix.-text dag\\">(.-)<\\/span')
      if (web_afvaltype == nil) then
         dprint("web_afvaltype:nil")
         break
      end
      if (web_afvaltype_date == nil) then
         print ('! afvalWijzer: "text dag" not found in Webdata for ' .. web_afvaltype)
         print ('! afvalWijzer: Webdata: ' .. Webdata)
         break
      end
      i=i+1
      dprint("web_afvaltype:"..tostring(web_afvaltype).."   web_afvaltype_date:"..tostring(web_afvaltype_date))
      logtxt = logtxt .. web_afvaltype .. " - " .. web_afvaltype_date.. " ; "
      planning = planning .. web_afvaltype .. "-" .. web_afvaltype_date.. "\r\n"
      -- Calculate the daysdifference between found date and Now and send notification is required
      local afvalday,s_afvalmonth,afvalyear=web_afvaltype_date:match("%a+ (%d+) (%a+) (%d+)")
      local afvalmonth = MON[s_afvalmonth:sub(1,3)]
      local afvalTime = os.time{day=afvalday,month=afvalmonth,year=afvalyear}
      local daysdifference = Round(os.difftime(afvalTime, curTime)/86400,0)   -- 1 day = 86400 seconds
      if (afvaltype_cfg[web_afvaltype] == nil) then
         print ('! afvalWijzer: Afvalsoort not defined in afvaltype_cfg for found Afvalsoort Webdata: ' .. web_afvaltype)
      end
      dprint("daysdifference:"..tostring(daysdifference).."   afvaltype_cfg[web_afvaltype].daysbefore:"..tostring(afvaltype_cfg[web_afvaltype].daysbefore))
      dag = ""
      dagb = nil
      if (timenow.hour==afvaltype_cfg[web_afvaltype].hour
      and timenow.min==afvaltype_cfg[web_afvaltype].min
      and daysdifference == afvaltype_cfg[web_afvaltype].daysbefore) then
         dagb = afvaltype_cfg[web_afvaltype].daysbefore
      end
      if (afvaltype_cfg[web_afvaltype.."2"] ~= nil
      and timenow.hour==afvaltype_cfg[web_afvaltype.."2"].hour
      and timenow.min==afvaltype_cfg[web_afvaltype.."2"].min
      and daysdifference == afvaltype_cfg[web_afvaltype.."2"].daysbefore) then
         dagb = afvaltype_cfg[web_afvaltype.."2"].daysbefore
      end
      if dagb ~= nil then
         print ('afvalWijzer Notification send for ' .. web_afvaltype)

         if dagb == 0 then
            dag = "vandaag"
         elseif dagb == 1 then
            dag = "morgen"
         else
            dag = "over " .. dagb .. " dagen"
         end
         local notificationtext = "afvalWijzer: " .. dag .. " wordt ".. web_afvaltype .. " afval opgehaald!"
         commandArray['SendNotification']='Afvalwijzer#'..notificationtext
      end
      -- strip Webdata and get date from Webdata
      Webdata = Webdata:sub(string.find(Webdata, "<\\/li>")+5)
      if (i == 0) then
         print ('! afvalWijzer: No valid information found in Webdata:' .. tostring(Webdata) )
      end
      -- update device when text changed
      dprint("=======================================================")
      dprint("== planning:"..planning)

      commandArray['UpdateDevice'] = otherdevices_idx[myAfvalDevice] .. '|0|' .. planning
      print ('afvalWijzer update: ' .. logtxt)
   end
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
