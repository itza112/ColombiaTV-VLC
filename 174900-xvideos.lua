--[[

 $Id$
 Copyright © 2016 the VideoLAN team

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
		and string.match( vlc.path, "xvideos.com/video" )
end

-- Parse function.
function parse()
	p = {}
	title = "video from xvideos"
	arturl = " "
	while true
	do
		line = vlc.readline()
		if not line then break end

		if string.match( line, "<meta property=\"og:image\" content=\"" ) then
			arturl = string.match( line, "content=\"(.-)\" />" )
		end

		if string.match( line, "html5player\.setVideoTitle" ) then
			title = string.match( line, "setVideoTitle..(.-)..;" )
		end

		if string.match( line, "html5player\.setVideoUrlHigh" ) then
			path = string.match( line, "setVideoUrlHigh..(.-)..;" )

			if path then
				table.insert( p, { path = path; arturl = arturl; name = title; url = vlc.path;} )
			end

		end

	end
	return p
end
