script_name('ARIZONA PET')
script_author('ARIZONA PET')
script_version('0.1.0')
script_description('Бублик: виртуальный питомец, память, комнаты и мини-игры')

-- Source and ImGui strings are UTF-8. SA-MP chat is encoded separately.
local ok,imgui=pcall(require,'mimgui')
if not ok then error('ARIZONA PET: install mimgui 1.7.1 (see README). '..tostring(imgui)) end
imgui.SetDpiScalingMode(0) -- this interface scales explicitly to game resolution
local encok,encoding=pcall(require,'encoding')
if encok then encoding.default='CP1251' end
local State=require 'arizona_pet.core.state'
local Storage=require 'arizona_pet.core.storage'
local Model=require 'arizona_pet.pet.model'
local Player=require 'arizona_pet.animation.player'
local Textures=require 'arizona_pet.animation.textures'
local View=require 'arizona_pet.ui.view'
local Integration=require 'arizona_pet.integration.game'
local Sound=require 'arizona_pet.core.sound'
local C=require 'arizona_pet.core.config'
local U=require 'arizona_pet.core.util'
local root=getWorkingDirectory()..'/resource/arizona_pet'
local configRoot=getWorkingDirectory()..'/config/arizona_pet'
local model,storage,ui,integration,player,textures,sound
local running=false; local initialized=false; local overlay,mainFrame
local fontRanges -- keep the native glyph range vector alive
local function chat(text)
    print('[ARIZONA PET] '..text)
    if type(sampAddChatMessage)=='function' and type(isSampAvailable)=='function' and isSampAvailable() then
        if encok then
            local converted,result=pcall(function() return encoding.UTF8:decode(text) end)
            if converted then pcall(sampAddChatMessage,'{65D6C0}[ARIZONA PET] {FFFFFF}'..result,-1); return end
        end
        pcall(sampAddChatMessage,'[ARIZONA PET] See moonloader.log for details.',-1)
    end
end
local function save()
    if not model or not storage then return end
    local saved,err=storage:save(model.s,os.time())
    if not saved then chat('Не удалось сохранить прогресс: '..tostring(err)) end
end
local function cursorState()
    if not ui then return end
    overlay.HideCursor=not ui.edit; overlay.LockPlayer=ui.edit
    mainFrame.HideCursor=false; mainFrame.LockPlayer=ui.open
end
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename=nil
    local font=root..'/fonts/OpenSans-Semibold.ttf'
    if U.exists(font) then
        local io=imgui.GetIO()
        local builder=imgui.ImFontGlyphRangesBuilder()
        builder:AddRanges(io.Fonts:GetGlyphRangesCyrillic())
        builder:AddText('•–—…×')
        fontRanges=imgui.ImVector_ImWchar()
        builder:BuildRanges(fontRanges)
        io.Fonts:Clear() -- replace the backend default instead of silently leaving it selected
        io.FontGlobalScale=1
        io.Fonts:AddFontFromFileTTF(font,16,nil,fontRanges[0].Data)
    else chat('Отсутствует русский шрифт: '..font) end
    initialized=true
end)
mainFrame=imgui.OnFrame(function() return running and initialized and ui.open end,
    function() textures:trim(); cursorState() end,
    function() ui:update(math.min(.25,imgui.GetIO().DeltaTime)); ui:main(); cursorState() end)
mainFrame.LockPlayer=true
overlay=imgui.OnFrame(function() return running and initialized and model.s.settings.mini and not ui.open end,
    function() textures:trim(); cursorState() end,
    function() ui:update(math.min(.25,imgui.GetIO().DeltaTime)); ui:mini(); cursorState() end)
overlay.HideCursor=true
local function profileName()
    -- Prefer a server/account-specific profile when these optional APIs work.
    if type(sampGetPlayerIdByCharHandle)=='function' and type(sampGetPlayerNickname)=='function' then
        local worked,found,id=pcall(sampGetPlayerIdByCharHandle,PLAYER_PED)
        if worked and found then
            local worked2,nick=pcall(sampGetPlayerNickname,id)
            local server='server'
            if type(sampGetCurrentServerAddress)=='function' then
                local worked3,host,port=pcall(sampGetCurrentServerAddress)
                if worked3 then server=tostring(host)..'_'..tostring(port) end
            end
            if worked2 then return U.profile(server..'_'..nick) end
        end
    end
    return 'default'
end
function main()
    if type(isSampAvailable)~='function' then chat('Требуется SA-MP и MoonLoader 0.26.'); return end
    while not isSampAvailable() do wait(200) end
    createDirectory(getWorkingDirectory()..'/config')
    createDirectory(configRoot)
    storage=Storage.new(configRoot..'/'..profileName()..'.json')
    local state,warning=storage:load(os.time())
    model=Model.new(state,os.time()); model:resume(os.time())
    player=Player.new(); textures=Textures.new(imgui,root,chat); sound=Sound.new(_G,root)
    ui=View.new(imgui,model,player,textures,save)
    integration=Integration.new(_G,model,chat)
    if warning then chat(warning) end
    -- Optional resource packs may add sound clips and animation states.
    sampRegisterChatCommand('pet',function() ui.open=not ui.open; ui.edit=false; ui.drag_food=nil; cursorState(); if not ui.open then ui.game=nil; if ui.menu=='game' then ui.menu=nil end; save() end end)
    sampRegisterChatCommand('petmini',function() model.s.settings.mini=not model.s.settings.mini; ui.edit=false; cursorState(); save() end)
    sampRegisterChatCommand('petedit',function() ui.edit=not ui.edit; ui.open=false; ui.game=nil; if ui.menu=='game' then ui.menu=nil end; model.s.settings.mini=true; cursorState(); save() end)
    sampRegisterChatCommand('pethide',function() ui.open=false; ui.edit=false; model.s.settings.mini=false; ui.game=nil; cursorState(); save() end)
    sampRegisterChatCommand('petsave',save)
    running=true; save(); chat('Бублик рядом! /pet — комната, /petmini — компаньон, /petedit — позиция.')
    local last=type(getGameTimer)=='function' and getGameTimer() or os.time()*1000
    local sinceSave,poll=0,0
    while true do
        wait(C.tick_ms)
        local nowTimer=type(getGameTimer)=='function' and getGameTimer() or os.time()*1000
        local dt=U.clamp((nowTimer-last)/1000,0,2); last=nowTimer
        model:tick(dt,os.time())
        -- Pet simulation stays active when hidden. Visual interpolation and
        -- minigames advance using render DeltaTime, independently of GTA FPS.
        poll=poll+dt; sinceSave=sinceSave+dt
        if poll>=1 then integration:update(poll); poll=0 end
        while #model.events>0 do
            local e=table.remove(model.events,1)
            if model.s.sleeping then player:play('sleep',true) else player:play(e.animation) end
            sound:play(e.id,model.s.settings)
        end
        cursorState()
        if sinceSave>=C.save_seconds then save(); sinceSave=0 end
    end
end
function onScriptTerminate(script,quitGame)
    if script~=thisScript() then return end
    running=false
    save()
    if mainFrame then mainFrame:Unsubscribe() end
    if overlay then overlay:Unsubscribe() end
    if textures then textures:clear() end
    if sound then sound:clear() end
end
-- Recover only our texture cache when the game's D3D device is recreated.
addEventHandler('onD3DDeviceLost',function() if textures then textures:clear() end end)
addEventHandler('onD3DDeviceReset',function() if textures then textures.failed={} end end)
