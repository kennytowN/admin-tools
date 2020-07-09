script_version('0.2.3-R3')

local sampev 				= require 'lib.samp.events'
local memory 				= require 'memory'
local key	 				= require 'vkeys'
local encoding			 	= require 'encoding'
local Matrix3X3 			= require "matrix3x3"
local Vector3D 				= require "vector3d"
local inicfg 				= require 'inicfg'

DEV_VERSION = false
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
	myId = -1,
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
		autoAduty = false,
    	autologin = false,
    	showpass = false,
		offReconAlert = true,
		offHelpersAnswers = false,
		password = ""
	},

	set = {
		wallhack = false,
		traicers = false,
		clickwarp = false
	}
}, 'admintools')
inicfg.save(mainIni, "admintools.ini")

function main()
	while not isSampAvailable() do wait(200) end
	while not sampIsLocalPlayerSpawned() do wait(1) end

	if not DEV_VERSION then
		autoupdate("https://raw.githubusercontent.com/kennytowN/admin-tools/master/admin-tools.json", "https://raw.githubusercontent.com/kennytowN/admin-tools/master/Admin_Tools.lua")
	end

	local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)

	if sampGetPlayerColor(playerId) == 16510045 then 
		scriptInfo.aduty = true 
	end

	scriptInfo.myId = playerId

	--if sampGetCurrentServerAddress() ~= "37.230.162.117" then
	if sampGetCurrentServerAddress() ~= "95.181.158.18" then
		thisScript():unload()
	else
		r_smart_lib_imgui()
		imgui_init()
		initializeRender()

		sampAddChatMessage("[Admin Tools]:{FFFFFF} Скрипт успешно загружен, приятного использования.", 0xffa500)

		while true do
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

			if scriptInfo.aduty then
				if isKeyDown(key.VK_MBUTTON) and ckClickWarp.v then -- Activate:: Clickwarp
					scriptInfo.clickwarp = not scriptInfo.clickwarp
					cursorEnabled = scriptInfo.clickwarp
					showCursor(cursorEnabled)
					while isKeyDown(key.VK_MBUTTON) do wait(80) end
				end

				if isKeyJustPressed(key.VK_RSHIFT) then -- Activate:: Airbreak
					scriptInfo.airbreak = not scriptInfo.airbreak

					if scriptInfo.airbreak then
						local posX, posY, posZ = getCharCoordinates(playerPed)
						airBrkCoords = {posX, posY, posZ, 0.0, 0.0, getCharHeading(playerPed)}
					end
				end

				if not wInfo.spectatemenu.v then imgui.Process = wInfo.main.v else imgui.Process = true end -- Close the window 

				local oTime = os.time()

				if scriptInfo.traicers and not isPauseMenuActive() then
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
					if isKeyDown(key.VK_UP) then airBrkCoords[3] = airBrkCoords[3] + scriptInfo.airspeed / 2.0 end
					if isKeyDown(key.VK_DOWN) and airBrkCoords[3] > -95.0 then airBrkCoords[3] = airBrkCoords[3] - scriptInfo.airspeed / 2.0 end
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
	ckAirBreak = imgui.ImBool(false)
	ckClickWarp = imgui.ImBool(mainIni.set.clickwarp)
	ckWallhack = imgui.ImBool(mainIni.set.wallhack)
	ckTraicers = imgui.ImBool(mainIni.set.traicers)
  
  	-- Search:: Variables settings
	ckAutoLogin = imgui.ImBool(mainIni.settings.autologin)
	ckOffHelpersAnswers = imgui.ImBool(mainIni.settings.offHelpersAnswers)
	ckOffReconAlert = imgui.ImBool(mainIni.settings.offReconAlert)
 	ckAutoAduty = imgui.ImBool(mainIni.settings.autoAduty)
  
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
	   --wInfo.stats.v = not wInfo.stats.v
	   sampAddChatMessage("[Admin Tools]:{FFFFFF} Эта функция находится в разработке.", 0xffa500)
    elseif imgui.Button(u8'Телепорт-лист',imgui.ImVec2(310,25)) then 
        wInfo.teleport.v = not wInfo.teleport.v
    elseif imgui.Button(u8'О скрипте',imgui.ImVec2(310,25)) then 
        wInfo.info.v = not wInfo.info.v
	end

    imgui.End()
end

function drawInfo()
    local ScreenX, ScreenY = getScreenResolution() 

    imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 600, ScreenY / 2 + 300), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8"Информация о скрипте", wInfo.info, imgui.WindowFlags.NoResize)

    if imgui.Button(u8'Связь с разработчиком',imgui.ImVec2(310,25)) then
        os.execute('start https://vk.com/unknownus3r')
    end

    imgui.SetCursorPosX((imgui.GetWindowWidth() - 70) / 2)
    imgui.Text(u8'Автор: taichi')
    imgui.SetCursorPosX((imgui.GetWindowWidth() - 100) / 2)
    imgui.Text(u8'Текущая версия скрипта: ' .. thisScript().version)

    if imgui.Button(u8'Назад',imgui.ImVec2(310,25)) then
        wInfo.info.v = false
        wInfo.main.v = true
    end

    imgui.End()
end

function drawTeleport()
    local ScreenX, ScreenY = getScreenResolution() 

    imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 565, ScreenY / 2 + 50), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(300, 120), imgui.Cond.FirstUseEver)
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

  	imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 1300, ScreenY - 500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
  	imgui.Begin(u8"Функции скрипта", wInfo.func, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)
	
	imgui.Text(u8"Основные функции:")
	imgui.Separator()
	imgui.Text(u8"\n")

  	if imgui.Checkbox(u8'Авто-логин', ckAutoLogin) then
   	 	mainIni.settings.autologin = ckAutoLogin.v
    	inicfg.save(mainIni, "admintools.ini")
	end
	  
	imgui.SameLine()
	imgui.TextQuestion(u8"Автоматически вводит пароль при входе на сервере")

  	if ckAutoLogin then
		imgui.SameLine()

		if wInfo.settings.showpass then
		if imgui.InputText(u8'##', temp_buffers.password) then
			mainIni.settings.password = temp_buffers.password.v
			inicfg.save(mainIni, "admintools.ini")
		end

		imgui.SameLine()
		if imgui.Button(u8"Скрыть пароль") then
			wInfo.settings.showpass = not wInfo.settings.showpass
		end
		else
		if imgui.InputText(u8'##', temp_buffers.password, imgui.InputTextFlags.Password) then
			mainIni.settings.password = temp_buffers.password.v
			inicfg.save(mainIni, "admintools.ini")
		end

		imgui.SameLine()
		if imgui.Button(u8"Показать пароль") then
			wInfo.settings.showpass = not wInfo.settings.showpass
		end
		end
	end

	if imgui.Checkbox(u8'Авто /aduty', ckAutoAduty) then
		mainIni.settings.autoAduty = ckAutoAduty.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.SameLine()
	imgui.TextQuestion(u8"Автоматически вводит /aduty при успешной авторизации в аккаунт")

	if imgui.Checkbox(u8'Отключение оповещения о начале слежки', ckOffReconAlert) then
		mainIni.settings.offReconAlert = ckOffReconAlert.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.SameLine()
	imgui.TextQuestion(u8"Убирает строку о начале слежки за игроком от другого администратора")

	if imgui.Checkbox(u8'Отключение ответов от хелперов', ckOffHelpersAnswers) then
		mainIni.settings.offHelpersAnswers = ckOffHelpersAnswers.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.SameLine()
	imgui.TextQuestion(u8"Убирает медвежью услугу в виде оповещения о том, что саппорт ответил игроку")
	
	if imgui.Checkbox("Wall Hack", ckWallhack) then
		mainIni.set.wallhack = ckWallhack.v
		inicfg.save(mainIni, "admintools.ini")

		nameTagSet(ckWallhack.v)
	end

	imgui.SameLine()
	imgui.TextQuestion(u8"Позволяет видеть игроков сквозь стены")

	if imgui.Checkbox(u8"Трейсеры пуль в слежке", ckTraicers) then 
		mainIni.set.traicers = ckTraicers.v 
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.SameLine()
	imgui.TextQuestion(u8"Позволяет видеть трейсера пуль того игрока, за которым вы следите")

	if imgui.Checkbox(u8"ТП по курсору", ckClickWarp) then 
		mainIni.set.clickwarp = ckClickWarp.v
		inicfg.save(mainIni, "admintools.ini")
	end

	imgui.Text(u8"\nAirBreak:")
	imgui.Separator()
	imgui.Text(u8"\n")

	if imgui.Checkbox(u8"AirBreak", ckAirBreak) then 
		scriptInfo.airbreak = ckAirBreak.v

		if scriptInfo.airbreak then
			local posX, posY, posZ = getCharCoordinates(playerPed)
			airBrkCoords = {posX, posY, posZ, 0.0, 0.0, getCharHeading(playerPed)}
		end
	end

	if imgui.SliderFloat(u8"Скорость", ckAirSpeed, 0.5, 15.0) then
		scriptInfo.airspeed = ckAirSpeed
	end

	imgui.Text(u8"\nУправление скриптом:")
	imgui.Separator()
	imgui.Text(u8"\n")

	if imgui.Button(u8'Перезагрузить скрипт') then
		thisScript():reload()
	end

	if imgui.Button(u8'Проверить обновления') then
		autoupdate("https://raw.githubusercontent.com/kennytowN/admin-tools/master/admin-tools.json", "https://raw.githubusercontent.com/kennytowN/admin-tools/master/Admin_Tools.lua")
	end

	imgui.End()
end

function drawSpectateMenu()
	local ScreenX, ScreenY = getScreenResolution()

	imgui.SetNextWindowPos(imgui.ImVec2(ScreenX - 350, ScreenY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(string.format(u8"Spectating: %s(%d)", sampGetPlayerNickname(recInfo.id), recInfo.id), wInfo.spectatemenu, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoResize)

	local result, ped = sampGetCharHandleBySampPlayerId(recInfo.id)

	if recInfo.loading then
		imgui.Text(u8"Loading...")

		if result then
			recInfo.loading = false
		end
	else
		imgui.Text(u8"Stats:\n\n")

		imgui.Text(u8"Health:")
		imgui.SameLine()
		imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t\t\t\t%d", sampGetPlayerHealth(recInfo.id)))

		imgui.Text(u8"Armour:")
		imgui.SameLine()
		imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t\t\t\t %d", sampGetPlayerArmor(recInfo.id)))

		imgui.Text(u8"Weapon:")
		imgui.SameLine()
		imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t\t\t\t%d", getCurrentCharWeapon(ped)))

		imgui.Text(u8"Ping:")
		imgui.SameLine()
		imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t %d", sampGetPlayerPing(recInfo.id)))

		imgui.Text(u8"In pause:")
		imgui.SameLine()
		imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t\t\t%s", sampIsPlayerPaused(recInfo.id)))

		if isCharInAnyCar(ped) then
			local vehicleId = storeCarCharIsInNoSave(ped)

			imgui.Text(u8"Speed:")
			imgui.SameLine()
			imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t\t\t\t %d", getCarSpeed(vehicleId) * 2.8))

			imgui.Text(u8"Vehicle health:")
			imgui.SameLine()
			imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t  %s", getCarHealth(vehicleId)))
		else
			imgui.Text(u8"Speed:")
			imgui.SameLine()
			imgui.Text(string.format(u8"\t\t\t\t\t\t\t\t\t\t\t\t\t\t   %d", getCharSpeed(ped)))

			imgui.Text(u8"Vehicle health:")
			imgui.SameLine()
			imgui.Text(u8"\t\t\t\t\t\t\t\t\t\t\t  -1")
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
			sampSendChat(string.format("/sethp %d %d", recInfo.id, tonumber(temp_buffers.sethp.v)))
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
function apply_custom_style()
	imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

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
function nameTagSet(arg)
  local pStSet = sampGetServerSettingsPtr()

  if arg then
	  memory.setfloat(pStSet + 39, 1488.0)
	  memory.setint8(pStSet + 47, 0)
    memory.setint8(pStSet + 56, 1)
  else
    memory.setfloat(pStSet + 39, 50.0)
	  memory.setint8(pStSet + 47, 0)
	  memory.setint8(pStSet + 56, 1)
  end
end

function ClearChat()
    memory.fill(sampGetChatInfoPtr() + 306, 0x0, 25200, false)
    setStructElement(sampGetChatInfoPtr() + 306, 25562, 4, true, false)
    memory.write(sampGetChatInfoPtr() + 0x63DA, 1, 1, false)
end

-- Search:: SA:MP Events
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
	if recInfo.state and tonumber(playerid) == recInfo.id and recInfo.traicers then
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
		if text:find(sampGetPlayerNickname(scriptInfo.myId)) or mainIni.settings.offReconAlert then
			return false 
		end
	elseif text:find("[A] Хелпер") and text:find("->") and mainIni.settings.offHelpersAnswers then
		return false
	elseif text:find("Надеемся, что вы") and ckAutoAduty.v and sampGetPlayerColor(scriptInfo.myId) ~= 16510045 then
		lua_thread.create(function() 
			wait(1000)
			sampSendChat('/aduty')
		end)

		if mainIni.set.wallhack then
			nameTagSet(true)
		end
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
	elseif text:find("начал дежурство") and sampGetPlayerNickname(scriptInfo.myId) then 
		scriptInfo.aduty = true 
	elseif text:find("ушёл с дежурства") and sampGetPlayerNickname(scriptInfo.myId) then 
		scriptInfo.aduty = false
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
					sampAddChatMessage('[Admin Tools]:{FFFFFF} Обновление скрипта не требуется, вы используете последнюю версию.', 0xffa500)
					update = false
				end
			end
		end
	end)

	while update ~= false do wait(100) end
end