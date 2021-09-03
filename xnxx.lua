--[[
    Version 1.0.0 -- check for updates at
    https://addons.videolan.org/p/1292810/

    Copyright © 2019 Palladium

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
        and (string.match(vlc.path, "xnxx%.com/video"))
end

-- Parse function.
function parse()
    local line
    local title, url, arturl, duration
    local hls_url
    while true do
        line = vlc.readline()
        if line == nil then
            break
        end

        if hls_url == nil then
            hls_url = string.match(line, "setVideoHLS%('(.-)'%)")
            if hls_url ~= nil then
                local base_url = string.match(hls_url, "^(.-)[\\/]?([^\\/]*)$")
                local hls_stream = parse_hls(hls_url)
                url = base_url .. "/" .. hls_stream
            end
        end

        if title == nil then
            title = string.match(line, "setVideoTitle%('(.-)'%)")
        end

        if duration == nil then
            duration = string.match(line, "og:duration\" content=\"(.-)\"")
        end

        if arturl == nil then
            arturl = string.match(line, "setThumbUrl%('(.-)'%)")
        end

        if url ~= nil and title ~= nil and duration ~= nil and arturl ~= nil then
            return { { path = url; name = title; duration = duration; arturl = arturl } }
        end
    end
    
    vlc.msg.err("Failed to extract a video URL")
    return {}

end

function parse_hls(hls_url)
    local line
    local hls_stream
    local current_highest_resolution = 0
    local hls = vlc.stream(hls_url)
    while true do
        line = hls:readline()
        if line == nil then
            break
        end
        local resolution = string.match(line, "RESOLUTION=%d+x(.-),")
        if resolution ~= nil then
            resolution = tonumber(resolution)
            if resolution > current_highest_resolution then
                current_highest_resolution = resolution
                hls_stream = hls:readline()
            end
        end
    end
    return hls_stream
end
