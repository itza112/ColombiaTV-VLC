--[[
 This program is free software; you can redistribute it and/or modify it. 
--]]

-- plugin configurations
local dream_ip = "???.???.???.???" -- IP address of the box
local dream_port = "8001"  -- Port Number of the box for channel streaming, default 8001 
local dream_bouquet = "favourites" -- userbouquet of the box to be retrieved, default favourites

-- plugin descriptor
function descriptor()
    return { title="E-TV",
    version = "1.0",
    shortdesc = "Parsing Enigma2 TV favorites",
    description = "Outputs the list of channels with art file, current EPG for a given Egnima2 TV bouquet.",
    capabilities = { "playing-listener" } }
end

-- translate xml tags to text
function xml2string(value)
  	value = string.gsub(value, "&#x([%x]+)%;", function(h)  return string.char(tonumber(h,16))  end)
  	value = string.gsub(value, "&#([0-9]+)%;", function(h)  return string.char(tonumber(h,10))  end)
	value = string.gsub (value, "&quot;", "\"")
	value = string.gsub (value, "&apos;", "'")
	value = string.gsub (value, "&gt;", ">")
	value = string.gsub (value, "&lt;", "<")
	value = string.gsub (value, "&amp;", "&")
	return value
end

-- get current epg for channel description
function epgnow(ref)
    local epgdesc = ""
    -- fetch the EPG NOW from the BOX
	fdepg, msg = vlc.stream( "http://"..dream_ip.."/web/epgservicenow?sRef="..ref)
    if not fdepg then
        vlc.msg.warn(msg)
        return epgdesc
    end
    local lineepg =  fdepg:readline()
    while ( lineepg ~= nil ) do
		if ( string.find( lineepg, "e2eventtitle" ) ) then
			_, _, ref = string.find( lineepg, "<e2eventtitle>(.+)</e2eventtitle>" )
			if (ref) then epgdesc = ref end
		elseif ( string.find( lineepg, "e2eventdescription" ) ) then
			_, _, ref = string.find( lineepg, "<e2eventdescription>(.+)</e2eventdescription>" )
			if (ref) then epgdesc = epgdesc .." - "..ref end
		elseif ( string.find( lineepg, "e2eventdescriptionextended" ) ) then
			_, _, ref = string.find( lineepg, "<e2eventdescriptionextended>(.+)</e2eventdescriptionextended>" )
			if (ref) then epgdesc = epgdesc .." - "..ref end
		end    	
   		lineepg = fdepg:readline()
    	if (line ~=  nil) then line = xml2string(line) end
    end
	return epgdesc
end

-- get piconurl for channel art
function picon(name)
    local piconurl = name
    if ( piconurl ~=  nil) then piconurl = string.lower(piconurl) end
    if ( piconurl ~=  nil) then piconurl = string.gsub(piconurl, "+", "plus") end
    if ( piconurl ~=  nil) then piconurl = string.gsub(piconurl, "&", "and") end
    if ( piconurl ~=  nil) then piconurl = string.gsub(piconurl, "-", "") end
    if ( piconurl ~=  nil) then piconurl = string.gsub(piconurl, "[.,;:'/ ]", "") end
    if ( piconurl ~=  nil) then piconurl = "http://"..dream_ip.."/picon/"..piconurl..".png" end
    if ( piconurl ==  nil) then piconurl = "" end
	return piconurl
end

-- Main
function main()
    -- put BOX in standby
    fd, msg = vlc.stream( "http://"..dream_ip.."/web/powerstate?newstate=5" )
    if not fd then
        vlc.sd.add_item({title = "E-TV.lua script error", path = "", description = msg.." [Check dream_xxx configuration in plugin file 'E-TV.lua']" })
        return nil
    end
    
    -- fetch bouquet from the BOX
    fd, msg = vlc.stream( "http://"..dream_ip.."/web/getservices?sRef=1:7:1:0:0:0:0:0:0:0:FROM%20BOUQUET%20%22userbouquet."..dream_bouquet..".tv%22%20ORDER%20BY%20bouquet" )
    if not fd then
        vlc.sd.add_item({title = "E-TV.lua script error", path = "", description = msg.." [Check dream_xxx configuration in plugin file 'E-TV.lua']" })
        return nil
    end
   
    -- create playlist
    local ref, name, nodename
    local nodeid
    local nb = 1
    local line=  fd:readline()
    while ( line ~= nil ) do
		if ( string.find( line, "e2servicereference" ) ) then
			_, _, ref = string.find( line, "<e2servicereference>(.+)</e2servicereference>" )
		elseif ( string.find( line, "e2servicename" ) ) then
			_, _, name = string.find( line, "<e2servicename>(.+)</e2servicename>" )
			if ( string.find( ref, name ) ) then
				nodename = name
				nodeid = vlc.sd.add_node{title=name}
			else
				if (nodeid) then
					nodeid:add_subitem({tracknum = string.format("%0003d",nb), path = "http://"..dream_ip..":"..dream_port.."/"..ref, title = name, genre = nodename, description = epgnow(ref), arturl = picon(name) })
				else
					vlc.sd.add_item({tracknum = string.format("%0003d",nb), path = "http://"..dream_ip..":"..dream_port.."/"..ref, title = name, description = epgnow(ref), arturl = picon(name) })
				end
				nb = nb + 1
			end
		end
    	line = fd:readline()
    	if (line ~=  nil) then line = xml2string(line) end
    end
    
    if ( nb == 1 ) then
        vlc.sd.add_item({title = "E-TV.lua script error", path = "", description = "No item [Check dream_xxx configuration in plugin file 'E-TV.lua']" })
        return nil
    end
end
