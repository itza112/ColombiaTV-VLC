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
		and string.find( vlc.path, "redtube.com/[0-9]" )
end

-- Parse function.
function parse()
	local title = "video from redtube"
	local arturl = " "
	local items
	local p = {}
	while true do
		line = vlc.readline()
		if not line then break end

		if string.match( line, "<title>" ) then
			title = string.match( line, "<title>(.-) | " )
		end

-- poster: "http:\/\/mimg01.redtubefiles.com\/m=enFamIbWx\/_thumbs\/0001420\/1420156\/1420156_013i.jpg",
		if string.match( line, "poster:" ) then
			arturl = string.match( line, "poster: \"(.-)\"" )
		end

-- sources: {"720":"http:\/\/vida.lsw.hd.redtubefiles.com\/videos\/0001420\/_hd\/1420156.mp4?st=QLk0N6GGWKjUq8DQUPiBBw&e=1454044709","480":"http:\/\/vida.lsw.redtubefiles.com\/videos\/0001420\/_mp4\/1420156.mp4?st=9KnwyOJUirWUeNpYKLoFwQ&e=1454044709"},
		if string.match( line, "sources: {" ) then
			for videodiv in string.gmatch(line, "sources: {(.-)},") do
				for resolution, path in string.gmatch( videodiv, "\"(.-)\":\"(.-)\"" ) do
					if not items then items = {} end
					local item = {}
					local zzz = string.gsub(path, "\\","")
					if string.find(zzz, "http:") == nil then
						zzz = "http:" .. zzz
					end
					item.path = zzz
					item.resolution = resolution
					item.name = "[" .. resolution .. "] " .. title
					if (arturl) then item.arturl = string.gsub(arturl, "\\","") end
					table.insert(items, item)
				end
			end
		end

		if items then
			table.sort(items, function(a,b) return a.resolution > b.resolution	end)
			return items
		end

	end
	return p
end



