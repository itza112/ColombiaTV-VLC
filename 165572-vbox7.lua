--[[
 $Id$
 
 vbox7.com parser for VLC media player 2.x.x
 Copyright © 2014 V.G.Marinov

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
--]]

-- Probe function.
function probe()
    return vlc.access == "http" 
		and string.match( vlc.path, "vbox7%.com.+play" )
end

-- Parse function.
function parse()		
	playID = string.match( vlc.path, "%w+$"):sub(3)	
	reply = vlc.stream( "http://svalqm.com/index.php?id=vbox7&url=http://vbox7.com/play:" .. playID )
	while true
	do
		line = reply:readline()
		if not line then break end
		if string.match( line, "dl%-button" ) then			
			return 
			{ 
				{	
					path = string.match( line, "https?://[%w-_%.%?%.:/%+=&]+" ); 
					name = "vbox7.com/play:" .. playID
				}
			}			
		end
	end
	return {}
end
