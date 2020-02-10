#There is total new rewrite of these scripts available in this repository: https://github.com/jvanderzande/GarbageCalendar
#This repository will not be maintained any further.





These Domoticz time scripts will retrieve the next garbage collection for your home address and update a TEXT device in Domoticz for the available regions/gemeentes.<br>
It will also send you a notification at the specified time 0-x days before the event.

# mijnafvalwijzer
This script is for the site mijnafvalwijzer.nl
This version is based on the idea from this thread/posts:
by zicht @ http://www.domoticz.com/forum/viewtopic.php?t=17963
script version by nf999 @ http://www.domoticz.com/forum/viewtopic.php?f=61&t=17963&p=174908#p169637

# huisvuil-opzet
The <b>script_time_huisvuil-opzet.lua</b> script is a generic screen scraping script for all gemeentes that use the service of OPZET.NL.
This makes the separate scripts for Pumerend, Zuidwest Friesland and mijnblink (for the gemeentes: Laarbeek, Deurne, Gemert-Bakel, Heeze-Leende, Someren, Asten en Nuenen) obsolete as they are supported by this script. check their website for supported gemeentes: http://www.opzet.nl/afvalkalender_digitaal
or check the afvalkalender of your gemeente and check whether it refers at the bottom of the page to "Ontwerp & techniek: Opzet".<br>
The <b>script_time_huisvuil-opzet_json.lua</b> script is created for those gemeentes that use OPZET but do not support the screenscraping (script_time_huisvuil-opzet.lua) version. This version will perform 3 API call and will save the result of 2 of these call into cachefiles “opzet-afvalstromen.txt” & “Opzet-bagid.txt”.

# huisvuil-westland
This script is for the site huisvuilkalender.gemeentewestland.nl for the gemeente Westland.

# huisvuil-zuidlimburg (RD4)
This script is for the site www.rd4info.nl for the gemeentes in Zuid Limburg.

# huisvuil-deafvalapp
This script is for the site deafvalapp.nl for the gemeentes Bergeijk, Bladel, Boekel, Boxmeer, Buren, Cuijk, Culemborg,
Echt-Susteren, Eersel, Geldermalsen, Grave,Helmond, Lingewaal, Maasdriel, Mill en Sint Hubert, Neder-BetuweNeerijnen,
Oirschot, Reusel-De Mierden, Sint Anthonis, Someren, Son en Breugel, Terneuzen, Tiel, West Maas en Waal, Zaltbommel.

# huisvuil-ophaalkalender-be
This script is for the site www.ophaalkalender.be for the gemeentes supported by https://www.fostplus.be

# script_time_huisvuil-goeree-overflakkee
This script is for the site https://webadapter.watsoftware.nl for the gemeente Goeree-Overflakkee.

# Obsolete:
<b>huisvuil-purmerend</b>
(Please use script_time_huisvuil_opzet.lua going forward)

<b>huisvuil-zuidwest-friesland</b>
(Please use script_time_huisvuil_opzet.lua going forward)

<b>huisvuil-mijnblink</b>
(Please use script_time_huisvuil_opzet.lua going forward)
