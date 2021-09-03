--[[
 Copyright © 2011 AUTHORS

 Authors: ale5000

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
--]]

--[[
	How to install and use:
	1) Install VLC 1.1.0 or higher
	2) Place the script in:
		- Windows (all users):		%ProgramFiles%\VideoLAN\VLC\lua\playlist\
		- Windows (current user):	%APPDATA%\VLC\lua\playlist\
		- Linux (all users):			/usr/share/vlc/lua/playlist/
		- Linux (current user):		~/.local/share/vlc/lua/playlist/
		- Mac OS X (all users):		/Applications/VLC.app/Contents/MacOS/share/lua/playlist/
	3) Open in VLC an url of a IIS Smooth Streaming manifest

	Formats currently supported:
		- Video (vc-1)
		- Audio (none)

	Know issues
	- It only support ism / isml manifests
	- When you start a video you can't stop the downloading until is ended, the only solution is to kill vlc
	- Currently Mac OS X isn't supported
]]

-- Global variables, modify this (if needed)
operative_mode = 2	-- 1 => Live mode (gap between every fragment), 2 => Raw mode, 3 => Container mode
windows_player_path = "%ProgramFiles%\\VideoLAN\\VLC\\vlc.exe"
linux_player_path = "/usr/bin/vlc"
custom_user_temp_folder = ""

require "simplexml"

function descriptor()
	return {
				title = "IIS Smooth Streaming parser";
				version = "0.03";
				author = "ale5000";
				url = "http://addons.videolan.org/usermanager/search.php?username=ale5000&action=contents";
				description = "It allow to view IIS Smooth Streaming in VLC."
			}
end

-- Probe function
function probe()
	local path = vlc.path:lower()

	return ( vlc.access == "http" or vlc.access == "https" ) and
		( path:find("%.isml?/manifest$") ~= nil or path:find("%.isml?/manifest%?") ~= nil )
end


function string.substr(text, start, length)
	return text:sub(start, start - 1 + length)
end

function string.lastIndexOf(text, search)
	local start, last_pos = 0
	while start ~= nil do
		last_pos = start
		start = text:find(search, start + 1, true)
	end

	if last_pos == 0 then return nil end
	return last_pos
end

function string.skip_bytes(data, bytes)
	return data:sub(bytes + 1)
end

-- Returns a string that has the internal numerical code equal of the number passed
function math.number_to_binary_code(in_number)
	if in_number == 0 then return "\0" end

	local out_string = ""
	while in_number > 0 do
		out_string = string.char(in_number % 256)..out_string
		in_number = math.floor(in_number / 256)
	end
	return out_string
end

-- Returns a number with the internal numerical code of the string passed
function string.binary_code_to_number(in_string)
	local len, i, out_number = in_string:len() + 1, 0, 0
	while len > 1 do
		len = len - 1
		out_number = in_string:sub(len, len):byte() * (256^i) + out_number
		i = i + 1
	end
	return out_number
end

function string.hex_string_to_binary_code(in_string)
	local len, out_string = in_string:len() + 1, ""
	while len > 2 do
		len = len - 2
		out_string = string.char( "0x"..in_string:substr(len, 2) )..out_string
	end
	return out_string
end

function string.size_should_be(binary, required_length)
	local len_to_add = required_length - binary:len()
	if len_to_add < 0 then vlc.msg.err("size should be: The string is too long => "..binary) binary = "" len_to_add = required_length end

	while len_to_add > 0 do
		binary = "\0"..binary
		len_to_add = len_to_add - 1
	end
	return binary
end

function string.size_should_be__add_to_right(binary, required_length)
	local len_to_add = required_length - binary:len()
	if len_to_add < 0 then vlc.msg.err("size should be, add to right: The string is too long => "..binary) binary = "" len_to_add = required_length end

	while len_to_add > 0 do
		binary = binary.."\0"
		len_to_add = len_to_add - 1
	end
	return binary
end

function string.add_length(in_string)
	if in_string == "" then return "" end
	return math.number_to_binary_code(in_string:len() + 4):size_should_be(4)..in_string   -- The length of the length itself is included
end

function string.add_length_x_byte(in_string, size_of_length)
	return math.number_to_binary_code(in_string:len()):size_should_be(size_of_length)..in_string
end

--[[function string.base64_decode(data)   -- by Alex Kloss <alexthkloss AT web.de>
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, '[^'..b..'=]', '')
	return (data:gsub('.', function(x)
		if x == '=' then return '' end
		local r,f='',(b:find(x)-1)
		for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
		return r;
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c=0
		for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
		return string.char(c)
	end))
end]]


function show_error(error_msg, seconds)
	vlc.msg.err("[IIS Smooth Streaming parser] "..error_msg)
	if seconds == nil then seconds = "10" end
	return { {name="[Smooth] "..error_msg, path="vlc://pause:"..seconds} }
end

function log_message(message, msg_type)
	message = "[IIS Smooth Streaming parser] "..message

	if msg_type == "error" then
		vlc.msg.err(message)
		return false
	elseif msg_type == "info" then
		vlc.msg.info(message)
	elseif msg_type == "warning" then
		vlc.msg.warn(message)
	elseif msg_type == "debug" then
		vlc.msg.dbg(message)
	else
		vlc.msg.err(message.." (Invalid message type)")
		return false
	end

	return true
end

-- .ism => http://smoothstreaming.rai.it/unmedicoinfamiglia_150511.ism/Manifest
-- .ism => http://91.211.156.217/smooth/2011/05/1300e117c8c-1_h264.ism/manifest
function get_pos(url)
	url = url:lower()
	local pos = url:find("%.ism.?/manifest")

	if url:find(".ism/manifest", 1, true) ~= nil then	
		return pos + 4	-- => + 5 - 1
	else
		return pos + 5	-- => + 6 - 1
	end
end

function detect_os()
	local current_os, os_env = "unknown", os.getenv("OS")

	if os_env ~= nil and os_env:lower():find("windows", 1, true) ~= nil then
		return "windows"
	end

	-- http://en.wikipedia.org/wiki/Uname
	local hnd = io.popen("uname -s")
	if hnd then
		if hnd:read("*a"):lower():find("linux", 1, true) ~= nil then
			current_os = "linux"
		end
		hnd:close()
	end

	return current_os
end

function get_player_path(current_os, file_name)
	local player_path = nil
	if current_os == "windows" then
		player_path = 'start "" "'..windows_player_path..'" '..file_name
	elseif current_os == "linux" then
		player_path = linux_player_path.." "..file_name.." &"
	end

	return player_path
end

function string.extract_mdat(data)
	local pos = data:find("mdat", 1, true)
	local length = data:substr(pos - 4, 4):binary_code_to_number()
	return data:substr(pos + 4, length - 8)
end

function string.extract_uuid(data)
	local pos = data:lastIndexOf("uuid")
	if pos == nil then return nil end
	return data:substr(pos + 25, 8):binary_code_to_number()
end

function create_mp4_header(time_scale, duration, track_type, fourcc, video_codecprivatedata, width, height)
	--[[ The numbers between parentheses in the comments are the size in bytes (stored as unsigned integer unless specified) ]]
	local box_size, track_type_4, track_type_name, avc1_profile, avc1_level, SPS, PPS
	local box_version = "\1"	-- The value of Version can be \0 or \1
	if box_version == "\0" then box_size = 4 else box_size = 8 end
	time_scale = math.number_to_binary_code(time_scale):size_should_be(4)
	duration = math.number_to_binary_code(duration):size_should_be(box_size)
	local rate = "\0\1\0\0"	-- Signed 32-bit fixed point number having 16 fractional bits
	local volume = "\1\0"	-- Signed 16-bit fixed point number having 8 fractional bits
	local description_record_count, compressor_name = 0, ""

	-- Video track => vide, Audio track => soun, Data track => data, Hint track => hint, Timed metadata track => meta
	if track_type == "video" then
		description_record_count = description_record_count + 1
		track_type_4 = "vide"
		track_type_name = "VideoHandler".."\0"
		fourcc = fourcc:size_should_be(4)
		if fourcc == "avc1" then
			compressor_name = "AVC Coding"
			avc1_profile = "\0"
			avc1_level = "\0"	-- Probably it isn't correct to set it to 0
			_, _, SPS, PPS = video_codecprivatedata:find("^00000001(%x-)00000001(%x+)$")
			if SPS == nil or PPS == nil then return false end
			SPS = SPS:hex_string_to_binary_code()
			PPS = PPS:hex_string_to_binary_code()
		elseif fourcc == "vc-1" then
			log_message("FourCC: "..fourcc, "warning")
			-- It isn't ready
		else
			log_message("FourCC: "..fourcc, "warning")
			return false	-- Not yet supported
		end
	else
		log_message("Track type: "..track_type, "warning")
		return false	-- Not yet supported
	end

	width  = math.number_to_binary_code(width):size_should_be(2)
	height = math.number_to_binary_code(height):size_should_be(2)
	local width_16_16  = width.."\0\0"	-- Unsigned 32-bit fixed point number having 16 fractional bits
	local height_16_16 = height.."\0\0"	-- Unsigned 32-bit fixed point number having 16 fractional bits
	local horiz_resolution_16_16 = (math.number_to_binary_code(72).."\0\0"):size_should_be(4)	-- Unsigned 32-bit fixed point number having 16 fractional bits
	local vert_resolution_16_16 = (math.number_to_binary_code(72).."\0\0"):size_should_be(4)	-- Unsigned 32-bit fixed point number having 16 fractional bits

	-- File type box => Header (4), MajorBrand (4), MinorVersion (4), CompatibleBrands (4 x n)
	local ftyp_box = "ftyp".."mp42".."\0\0\0\0".."isom".."mp42"
	-- Free space box
	local free_box = "free".."File joined by ale5000's tool\0"

	-- Movie box => Header (4), Boxes (n x n)
	local moov_box = "moov"
		-- Movie header box => Header (4), Version(1), Flags (3), CreationTime (Version == 0 ? 4 : 8), ModificationTime (Version == 0 ? 4 : 8),
		local mvhd_box = "mvhd"..box_version.."\0\0\0"..("\0"):size_should_be(box_size)..("\0"):size_should_be(box_size)
						-- TimeScale (4), Duration (Version == 0 ? 4 : 8), Rate (signed 4), Volume (signed 2), Reserved (2), Reserved (4 x 2),
						..time_scale..duration..rate..volume.."\0\0".."\0\0\0\0".."\0\0\0\0"
						-- Matrix (signed 4 x 9),
						.."\0\1\0\0".."\0\0\0\0".."\0\0\0\0".."\0\0\0\0".."\0\1\0\0".."\0\0\0\0".."\0\0\0\0".."\0\0\0\0".."\64\0\0\0"
						-- Reserved (4 x 6),
						.."\0\0\0\0".."\0\0\0\0".."\0\0\0\0".."\0\0\0\0".."\0\0\0\0".."\0\0\0\0"
						-- NextTrackID (4) ?????? To CHECK
						..("\3"):size_should_be(4)
		-- Movie extends box => Header (4), Boxes (n x n)
		local mvex_box = "mvex"	-- Present when the file is fragmented MP4
			-- Track extends box => Header (4), Version(1), Flags (3), TrackID (4), DefaultSampleDescriptionIndex (4), DefaultSampleDuration (4), DefaultSampleSize (4),
			local trex_box = "trex".."\0".."\0\0\0".."\0\0\0\1".."\0\0\0\1".."\0\0\0\42".."\0\0\0\0"
							-- DefaultSampleFlags (4) => ?????? To CHECK
							.."\0\1\0\0"
		mvex_box = mvex_box..trex_box:add_length()
		-- Track box => Header (4), Boxes (n x n)
		local trak_box = "trak"
			local track_volume = "\0\0"
			if track_type_4 == "soun" then track_volume = volume end
			-- Track header box => Header (4), Version(1), Flags (3) ?????? To CHECK, CreationTime (Version == 0 ? 4 : 8), ModificationTime (Version == 0 ? 4 : 8),
			local tkhd_box = "tkhd"..box_version.."\0\0\15"..("\0"):size_should_be(box_size)..("\0"):size_should_be(box_size)
							-- TrackID (4), Reserved (4), Duration (Version == 0 ? 4 : 8), Reserved (4 x 2),
							.."\0\0\0\1".."\0\0\0\0"..duration.."\0\0\0\0".."\0\0\0\0"
							-- Layer (signed 2), AlternateGroup(signed 2), Volume (signed 2), Reserved (2),
							.."\0\0".."\0\0"..track_volume.."\0\0"
							-- TransformMatrix (signed 4 x 9),
							.."\0\1\0\0".."\0\0\0\0".."\0\0\0\0".."\0\0\0\0".."\0\1\0\0".."\0\0\0\0".."\0\0\0\0".."\0\0\0\0".."\64\0\0\0"
							-- Width (4), Height (4)
							..width_16_16..height_16_16
			-- Media box => Header (4), Boxes (n x n)
			local mdia_box = "mdia"
				-- Media header box => Header (4), Version(1), Flags (3), CreationTime (Version == 0 ? 4 : 8), ModificationTime (Version == 0 ? 4 : 8),
				local mdhd_box = "mdhd"..box_version.."\0\0\0"..("\0"):size_should_be(box_size)..("\0"):size_should_be(box_size)
								-- TimeScale (4), Duration (Version == 0 ? 4 : 8), Pad - Language (1 bit set to 0 + 5 x 3 bit = 2 bytes) ?????? To CHECK, Reserved (2)
								..time_scale..duration.."\85\196".."\0\0"
				-- Handler reference box => Header (4), Version(1), Flags (3), Predefined (4), HandlerType (4), Reserved (4 x 3), Name (n)
				local hdlr_box = "hdlr".."\0".."\0\0\0".."\0\0\0\0"..track_type_4.."\0\0\0\0".."\0\0\0\0".."\0\0\0\0"..track_type_name
				-- Media information box => Header (4), Boxes (n x n)
				local minf_box = "minf"
					local vmhd_box = ""
					if track_type_4 == "vide" then
						-- Video media header box => Header (4), Version(1), Flags (3), GraphicsMode (2), OpColor (2 x 3)
						vmhd_box = "vmhd".."\0".."\0\0\1".."\0\0".."\0\0".."\0\0".."\0\0"
					end
					-- Data information box => Header (4), Data reference box (n)
					local dinf_box = "dinf"
						-- Data reference box => Header (4), Version(1), Flags (3), EntryCount (4), DataEntry (n x EntryCount)
						local dref_box = "dref".."\0".."\0\0\0".."\0\0\0\1"
							-- DataEntry box => Header (4), Version(1), Flags (3)
							local url_box = "url ".."\0".."\0\0\1"
						dref_box = dref_box..url_box:add_length()
					dinf_box = dinf_box..dref_box:add_length()
					-- Sample table box => Header (4), Boxes (n x n)
					local stbl_box = "stbl"
						-- Sample description box => Header (4), Version(1), Flags (3), Count (4), Boxes (n x Count)
						local stsd_box = "stsd".."\0".."\0\0\0"..math.number_to_binary_code(description_record_count):size_should_be(4)
							local description_record = ""	-- MP4 FourCC: http://mp4ra.org/codecs.html
							if track_type_4 == "vide" then
								-- VisualSampleEntry box => Header (4), Reserved (1 x 6), DataReferenceIndex (2), Predefined (2), Reserved (2),
								description_record = fourcc.."\0".."\0".."\0".."\0".."\0".."\0".."\0\1".."\0\0".."\0\0"
													-- Predefined (4 x 3),
													.."\0\0\0\0".."\0\0\0\0".."\0\0\0\0"
													-- Width (2), Height (2), HorizResolution (4), VertResolution (4), Reserved (4), FrameCount (2),
													..width..height..horiz_resolution_16_16..vert_resolution_16_16.."\0\0\0\0".."\0\1"
													-- CompressorName (1 x 32), Depth (2), Predefined (signed 2), Boxes (n x n)
													..compressor_name:add_length_x_byte(1):size_should_be__add_to_right(32).."\0\24".."\255\255"
									if fourcc == "avc1" then
										-- Header (4), configurationVersion (1), AVCProfileIndication (1), profile_compatibility (1), AVCLevelIndication (1),
										local avcc_box = "avcC".."\1"..avc1_profile.."\0"..avc1_level
														-- ?????? To CHECK
														.."\255".."\225"..SPS:add_length_x_byte(2).."\1"..PPS:add_length_x_byte(2)
										description_record = description_record..avcc_box:add_length()
									elseif fourcc == "vc-1" then
										-- http://wiki.multimedia.cx/index.php?title=VC-1
										-- It isn't ready
									end
							end
						stsd_box = stsd_box..description_record:add_length()
						-- Decoding time to sample box => Header (4), Version(1), Flags (3), Count (4), Entries (n x Count)
						local stts_box = "stts".."\0".."\0\0\0".."\0\0\0\0"
						-- Sample to chunk box => Header (4), Version(1), Flags (3), Count (4), Entries (n x Count)
						local stsc_box = "stsc".."\0".."\0\0\0".."\0\0\0\0"
						-- Sample Size box => Header (4), Version(1), Flags (3), ConstantSize (4), SizeCount (4), SizeTable (ConstantSize == 0 ? 4 x SizeCount : 0)
						local stsz_box = "stsz".."\0".."\0\0\0".."\0\0\0\0".."\0\0\0\0"	-- stsz box isn't mandaory but Nero splitter require it
						-- Chunk offset box => Header (4), Version(1), Flags (3), OffsetCount (4), Offsets (4 x OffsetCount)
						local stco_box = "stco".."\0".."\0\0\0".."\0\0\0\0"
					stbl_box = stbl_box..stsd_box:add_length()..stts_box:add_length()..stsc_box:add_length()..stsz_box:add_length()..stco_box:add_length()
				minf_box = minf_box..vmhd_box:add_length()..dinf_box:add_length()..stbl_box:add_length()
			mdia_box = mdia_box..mdhd_box:add_length()..hdlr_box:add_length()..minf_box:add_length()
		trak_box = trak_box..tkhd_box:add_length()..mdia_box:add_length()
	moov_box = moov_box..mvhd_box:add_length()..mvex_box:add_length()..trak_box:add_length()

	return ftyp_box:add_length()..free_box:add_length()..moov_box:add_length()
end

-- Parse function
function parse()
	local default_options = { "no-http-forward-cookies", "", "" }

	local protocol, url = vlc.access, "://"..vlc.path
	local base_url = url:sub(1, get_pos(url))

	local page = ""
	while true do
		local line = vlc.readline() if line == nil then break end
		page = page..line.."\n"
	end
	page = page:gsub("(<%?xml%s.-encoding=[\"'][Uu][Tt][Ff]%-)16([\"'][^%?]*%?>)", "%18%2", 1)	-- Workaround for the error in the XML parser => the text is automatically converted to UTF-8, so I change the xml declaration accordingly
	local curr_element = simplexml.parse_string(page)
	if curr_element == nil then return show_error("Failed loading of \""..protocol..url.."\"") end

	local stream_list, live, time_scale, duration, width, height, video_fourcc, video_codecprivatedata = {}, false, nil, "0", 0, 0, "", ""
	if curr_element.name == "SmoothStreamingMedia" then
		local audio_list = {}
		time_scale = curr_element.attributes["TimeScale"]
		if curr_element.attributes["IsLive"] == "TRUE" then
			duration = "0"
		else
			duration = curr_element.attributes["Duration"]
			if duration == nil then duration = "0" log_message("Missing required attribute: Duration", "error") end
		end
		if duration == "0" then live = true end
		for _, curr_element in ipairs( curr_element.children ) do
			if curr_element.name == "StreamIndex" then
				if curr_element.attributes["Type"] == "video" then
					local i, path, bitrate, last_start_time, custom_attributes = 1, curr_element.attributes["Url"], 0, 0, ""
					for _, curr_element in ipairs( curr_element.children ) do
						if curr_element.name == "QualityLevel" then
							if curr_element.attributes["Bitrate"]+0 > bitrate then	-- Currently we use only the highest bitrate
								-- FourCC: WVC1 => VC-1
								-- FourCC: AVC1 => H.264 MPEG 4 Part 15
								-- FourCC: AVCB => H.264 MPEG 4 Annex B
								video_fourcc = curr_element.attributes["FourCC"]:lower()
								if video_fourcc == "wvc1" or video_fourcc == "wmva" then video_fourcc = "vc-1"
								elseif video_fourcc == "h264" or video_fourcc == "x264" or video_fourcc == "davc" then video_fourcc = "avc1" end
								-- if video_fourcc == "vc-1" then default_options[3] = "demux=vc1" end	--[[ This apply also to input-slave so it shouldn't be used ]]
								video_codecprivatedata = curr_element.attributes["CodecPrivateData"]
								bitrate = curr_element.attributes["Bitrate"]+0
								width = curr_element.attributes["Width"] height = curr_element.attributes["Height"]
								if not width or not height then
									width = curr_element.attributes["MaxWidth"] height = curr_element.attributes["MaxHeight"]
								end
								custom_attributes = ""
								local curr_element = curr_element.children[1]
								if curr_element ~= nil and curr_element.name == "CustomAttributes" then
									for _, curr_element in ipairs( curr_element.children ) do
										if curr_element.name == "Attribute" then
											if custom_attributes ~= "" then custom_attributes = custom_attributes.."," end	-- What is the separator of custom attributes???
											custom_attributes = custom_attributes..curr_element.attributes["Name"].."="..curr_element.attributes["Value"]
										end
									end
								end
							end
						elseif curr_element.name == "c" then	-- Chunks => n: number, t: time, d: duration
							local start_time, temp = 0, nil
							if live then	-- Live video
								start_time = curr_element.attributes["t"]
							else			-- Fixed length video
								start_time = last_start_time
								last_start_time = last_start_time + curr_element.attributes["d"]
							end
							temp = base_url..path:gsub("{bitrate}", bitrate):gsub("{start time}", start_time):gsub("{CustomAttributes}", custom_attributes)
							if operative_mode == 1 and video_fourcc == "vc-1" then temp = protocol.."/vc1"..temp	-- Force VC-1 demuxer
							else temp = protocol..temp end															-- Other formats (VLC will autodetect them, maybe)

							--log_message("Video "..(i - 1)..": "..temp, "info")
							stream_list[i] = { name=(i - 1).." - "..(bitrate / 1000).." Kbps - "..width.."x"..height, path=temp }
							stream_list[i].options = { default_options[1], default_options[2], default_options[3] }
							i = i + 1
						end
					end
				elseif curr_element.attributes["Type"] == "audio" then
					local i, path, bitrate, last_start_time, custom_attributes, fourcc = 1, curr_element.attributes["Url"], 0, 0, "", ""
					for _, curr_element in ipairs( curr_element.children ) do
						if curr_element.name == "QualityLevel" then
							if curr_element.attributes["Bitrate"]+0 > bitrate then	-- Currently we use only the highest bitrate
								-- FourCC: AACL, AudioTag: 255 => AAC Low Complexity (0x00FF)
								-- FourCC: WMA2, AudioTag: 353 => Windows Media Audio 2 (0x0161)
								-- Subtype: WmaPro => Windows Media Audio Professional (0x0162)
								bitrate = curr_element.attributes["Bitrate"]+0
								fourcc = curr_element.attributes["FourCC"]
								--audio_tag = curr_element.attributes["AudioTag"]
								--sub_type = curr_element.attributes["Subtype"]
								custom_attributes = ""
								local curr_element = curr_element.children[1]
								if curr_element ~= nil and curr_element.name == "CustomAttributes" then
									for _, curr_element in ipairs( curr_element.children ) do
										if curr_element.name == "Attribute" then
											if custom_attributes ~= "" then custom_attributes = custom_attributes.."," end	-- What is the separator of custom attributes???
											custom_attributes = custom_attributes..curr_element.attributes["Name"].."="..curr_element.attributes["Value"]
										end
									end
								end
							end
						elseif curr_element.name == "c" then	-- Chunks => n: number, t: time, d: duration
							local start_time, temp = 0, nil
							if live then	-- Live video
								start_time = curr_element.attributes["t"]
							else			-- Fixed length video
								start_time = last_start_time
								last_start_time = last_start_time + curr_element.attributes["d"]
							end
							temp = protocol..base_url..path:gsub("{bitrate}", bitrate):gsub("{start time}", start_time):gsub("{CustomAttributes}", custom_attributes)

							--log_message("Audio "..(i - 1)..": "..temp, "info")
							audio_list[i] = temp
							-- audio-language
							i = i + 1
						end
					end
				elseif curr_element.attributes["Type"] == "text" then
					--[[for _, curr_element in ipairs( curr_element.children ) do
						if curr_element.name == "QualityLevel" then
							-- ToDO
						elseif curr_element.name == "c" then	-- Chunks => n: number, t: time, d: duration
							local curr_element = curr_element.children[1]
							if curr_element.name == "f" then	-- Data
								base64.decode(curr_element.children[1])
								-- ToDO
							end
						end
					end]]
				else
					log_message("Unknown type of stream: "..curr_element.attributes["Type"], "error")
				end
			end
		end

		local i, len = 0, #stream_list
		if #audio_list < #stream_list then len = #audio_list end
		while i < len do
			i = i + 1
			stream_list[i].options[4] = "input-slave="..audio_list[i]
		end
	end

	local chunk_count = #stream_list
	if chunk_count > 0 then
		if operative_mode == 1 then
			if live then stream_list[chunk_count + 1] = { name="Smooth - continuation", path=protocol..url } end
			return stream_list
		else
			local data, video_extension = nil, nil
			if video_fourcc ~= "vc-1" and video_fourcc ~= "avc1" then return show_error("Unsupported video format") end
			if time_scale == nil then time_scale = 10000000 end	-- The time scale that Smooth Streaming uses by default is 10 * 1000 * 1000 ticks per seconds, the duration in seconds is duration / time_scale

			if operative_mode == 2 then
				if video_fourcc == "vc-1" then
					video_extension = "vc1"
					-- ToDO
				elseif video_fourcc == "avc1" then
					video_extension = "h264"
					local _, _, SPS, PPS = video_codecprivatedata:find("^00000001(%x-)00000001(%x+)$")
					if SPS == nil or PPS == nil then return show_error("Error while extracting SPS and/or PPS") end
					data = "\0\0\0\1"..SPS:hex_string_to_binary_code().."\0\0\0\1"..PPS:hex_string_to_binary_code().."\0\0\0\1"..--[[ Probably some info ]]"".."\0\0\0\1"
				end
			elseif operative_mode == 3 then
				video_extension = "mp4"
				local track_type = "video"
				data = create_mp4_header(time_scale+0, duration+0, track_type, video_fourcc, video_codecprivatedata, width+0, height+0)
				if data == false then
					return show_error("Error while creating the mp4 header")
				end
			end

			local current_os, user_temp_folder = detect_os()
			if true then
				local slash
				log_message("OS: "..current_os, "info")
				if current_os == "windows" then slash = "\\"
				elseif current_os == "linux" then slash = "/"
				else
					return show_error("Your OS is currently not supported")
				end

				if custom_user_temp_folder ~= "" then
					user_temp_folder = custom_user_temp_folder
				else
					user_temp_folder = os.getenv("TEMP")
					if user_temp_folder == nil then
						return show_error("You must manually set the user temp folder")
					end
				end
				user_temp_folder = user_temp_folder..slash
				log_message("Temp folder: "..user_temp_folder, "info")

				os.remove(user_temp_folder.."vlc_smooth_temp_file.mp4")
				os.remove(user_temp_folder.."vlc_smooth_temp_file.vc1")
				os.remove(user_temp_folder.."vlc_smooth_temp_file.h264")
			end

			local file_name = user_temp_folder.."vlc_smooth_temp_file."..video_extension
			local file, error_msg = io.open(file_name, "wb")
			if(file == nil) then return show_error("Failed opening the file: "..file_name..", error: "..error_msg) end
			file_name = file_name:gsub("\\", "/"):gsub(" ", "%%20")
			file:setvbuf("full", 8388608)

			if data ~= nil then
				file:write(data) data = nil file:flush()
			end

			local i = 0
			while i < chunk_count --[[or live == true]] do
				i = i + 1
				local stream = vlc.stream(stream_list[i].path)
				if(stream == nil) then return show_error("Failed downloading of the chunk: "..stream_list[i].path) end

				local dataBuffer = ""
				while true do
					local chunk_data = stream:read(1048576) if chunk_data == "" or chunk_data == nil then break end
					dataBuffer = dataBuffer..chunk_data
				end
				--stream:close()
				stream = nil

				log_message("Writing...", "info")
				local uuid = nil
				if live == true then
					uuid = dataBuffer:extract_uuid()
					if uuid == nil then return show_error("Missing uuid") end
					log_message("Next uuid: "..dataBuffer:extract_uuid(), "info")
				end

				if operative_mode == 2 then
					file:write(dataBuffer:extract_mdat())
				elseif operative_mode == 3 then
					file:write(dataBuffer)
				end
				dataBuffer = nil
				if i % 2 == 0 then file:flush() end

				if i == 2 then
					local command
					if operative_mode == 2 and video_fourcc == "vc-1" then
						command = get_player_path(current_os, "file/vc1:///"..file_name)
					else
						command = get_player_path(current_os, "file:///"..file_name)
					end
					if os.execute(command) ~= 0 then
						return show_error("Failed opening the player, command: "..command)
					end
				end
			end

			file:close()
			return { {name="Done", path="vlc://nop"} }
		end
	else return show_error("Failed parsing the url: "..protocol..url) end
end
