require("lfs")
require("iuplua")
require( "iupluacontrols" )

function iterate(loc,dname)
	lfs.chdir(loc)
	for file in lfs.dir(".") do
		if file ~= "." and file ~= ".." and lfs.attributes(file,"mode")=="directory" then
			print("Looking inside "..file.."...")
			iterate(file,file)
			lfs.chdir(loc)
		elseif file ~= "." and file ~= ".." and lfs.attributes(file,"mode")=="file" then
			local fname = file:match("([^\.]*)\.") or file
			if dname then fname = dname.."/"..fname end
			print("Examining "..fname.."...")
			local config = io.open(file,"r")
			config = config:read("*a")
			local blocks = config:match("block {([^}]*)}")
			local items = config:match("item {([^}]*)}")
			if blocks then
				examine(blocks,"block",fname,file,dname)
			end
			if items then
				examine(items,"item",fname,file,dname)
			end
			if lookedat then lookedat = lookedat + 1 bar.value = lookedat end
		end
	end
end

function examine(text,kind,file,loc,dname)
	local tab = {}
	for s in text:gmatch("[^\n]+") do
		local name,id = s:match("I:([^=]+)=(%d+)")
		--if not id or not name then print("BREAK "..s) break end
		if not name or not id then
			print("Found malformed ID: "..s.." from "..file)
			break
		end
		print("Found a "..kind.." called "..name.." with ID "..id)
		id = tonumber(id)
		if ids[id] then
			--[[local str = kind .. " " .. ids[id].name.." from "..ids[id].from.." conflicts with "..name.." from "..file.." over ID "..id
			print("CONFLICT! "..str)
			conflictf:write(str.."\n")]]
			conflicts[id] = true
		end
		--ids[id] = {name=name,from=file}
		ids[id] = true
		table.insert(entries,{name=name,id=id,from=file,loc=(maindir.."/"..(dname or "").."/"..loc),type=kind})
	end
end

function GetNumFiles(loc)
	local c = 0
	lfs.chdir(loc)
	for file in lfs.dir(".") do
		if file ~= "." and file ~= ".." and lfs.attributes(file,"mode")=="directory" then
			c = c + GetNumFiles(file)
			lfs.chdir(loc)
		else
			c = c + 1
		end
	end
	return c - 2
end

function OpenListView(entries)
	--cfglist = iup.list{expand="YES",scrollbar="YES",autohide="NO",size="80x10"}
	local cfglist = iup.matrix{numcol=4,numlin=#entries, numlin_visible=10, usetitlesize="NO",expand="YES",scrollbar="VERTICAL",size="280x80",readonly="YES"}
	local blabel = iup.label{expand="HORIZONTAL",title=(#(_G.entries)).." entries total. "..NumConflicts().." ID conflicts detected.",alignment="ACENTER:ABOTTOM",size="x10"}
	local mainp = iup.vbox{cfglist,blabel;size="QUARTERxHALF"}

	local reload = iup.item{title="Reload Configs"}
	local opendir = iup.item{title="Open Config directory"}
	local finder = iup.item{title="Find Free ID Ranges...",active="NO"}
	local auto = iup.item{title="Auto-resolve IDs...",active="NO"}
	local exit = iup.item{title="Exit"}
	local file = iup.submenu{iup.menu{reload,opendir,{},finder,auto,{},exit};title="File"}

	local vall = iup.item{title="See All IDs",value="ON",active="NO"}
	local vcon = iup.item{title="See Conflicted IDs",active="NO"}
	local vfine = iup.item{title="See Fine IDs",active="NO"}
	local vcustom = iup.item{title="See Custom Search",active="NO"}
	local editcustom = iup.item{title="Edit Search Criteria...",active="NO"}
	local view = iup.submenu{iup.menu{vall,vcon,vfine,vcustom,{},editcustom};title="View"}

	local settings = iup.item{title="Settings..."}
	local about = iup.item{title="About..."}
	local options = iup.submenu{iup.menu{settings,about};title="Options"}

	local menu = iup.menu{file,view,options}
	local dlg = iup.dialog{mainp; title="Config Magic",size="290xHALF",menu=menu}

	function reload:action()
		SaveSettings()
		dlg:destroy()
		LoadSettings()
	end
	function exit:action()
		os.exit()
	end
	function opendir:action()
		os.execute("explorer  /root,\""..maindir:gsub("/","\\").."\"")
	end
	function about:action()
		iup.Message("About","Config Magic v. "..VER..". Written by Iconmaster in 2013.")
	end
	function settings:action()
		local dirl = iup.label{title="MC Config:",alignment="ALEFT:ACENTER",size="60x"}
		local dirt = iup.text{value=maindir,alignment="ARIGHT:ACENTER",size="120x"}
		local dirbox = iup.hbox{dirl,dirt}
		local ok = iup.button{title="OK",alignment="ACENTER:ACENTER",expand="HORIZONTAL"}
		local cancel = iup.button{title="Cancel",alignment="ACENTER:ACENTER",expand="HORIZONTAL"}
		local buttons = iup.hbox{ok,cancel}
		local panel = iup.vbox{dirbox,buttons;gap=8}
		local dlg2 = iup.dialog{panel,size="200x40"}
		function ok:action()
			if maindir ~= dirt.value then
				maindir = dirt.value
				dlg:destroy()
				dlg2:destroy()
				SaveSettings()
				LoadSettings()
				return
			end
			dlg2:destroy()
		end
		function cancel:action()
			dlg2:destroy()
		end
		iup.Popup(dlg2)
	end

	cfglist:setcell(0,1,"Type")
	cfglist["width1"] = 30
	cfglist:setcell(0,2,"Name")
	cfglist["width2"] = 120
	cfglist:setcell(0,3,"ID")
	cfglist["width3"] = 30
	cfglist:setcell(0,4,"Mod From")
	cfglist["width4"] = 80
	UpdateTable(cfglist,entries)
	local sel
	function cfglist:click_cb(lin,col,status)
		if sel and sel[1] == lin and sel[2]==col then
			OpenPropertyWindow(cfglist,entries,entries[lin])
			sel = nil
		else
			sel = {lin,col}
		end
	end
	--print(cfglist.count)
	dlg:show()
	iup.MainLoop()
end

function OpenPropertyWindow(cfglist,entries,entry)
	local namebox = iup.label{title="Real Name: "..entry.name.." ("..entry.type..")",expand="HORIZONTAL",alignment="ACENTER:ACENTER"}

	local dnametext = iup.text{value=(entry.dname or entry.name),expand="HORIZONTAL",alignment="ACENTER:ACENTER"}
	local dnamebox = iup.hbox{iup.label{title="Display Name: ",expand="HORIZONTAL",alignment="ALEFT:ACENTER"},dnametext;gap=8,expand="HORIZONTAL",alignment="ACENTER:ACENTER"}

	local idtext = iup.text{value=entry.id,expand="HORIZONTAL",alignment="ACENTER:ACENTER"}
	local idbox = iup.hbox{iup.label{title="ID: ",expand="HORIZONTAL",alignment="ALEFT:ACENTER"},idtext;gap=8,expand="HORIZONTAL",alignment="ACENTER:ACENTER"}

	local labels = {}
	local modbox = iup.label{title="Mod From: "..entry.from,expand="HORIZONTAL",alignment="ACENTER:ACENTER"}
	local conflictbox
	if not conflicts[entry.id] then
		conflictbox = iup.vbox{iup.label{title="No conflicts detected!",expand="HORIZONTAL",alignment="ACENTER:ACENTER",fgcolor=COLOR_GREEN};expand="HORIZONTAL",alignment="ACENTER:ACENTER"}
	else
		for i,v in ipairs(entries) do
			if v.id == entry.id and v ~= entry then
				table.insert(labels,iup.label{title=v.name.." from "..v.from,expand="HORIZONTAL",alignment="ACENTER:ACENTER",fgcolor=COLOR_RED})
			end
		end
		conflictbox = iup.vbox{iup.label{title="Conflict(s) detected with:",expand="HORIZONTAL",alignment="ACENTER:ACENTER",fgcolor=COLOR_RED},unpack(labels);expand="HORIZONTAL",alignment="ACENTER:ACENTER"}
	end

	local okbutton = iup.button{title="OK",alignment="ACENTER:ACENTER",expand="HORIZONTAL"}
	local cancelbutton = iup.button{title="Cancel",alignment="ACENTER:ACENTER",expand="HORIZONTAL"}
	local buttonbar = iup.hbox{okbutton,iup.label{expand="YES"},cancelbutton;gap=8,expand="HORIZONTAL",homogenous="YES",margin="16x0"}
	local doneprop = nil
	function okbutton:action()
		local newname = dnametext.value
		local newid = tonumber(idtext.value)

		if (newname ~= entry.name and not entry.dname) or (newname~=entry.dname and entry.dname) then
			print("Updating internal name...")
			entry.dname = newname
			SaveSettings()
		end
		if newid ~= entry.id then
			print("Updating item ID...")
			lfs.chdir(maindir)
			local file = io.open(entry.loc)
			if not file then
				iup.Message("Config Magic","The config file at "..entry.loc.." cound not be found. The ID was not updated.")
				doneprop = true
				return
			end
			file = file:read("*a")
			if not file then
				iup.Message("Config Magic","The config file for "..entry.from.." cound not be read. The ID was not updated.")
				doneprop = true
				return
			end
			local new,reps = file:gsub("I:"..entry.name.."="..entry.id,"I:"..entry.name.."="..newid)
			if reps == 0 then
				iup.Message("Config Magic","The entry for "..entry.name.." cound not be found. The ID was not updated.")
				doneprop = true
				return
			end
			if reps>1 then
				local ok = iup.Alarm("Config Magic", "There are multiple entries for "..entry.name.." in the config file. This is not expected behavior. Overwrite them with the new IDs anyways?" ,"Yes" ,"No")
				if not ok then
					iup.Message("Config Magic","The ID was not updated.")
					doneprop = true
					return
				end
			end
			file = io.open(entry.loc,"w")
			file:write(new)
			entry.id = newid
		end
		doneprop = true
	end
	function cancelbutton:action()
		doneprop = true
	end

	local dlg = iup.dialog{iup.vbox{namebox,dnamebox,modbox,idbox,conflictbox,buttonbar;gap=8}; title="Edit "..entry.name,size="200x"..(100+10*(#labels)),expandchildren="YES",expand="YES"}
	dlg:show()
	iup.SetIdle(function()
		if doneprop then
			UpdateTable(cfglist,entries)
			dlg:destroy()
			iup.SetIdle(nil)
		end
	end)
	--iup.MainLoop()
end

function NumConflicts()
	local n = 0
	for i,v in pairs(conflicts) do
		n = n + 1
	end
	return n
end

function UpdateTable(cfglist,entries)
	print("Updating table...")
	cfglist.numlin = #entries
	for i,v in ipairs(entries) do
		--cfglist[i] = v
		cfglist:setcell(i,1,v.type)
		cfglist:setcell(i,2,v.dname or v.name)
		cfglist:setcell(i,3,v.id)
		cfglist:setcell(i,4,v.from)
		if conflicts[v.id] then
			cfglist["FGCOLOR"..i..":*"] = COLOR_RED
		else
			cfglist["FGCOLOR"..i..":*"] = COLOR_GREEN
		end
	end
end

function LoadConfigs()
	ids = {}
	entries = {}
	conflicts = {}
	--conflictf = io.open("conflicts.txt","a")

	local text = iup.label{expand = "YES",title= "Looking for config files...",alignment="ACENTER:ACENTER"}
	bar = iup.progressbar{expand="HORIZONTAL",min=0,max=GetNumFiles(maindir)}
	lookedat = 0
	local dlg = iup.dialog{iup.vbox{text,bar}; title="Config Magic",size="200x80"}
	iup.SetIdle(function()
		iterate(maindir)
		lookeat = nil
		iup.SetIdle(nil)
		dlg:destroy()
		OpenListView(entries)
	end)
	dlg:show()
	iup.MainLoop()
end

function LoadSettings()
	lfs.chdir(thisdir)
	local file = io.open("ConfigMagic.cfg","r")
	if not file then
		local dir
		if os.getenv("APPDATA") then
			dir = os.getenv("APPDATA"):gsub("\\","/").."/.minecraft/config"
		else
			dir = "~/.minecraft/config"
			if lfs.attributes(dir,"mode") ~= "folder" then
				dir = "~/Library/Application Support/minecraft/config"
				if lfs.attributes(dir,"mode") ~= "folder" then
					dir = ""
				end
			end
		end
		local box = iup.text{value=dir,alignment="ALEFT:ACENTER",size="160x"}
		local browse = iup.button{title="...",alignment="ACENTER:ACENTER",size="20x"}
		local title = iup.label{title="Please confirm your Minecraft's configuration directory:",alignment="ACENTER:ACENTER",expand="HORIZONTAL"}
		local bar = iup.hbox{box,browse,alignment="ACENTER:ACENTER",expand="HORIZONTAL"}
		local ok = iup.button{title="OK",alignment="ACENTER:ACENTER"}
		local dlg = iup.dialog{iup.vbox{title,bar,ok;alignment="ACENTER";gap=8}; title="Welcome to Config Magic!",size="250x80"}

		function browse:action()
			local filedlg = iup.filedlg{dialogtype="DIR"}
			if filedlg then
				iup.Popup(filedlg)
				box.value = filedlg.value
			end
		end
		function ok:action()
			maindir = box.value
			SaveSettings()
			dlg:destroy()

			LoadConfigs()
		end

		dlg:show()
		iup.MainLoop()
	else
		maindir = file:read("*l")
		local names = file:read("*l")
		file:close()
		if names then
			for name,dname in names:gmatch("([^=]+)=([^,]*),") do
				for i,v in pairs(entries) do
					if v.name == name then
						v.dname = dname
					end
				end
			end
		end
		LoadConfigs()
	end

end

function SaveSettings()
	local file = io.open("ConfigMagic.cfg","w+")
	if not file then print("Saving to file failed!") return end
	print("Saving settings to file...")

	file:write(maindir)

	local str = ""
	if entries then
		for i,v in pairs(entries) do
			if v.dname then
				str = str .. v.name .. "=" .. v.dname .. ","
			end
		end
	end
	file:write(str)

	file:flush()
	file:close()
end

COLOR_GREEN = "0 196 0"
COLOR_RED = "196 0 0"
thisdir = lfs.currentdir()
VER = "0.1.1"

LoadSettings()
