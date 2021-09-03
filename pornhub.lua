--[[
    Version 1.6.0 -- check for updates at
    https://addons.videolan.org/p/1236338/

    Copyright © 2018-2021 Palladium

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
        and (string.match(vlc.path, "pornhub%.com"))
end

-- Parse function.
function parse()
    local line
    while true do
        line = vlc.readline()
        if line == nil then
            break
        end

        if string.match(line, "flashvars") then
            local main_parameters_line = line
            local title = vlc.strings.resolve_xml_special_chars(string.match(line, "\"video_title\":\"(.-)\""))
            local duration = string.match(line, "\"video_duration\":\"(.-)\"")
            local arturl = string.match(line, "\"image_url\":\"(.-)\"")
            if arturl ~= nil then
                arturl = string.gsub(arturl, "\\/", "/")
            end

            while true do
                line = vlc.readline()
                if line == nil then
                    break
                elseif string.match(line, "flashvars") then
                    line = vlc.readline()
                    break
                end
            end

            local current_highest_resolution = 0
            local resolution_limit = math.huge
            local preferred_resolution = vlc.var.inherit(nil, "preferred-resolution")
            if preferred_resolution > 0 then
                resolution_limit = preferred_resolution
            end
            local resolution
            local resolution_index = 0
            local url
            for _,resolution in ipairs({1080, 720, 480, 240}) do
                local stream_url = string.match(line, "\"id\":\"quality" .. resolution .. "p\",.-\"url\":\"(.-)\"")
                if stream_url ~= nil and stream_url ~= "" and resolution > current_highest_resolution and resolution <= resolution_limit then
                    url = stream_url
                    current_highest_resolution = resolution
                end
            end
            if url == nil then
                local stream_definitions = parse_stream_definitions(line)
                local available_resolutions = string.match(main_parameters_line, "\"mediaDefinitions\":%[(.-)%]")
                for resolution in string.gmatch(available_resolutions, "\"quality\":\"(.-)\"") do
                    resolution = tonumber(resolution)
                    local stream_url = string.match(main_parameters_line, "\"quality\":\"" .. resolution .. "\",\"videoUrl\":\"(.-)\"")
                    if stream_url == nil or stream_url == "" then
                        stream_url = stream_definitions["quality_" .. resolution .. "p"]
                    end
                    if stream_url == nil or stream_url == "" then
                        stream_url = stream_definitions["media_" .. resolution_index]
                    end
                    if stream_url ~= nil and resolution > current_highest_resolution and resolution <= resolution_limit then
                        url = stream_url
                        current_highest_resolution = resolution
                    end
                    resolution_index = resolution_index + 1
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

function parse_stream_definitions(statements)
    statements = string.gsub(statements, "/%*[^;]-%*/", "")
    local variables = {}
    for statement in string.gmatch(statements, "[^;]+") do
        if statement ~= nil and not string.match(statement, "%[") then
            local variable, expression = string.match(statement, "%s*(.-)%s*=(.+)")
            variable = string.gsub(variable, "^%s*var%s+", "")
            variables[variable] = parse_expression(expression, variables)
        end
    end
    return variables
end

function parse_expression(expression, variables)
    if string.match(expression, "+") then
        local result = ""
        for concatenation_element in string.gmatch(expression, "[^%+]+") do
            result = result .. parse_expression(concatenation_element, variables)
        end
        return result
    end
    expression = string.gsub(expression, "^%s*(.-)%s*$", "%1")
    if variables[expression] ~= nil then
        return variables[expression]
    end
    return string.gsub(expression, "\"(.-)\"", "%1")
end
