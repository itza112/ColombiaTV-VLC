--[[
	Version 1.2.0 -- check for updates at
	https://addons.videolan.org/p/1278915/

	Copyright © 2018-2020 Palladium

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
		and (string.match(vlc.path, "dailymotion%.com/video/") or string.match(vlc.path, "dailymotion%.com/player/metadata/"))
end

-- Parse function.
function parse()
	if string.match(vlc.path, "dailymotion%.com/video/") then
		return parse_video_page()
	elseif string.match(vlc.path, "dailymotion%.com/player/metadata/") then
		return parse_metadata()
	end

	vlc.msg.err("Failed to extract a video URL")
	return {}
end

function parse_video_page()
	local line
	while true do
		line = vlc.readline()
		if line == nil then
			break
		end

		if string.match(line, "var __PLAYER_CONFIG__ = ") then
			local video_id = string.match(vlc.path, "/video/([^&]+)")
			local metadata_url = string.match(line, "\"metadata_template_url\":\"(.-)\"")
			if metadata_url ~= nil then
				metadata_url = string.gsub(metadata_url, "\\/", "/")
				metadata_url = string.gsub(metadata_url, ":videoId", video_id)
				metadata_url = string.gsub(metadata_url, ":embedder", "")
				metadata_url = string.gsub(metadata_url, ":referer", "")
				metadata_url = string.gsub(metadata_url, ":onsite", "")
			end
			return { { path = metadata_url } }
		end
	end

	vlc.msg.err("Failed to extract a video URL")
	return {}
end

function parse_metadata()
	local line
	while true do
		line = vlc.readline()
		if line == nil then
			break
		end

		local title = string.match(line, "\"title\":\"(.-)\"")
		local duration = tonumber(string.match(line, "\"duration\":(.-)"))
		local arturl = string.match(line, "\"posters\":{\".-\":\"(.-)\".*}")
		if arturl ~= nil then
			arturl = string.gsub(arturl, "\\/", "/")
		end

		local url
		local hls_url = string.match(line, "\"qualities\":{\"auto\":%[.-,\"url\":\"(.-)\".-%]}")
		if hls_url ~= nil then
			hls_url = string.gsub(hls_url, "\\/", "/")
			url = parse_hls(hls_url)
		end

		if url ~= nil then
			url = string.gsub(url, "\\/", "/")
			return { { path = url; name = title; duration = duration; arturl = arturl; } }
		end
	end

	vlc.msg.err("Failed to extract a video URL")
	return {}
end

function parse_hls(hls_url)
    local line
    local hls_stream
	local current_highest_resolution = 0
	local resolution
	local resolution_limit = math.huge
	local preferred_resolution = vlc.var.inherit(nil, "preferred-resolution")
	if preferred_resolution > 0 then
		resolution_limit = preferred_resolution
	end
    local hls = vlc.stream(hls_url)
    while true do
        line = hls:readline()
        if line == nil then
            break
        end
        local resolution = string.match(line, "RESOLUTION=%d+x(.-),")
        if resolution ~= nil then
            resolution = tonumber(resolution)
            if resolution > current_highest_resolution and resolution <= resolution_limit then
                current_highest_resolution = resolution
                hls_stream = hls:readline()
            end
        end
    end
    return hls_stream
end
