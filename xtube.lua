--[[
    Version 1.0.0 -- check for updates at
    https://addons.videolan.org/p/1404592/

    Copyright © 2020 Palladium

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
    return (vlc.access == "http" or vlc.access == "https")
        and (string.match(vlc.path, "xtube%.com/video%-watch"))
end

-- Parse function.
function parse()
    local line
    while true do
        line = vlc.readline()
        if line == nil then
            break
        end

        if string.match(line, "playerConf") then
            local title = vlc.strings.resolve_xml_special_chars(string.match(line, "\"title\":\"(.-)\""))
            local duration = string.match(line, "\"duration\":([0-9]+)")
            local arturl = string.match(line, "\"poster\":\"(.-)\"")
            if arturl ~= nil then
                arturl = string.gsub(arturl, "\\/", "/")
            end

            local available_resolutions = string.match(line, "\"format\":{(.-)}")
            local current_highest_resolution = 0
            local resolution_limit = math.huge
            local preferred_resolution = vlc.var.inherit(nil, "preferred-resolution")
            if preferred_resolution > 0 then
                resolution_limit = preferred_resolution
            end
            local resolution
            local url
            for resolution,stream_url in string.gmatch(available_resolutions, "\"(.-)\":\"(.-)\"") do
                resolution = tonumber(resolution)
                if stream_url ~= nil and resolution > current_highest_resolution and resolution <= resolution_limit then
                    url = stream_url
                    current_highest_resolution = resolution
                end
            end
            if url ~= nil then
                url = string.gsub(url, "\\/", "/")
                return { { path = url; name = title; duration = duration; arturl = arturl } }
            end
        end
    end
    
    vlc.msg.err("Failed to extract a video URL")
    return {}

end
