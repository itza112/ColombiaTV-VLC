--[[
    Translate TVN Fakty URLs to the corresponding mp4 URL.

 $Id$

 Copyright © 2011 tuxfre (http://benjamin.vigier.biz)

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
        and string.match( vlc.path, "tvn24.pl" ) 
end

-- Parse function.
function parse()
    while true do
        line = vlc.readline()
        if not line then break end
        if string.match(line, "TYTUL" ) then
			vlc.msg.info("Searching for title ...")
			_,_,title = string.find( line, "{name: \"TYTUL\", value: \"([^\"]*)\"" )
			vlc.msg.info("Found at"..title)
        end
        if string.match(line, "var mp =" ) then
			vlc.msg.info("Searching for artwork ...")
			_,_,art = string.find( line, ", '(.-%.jpg)&" )
			art = "http://m.onet.pl/_m/"..art
			vlc.msg.info("Found at"..art)
        end
        if string.match(line, "http://www.tvn24.pl/_mv/" ) then
			vlc.msg.info("Searching for video ...")
            _,_,video = string.find( line, "_mv/(.-%.mp4)" )
            video = "http://www.tvn24.pl/_mv/"..video
			vlc.msg.info("Found at"..video)
        end
        if video and title and art then break end
    end
    if video and art and title then
        return { { path = video; arturl = art; title = title } }
    elseif video and title then
        return { { path = video; title = title } }    
    elseif video and art then
        return { { path = video; arturl = art } }
    elseif video then
        return { { path = video } }
    else
        return { }
    end
end
