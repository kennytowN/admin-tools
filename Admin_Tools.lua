script_version('0.1.8-beta')

local sampev 				= require 'lib.samp.events'
local memory 				= require 'memory'
local key	 				= require 'vkeys'
local encoding			 	= require 'encoding'
local Matrix3X3 			= require "matrix3x3"
local Vector3D 				= require "vector3d"
local inicfg 				= require 'inicfg'

encoding.default = 'cp1251'
u8 = encoding.UTF8

local ToScreen = convertGameScreenCoordsToWindowScreenCoords
local nextplayer = false
local main_window_state = false
local BulletSync = {lastId = 0, maxLines = 15}

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

local tInfo = {
	refreshId = -1,
	exitId = -1
}

local rInfo = {
	state = false,
    id = -1,
	lastCar = -1
}

local pInfo = {
	airbreak = false,
	clickwarp = false,
	aduty = false,
	showpass = false,
	airspeed = 0.5,
	session_time = 0
}

local wInfo = {
	main = false,
	func = false,
	stats = false,
	settings = false,
	info = false,
	teleport = false,
	spectatemenu = false
}

local mainIni = inicfg.load({
	settings = {
		autoAduty = false,
		autologin = false,
		offReconAlert = true,
		ckOffAsk = false,
		password = ""
	},

	functions = {
		wallhack = false,
		traicers = false
	},

	punishments = {
		jail = 0,
		kick = 0,
		mute = 0,
	},

	dayOnline = {
		real = 0,
		afk = 0
	}
}, 'admintools')
inicfg.save(mainIni, "admintools.ini")

for i = 1, BulletSync.maxLines do
	BulletSync[i] = {enable = false, o = {x, y, z}, t = {x, y, z}, time = 0, tType = 0}
end

function main()
	while not isSampAvailable() do wait(200) end
	while not sampIsLocalPlayerSpawned() do wait(1) end

	autoupdate("https://raw.githubusercontent.com/kennytowN/admin-tools/master/admin-tools.json", '['..string.upper(thisScript().name)..']: ', "https://raw.githubusercontent.com/kennytowN/admin-tools/master/Admin_Tools.lua")

	-- Reconnect
	sampRegisterChatCommand("rec", reconnect)

	-- Fix reload the script
	local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)

	if sampGetPlayerColor(id) == 16510045 then 
		pInfo.aduty = true 

		setCharProofs(playerPed, true, true, true, true, true)
		writeMemory(0x96916E, 1, 1, false)
	end

	serveradress = sampGetCurrentServerAddress()

	if serveradress ~= "95.181.158.18" then
		thisScript():unload()
	else
		lua_thread.create(dayOnlineTimer)

		r_smart_lib_imgui()
		imgui_init()
		initializeRender()

		sampAddChatMessage("[Admin Tools]:{FFFFFF} Скрипт успешно загружен, приятного использования.", 0xffa500)

		while true do
			if isKeyJustPressed(key.VK_F9) then
				if not pInfo.aduty then sampSendChat('/aduty')
				else
					pInfo.clickwarp = false

					wInfo.main = not wInfo.main

					if not wInfo.spectatemenu and not wInfo.main then
						imgui.Process = false
						showCursor(false)
					elseif wInfo.main then
						imgui.Process = true
						imgui.ShowCursor = true
						showCursor(true)
					end

					if not wInfo.main then
						wInfo.func 			= false
						wInfo.stats 		= false
						wInfo.settings 		= false
						wInfo.info 			= false
						wInfo.teleport 		= false
					end
				end
			end

			if pInfo.aduty then
				while isPauseMenuActive() do
					if cursorEnabled then
						showCursor(false)
					end
					wait(100)
				end
				
				if isKeyDown(key.VK_MBUTTON) then
					pInfo.clickwarp = not pInfo.clickwarp
					cursorEnabled = not cursorEnabled
					showCursor(cursorEnabled)
					while isKeyDown(key.VK_MBUTTON) do
						wait(80)
					end
				end

				if isKeyJustPressed(key.VK_RSHIFT) then -- airbrake
					pInfo.airbreak = not pInfo.airbreak

					if pInfo.airbreak then
						local posX, posY, posZ = getCharCoordinates(playerPed)
						airBrkCoords = {posX, posY, posZ, 0.0, 0.0, getCharHeading(playerPed)}
					end
				end
				
				if pInfo.clickwarp and pInfo.aduty then
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
						local result, colpoint =
							processLineOfSight(camX, camY, camZ, posX, posY, posZ, true, true, false, true, false, false, false)
						if result and colpoint.entity ~= 0 then
							local normal = colpoint.normal
							local pos =
								Vector3D(colpoint.pos[1], colpoint.pos[2], colpoint.pos[3]) -
								(Vector3D(normal[1], normal[2], normal[3]) * 0.1)
							local zOffset = 300
							if normal[3] >= 0.5 then
								zOffset = 1
							end
							-- search for the ground position vertically down
							local result, colpoint2 =
								processLineOfSight(
								pos.x,
								pos.y,
								pos.z + zOffset,
								pos.x,
								pos.y,
								pos.z - 0.3,
								true,
								true,
								false,
								true,
								false,
								false,
								false
							)
							if result then
								pos = Vector3D(colpoint2.pos[1], colpoint2.pos[2], colpoint2.pos[3] + 1)
				
								local curX, curY, curZ = getCharCoordinates(playerPed)
								local dist = getDistanceBetweenCoords3d(curX, curY, curZ, pos.x, pos.y, pos.z)
								local hoffs = renderGetFontDrawHeight(font)
				
								sy = sy - 2
								sx = sx - 2
								renderFontDrawText(font, string.format("%0.2fm", dist), sx, sy - hoffs, 0xEEEEEEEE)
				
								local tpIntoCar = nil
								if colpoint.entityType == 2 then
									local car = getVehiclePointerHandle(colpoint.entity)
									if
										doesVehicleExist(car) and
											(not isCharInAnyCar(playerPed) or storeCarCharIsInNoSave(playerPed) ~= car)
									then
										displayVehicleName(sx, sy - hoffs * 2, getNameOfVehicleModel(getCarModel(car)))
										local color = 0xAAFFFFFF
										if isKeyDown(key.VK_RBUTTON) then
											tpIntoCar = car
											color = 0xFFFFFFFF
										end
										renderFontDrawText(
											font2,
											"Hold right mouse button to teleport into the car",
											sx,
											sy - hoffs * 3,
											color
										)
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
									removePointMarker()
				
									while isKeyDown(key.VK_LBUTTON) do
										wait(0)
									end
									
									pInfo.clickwarp = false
									showCursor(false)
								end
							end
						end
					end
				end		

				local oTime = os.time()
				if pInfo.traicers and not isPauseMenuActive() then
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
			end

			if nextplayer then 
				local result, ped = sampGetCharHandleBySampPlayerId(rInfo.id)

				if not result then
					wait(400)
				else
					wait(200)
					nextplayer = false
				end
			else
				if rInfo.id ~= -1 and rInfo.state then
					local _, ped = sampGetCharHandleBySampPlayerId(rInfo.id)
					
					if ped ~= -1 then
						if isCharInAnyCar(ped) and storeCarCharIsInNoSave(ped) ~= rInfo.lastCar then
							sampSendClickTextdraw(tInfo.refreshId)
						elseif not isCharInAnyCar(ped) and rInfo.lastCar ~= -1 then
							sampSendClickTextdraw(tInfo.refreshId)
							rInfo.lastCar = -1
						end

						if not isCharInAnyHeli(ped) and not isCharInAnyPlane(ped) and getDistanceToPlayer(rInfo.id) > 30.0 or getDistanceToPlayer(rInfo.id) == -1 then
							sampSendClickTextdraw(tInfo.refreshId)
						end
					else
						sampSendClickTextdraw(tInfo.refreshId)
					end
				end
			end

			if res then
				sampDisconnectWithReason(quit)

				if time ~= nil then
					wait(time*1000)
				else 
					wait(2000)
				end

				sampSetGamestate(1)
				res = false
			end

			local time = os.clock() * 1000
			if pInfo.airbreak then -- airbrake
				if isCharInAnyCar(playerPed) then heading = getCarHeading(storeCarCharIsInNoSave(playerPed))
				else heading = getCharHeading(playerPed) end
				local camCoordX, camCoordY, camCoordZ = getActiveCameraCoordinates()
				local targetCamX, targetCamY, targetCamZ = getActiveCameraPointAt()
				local angle = getHeadingFromVector2d(targetCamX - camCoordX, targetCamY - camCoordY)
				if isCharInAnyCar(playerPed) then difference = 0.79 else difference = 1.0 end
				setCharCoordinates(playerPed, airBrkCoords[1], airBrkCoords[2], airBrkCoords[3] - difference)
				if isKeyDown(key.VK_W) then
					airBrkCoords[1] = airBrkCoords[1] + pInfo.airspeed * math.sin(-math.rad(angle))
					airBrkCoords[2] = airBrkCoords[2] + pInfo.airspeed * math.cos(-math.rad(angle))
					if not isCharInAnyCar(playerPed) then setCharHeading(playerPed, angle)
					else setCarHeading(storeCarCharIsInNoSave(playerPed), angle) end
				elseif isKeyDown(key.VK_S) then
					airBrkCoords[1] = airBrkCoords[1] - pInfo.airspeed * math.sin(-math.rad(heading))
					airBrkCoords[2] = airBrkCoords[2] - pInfo.airspeed * math.cos(-math.rad(heading))
				end
				if isKeyDown(key.VK_A) then
					airBrkCoords[1] = airBrkCoords[1] - pInfo.airspeed * math.sin(-math.rad(heading - 90))
					airBrkCoords[2] = airBrkCoords[2] - pInfo.airspeed * math.cos(-math.rad(heading - 90))
				elseif isKeyDown(key.VK_D) then
					airBrkCoords[1] = airBrkCoords[1] - pInfo.airspeed * math.sin(-math.rad(heading + 90))
					airBrkCoords[2] = airBrkCoords[2] - pInfo.airspeed * math.cos(-math.rad(heading + 90))
				end
				if isKeyDown(key.VK_UP) then airBrkCoords[3] = airBrkCoords[3] + pInfo.airspeed / 2.0 end
				if isKeyDown(key.VK_DOWN) and airBrkCoords[3] > -95.0 then airBrkCoords[3] = airBrkCoords[3] - pInfo.airspeed / 2.0 end
				if not isSampfuncsConsoleActive() and not sampIsChatInputActive() and not sampIsDialogActive() and not isPauseMenuActive() then
					if isKeyDown(key.VK_OEM_PLUS) and time - tick.Keys.Plus > tick.Time.PlusMinus then
						if pInfo.airspeed < 14.9 then pInfo.airspeed = pInfo.airspeed + 0.5 end
						tick.Keys.Plus = os.clock() * 1000
					elseif isKeyDown(key.VK_OEM_MINUS) and time - tick.Keys.Minus > tick.Time.PlusMinus then
						if pInfo.airspeed > 0.5 then pInfo.airspeed = pInfo.airspeed - 0.5 end
						tick.Keys.Minus = os.clock() * 1000
					end
				end
			else
				setCharProofs(playerPed, true, true, true, true, true)
				writeMemory(0x96916E, 1, 1, false)
			end

			wait(0)
			removePointMarker()
		end
	end
end

-- Downloading packages
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

-- Initizalize
function initializeRender()
	font = renderCreateFont("Tahoma", 10, FCR_BOLD + FCR_BORDER)
	font2 = renderCreateFont("Arial", 8, FCR_ITALICS + FCR_BORDER)
end

function imgui_init()
	ckWallhack = imgui.ImBool(mainIni.functions.wallhack)
	ckTraicers = imgui.ImBool(mainIni.functions.traicers)
	ckAutoLogin = imgui.ImBool(mainIni.settings.autologin)
	ckOffReconAlert = imgui.ImBool(mainIni.settings.offReconAlert)
	ckOffAsk = imgui.ImBool(mainIni.settings.ckOffAsk)
	ckAutoAduty = imgui.ImBool(mainIni.settings.autoAduty)

	temp_buffers = {
		password = imgui.ImBuffer(mainIni.settings.password, 256),
		sethp = imgui.ImBuffer(4)
	}

	if ckWallhack.v then 
		nameTagOn() 
	end

	apply_custom_style()

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

	function imgui.OnDrawFrame()
		ScreenX, ScreenY = getScreenResolution()

		if wInfo.spectatemenu and rInfo.id ~= -1 then
			if not wInfo.main and not wInfo.teleport and not wInfo.func and not wInfo.info and not wInfo.stats then
				imgui.ShowCursor = false
			end

			if ScreenY == 1080 then
				imgui.SetNextWindowPos(imgui.ImVec2(1550, ScreenY - 200), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			elseif ScreenY == 600 then 
				imgui.SetNextWindowPos(imgui.ImVec2(600, ScreenY - 200), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			elseif ScreenY == 1024 then
				imgui.SetNextWindowPos(imgui.ImVec2(1150, ScreenY - 200), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			elseif ScreenY == 768 then
				imgui.SetNextWindowPos(imgui.ImVec2(1000, ScreenY - 200), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			elseif ScreenY == 900 then
				imgui.SetNextWindowPos(imgui.ImVec2(1080, ScreenY - 200), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			end

			imgui.Begin(sampGetPlayerNickname(rInfo.id), wInfo.spectatemenu, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

			local result, ped = sampGetCharHandleBySampPlayerId(rInfo.id)

			if result and doesCharExist(ped) then
				imgui.Text(string.format(u8"Skin: %d", getCharModel(ped)))
				imgui.SameLine()

				if isCharInAnyCar(ped) then
					local vehicleId = storeCarCharIsInNoSave(ped)

					imgui.Text(string.format(u8"Ping: %d", sampGetPlayerPing(rInfo.id)))
					imgui.SameLine()
					imgui.Text(string.format(u8"Armour: %d", sampGetPlayerArmor(rInfo.id)))
					imgui.Text(string.format(u8"HP: %d", getCarHealth(vehicleId)))
					imgui.SameLine()
					imgui.Text(string.format(u8"Speed: %f", getCarSpeed(vehicleId) * 2.8))
					imgui.SameLine()
					imgui.Text(string.format(u8"Model: %s", getNameOfVehicleModel(getCarModel(vehicleId))))
					imgui.SameLine()
					imgui.Text(string.format(u8"Engine: %s", isCarEngineOn(vehicleId)))
				else
					imgui.Text(string.format(u8"HP: %d", sampGetPlayerHealth(rInfo.id)))
					imgui.SameLine()
					imgui.Text(string.format(u8"Ping: %d", sampGetPlayerPing(rInfo.id)))
					imgui.Text(string.format(u8"Armour: %d", sampGetPlayerArmor(rInfo.id)))
					imgui.SameLine()
					imgui.Text(string.format(u8"Speed: %f", getCharSpeed(ped)))
				end

				if imgui.Button(u8'Next') then
					if rInfo.id == sampGetMaxPlayerId(false) then
						sampAddChatMessage("[Admin Tools]:{FFFFFF} Следующий игрок не найден.", 0xffa500)
					else 
						for i = rInfo.id, sampGetMaxPlayerId(false) do
							if sampIsPlayerConnected(i) and sampGetPlayerScore(i) ~= 0 and sampGetPlayerColor(i) ~= 16510045 and i ~= rInfo.id then
								sampSendChat(string.format("/re %d", i))
								break
							end
						end
					end
				end
				imgui.SameLine()

				if imgui.Button(u8'Previous') then
					if rInfo.id == 0 then
						sampAddChatMessage("[Admin Tools]:{FFFFFF} Предыдущий игрок не найден.", 0xffa500)
					else 
						for i = rInfo.id, 0, -1 do
							if sampIsPlayerConnected(i) and sampGetPlayerScore(i) ~= 0 and sampGetPlayerColor(i) ~= 16510045 and i ~= rInfo.id then
								sampSendChat(string.format("/re %d", i))
								break
							end
						end
					end
				end
				imgui.SameLine()

				if imgui.Button(u8'Spawn') then
					sampSendChat(string.format("/spawn %d", rInfo.id))
				end
				imgui.SameLine()
				
				if imgui.Button(u8'Вы тут?') then
					sampSendChat(string.format("/ans %d Вы тут? Ответьте в /b.", rInfo.id))
				end
				imgui.SameLine()
				
				if imgui.Button(u8'Не прыгайте') then
					sampSendChat(string.format("/ans %d Не прыгайте.", rInfo.id))
				end

				if imgui.Button(u8'/aheal') then
					sampSendChat(string.format("/aheal %d", rInfo.id))
				end
				imgui.SameLine()

				if imgui.Button(u8'/sethp') then
					sampSendChat(string.format("/sethp %d %d", rInfo.id, tonumber(temp_buffers.sethp.v)))
				end

				imgui.SameLine()
				imgui.PushItemWidth(35)
				imgui.InputText(u8"##", temp_buffers.sethp)
				imgui.PopItemWidth()

				if isCharInAnyCar(ped) then
					imgui.SameLine()

					if imgui.Button(u8'/afixcar') then
						local _, id = sampGetVehicleIdByCarHandle(storeCarCharIsInNoSave(ped))
						sampSendChat(string.format("/afixcar %d", id))
					end
				end
			else
				imgui.Text(u8'Загрузка...')
			end

			imgui.End()
		end

		if wInfo.main then 
			imgui.SetNextWindowPos(imgui.ImVec2(ScreenX / 2, ScreenY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.Begin(u8'Admin tools', wInfo.main, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

			if imgui.Button(u8'Функции',imgui.ImVec2(310,25)) then
				wInfo.main = false
				wInfo.func = true
			elseif imgui.Button(u8'Статистика',imgui.ImVec2(310,25)) then 
				wInfo.main = false
				wInfo.stats = true
			elseif imgui.Button(u8'Телепорт-лист',imgui.ImVec2(310,25)) then 
				wInfo.teleport = true
				wInfo.main = false
			elseif imgui.Button(u8'О скрипте',imgui.ImVec2(310,25)) then 
				wInfo.main = false
				wInfo.info = true
			end

			imgui.End()
		elseif wInfo.stats then
			local _, playerid = sampGetPlayerIdByCharHandle(PLAYER_PED)

			imgui.SetNextWindowPos(imgui.ImVec2(ScreenX / 2, ScreenY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.Begin(string.format(u8'Статистика %s', sampGetPlayerNickname(playerid)), wInfo.main, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

			imgui.Text(string.format(u8"Текущая сессия: %s", secToTime(pInfo.session_time)))
			imgui.Text(string.format(u8"Реальный онлайн: %s", secToTime(mainIni.dayOnline.real)))
			imgui.Text(string.format(u8"Время проведённое в AFK: %s", secToTime(mainIni.dayOnline.afk)))

			imgui.Text(string.format(u8"Выдано блокировок чата: %d", mainIni.punishments.mute))
			imgui.Text(string.format(u8"Выдано джайлов: %d", mainIni.punishments.jail))
			imgui.Text(string.format(u8"Отключено игроков: %d", mainIni.punishments.kick))

			if imgui.Button(u8'Назад',imgui.ImVec2(250,25)) then
				wInfo.stats = false
				wInfo.main = true
			end

			imgui.End()	
		elseif wInfo.info then
			imgui.SetNextWindowPos(imgui.ImVec2(ScreenX / 2 , ScreenY / 2), imgui.Cond.FirsUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.Begin(u8"Информация о скрипте", wInfo.info, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)
			if imgui.Button(u8'Связь с автором',imgui.ImVec2(310,25)) then
				os.execute('start https://vk.com/unknownus3r')
			end
			imgui.SetCursorPosX((imgui.GetWindowWidth() - 70) / 2)
			imgui.Text(u8'Автор: taichi')
			imgui.SetCursorPosX((imgui.GetWindowWidth() - 100) / 2)
			imgui.Text(u8'Текущая версия скрипта: 1.6')
			if imgui.Button(u8'Назад',imgui.ImVec2(310,25)) then
				wInfo.info = false
				wInfo.main = true
			end
			imgui.End()
		elseif wInfo.func then
			imgui.SetNextWindowPos(imgui.ImVec2(ScreenX / 2 , ScreenY / 2), imgui.Cond.FirsUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.Begin(u8"Функции скрипта", wInfo.info, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

			imgui.TextQuestion(u8"Автоматически вводит пароль при входе на сервере")
			imgui.SameLine()
			
			if imgui.Checkbox(u8'Авто-логин', ckAutoLogin) then
				mainIni.settings.autologin = ckAutoLogin.v
				inicfg.save(mainIni, "admintools.ini")
			end

			if ckAutoLogin then
				imgui.SameLine()

				if pInfo.showpass then
					if imgui.InputText(u8'##', temp_buffers.password) then
						mainIni.settings.password = temp_buffers.password.v
						inicfg.save(mainIni, "admintools.ini")
					end

					imgui.SameLine()
					if imgui.Button(u8"Скрыть пароль") then
						pInfo.showpass = not pInfo.showpass
					end
				else
					if imgui.InputText(u8'##', temp_buffers.password, imgui.InputTextFlags.Password) then
						mainIni.settings.password = temp_buffers.password.v
						inicfg.save(mainIni, "admintools.ini")
					end

					imgui.SameLine()
					if imgui.Button(u8"Показать пароль") then
						pInfo.showpass = not pInfo.showpass
					end
				end
			end

			imgui.TextQuestion(u8"Автоматически вводит /aduty при успешной авторизации в аккаунт")
			imgui.SameLine()

			if imgui.Checkbox(u8'Авто /aduty', ckAutoAduty) then
				mainIni.settings.autoAduty = ckAutoAduty.v
				inicfg.save(mainIni, "admintools.ini")
			end

			imgui.TextQuestion(u8"Убирает строку о начале слежки за игроком от другого администратора")
			imgui.SameLine()

			if imgui.Checkbox(u8'Отключение оповещения о начале слежки', ckOffReconAlert) then
				mainIni.settings.offReconAlert = ckOffReconAlert.value
				inicfg.save(mainIni, "admintools.ini")
			end

			imgui.TextQuestion(u8"Визуально отключает вопросы от игроков")
			imgui.SameLine()

			if imgui.Checkbox(u8'Отключение вопросов от игроков', ckOffAsk) then
				mainIni.settings.OffAsk = ckOffAsk.value
				inicfg.save(mainIni, "admintools.ini")
			end

			imgui.TextQuestion(u8"Позволяет видеть игроков сквозь стены")
			imgui.SameLine()
			
			if imgui.Checkbox("Wall Hack", ckWallhack) then
				mainIni.functions.wallhack = ckWallhack.v
				inicfg.save(mainIni, "admintools.ini")
				if ckWallhack.v then nameTagOn() else nameTagOff() end
			end
		
			imgui.TextQuestion(u8"Позволяет видеть трейсера пуль того игрока, за которым вы следите")
			imgui.SameLine()

			if imgui.Checkbox(u8"Трейсеры пуль", ckTraicers) then 
				mainIni.functions.traicers = ckTraicers.v 
				inicfg.save(mainIni, "admintools.ini")
			end

			imgui.TextQuestion(u8"Простая очистка чата")
			imgui.SameLine()

			if imgui.Button(u8'Очистить чат') then 
				ClearChat() 
			end

			if imgui.Button(u8'Назад',imgui.ImVec2(490,25)) then
				wInfo.func = false
				wInfo.main = true
			end

			imgui.End()
		elseif wInfo.teleport then
			imgui.SetNextWindowPos(imgui.ImVec2(ScreenX / 2, ScreenY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.SetNextWindowSize(imgui.ImVec2(300, 200), imgui.Cond.FirstUseEver)
			imgui.Begin(u8'Телепорт-меню', wInfo.teleport, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

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

			if imgui.Button(u8'Назад',imgui.ImVec2(310,25)) then
				wInfo.teleport = false
				wInfo.main = true
			end

			imgui.End()
		end
    end
end

-- Imgui settings
function apply_custom_style()
	imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowPadding = ImVec2(15, 15)
    style.WindowRounding = 5.0
    style.FramePadding = ImVec2(5, 5)
    style.FrameRounding = 4.0
    style.ItemSpacing = ImVec2(12, 8)
    style.ItemInnerSpacing = ImVec2(8, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 15.0
    style.ScrollbarRounding = 9.0
    style.GrabMinSize = 5.0
    style.GrabRounding = 3.0

    colors[clr.Text] = ImVec4(0.80, 0.80, 0.83, 1.00)
    colors[clr.TextDisabled] = ImVec4(0.24, 0.23, 0.29, 1.00)
    colors[clr.WindowBg] = ImVec4(0.06, 0.05, 0.07, 1.00)
	colors[clr.ChildWindowBg] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.PopupBg] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.Border] = ImVec4(0.80, 0.80, 0.83, 0.88)
    colors[clr.BorderShadow] = ImVec4(0.92, 0.91, 0.88, 0.00)
    colors[clr.FrameBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.FrameBgHovered] = ImVec4(0.24, 0.23, 0.29, 1.00)
    colors[clr.FrameBgActive] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.TitleBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.TitleBgCollapsed] = ImVec4(1.00, 0.98, 0.95, 0.75)
    colors[clr.TitleBgActive] = ImVec4(0.07, 0.07, 0.09, 1.00)
    colors[clr.MenuBarBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.ScrollbarBg] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.ScrollbarGrab] = ImVec4(0.80, 0.80, 0.83, 0.31)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.ScrollbarGrabActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.ComboBg] = ImVec4(0.19, 0.18, 0.21, 1.00)
    colors[clr.CheckMark] = ImVec4(0.80, 0.80, 0.83, 0.31)
    colors[clr.SliderGrab] = ImVec4(0.80, 0.80, 0.83, 0.31)
    colors[clr.SliderGrabActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.Button] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.ButtonHovered] = ImVec4(0.24, 0.23, 0.29, 1.00)
    colors[clr.ButtonActive] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.Header] = ImVec4(0.10, 0.09, 0.12, 1.00)
    colors[clr.HeaderHovered] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.HeaderActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.ResizeGrip] = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.ResizeGripHovered] = ImVec4(0.56, 0.56, 0.58, 1.00)
    colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.16)
    colors[clr.CloseButtonHovered] = ImVec4(0.40, 0.39, 0.38, 0.39)
    colors[clr.CloseButtonActive] = ImVec4(0.40, 0.39, 0.38, 1.00)
    colors[clr.PlotLines] = ImVec4(0.40, 0.39, 0.38, 0.63)
    colors[clr.PlotLinesHovered] = ImVec4(0.25, 1.00, 0.00, 1.00)
    colors[clr.PlotHistogram] = ImVec4(0.40, 0.39, 0.38, 0.63)
    colors[clr.PlotHistogramHovered] = ImVec4(0.25, 1.00, 0.00, 1.00)
    colors[clr.TextSelectedBg] = ImVec4(0.25, 1.00, 0.00, 0.43)
    colors[clr.ModalWindowDarkening] = ImVec4(1.00, 0.98, 0.95, 0.73)
end

-- RPC
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
	if dialogId ~= 65535 and title:find("Ввод пароля") and ckAutoLogin and mainIni.settings.password ~= "" then
		sampSendDialogResponse(dialogId, 1, -1, mainIni.settings.password)
		return false
	end
end

function sampev.onBulletSync(playerid, data)
	if rInfo.state and tonumber(playerid) == rInfo.id and rInfo.traicers then
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

function sampev.onTogglePlayerSpectating(state)
    rInfo.state = state

	if not state then
		rInfo.lastCar = -1
		rInfo.id = -1
		wInfo.spectatemenu = false
	else
		wInfo.spectatemenu = true
	end
end

function sampev.onSendCommand(cmd)
	local reId = string.match(cmd, "^%/re (%d+)")
	if not reId then reId = string.match(cmd, "^%/sp (%d+)") end

	if reId and sampIsPlayerConnected(reId) and sampGetPlayerColor(reId) ~= 16510045 then
		if rInfo.id then 
			nextplayer = true 
		end

		rInfo.state = false
		rInfo.id = tonumber(reId)
		saveId = reId
		rInfo.lastCar = -1

		wInfo.spectatemenu = true
		imgui.Process = true
	end
	
    if cmd:find("/re off") or cmd:find("/sp off") then
        rInfo.lastCar = -1
		rInfo.id = -1
		wInfo.spectatemenu = false
		
		if not wInfo.main and not wInfo.teleport and not wInfo.func and not wInfo.info and not wInfo.stats then
			imgui.Process = false
			imgui.ShowCursor = false
		end
    end
end

function sampev.onSpectatePlayer(playerid, camtype)
    rInfo.state = true
    rInfo.id = tonumber(playerid)
	rInfo.lastCar = -1
end
function sampev.onSpectateVehicle(carid, camtype)
    local _, car = sampGetCarHandleBySampVehicleId(carid)

    rInfo.lastCar = car
	rInfo.state = true
	
	reconNext = false
	reconPrevious = false
end

function sampev.onServerMessage(color, text)
    local _, playerid = sampGetPlayerIdByCharHandle(PLAYER_PED)

	if text:find("начал слежку за") then 
		if text:find(sampGetPlayerNickname(playerid)) or mainIni.settings.offReconAlert then 
			return false
		end
	elseif text:find("Вопрос от") and mainIni.settings.OffAsk then
		return false
	end

	if text:find(sampGetPlayerNickname(playerid)) then
		if text:find("начал дежурство") then 
			pInfo.aduty = true 
			setCharProofs(playerPed, true, true, true, true, true)
			writeMemory(0x96916E, 1, 1, false)
		elseif text:find("ушёл с дежурства") then 
			pInfo.aduty = false 
		elseif text:find("выдал бан OOC чата") then
			mainIni.punishments.mute = mainIni.punishments.mute + 1
			inicfg.save(mainIni, "admintools.ini")
		elseif text:find("посадил") then
			mainIni.punishments.jail = mainIni.punishments.jail + 1
			inicfg.save(mainIni, "admintools.ini")
		elseif text:find("кикнул") then
			mainIni.punishments.kick = mainIni.punishments.kick + 1
 			inicfg.save(mainIni, "admintools.ini")
		end
	elseif text:find("Надеемся, что вы") and ckAutoAduty then
		lua_thread.create(function() 
			local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)

			if sampGetPlayerColor(id) ~= 16510045 then
				wait(1000)
				sampSendChat('/aduty')
			end
		end)
	elseif text:find("Во время слежки") then
		rInfo.lastCar = -1
		rInfo.id = -1
		wInfo.spectatemenu = false
		
		if not wInfo.main and not wInfo.teleport and not wInfo.func and not wInfo.info and not wInfo.stats then
			imgui.Process = false
		end
	elseif text:find("Вы не можете следить за администратором") or text:find("Данный игрок не авторизован") then
		sampSendChat(string.format("/re %d", rInfo.id))
		wInfo.spectatemenu = true
	end
end

function sampev.onShowTextDraw(textdrawId, data)
	if data.text:find("Refresh") then tInfo.refreshId = textdrawId
	elseif data.text:find("Exit") then tInfo.exitId = textdrawId end
end

function sampev.onSendClickTextDraw(textdrawId)
	if textdrawId == tInfo.exitId then
		rInfo.lastCar = -1
		rInfo.id = -1
		wInfo.spectatemenu = false
		
		if not wInfo.main and not wInfo.teleport and not wInfo.func and not wInfo.info and not wInfo.stats then
			imgui.Process = false
			imgui.ShowCursor = false
		end
	end
end

-- Custom functions
function calcScreenCoors(fX,fY,fZ)
	local dwM = 0xB6FA2C

	local m_11 = memory.getfloat(dwM + 0*4)
	local m_12 = memory.getfloat(dwM + 1*4)
	local m_13 = memory.getfloat(dwM + 2*4)
	local m_21 = memory.getfloat(dwM + 4*4)
	local m_22 = memory.getfloat(dwM + 5*4)
	local m_23 = memory.getfloat(dwM + 6*4)
	local m_31 = memory.getfloat(dwM + 8*4)
	local m_32 = memory.getfloat(dwM + 9*4)
	local m_33 = memory.getfloat(dwM + 10*4)
	local m_41 = memory.getfloat(dwM + 12*4)
	local m_42 = memory.getfloat(dwM + 13*4)
	local m_43 = memory.getfloat(dwM + 14*4)

	local dwLenX = memory.read(0xC17044, 4)
	local dwLenY = memory.read(0xC17048, 4)

	frX = fZ * m_31 + fY * m_21 + fX * m_11 + m_41
	frY = fZ * m_32 + fY * m_22 + fX * m_12 + m_42
	frZ = fZ * m_33 + fY * m_23 + fX * m_13 + m_43

	fRecip = 1.0/frZ
	frX = frX * (fRecip * dwLenX)
	frY = frY * (fRecip * dwLenY)

    if(frX<=dwLenX and frY<=dwLenY and frZ>1)then
        return frX, frY, frZ
	else
		return -1, -1, -1
	end
end

function nameTagOn()
	local pStSet = sampGetServerSettingsPtr()

	memory.setfloat(pStSet + 39, 1488.0)
	memory.setint8(pStSet + 47, 0)
	memory.setint8(pStSet + 56, 1)
end

function ClearChat()
    memory.fill(sampGetChatInfoPtr() + 306, 0x0, 25200, false)
    setStructElement(sampGetChatInfoPtr() + 306, 25562, 4, true, false)
    memory.write(sampGetChatInfoPtr() + 0x63DA, 1, 1, false)
end

function nameTagOff()
	local pStSet = sampGetServerSettingsPtr()

	memory.setfloat(pStSet + 39, 50.0)
	memory.setint8(pStSet + 47, 0)
	memory.setint8(pStSet + 56, 1)
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

-- Click warp functions
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

	writeMemory(0x00BA6748 + 0x15C, 1, 1, false) -- textures loaded
	writeMemory(0x00BA6748 + 0x15D, 1, 5, false) -- current menu
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

function showCursor(toggle)
	if toggle then
		sampSetCursorMode(CMODE_LOCKCAM)
	else
		sampToggleCursor(false)
	end

	cursorEnabled = toggle
end  

function onScriptTerminate(script, quitGame)
	if script == thisScript() then
		if not doesDirectoryExist("moonloader\\config") then
			createDirectory("moonloader\\config")
		end

		inicfg.save(mainIni, "admintools")
	end
end

function reconnect(param)
	time = tonumber(param)
	res = true
end

function secToTime(sec)
	local hour, minute, second = sec / 3600, math.floor(sec / 60), sec % 60
	return string.format("%02d:%02d:%02d", math.floor(hour) ,  minute - (math.floor(hour) * 60), second)
end

-- Custom threads
function dayOnlineTimer()
	while true do
		wait(1000)

		pInfo.session_time = pInfo.session_time + 1

		if not isGamePaused() then
			mainIni.dayOnline.real = mainIni.dayOnline.real + 1
		else
			mainIni.dayOnline.afk = mainIni.dayOnline.afk + 1
		end
	end
end

function autoupdate(json_url, prefix, url)
	local json = getWorkingDirectory() .. '\\admin-tools.json'
	if doesFileExist(json) then os.remove(json) end

	downloadUrlToFile(json_url, json,
		function(id, status, p1, p2)
			if status == 58 then
				if doesFileExist(json) then
					local file = io.open(json, 'r')

					if file then
						local data = decodeJson(file:read('*a'))

						updatelink = data.updateurl
						updateversion = data.latest

						file:close()
						os.remove(json)

						if thisScript().version ~= updateversion then
							lua_thread.create(function()
								sampAddChatMessage(string.format("[Admin Tools]:{FFFFFF} Загружается последняя версия скрипта: %s.", updateversion), 0xffa500)
								wait(250)							

								downloadUrlToFile(url, thisScript().path,
									function(id, status, p1, p2)
										if status == 58 then
											sampAddChatMessage(string.format("[Admin Tools]:{FFFFFF} Загрузка завершена, текущая версия скрипта: %s.", updateversion), 0xffa500)
										end
									end
								)
							end)
						else
							sampAddChatMessage('[Admin Tools]:{FFFFFF} Обновление скрипта не требуется, вы используете последнюю версию.', 0xffa500)
							update = false
						end
					end
				end
			end
		end
	)

	while update ~= false do wait(100) end
end