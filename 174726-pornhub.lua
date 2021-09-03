--[[
 $Id$

 Copyright © 2007-2012 the VideoLAN team

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

-- Helper function to get a parameter's value in a URL
--function get_url_param( url, name )
--    local _, _, res = string.find( url, "[&?]"..name.."=([^&]*)" )
--    return res
--end

-- Probe function.
function probe()
    return vlc.access == "http"
        and string.find( vlc.path, "www.pornhub.com/view_video.php" )
end

-- Parse function.
function parse()
    local items
    local arturl
    local name
    local duration
    local line

    while true do
        line = vlc.readline()
        if not line then break end

        if not arturl then
            arturl = string.match( line, "\"image_url\":\"(.-)\"")
            if arturl then arturl = arturl:gsub("\\","") end
        end

        if not name then
            name = string.match( line, "\"video_title\":\"(.-)\"")
        end

        if not duration then
            duration = string.match( line, "\"video_duration\":\"(.-)\"")
        end


        for resolution, path in string.gmatch( line, "var player_quality_(.-)p = '(.-)'" ) do
            if not items then items = {} end
            local item = {}
            item.path = path
            item.resolution = resolution
            if not name then name = "from pornhub" end
            item.name = "[" .. resolution .. "] " .. name
            if (arturl) then item.arturl = arturl end
            if (duration) then item.duration = duration end
            table.insert(items, item)
        end

        if items then
            table.sort(items, function(a,b) return a.resolution > b.resolution  end)
            return items
        end
    end
    return {}
end
