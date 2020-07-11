script_version('0.2.9')
script_properties("work-in-pause")

local sampev 				= require 'lib.samp.events'
local memory 				= require 'memory'
local key	 				= require 'vkeys'
local encoding			 	= require 'encoding'
local Matrix3X3 			= require "matrix3x3"
local Vector3D 				= require "vector3d"
local inicfg 				= require 'inicfg'

DEV_VERSION = true
encoding.default = 'cp1251'
u8 = encoding.UTF8

-- Search:: Script variables
local BulletSync = {lastId = 0, maxLines = 15}

for i = 1, BulletSync.maxLines do
	BulletSync[i] = {enable = false, o = {x, y, z}, t = {x, y, z}, time = 0, tType = 0}
end

local recInfo = {
	loading = false,
	state = false,
  	id = -1,
	lastCar = -1
}

local scriptInfo = {
	buttonId = 1,
	aduty = false,
  	clickwarp = false,
	airBreak = false, 
  	airspeed = 0.5,

  	textdraws = {
		refreshId = -1,
		exitId = -1
  	}
}

local tick = {
	Keys = {
		Up = 0, 
		Down = 0, 
		Plus = 0, 
		Minus = 0, 
		Num = {
			Plus = 0, 
			Minus = 0
		}
	},

	Time = {
		PlusMinus = 150
	}
}

-- Search:: Main config
local mainIni = inicfg.load({
	settings = {
		fixFindZ = true,
		autoAduty = false,
    	autologin = false,
		showpass = false,
		offReconAlert = true,
		offHelpersAnswers = false,
		password = "",
		themeId = 0
	},

	set = {
		airbreak = false,
		wallhack = false,
		traicers = false,
		clickwarp = false
	},

	stats = {
		adutyTime = 0,
		afkTime = 0,
		countAnswers = 0,
		countJail = 0,
		countMute = 0,
		countKick = 0
	}
}, 'admintools')
inicfg.save(mainIni, "admintools.ini")

function main()
	while not isSampAvailable() do wait(200) end
	while not sampIsLocalPlayerSpawned() do wait(1) end

	sampRegisterChatCommand("rec", function(arg)
		time = tonumber(arg)
		res = true
	end)

	if not DEV_VERSION then
		autoupdate("https://raw.githubusercontent.com/kennytowN/admin-tools/master/admin-tools.json", "https://raw.githubusercontent.com/kennytowN/admin-tools/master/Admin_Tools.lua")
	end

	if sampGetPlayerColor(getLocalPlayerId()) == 16510045 then 
		scriptInfo.aduty = true
		addTimeToStatsId = lua_thread.create(addTimeToStats) 
	end

	--if sampGetCurrentServerAddress() ~= "37.230.162.117" then
	if sampGetCurrentServerAddress() ~= "95.181.158.18" then
		thisScript():unload()
	else
		r_smart_lib_imgui()
		imgui_init()
		initializeRender()

		sampAddChatMessage("[Admin Tools]:{FFFFFF} Скрипт успешно загружен. Текущая версия: " .. thisScript().version, 0xffa500)

		while true do
			if sampGetChatString(99) == "Server closed the connection." or sampGetChatString(99) == "You are banned from this server." then
				time = nil
				res = true
			end

			if isKeyJustPressed(key.VK_F9) then -- Activate:: Main window
				if not scriptInfo.aduty then sampSendChat("/aduty") 
				else
					scriptInfo.clickwarp = false
					wInfo.main.v = not wInfo.main.v

					if not wInfo.main.v then
						wInfo.func.v = false
						wInfo.stats.v = false
						wInfo.settings.v = false
						wInfo.info.v = false
						wInfo.teleport.v = false
					else
						imgui.ShowCursor = true
					end
				end
			end

			if res and time ~= nil then
				sampDisconnectWithReason(quit)
				wait(time*1000)
				sampSetGamestate(1)
				res = false
			elseif res and time == nil then
				sampDisconnectWithReason(quit)
				wait(1000)
				sampSetGamestate(1)
				res = false
			end

			if scriptInfo.aduty then
				if not wInfo.spectatemenu.v then imgui.Process = wInfo.main.v else imgui.Process = true end -- Search:: Close the window 

				if isKeyDown(key.VK_MBUTTON) and ckClickWarp.v then -- Activate:: Clickwarp
					scriptInfo.clickwarp = not scriptInfo.clickwarp
					cursorEnabled = scriptInfo.clickwarp
					showCursor(cursorEnabled)
					while isKeyDown(key.VK_MBUTTON) do wait(80) end
				end

				if isKeyJustPressed(key.VK_RSHIFT) and ckAirBreak.v then -- Activate:: Airbreak
					scriptInfo.airbreak = not scriptInfo.airbreak

					if scriptInfo.airbreak then
						local posX, posY, posZ = getCharCoordinates(playerPed)
						airBrkCoords = {posX, posY, posZ, 0.0, 0.0, getCharHeading(playerPed)}
					end
				end

				local oTime = os.time()
				if ckTraicers.traicers and not isPauseMenuActive() then
					for i = 1, BulletSync.maxLines do
						if BulletSync[i].enable == true and BulletSync[i].time >= oTime then
							local sx, sy, sz = calcScreenCoors(BulletSync[i].o.x, BulletSync[i].o.y, BulletSync[i].o.z)
							local fx, fy, fz = calcScreenCoors(BulletSync[i].t.x, BulletSync[i].t.y, BulletSync[i].t.z)

							if sz > 1 and fz > 1 then
								renderDrawLine(sx, sy, fx, fy, 1, BulletSync[i].tType == 0 and 0xFFFFFFFF or 0xFFFFC700)
								renderDrawPolygon(fx, fy-1, 3, 3, 4.0, 10, BulletSync[i].tType == 0 and 0xFFFFFFFF or 0xFFFFC700)
							end
						end
					end
				end

				local time = os.clock() * 1000
				if scriptInfo.airbreak then -- Аирбрейк
					if isCharInAnyCar(playerPed) then heading = getCarHeading(storeCarCharIsInNoSave(playerPed))
					else heading = getCharHeading(playerPed) end
					local camCoordX, camCoordY, camCoordZ = getActiveCameraCoordinates()
					local targetCamX, targetCamY, targetCamZ = getActiveCameraPointAt()
					local angle = getHeadingFromVector2d(targetCamX - camCoordX, targetCamY - camCoordY)
					if isCharInAnyCar(playerPed) then difference = 0.79 else difference = 1.0 end
					setCharCoordinates(playerPed, airBrkCoords[1], airBrkCoords[2], airBrkCoords[3] - difference)
					if isKeyDown(key.VK_W) then
						airBrkCoords[1] = airBrkCoords[1] + scriptInfo.airspeed * math.sin(-math.rad(angle))
						airBrkCoords[2] = airBrkCoords[2] + scriptInfo.airspeed * math.cos(-math.rad(angle))
						if not isCharInAnyCar(playerPed) then setCharHeading(playerPed, angle)
						else setCarHeading(storeCarCharIsInNoSave(playerPed), angle) end
					elseif isKeyDown(key.VK_S) then
						airBrkCoords[1] = airBrkCoords[1] - scriptInfo.airspeed * math.sin(-math.rad(heading))
						airBrkCoords[2] = airBrkCoords[2] - scriptInfo.airspeed * math.cos(-math.rad(heading))
					end
					if isKeyDown(key.VK_A) then
						airBrkCoords[1] = airBrkCoords[1] - scriptInfo.airspeed * math.sin(-math.rad(heading - 90))
						airBrkCoords[2] = airBrkCoords[2] - scriptInfo.airspeed * math.cos(-math.rad(heading - 90))
					elseif isKeyDown(key.VK_D) then
						airBrkCoords[1] = airBrkCoords[1] - scriptInfo.airspeed * math.sin(-math.rad(heading + 90))
						airBrkCoords[2] = airBrkCoords[2] - scriptInfo.airspeed * math.cos(-math.rad(heading + 90))
					end
					if isKeyDown(key.VK_Q) then airBrkCoords[3] = airBrkCoords[3] + scriptInfo.airspeed / 2.0 end
					if isKeyDown(key.VK_E) and airBrkCoords[3] > -95.0 then airBrkCoords[3] = airBrkCoords[3] - scriptInfo.airspeed / 2.0 end
					if not isSampfuncsConsoleActive() and not sampIsChatInputActive() and not sampIsDialogActive() and not isPauseMenuActive() then
						if isKeyDown(key.VK_OEM_PLUS) and time - tick.Keys.Plus > tick.Time.PlusMinus then
							if scriptInfo.airspeed < 14.9 then scriptInfo.airspeed = scriptInfo.airspeed + 0.5 end
							tick.Keys.Plus = time
						elseif isKeyDown(key.VK_OEM_MINUS) and time - tick.Keys.Minus > tick.Time.PlusMinus then
							if scriptInfo.airspeed > 0.5 then scriptInfo.airspeed = scriptInfo.airspeed - 0.5 end
							tick.Keys.Minus = time
						end
					end
				else
					setCharProofs(playerPed, true, true, true, true, true)
					writeMemory(0x96916E, 1, 1, false)
				end

				if scriptInfo.clickwarp then
					local mode = sampGetCursorMode()
					if mode == 0 then
					showCursor(true)
					end
					local sx, sy = getCursorPos()
					local sw, sh = getScreenResolution()
					-- is cursor in game window bounds?
					if sx >= 0 and sy >= 0 and sx < sw and sy < sh then
						local posX, posY, posZ = convertScreenCoordsToWorld3D(sx, sy, 700.0)
						local camX, camY, camZ = getActiveCameraCoordinates()
						-- search for the collision point
						local result, colpoint = processLineOfSight(camX, camY, camZ, posX, posY, posZ, true, true, false, true, false, false, false)
						
						if result and colpoint.entity ~= 0 then
							local normal = colpoint.normal
							local pos = Vector3D(colpoint.pos[1], colpoint.pos[2], colpoint.pos[3]) - (Vector3D(normal[1], normal[2], normal[3]) * 0.1)
							local zOffset = 300
							if normal[3] >= 0.5 then zOffset = 1 end
							-- search for the ground position vertically down
							local result, colpoint2 = processLineOfSight(pos.x, pos.y, pos.z + zOffset, pos.x, pos.y, pos.z - 0.3, true, true, false, true, false, false, false)

							if result then
								pos = Vector3D(colpoint2.pos[1], colpoint2.pos[2], colpoint2.pos[3] + 1)
					
								local curX, curY, curZ  = getCharCoordinates(playerPed)
								local dist              = getDistanceBetweenCoords3d(curX, curY, curZ, pos.x, pos.y, pos.z)
								local hoffs             = renderGetFontDrawHeight(font)
					
								sy = sy - 2
								sx = sx - 2
								renderFontDrawText(font, string.format("%0.2fm", dist), sx, sy - hoffs, 0xEEEEEEEE)

								local tpIntoCar = nil
								if colpoint.entityType == 2 then
									local car = getVehiclePointerHandle(colpoint.entity)
									if doesVehicleExist(car) and (not isCharInAnyCar(playerPed) or storeCarCharIsInNoSave(playerPed) ~= car) then
										displayVehicleName(sx, sy - hoffs * 2, getNameOfVehicleModel(getCarModel(car)))
										local color = 0xAAFFFFFF
										if isKeyDown(key.VK_RBUTTON) then
										tpIntoCar = car
										color = 0xFFFFFFFF
										end
										renderFontDrawText(font2, "Hold right mouse button to teleport into the car", sx, sy - hoffs * 3, color)
									end
								end

								createPointMarker(pos.x, pos.y, pos.z)

								-- teleport!
								if isKeyDown(key.VK_LBUTTON) then
								  if tpIntoCar then
									if not jumpIntoCar(tpIntoCar) then
									  -- teleport to the car if there is no free seats
									  teleportPlayer(pos.x, pos.y, pos.z)
									end
								  else
									if isCharInAnyCar(playerPed) then
									  local norm = Vector3D(colpoint.normal[1], colpoint.normal[2], 0)
									  local norm2 = Vector3D(colpoint2.normal[1], colpoint2.normal[2], colpoint2.normal[3])
									  rotateCarAroundUpAxis(storeCarCharIsInNoSave(playerPed), norm2)
									  pos = pos - norm * 1.8
									  pos.z = pos.z - 0.8
									end
									teleportPlayer(pos.x, pos.y, pos.z)
								  end

								  scriptInfo.clickwarp = false
								  removePointMarker()
				  
								  while isKeyDown(key.VK_LBUTTON) do wait(0) end
								  showCursor(false)
								end
							end
						end
					end
				end
			end

			wait(0)
			removePointMarker()

			if memory.read(0x8E4CB4, 4, true) > 419430400 then
				cleanStreamMemoryBuffer()
			end
		end
	end
end

-- Search:: Packages
function r_smart_lib_imgui()
    if not pcall(function() imgui = require 'imgui' end) then
      	waiter = true
      	local prefix = "[Admin Tools]:{FFFFFF} "
      	local color = 0xffa500
      	sampAddChatMessage(prefix.."Модуль Dear ImGui загружен неудачно. Для работы скрипта этот модуль обязателен.", color)
		sampAddChatMessage(prefix.."Запускаю средство автоматического исправления ошибок.", color)
		
        local imguifiles = {
          [getGameDirectory().."\\moonloader\\lib\\imgui.lua"] = "https://raw.githubusercontent.com/kennytowN/admin-tools/master/libs/imgui.lua",
          [getGameDirectory().."\\moonloader\\lib\\MoonImGui.dll"] = "https://github.com/kennytowN/admin-tools/raw/master/libs/MoonImGui.dll"
        }
        createDirectory(getGameDirectory().."\\moonloader\\lib\\")
        for k, v in pairs(imguifiles) do
          if doesFileExist(k) then
            sampAddChatMessage(prefix.."Файл "..k.." найден.", color)
            sampAddChatMessage(prefix.."Удаляю "..k.." и скачиваю последнюю доступную версию.", color)
            os.remove(k)
          else
            sampAddChatMessage(prefix.."Файл "..k.." не найден.", color)
          end
          sampAddChatMessage(prefix.."Ссылка: "..v..". Пробую скачать.", color)
          pass = false
          wait(1500)
          downloadUrlToFile(v, k,
            function(id, status, p1, p2)
              if status == 58 then
                sampAddChatMessage(prefix..k..' - Загрузка завершена.', color)
                pass = true
              end
            end
          )
          while pass == false do wait(1) end
        end
        sampAddChatMessage(prefix.."Кажется, все файлы загружены. Попробую запустить модуль Dear ImGui ещё раз.", color)
        local status, err = pcall(function() imgui = require 'imgui' end)
        if status then
          sampAddChatMessage(prefix.."Модуль Dear ImGui успешно загружен!", color)
          waiter = false
          waitforreload = true
        else
          sampAddChatMessage(prefix.."Модуль Dear ImGui загружен неудачно, обратитесь к автору скрипта!", color)
          print(err)
          for k, v in pairs(imguifiles) do
            print(k.." - "..tostring(doesFileExist(k)).." from "..v)
          end
          thisScript():unload()
        end
    end
    while waiter do wait(100) end
end

-- Search:: Initizalize
function initializeRender()
	font = renderCreateFont("Tahoma", 10, FCR_BOLD + FCR_BORDER)
	font2 = renderCreateFont("Arial", 8, FCR_ITALICS + FCR_BORDER)
end

function imgui_init()
	-- Search:: Text buffers
	temp_buffers = {
		password = imgui.ImBuffer(mainIni.settings.password, 256),
		sethp = imgui.ImBuffer(4)
	}

	-- Search:: Variables functions
	ckAirSpeed = imgui.ImFloat(scriptInfo.airspeed)
	ckAirBreak = imgui.ImBool(mainIni.set.airbreak)
	ckClickWarp = imgui.ImBool(mainIni.set.clickwarp)
	ckWallhack = imgui.ImBool(mainIni.set.wallhack)
	ckTraicers = imgui.ImBool(mainIni.set.traicers)
  
	-- Search:: Variables settings
	ckThemeId = imgui.ImInt(mainIni.settings.themeId)
	ckFixFindZ = imgui.ImBool(mainIni.settings.fixFindZ)
	ckAutoLogin = imgui.ImBool(mainIni.settings.autologin)
	ckOffHelpersAnswers = imgui.ImBool(mainIni.settings.offHelpersAnswers)
	ckOffReconAlert = imgui.ImBool(mainIni.settings.offReconAlert)
 	ckAutoAduty = imgui.ImBool(mainIni.settings.autoAduty)
  
	apply_custom_style(mainIni.settings.themeId)
	if ckWallhack.v then nameTagOn() end

	function imgui.TextQuestion(text)
		imgui.TextDisabled('(?)')
		if imgui.IsItemHovered() then
			imgui.BeginTooltip()
			imgui.PushTextWrapPos(450)
			imgui.TextUnformatted(text)
			imgui.PopTextWrapPos()
			imgui.EndTooltip()
		end
    end
    
    wInfo = {
        main = imgui.ImBool(false),
        func = imgui.ImBool(false),
        stats = imgui.ImBool(false),
        settings = imgui.ImBool(false),
        info = imgui.ImBool(false),
        teleport = imgui.ImBool(false),
        spectatemenu = imgui.ImBool(false)
    }

	function imgui.OnDrawFrame()
        if wInfo.main.v then drawMain() end
        if wInfo.info.v then drawInfo() end
        if wInfo.teleport.v then drawTeleport() end
		if wInfo.func.v then drawFunctions() end
		if wInfo.spectatemenu.v and sampIsPlayerConnected(recInfo.id) and sampGetPlayerScore(recInfo.id) ~= 0 then drawSpectateMenu() end
		if wInfo.stats.v then drawStats() end
	end
	
	function imgui.ToggleButton(str_id, bool)
		local rBool = false
	
		if LastActiveTime == nil then
			LastActiveTime = {}
		end
		if LastActive == nil then
			LastActive = {}
		end
	
		local function ImSaturate(f)
			return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
		end
		
		local p = imgui.GetCursorScreenPos()
		local draw_list = imgui.GetWindowDrawList()
	
		local height = imgui.GetTextLineHeightWithSpacing()
		local width = height * 1.55
		local radius = height * 0.50
		local ANIM_SPEED = 0.15
	
		if imgui.InvisibleButton(str_id, imgui.ImVec2(width, height)) then
			bool.v = not bool.v
			rBool = true
			LastActiveTime[tostring(str_id)] = os.clock()
			LastActive[tostring(str_id)] = true
		end
	
		local t = bool.v and 1.0 or 0.0
	
		if LastActive[tostring(str_id)] then
			local time = os.clock() - LastActiveTime[tostring(str_id)]
			if time <= ANIM_SPEED then
				local t_anim = ImSaturate(time / ANIM_SPEED)
				t = bool.v and t_anim or 1.0 - t_anim
			else
				LastActive[tostring(str_id)] = false
			end
		end
	
		local col_bg
		if bool.v then
			col_bg = imgui.GetColorU32(imgui.GetStyle().Colors[imgui.Col.FrameBgHovered])
		else
			col_bg = imgui.ImColor(100, 100, 100, 180):GetU32()
		end
	
		draw_list:AddRectFilled(imgui.ImVec2(p.x, p.y + (height / 6)), imgui.ImVec2(p.x + width - 1.0, p.y + (height - (height / 6))), col_bg, 5.0)
		draw_list:AddCircleFilled(imgui.ImVec2(p.x + radius + t * (width - radius * 2.0), p.y + radius), radius - 0.75, imgui.GetColorU32(bool.v and imgui.GetStyle().Colors[imgui.Col.ButtonActive] or imgui.ImColor(150, 150, 150, 255):GetVec4()))
	
		return rBool
	end

	function imgui.RoundDiagram(valTable, radius, segments)
		local draw_list = imgui.GetWindowDrawList()
		local default = imgui.GetStyle().AntiAliasedShapes
		imgui.GetStyle().AntiAliasedShapes = false
		local center = imgui.ImVec2(imgui.GetCursorScreenPos().x + radius, imgui.GetCursorScreenPos().y + radius)
		local function round(num)
			if num >= 0 then
				if select(2, math.modf(num)) >= 0.5 then
					return math.ceil(num)
				else
					return math.floor(num)
				end
			else
				if select(2, math.modf(num)) >= 0.5 then
					return math.floor(num)
				else
					return math.ceil(num)
				end
			end
		end
	
		local sum = 0
		local q = {}
	 
		for k, v in ipairs(valTable) do
			sum = sum + v.v
		end
	
		for k, v in ipairs(valTable) do
			if k > 1 then
				q[k] = q[k-1] + round(valTable[k].v/sum*segments)
			else
				q[k] = round(valTable[k].v/sum*segments)
			end
		end
	
		local current = 1
		local count = 1
		local theta = 0
		local step = 2*math.pi/segments
	
		for i = 1, segments do -- theta < 2*math.pi
			if q[current] < count then
				current = current + 1
			end
			draw_list:AddTriangleFilled(center, imgui.ImVec2(center.x + radius*math.cos(theta), center.y + radius*math.sin(theta)), imgui.ImVec2(center.x + radius*math.cos(theta+step), center.y + radius*math.sin(theta+step)), valTable[current].color)
			theta = theta + step
			count = count + 1
		end
	
		local fontsize = imgui.GetFontSize()
		local indented = 2*(radius + imgui.GetStyle().ItemSpacing.x)
		imgui.Indent(indented)
	
		imgui.SameLine(0)
		imgui.NewLine() -- awful fix for first line padding
		imgui.SetCursorScreenPos(imgui.ImVec2(imgui.GetCursorScreenPos().x, center.y - imgui.GetTextLineHeight() * #valTable / 2))
		for k, v in ipairs(valTable) do
			draw_list:AddRectFilled(imgui.ImVec2(imgui.GetCursorScreenPos().x, imgui.GetCursorScreenPos().y), imgui.ImVec2(imgui.GetCursorScreenPos().x + fontsize, imgui.GetCursorScreenPos().y + fontsize), v.color)
			imgui.SetCursorPosX(imgui.GetCursorPosX() + fontsize*1.3)
			imgui.Text(u8(v.name .. ' - ' .. string.format('%s', SecondsToClock(v.v)) .. ' (' .. string.format('%.1f', v.v/sum*100) .. '%)'))
		end
		imgui.Unindent(indented)
		imgui.SetCursorScreenPos(imgui.ImVec2(imgui.GetCursorScreenPos().x, center.y + radius + imgui.GetTextLineHeight()))
		imgui.GetStyle().AntiAliasedShapes = default
	end

	function imgui.DrawToggleButtonRight(str_id, text, bool)
		imgui.Text(u8(text))
		imgui.SameLine()

		local width = imgui.GetWindowWidth()
		local calc = imgui.CalcTextSize(u8(str_id))
		imgui.SetCursorPosX(width - calc.x - 25)

		local rBool = imgui.ToggleButton(u8(str_id), bool)
		return rBool
	end

	function imgui.TextFloatRight(text)
		local width = imgui.GetWindowWidth()
		local calc = imgui.CalcTextSize(u8(text))
		imgui.SetCursorPosX(width - calc.x - 10)
		imgui.Text(u8(text))
	end

	function imgui.TextColoredRGB(text)
		local style = imgui.GetStyle()
		local colors = style.Colors
		local ImVec4 = imgui.ImVec4

		local explode_argb = function(argb)
			local a = bit.band(bit.rshift(argb, 24), 0xFF)
			local r = bit.band(bit.rshift(argb, 16), 0xFF)
			local g = bit.band(bit.rshift(argb, 8), 0xFF)
			local b = bit.band(argb, 0xFF)
			return a, r, g, b
		end

		local getcolor = function(color)
			if color:sub(1, 6):upper() == 'SSSSSS' then
				local r, g, b = colors[1].x, colors[1].y, colors[1].z
				local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
				return ImVec4(r, g, b, a / 255)
			end
			local color = type(color) == 'string' and tonumber(color, 16) or color
			if type(color) ~= 'number' then return end
			local r, g, b, a = explode_argb(color)
			return imgui.ImColor(r, g, b, a):GetVec4()
		end

		local render_text = function(text_)
			for w in text_:gmatch('[^\r\n]+') do
				local text, colors_, m = {}, {}, 1
				w = w:gsub('{(......)}', '{%1FF}')
				while w:find('{........}') do
					local n, k = w:find('{........}')
					local color = getcolor(w:sub(n + 1, k - 1))
					if color then
						text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
						colors_[#colors_ + 1] = color
						m = n
					end
					w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
				end
				if text[0] then
					for i = 0, #text do
						imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
						imgui.SameLine(nil, 0)
					end
					imgui.NewLine()
				else imgui.Text(u8(w)) end
			end
		end

		render_text(text)
	end
end

-- Search:: Imgui draw windows
function drawMain()
    local ScreenX, ScreenY = getScreenResolution()

    imgui.SetNextWindowPos(imgui.ImVec2(250, ScreenY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8'Mailen Tools', wInfo.main, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

    if imgui.Button(u8'Функции',imgui.ImVec2(310,25)) then
        wInfo.func.v = not wInfo.func.v
    elseif imgui.Button(u8'Статистика',imgui.ImVec2(310,25)) then 
	   wInfo.stats.v = not wInfo.stats.v
    elseif imgui.Button(u8'Телепорт-лист',imgui.ImVec2(310,25)) then 
        wInfo.teleport.v = not wInfo.teleport.v
    elseif imgui.Button(u8'О скрипте',imgui.ImVec2(310,25)) then 
        wInfo.info.v = not wInfo.info.v
	end

    imgui.End()
end

function drawInfo()
    local ScreenX, ScreenY = getScreenResolution() 

    imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 900, ScreenY - 350), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8"Информация о скрипте", wInfo.info, imgui.WindowFlags.NoResize)

    imgui.Text(u8'Автор: taichi')
	imgui.Text(u8'Текущая версия скрипта: ' .. thisScript().version)
	imgui.Text(u8'\n')

	if imgui.Button(u8'Связь с разработчиком',imgui.ImVec2(310,25)) then
        os.execute('start https://vk.com/unknownus3r')
    end

    imgui.End()
end

function drawTeleport()
    local ScreenX, ScreenY = getScreenResolution() 

    imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 760, ScreenY - 450), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(300, 100), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'Телепорт-меню', wInfo.teleport, imgui.WindowFlags.NoResize)

	if imgui.BeginMenu(u8'Важные места') then
		if imgui.MenuItem(u8'Мэрия') then teleportPlayer(1481.1948,-1742.2594,13.5469)
        elseif imgui.MenuItem(u8'Spawn') then teleportPlayer(1716.4712,-1900.9441,13.5662)
        elseif imgui.MenuItem(u8'Банк') then teleportPlayer(591.5851,-1243.9316,17.9945)
        elseif imgui.MenuItem(u8'Автосалон') then teleportPlayer(553.4409,-1284.4994,17.2482)
        elseif imgui.MenuItem(u8'Мотосалон') then teleportPlayer(2128.8518,-1142.8802,24.9510)
        elseif imgui.MenuItem(u8'Департамент транспорта') then teleportPlayer(738.8824,-1412.5363,13.5287)
        elseif imgui.MenuItem(u8'Торговый центр Mall') then teleportPlayer(1136.7538,-1443.1121,15.7969) end

        imgui.EndMenu()
    end

    if imgui.BeginMenu(u8'Организации') then
        if imgui.MenuItem(u8'Пресса') then teleportPlayer(644.4466,-1359.8496,13.5839)
        elseif imgui.MenuItem(u8'LSFD') then teleportPlayer(1337.7219,-864.5389,39.3089)
        elseif imgui.MenuItem(u8'LSPD') then teleportPlayer(1337.7219,-864.5389,39.3089)
        elseif imgui.MenuItem(u8'54 станция') then teleportPlayer(1541.9823,-1674.7384,13.5536)
        elseif imgui.MenuItem(u8'LSFD') then teleportPlayer(2317.1174,-1341.3965,24.0152)
        elseif imgui.MenuItem(u8'LSSD') then teleportPlayer(633.9006,-571.9080,16.3359)
        elseif imgui.MenuItem(u8'LSHS') then teleportPlayer(1813.4537,-1347.5161,15.0655) end

        imgui.EndMenu()
    end

    if imgui.BeginMenu(u8'Города') then
        if imgui.MenuItem(u8'Лос-Сантос') then teleportPlayer(1437.3413,-1358.1964,35.9609)
        elseif imgui.MenuItem(u8'Сан-Фиерро') then teleportPlayer(-2088.7825,541.0121,79.1693)
        elseif imgui.MenuItem(u8'Лас-Вентурас') then teleportPlayer(2028.8269,1371.3090,10.8130) end

        imgui.EndMenu()
    end

    imgui.End()
end

function drawFunctions() 
  	local ScreenX, ScreenY = getScreenResolution() 

	imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 1150, ScreenY - 460), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(400, 475), imgui.Cond.FirstUseEver)
  	imgui.Begin(u8"Функции скрипта", wInfo.func, imgui.WindowFlags.NoResize)
	
	imgui.Text(u8"Основные функции:")
	imgui.Separator()

	imgui.TextQuestion(u8"Устанавливает тему для всех интерфейсов скрипта")
	imgui.SameLine()

	imgui.Text(u8"Стиль интерфейса:")
	imgui.SameLine()
	imgui.PushItemWidth(130)

	local styles = {u8"Голубой", u8"Красный", u8"Фиолетовый", u8"Зеленый", u8"Черный", u8"Желтый"}
	if imgui.Combo(u8"##styleedit", ckThemeId, styles) then
		mainIni.settings.themeId = ckThemeId.v
		inicfg.save(mainIni, "admintools.ini")

		apply_custom_style(mainIni.settings.themeId)
	end

	imgui.TextQuestion(u8"Автоматически вводит пароль при входе на сервере")
	imgui.SameLine()

  	if imgui.DrawToggleButtonRight('#_1', 'Авто-логин', ckAutoLogin) then
   	 	mainIni.settings.autologin = ckAutoLogin.v
    	inicfg.save(mainIni, "admintools.ini")
	end

	imgui.TextQuestion(u8"Пароль сохраняется в папке moonloader/config/admintools.ini, никогда не отправляйте и не показывайте этот файл другим людям.")
	imgui.SameLine()

	imgui.Text(u8"Пароль от аккаунта:"); imgui.SameLine()
	if imgui.InputText(u8'##', temp_buffers.password, imgui.InputTextFlags.Password) then
		mainIni.settings.password = temp_buffers.password.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.TextQuestion(u8"Автоматически вводит /aduty при успешной авторизации в аккаунт")
	imgui.SameLine()

	if imgui.DrawToggleButtonRight('#_2', 'Авто /aduty', ckAutoAduty) then
		mainIni.settings.autoAduty = ckAutoAduty.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.TextQuestion(u8"Корректно определяет координату Z когда Вы ставите метку на карте.")
	imgui.SameLine()

	if imgui.DrawToggleButtonRight('#_3', 'Fix SetPlayerPosFindZ', ckFixFindZ) then
		mainIni.settings.fixFindZ = ckFixFindZ.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.TextQuestion(u8"Убирает строку о начале слежки за игроком от другого администратора")
	imgui.SameLine()

	if imgui.DrawToggleButtonRight('#_4', 'Отключение оповещения о начале слежки', ckOffReconAlert) then
		mainIni.settings.offReconAlert = ckOffReconAlert.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.TextQuestion(u8"Убирает медвежью услугу в виде оповещения о том, что хелпер ответил игроку")
	imgui.SameLine()

	if imgui.DrawToggleButtonRight('#_5', 'Отключение ответов от хелперов', ckOffHelpersAnswers) then
		mainIni.settings.offHelpersAnswers = ckOffHelpersAnswers.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.TextQuestion(u8"Позволяет видеть игроков сквозь стены")
	imgui.SameLine()

	if imgui.DrawToggleButtonRight('#_6', 'Wall Hack', ckWallhack) then
		mainIni.settings.wallhack = ckWallhack.v
		inicfg.save(mainIni, "admintools.ini")

		if ckWallhack.v then nameTagOn() else nameTagOff() end
	end

	imgui.TextQuestion(u8"Позволяет видеть трейсера пуль того игрока, за которым вы следите")
	imgui.SameLine()

	if imgui.DrawToggleButtonRight('#_7', 'Трейсеры пуль в слежке', ckTraicers) then 
		mainIni.set.traicers = ckTraicers.v 
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.TextQuestion(u8"Позволяет телепортироваться по созданному маркеру. Активация: колёсико мыши.")
	imgui.SameLine()

	if imgui.DrawToggleButtonRight('#_8', 'ТП по курсору', ckClickWarp) then 
		mainIni.set.clickwarp = ckClickWarp.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.Text(u8"\nНастройки AirBreak:")
	imgui.Separator()

	if imgui.DrawToggleButtonRight('#_9', 'AirBreak', ckAirBreak) then 
		mainIni.set.airbreak = ckAirBreak.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.Text(u8'Скорость:')
	if imgui.SliderFloat(u8"######", ckAirSpeed, 0.5, 15.0) then
		scriptInfo.airspeed = ckAirSpeed.v
	end

	--imgui.Text(u8"\n")
	imgui.TextColoredRGB("Активация: {008080}Right Shift")
	imgui.TextColoredRGB("Управление: {008080}WASD | Q - Вверх | E -Вниз")

	imgui.Text(u8"\nУправление скриптом:")
	imgui.Separator()

	if imgui.Button(u8'Перезагрузить скрипт') then
		thisScript():reload()
	end

	imgui.SameLine()

	if imgui.Button(u8'Сбросить настройки') then
		mainIni.settings.themeId = 0
		mainIni.settings.autoAduty = false
		mainIni.settings.autologin = false
		mainIni.settings.offReconAlert = true
		mainIni.settings.offHelpersAnswers = false
		mainIni.settings.password = ""

		mainIni.set.wallhack = false
		mainIni.set.traicers = false
		mainIni.set.clickwarp = true
		mainIni.set.airbreak = true

		ckAirSpeed = imgui.ImFloat(scriptInfo.airspeed)
		ckAirBreak = imgui.ImBool(mainIni.set.airbreak)
		ckClickWarp = imgui.ImBool(mainIni.set.clickwarp)
		ckWallhack = imgui.ImBool(mainIni.set.wallhack)
		ckTraicers = imgui.ImBool(mainIni.set.traicers)
		ckThemeId = imgui.ImInt(mainIni.settings.themeId)
		apply_custom_style(mainIni.settings.themeId)

		ckFixFindZ = imgui.ImBool(mainIni.settings.fixFindZ)
		ckAutoLogin = imgui.ImBool(mainIni.settings.autologin)
		ckOffHelpersAnswers = imgui.ImBool(mainIni.settings.offHelpersAnswers)
		ckOffReconAlert = imgui.ImBool(mainIni.settings.offReconAlert)
		ckAutoAduty = imgui.ImBool(mainIni.settings.autoAduty)

		nameTagOff()
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.End()
end
	
function drawStats() 
	local ScreenX, ScreenY = getScreenResolution() 

  	imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 220, ScreenY - 600), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
  	imgui.SetNextWindowSize(imgui.ImVec2(400, 160), imgui.Cond.FirstUseEver)
	imgui.Begin(u8"Статистика администрирования", wInfo.stats, imgui.WindowFlags.NoResize)

	local statsDiagram = {
        {
            v = mainIni.stats.adutyTime,
            name = 'Время в /aduty без AFK',
            color = 0xFFFF7755
        },
        {
            v = mainIni.stats.afkTime,
            name = 'Время в /aduty в AFK',
            color = 0xFF77FF55
        }
	}
	
	imgui.RoundDiagram(statsDiagram, 30, 50)

	imgui.Text(string.format(u8"Отправлено игроков в Де Морган: %d", mainIni.stats.countJail))
	imgui.Text(string.format(u8"Количество отключённых игроков: %d", mainIni.stats.countKick))
	imgui.Text(string.format(u8"Отправлено ответов игрокам: %d", mainIni.stats.countAnswers))

	imgui.End()
end

function drawSpectateMenu()
	local ScreenX, ScreenY = getScreenResolution()

	imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 350, ScreenY - 350), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(string.format(u8"Spectating: %s(%d)", sampGetPlayerNickname(recInfo.id), recInfo.id), wInfo.spectatemenu, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

	local result, ped = sampGetCharHandleBySampPlayerId(recInfo.id)

	if recInfo.loading or not result then
		imgui.Text(u8"Loading...")

		if result then
			recInfo.loading = false
		end
	else
		imgui.Text(u8"Stats:\n\n")

		imgui.Text(u8"Health:")
		imgui.SameLine()
		imgui.TextFloatRight(string.format("%d", sampGetPlayerHealth(recInfo.id)))

		imgui.Text(u8"Armour:")
		imgui.SameLine()
		imgui.TextFloatRight(string.format("%d", sampGetPlayerArmor(recInfo.id)))

		imgui.Text(u8"Weapon:")
		imgui.SameLine()
		imgui.TextFloatRight(string.format("%d", getCurrentCharWeapon(ped)))

		imgui.Text(u8"Ping:")
		imgui.SameLine()
		imgui.TextFloatRight(string.format("%d", sampGetPlayerPing(recInfo.id)))

		imgui.Text(u8"In pause:")
		imgui.SameLine()
		imgui.TextFloatRight(string.format("%s", sampIsPlayerPaused(recInfo.id)))

		if isCharInAnyCar(ped) then
			local vehicleId = storeCarCharIsInNoSave(ped)
			local _, sampVehicleId = sampGetVehicleIdByCarHandle(vehicleId)

			if recInfo.lastCar ~= sampVehicleId then
				recInfo.lastCar = sampVehicleId
				sampSendClickTextdraw(scriptInfo.textdraws.refreshId)
			end

			imgui.Text(u8"Speed:")
			imgui.SameLine()
			imgui.TextFloatRight(string.format("%d", getCarSpeed(vehicleId) * 2.8))

			imgui.Text(u8"Vehicle health:")
			imgui.SameLine()
			imgui.TextFloatRight(string.format(" %s", getCarHealth(vehicleId)))
		else
			if recInfo.lastCar ~= -1 then
				recInfo.lastCar = -1
				sampSendClickTextdraw(scriptInfo.textdraws.refreshId)
			end

			imgui.Text(u8"Speed:")
			imgui.SameLine()
			imgui.TextFloatRight(string.format("%d", getCharSpeed(ped)))

			imgui.Text(u8"Vehicle health:")
			imgui.SameLine()
			imgui.TextFloatRight("-1")
		end

		imgui.Text(u8"\nActions:\n")

		if imgui.Button(u8'<<< Previous') then
			local find = false

			if recInfo.id == 0 then
				sampAddChatMessage("[Admin Tools]:{FFFFFF} Предыдущий игрок не найден.", 0xffa500)
			else 
				for i = recInfo.id, 0, -1 do
					if sampIsPlayerConnected(i) and sampGetPlayerScore(i) ~= 0 and sampGetPlayerColor(i) ~= 16510045 and i ~= recInfo.id then
						find = true
						recInfo.loading = true
						sampSendChat(string.format("/re %d", i))
						break
					end
				end

				if not find then
					sampAddChatMessage("[Admin Tools]:{FFFFFF} Предыдущий игрок не найден.", 0xffa500)
				end
			end
		end
		imgui.SameLine()

		if imgui.Button(u8'Next >>>') then
			if recInfo.id == sampGetMaxPlayerId(false) then
				sampAddChatMessage("[Admin Tools]:{FFFFFF} Следующий игрок не найден.", 0xffa500)
			else 
				for i = recInfo.id, sampGetMaxPlayerId(false) do
					if sampIsPlayerConnected(i) and sampGetPlayerScore(i) ~= 0 and sampGetPlayerColor(i) ~= 16510045 and i ~= recInfo.id then
						recInfo.loading = true
						sampSendChat(string.format("/re %d", i))
						break
					end
				end
			end
		end
		imgui.SameLine()

		if imgui.Button(u8'Spawn') then
			sampSendChat(string.format("/spawn %d", recInfo.id))
		end
		imgui.SameLine()
		
		if imgui.Button(u8'Check AFK') then
			sampSendChat(string.format("/ans %d Вы тут? Ответьте в /b.", recInfo.id))
		end
		
		if imgui.Button(u8'Не прыгайте') then
			sampSendChat(string.format("/ans %d Не прыгайте.", recInfo.id))
		end
		imgui.SameLine()

		if imgui.Button(u8'/aheal') then
			sampSendChat(string.format("/aheal %d", recInfo.id))
		end
		imgui.SameLine()

		if imgui.Button(u8'/sethp') then
			if temp_buffers.sethp == "" then
				sampAddChatMessage('[Admin Tools]:{FFFFFF} В поле для ввода ничего нет.', 0xffa500)
			else
				sampSendChat(string.format("/sethp %d %d", recInfo.id, tonumber(temp_buffers.sethp.v)))
			end
		end

		imgui.SameLine()
		imgui.PushItemWidth(87)
		imgui.InputText(u8"##", temp_buffers.sethp)
		imgui.PopItemWidth()

		imgui.Text("\n")

		if imgui.Button("REFRESH", imgui.ImVec2(295,25)) then
			sampSendClickTextdraw(scriptInfo.textdraws.refreshId)
		end

		if imgui.Button("STOP", imgui.ImVec2(295,25)) then
			sampSendChat("/re off")
		end
	end

	imgui.End()
end

-- Search:: Imgui settings
function apply_custom_style(id)
	imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	
	if id == 0 then -- Голубой
		style.WindowRounding = 2.0
		style.WindowTitleAlign = imgui.ImVec2(0.5, 0.84)
		style.ChildWindowRounding = 2.0
		style.FrameRounding = 2.0
		style.ItemSpacing = imgui.ImVec2(5.0, 4.0)
		style.ScrollbarSize = 13.0
		style.ScrollbarRounding = 0
		style.GrabMinSize = 8.0
		style.GrabRounding = 1.0

		colors[clr.FrameBg]                = ImVec4(0.16, 0.29, 0.48, 0.54)
		colors[clr.FrameBgHovered]         = ImVec4(0.26, 0.59, 0.98, 0.40)
		colors[clr.FrameBgActive]          = ImVec4(0.26, 0.59, 0.98, 0.67)
		colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
		colors[clr.TitleBgActive]          = ImVec4(0.16, 0.29, 0.48, 1.00)
		colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
		colors[clr.CheckMark]              = ImVec4(0.26, 0.59, 0.98, 1.00)
		colors[clr.SliderGrab]             = ImVec4(0.24, 0.52, 0.88, 1.00)
		colors[clr.SliderGrabActive]       = ImVec4(0.26, 0.59, 0.98, 1.00)
		colors[clr.Button]                 = ImVec4(0.26, 0.59, 0.98, 0.40)
		colors[clr.ButtonHovered]          = ImVec4(0.26, 0.59, 0.98, 1.00)
		colors[clr.ButtonActive]           = ImVec4(0.06, 0.53, 0.98, 1.00)
		colors[clr.Header]                 = ImVec4(0.26, 0.59, 0.98, 0.31)
		colors[clr.HeaderHovered]          = ImVec4(0.26, 0.59, 0.98, 0.80)
		colors[clr.HeaderActive]           = ImVec4(0.26, 0.59, 0.98, 1.00)
		colors[clr.Separator]              = colors[clr.Border]
		colors[clr.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
		colors[clr.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
		colors[clr.ResizeGrip]             = ImVec4(0.26, 0.59, 0.98, 0.25)
		colors[clr.ResizeGripHovered]      = ImVec4(0.26, 0.59, 0.98, 0.67)
		colors[clr.ResizeGripActive]       = ImVec4(0.26, 0.59, 0.98, 0.95)
		colors[clr.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
		colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
		colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
		colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
		colors[clr.ChildWindowBg]          = ImVec4(1.00, 1.00, 1.00, 0.00)
		colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
		colors[clr.ComboBg]                = colors[clr.PopupBg]
		colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
		colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
		colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
		colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
		colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
		colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
		colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
		colors[clr.CloseButton]            = ImVec4(0.41, 0.41, 0.41, 0.50)
		colors[clr.CloseButtonHovered]     = ImVec4(0.98, 0.39, 0.36, 1.00)
		colors[clr.CloseButtonActive]      = ImVec4(0.98, 0.39, 0.36, 1.00)
		colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
		colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
		colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
		colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
		colors[clr.ModalWindowDarkening]   = ImVec4(0.80, 0.80, 0.80, 0.35)
	elseif id == 1 then 
		colors[clr.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00)
		colors[clr.Text]                   = ImVec4(0.9, 0.9, 0.9, 1.00)
		colors[clr.WindowBg]               = imgui.ImColor(2, 0, 0, 230):GetVec4() -- 04
		colors[clr.FrameBg]     	          = imgui.ImColor(150, 10, 10, 100):GetVec4() -- 01
		colors[clr.FrameBgHovered]         = imgui.ImColor(150, 10, 10, 180):GetVec4()
		colors[clr.FrameBgActive]          = imgui.ImColor(150, 10, 10, 70):GetVec4()
		colors[clr.TitleBg]                = imgui.ImColor(150, 20, 20, 235):GetVec4() -- 01
		colors[clr.TitleBgActive]          = imgui.ImColor(150, 20, 20, 235):GetVec4() -- 01
		colors[clr.Button]                 = imgui.ImColor(150, 10, 10, 235):GetVec4() -- 01
		colors[clr.ButtonHovered]          = imgui.ImColor(150, 10, 10, 180):GetVec4() -- 01
		colors[clr.ButtonActive]           = imgui.ImColor(120, 10, 10, 180):GetVec4() -- 01
	elseif id == 2 then -- Фиолетовый
		colors[clr.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00)
		colors[clr.Text]                   = ImVec4(0.9, 0.9, 0.9, 1.00)
		colors[clr.WindowBg]               = imgui.ImColor(2, 1, 3, 230):GetVec4() -- 04
		colors[clr.FrameBg]    	 		  = imgui.ImColor(70, 21, 135, 100):GetVec4() -- 02
		colors[clr.FrameBgHovered]         = imgui.ImColor(70, 18, 115, 180):GetVec4()
		colors[clr.FrameBgActive]          = imgui.ImColor(70, 21, 135, 70):GetVec4()
		colors[clr.TitleBg]                = imgui.ImColor(70, 21, 135, 235):GetVec4() -- 02
		colors[clr.TitleBgActive]          = imgui.ImColor(70, 21, 135, 235):GetVec4() -- 02
		colors[clr.Button]                 = imgui.ImColor(70, 21, 135, 235):GetVec4() -- 02
		colors[clr.ButtonHovered]          = imgui.ImColor(70, 21, 135, 170):GetVec4() -- 02
		colors[clr.ButtonActive]           = imgui.ImColor(55, 18, 115, 170):GetVec4() -- 02
	elseif id == 3 then -- Зелёный
		colors[clr.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00)
		colors[clr.Text]                   = ImVec4(0.9, 0.9, 0.9, 1.00)
		colors[clr.WindowBg]               = imgui.ImColor(0, 2, 0, 230):GetVec4() -- 03
		colors[clr.FrameBg] 				   = ImVec4(0.2, 0.79, 0.14, 0.24) -- 03
		colors[clr.FrameBgHovered]         = ImVec4(0.2, 0.79, 0.14, 0.4)
		colors[clr.FrameBgActive]          = ImVec4(0.15, 0.59, 0.14, 0.39)
		colors[clr.TitleBg]                = ImVec4(0.05, 0.35, 0.05, 0.95) -- 03
		colors[clr.TitleBgActive]          = ImVec4(0.05, 0.35, 0.05, 0.95) -- 03
		colors[clr.Button]                 = ImVec4(0.2, 0.79, 0.14, 0.59) -- 03
		colors[clr.ButtonHovered]          = ImVec4(0.2, 0.79, 0.14, 0.4) -- 03
		colors[clr.ButtonActive]           = ImVec4(0.15, 0.59, 0.14, 0.39) -- 03
	elseif id == 4 then -- Чёрный
		colors[clr.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00)
		colors[clr.Text]                   = ImVec4(0.9, 0.9, 0.9, 1.00)
		colors[clr.WindowBg]               = imgui.ImColor(0, 0, 0, 230):GetVec4()
		colors[clr.FrameBg]    	 		  = imgui.ImColor(40, 40, 40, 100):GetVec4()
		colors[clr.FrameBgHovered]         = imgui.ImColor(95, 95, 95, 140):GetVec4()
		colors[clr.FrameBgActive]          = imgui.ImColor(95, 95, 95, 70):GetVec4()
		colors[clr.TitleBg]                = imgui.ImColor(7, 7, 7, 232):GetVec4()
		colors[clr.TitleBgActive]          = imgui.ImColor(7, 7, 7, 232):GetVec4()
		colors[clr.Button]                 = imgui.ImColor(30, 30, 30, 163):GetVec4()
		colors[clr.ButtonHovered]          = imgui.ImColor(95, 95, 95, 100):GetVec4()
		colors[clr.ButtonActive]           = imgui.ImColor(50, 50, 50, 100):GetVec4()
	elseif id == 5 then -- Жёлтый
		colors[clr.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00)
		colors[clr.Text]                   = ImVec4(0.9, 0.9, 0.9, 1.00)
		colors[clr.WindowBg]               = imgui.ImColor(3, 3, 0, 230):GetVec4()
		colors[clr.FrameBg]    	 		  = imgui.ImColor(210, 210, 0, 100):GetVec4()
		colors[clr.FrameBgHovered]         = imgui.ImColor(210, 210, 0, 140):GetVec4()
		colors[clr.FrameBgActive]          = imgui.ImColor(210, 210, 0, 70):GetVec4()
		colors[clr.TitleBg]                = imgui.ImColor(120, 120, 0, 232):GetVec4()
		colors[clr.TitleBgActive]          = imgui.ImColor(120, 120, 0, 232):GetVec4()
		colors[clr.Button]                 = imgui.ImColor(180, 180, 0, 163):GetVec4()
		colors[clr.ButtonHovered]          = imgui.ImColor(180, 180, 0, 100):GetVec4()
		colors[clr.ButtonActive]           = imgui.ImColor(100, 100, 0, 100):GetVec4()
	end
end

function getDistanceToPlayer(playerId)
	if sampIsPlayerConnected(playerId) then
		local result, ped = sampGetCharHandleBySampPlayerId(playerId)
		if result and doesCharExist(ped) then
			local myX, myY, myZ = getCharCoordinates(playerPed)
			local playerX, playerY, playerZ = getCharCoordinates(ped)
			return getDistanceBetweenCoords3d(myX, myY, myZ, playerX, playerY, playerZ)
		end
	end
	return -1
end

function showCursor(toggle)
	if toggle then
		sampSetCursorMode(CMODE_LOCKCAM)
	else
		sampToggleCursor(false)
	end

	cursorEnabled = toggle
end 

-- Search:: Clickwarp functions
function rotateCarAroundUpAxis(car, vec)
	local mat = Matrix3X3(getVehicleRotationMatrix(car))
	local rotAxis = Vector3D(mat.up:get())
	vec:normalize()
	rotAxis:normalize()
	local theta = math.acos(rotAxis:dotProduct(vec))
	if theta ~= 0 then
	  rotAxis:crossProduct(vec)
	  rotAxis:normalize()
	  rotAxis:zeroNearZero()
	  mat = mat:rotate(rotAxis, -theta)
	end
	setVehicleRotationMatrix(car, mat:get())
  end
  
function readFloatArray(ptr, idx)
	return representIntAsFloat(readMemory(ptr + idx * 4, 4, false))
end

function writeFloatArray(ptr, idx, value)
	writeMemory(ptr + idx * 4, 4, representFloatAsInt(value), false)
end

function getVehicleRotationMatrix(car)
	local entityPtr = getCarPointer(car)
	if entityPtr ~= 0 then
		local mat = readMemory(entityPtr + 0x14, 4, false)
		if mat ~= 0 then
		local rx, ry, rz, fx, fy, fz, ux, uy, uz
		rx = readFloatArray(mat, 0)
		ry = readFloatArray(mat, 1)
		rz = readFloatArray(mat, 2)

		fx = readFloatArray(mat, 4)
		fy = readFloatArray(mat, 5)
		fz = readFloatArray(mat, 6)

		ux = readFloatArray(mat, 8)
		uy = readFloatArray(mat, 9)
		uz = readFloatArray(mat, 10)
		return rx, ry, rz, fx, fy, fz, ux, uy, uz
		end
	end
end

function setVehicleRotationMatrix(car, rx, ry, rz, fx, fy, fz, ux, uy, uz)
	local entityPtr = getCarPointer(car)
	if entityPtr ~= 0 then
		local mat = readMemory(entityPtr + 0x14, 4, false)
		if mat ~= 0 then
		writeFloatArray(mat, 0, rx)
		writeFloatArray(mat, 1, ry)
		writeFloatArray(mat, 2, rz)

		writeFloatArray(mat, 4, fx)
		writeFloatArray(mat, 5, fy)
		writeFloatArray(mat, 6, fz)

		writeFloatArray(mat, 8, ux)
		writeFloatArray(mat, 9, uy)
		writeFloatArray(mat, 10, uz)
		end
	end
end

function displayVehicleName(x, y, gxt)
	x, y = convertWindowScreenCoordsToGameScreenCoords(x, y)
	useRenderCommands(true)
	setTextWrapx(640.0)
	setTextProportional(true)
	setTextJustify(false)
	setTextScale(0.33, 0.8)
	setTextDropshadow(0, 0, 0, 0, 0)
	setTextColour(255, 255, 255, 230)
	setTextEdge(1, 0, 0, 0, 100)
	setTextFont(1)
	displayText(x, y, gxt)
end

function createPointMarker(x, y, z)
	pointMarker = createUser3dMarker(x, y, z + 0.3, 4)
end

function removePointMarker()
	if pointMarker then
		removeUser3dMarker(pointMarker)
		pointMarker = nil
	end
end

function getCarFreeSeat(car)
	if doesCharExist(getDriverOfCar(car)) then
		local maxPassengers = getMaximumNumberOfPassengers(car)
		for i = 0, maxPassengers do
		if isCarPassengerSeatFree(car, i) then
			return i + 1
		end
		end
		return nil -- no free seats
	else
		return 0 -- driver seat
	end
end

function jumpIntoCar(car)
	local seat = getCarFreeSeat(car)

	if not seat then return false end                         -- no free seats
	if seat == 0 then warpCharIntoCar(playerPed, car)         -- driver seat
	else warpCharIntoCarAsPassenger(playerPed, car, seat - 1) end

	restoreCameraJumpcut()
	return true
end

function teleportPlayer(x, y, z)
	if isCharInAnyCar(playerPed) then
		setCharCoordinates(playerPed, x, y, z)
	end

	setCharCoordinatesDontResetAnim(playerPed, x, y, z)

	--writeMemory(0x00BA6748 + 0x15C, 1, 1, false) -- textures loaded
	--writeMemory(0x00BA6748 + 0x15D, 1, 5, false) -- current menu
end

function setCharCoordinatesDontResetAnim(char, x, y, z)
	if doesCharExist(char) then
		local ptr = getCharPointer(char)
		setEntityCoordinates(ptr, x, y, z)
	end
end

function setEntityCoordinates(entityPtr, x, y, z)
	if entityPtr ~= 0 then
		local matrixPtr = readMemory(entityPtr + 0x14, 4, false)
		if matrixPtr ~= 0 then
            local posPtr = matrixPtr + 0x30
            writeMemory(posPtr + 0, 4, representFloatAsInt(x), false) -- X
            writeMemory(posPtr + 4, 4, representFloatAsInt(y), false) -- Y
            writeMemory(posPtr + 8, 4, representFloatAsInt(z), false) -- Z
		end
	end
end

-- Search:: Custom functions
function SecondsToClock(seconds)
	local seconds = tonumber(seconds)
  
	if seconds <= 0 then
	  return "00:00:00";
	else
	  hours = string.format("%02.f", math.floor(seconds/3600));
	  mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
	  secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
	  return hours..":"..mins..":"..secs
	end
end

function getTargetBlipCoordinatesFixed()
    local bool, x, y, z = getTargetBlipCoordinates(); if not bool then return false end
    requestCollision(x, y); loadScene(x, y, z)
    local bool, x, y, z = getTargetBlipCoordinates()
    return bool, x, y, z
end

function getLocalPlayerId()
	local _, id = sampGetPlayerIdByCharHandle(playerPed)
	return id
end

function nameTagOn()
    local pStSet = sampGetServerSettingsPtr()
    memory.setfloat(pStSet + 39, 1488.0)
    memory.setint8(pStSet + 47, 0)
    memory.setint8(pStSet + 56, 1)
end

function nameTagOff()
    local pStSet = sampGetServerSettingsPtr()
    memory.setfloat(pStSet + 39, 50.0)
    memory.setint8(pStSet + 47, 1)
    memory.setint8(pStSet + 56, 1)
end

function ClearChat()
    memory.fill(sampGetChatInfoPtr() + 306, 0x0, 25200, false)
    setStructElement(sampGetChatInfoPtr() + 306, 25562, 4, true, false)
    memory.write(sampGetChatInfoPtr() + 0x63DA, 1, 1, false)
end

-- Search:: SA:MP Events
function sampev.onSendMapMarker(position)
	if scriptInfo.aduty and ckFixFindZ.v then
		ignoreMessage = true
		local _, x, y, z = getTargetBlipCoordinatesFixed()
		setCharCoordinates(PLAYER_PED, x, y, z)
		sampSendChat('/vw 0')
			
		return false
	end
end

function sampev.onShowTextDraw(textdrawId, data)
	if data.text:find("Refresh") then 
		scriptInfo.textdraws.refreshId = textdrawId
		recInfo.loading = true

		wInfo.spectatemenu.v = true
		wInfo.info.v = false

		imgui.Process = true
		imgui.ShowCursor = false
	elseif data.text:find("Exit") then scriptInfo.textdraws.exitId = textdrawId end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
	if dialogId ~= 65535 and title:find("Ввод пароля") and ckAutoLogin and mainIni.settings.password ~= "" then
		sampSendDialogResponse(dialogId, 1, -1, mainIni.settings.password)
		return false
	end
end

function sampev.onBulletSync(playerid, data)
	if recInfo.state and tonumber(playerid) == recInfo.id and ckTraicers.v then
		if data.target.x == -1 or data.target.y == -1 or data.target.z == -1 then
			return true
		end
		BulletSync.lastId = BulletSync.lastId + 1
		if BulletSync.lastId < 1 or BulletSync.lastId > BulletSync.maxLines then
			BulletSync.lastId = 1
		end
		local id = BulletSync.lastId
		BulletSync[id].enable = true
		BulletSync[id].tType = data.targetType
		BulletSync[id].time = os.time() + 15
		BulletSync[id].o.x, BulletSync[id].o.y, BulletSync[id].o.z = data.origin.x, data.origin.y, data.origin.z
		BulletSync[id].t.x, BulletSync[id].t.y, BulletSync[id].t.z = data.target.x, data.target.y, data.target.z
	end
end

function sampev.onSendClickTextDraw(textdrawId)
	if textdrawId == scriptInfo.textdraws.exitId then
		wInfo.spectatemenu.v = false
		resetSpectateInfo()

		if not wInfo.main.v then
			imgui.Process = false
		end
	end
end

function sampev.onSpectateVehicle(vehicleId, camtype)
	recInfo.lastCar = vehicleId
end

function sampev.onServerMessage(color, text)
	if text:find("начал слежку за") then 
		if text:find(sampGetPlayerNickname(getLocalPlayerId())) or mainIni.settings.offReconAlert then
			return false 
		end
	elseif text:find("[A] Хелпер") and text:find("->") and mainIni.settings.offHelpersAnswers then
		return false
	elseif text:find("Надеемся, что вы") and ckAutoAduty.v and sampGetPlayerColor(getLocalPlayerId()) ~= 16510045 then
		lua_thread.create(function() 
			wait(1000)
			sampSendChat('/aduty')
		end)
	elseif text:find("Во время слежки") then
		wInfo.spectatemenu.v = false
		resetSpectateInfo()
		
		if not wInfo.main.v then
			imgui.Process = false
		end
	elseif text:find("Вы не можете следить за администратором") then
		if saveId ~= nil then -- Если игрок за кем-то следил
			recInfo.loading = true
			recInfo.state = true
			recInfo.id = saveId

			wInfo.spectatemenu.v = true
			wInfo.info.v = false

			imgui.Process = true
		else
			wInfo.spectatemenu.v = false
			resetSpectateInfo()
		end
	elseif text:find("начал дежурство") and text:find(sampGetPlayerNickname(getLocalPlayerId())) then 
		scriptInfo.aduty = true 
		if addTimeToStatsId == nil then addTimeToStatsId = lua_thread.create(addTimeToStats) end
	elseif text:find("ушёл с дежурства") and text:find(sampGetPlayerNickname(getLocalPlayerId())) then 
		scriptInfo.aduty = false
	elseif text:find("Вы переместились в виртуальный мир #0") and ignoreMessage then
		ignoreMessage = nil
		return false
	elseif text:find(sampGetPlayerNickname(getLocalPlayerId())) then
		if text:find("->") then
			mainIni.stats.countAnswers = mainIni.stats.countAnswers + 1
			inicfg.save(mainIni, "admintools.ini")
		end

		if text:find("кикнул") then
			mainIni.stats.countKick = mainIni.stats.countKick + 1
			inicfg.save(mainIni, "admintools.ini")
		end

		if text:find("посадил") then
			mainIni.stats.countJail = mainIni.stats.countJail + 1
			inicfg.save(mainIni, "admintools.ini")
		end
	end
end

function sampev.onSendCommand(cmd)
	local reId = string.match(cmd, "^%/re (%d+)")
	if reId == nil then reId = string.match(cmd, "^%/sp (%d+)") end

	if reId ~= nil then
		recInfo.loading = true
		recInfo.id = tonumber(reId)
	elseif cmd:find('/re off') or cmd:find('/sp off') then
		resetSpectateInfo()

		wInfo.spectatemenu.v = false

		if not wInfo.main.v then
			imgui.Process = false
		end
	end
end

-- Search:: Spectate functions
function resetSpectateInfo()
	recInfo.state = false
	recInfo.id = -1
	recInfo.lastCar = -1
end

-- Search:: Timer stats
function addTimeToStats()
	while true do
		if not scriptInfo.aduty then addTimeToStatsId:terminate() end

		if not isPauseMenuActive() then
			mainIni.stats.adutyTime = mainIni.stats.adutyTime + 1
		else
			mainIni.stats.afkTime = mainIni.stats.afkTime + 1
		end

		wait(1000)
	end
end

-- Search:: Clean stream buffer
function cleanStreamMemoryBuffer() -- fix crash
	local h0 = callFunction(0x53C500, 2, 2, true, true)
	local h1 = callFunction(0x53C810, 1, 1, true)
	local h2 = callFunction(0x40CF80, 0, 0)
	local h3 = callFunction(0x4090A0, 0, 0)
	local h4 = callFunction(0x5A18B0, 0, 0)
	local h5 = callFunction(0x707770, 0, 0)
	local pX, pY, pZ = getCharCoordinates(PLAYER_PED)
	requestCollision(pX, pY)
	loadScene(pX, pY, pZ)
end

-- Search:: Autoupdates
function autoupdate(json_url, url)
	local json = getWorkingDirectory() .. '\\admin-tools.json'
	if doesFileExist(json) then os.remove(json) end

	downloadUrlToFile(json_url, json, function(id, status, p1, p2)
		if status == 58 and doesFileExist(json) then
			local file = io.open(json, 'r')
			if file then
				local info = decodeJson(file:read('*a'))
				updatelink = info.updateurl
				updateversion = info.latest
				file:close()
				os.remove(json)

				if updateversion ~= thisScript().version then
					lua_thread.create(function()
						sampAddChatMessage(string.format("[Admin Tools]:{FFFFFF} Загружается последняя версия скрипта: %s.", updateversion), 0xffa500)
						wait(250)							

						downloadUrlToFile(url, thisScript().path, function(id, status, p1, p2)
							if status == 58 then
								sampAddChatMessage(string.format("[Admin Tools]:{FFFFFF} Загрузка завершена, текущая версия скрипта: %s.", updateversion), 0xffa500)
								update = false
								lua_thread.create(function() wait(500) thisScript():reload() end)
							end
						end)
					end)
				else
					update = false
				end
			end
		end
	end)

	while update ~= false do wait(100) end
end