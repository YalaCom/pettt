local Mock=dofile('tests/imgui_mock.lua')
local U=require 'arizona_pet.core.util'
local Storage=require 'arizona_pet.core.storage'
return {moonloader_lifecycle_with_mocks=function()
    local i=Mock.new(1280,720); local subscriptions,initialize,events,commands={},{},{},{}
    local ticks=0; local script={}; local logs={}
    local oldprint=print
    package.loaded.mimgui=i
    package.preload.encoding=function() return {UTF8={decode=function(_,s) return s end}} end
    i.GetIO().Fonts={Clear=function() end,AddFontFromFileTTF=function() end,GetGlyphRangesCyrillic=function() return {} end}
    function i.OnInitialize(fn) initialize[#initialize+1]=fn end
    function i.OnFrame(cond,before,draw)
        local sub={Condition=cond,before=draw and before or nil,draw=draw or before,HideCursor=false,LockPlayer=false,active=true}
        function sub:Unsubscribe() self.active=false end
        subscriptions[#subscriptions+1]=sub; return sub
    end
    script_name=function() end; script_author=function() end; script_version=function() end; script_description=function() end
    getWorkingDirectory=function() return TEST_OUTPUT..'/client' end
    createDirectory=function(path) assert(U.exists(path..'/.directory-marker'),'Test directories must be prepared: '..path) end
    isSampAvailable=function() return true end
    sampRegisterChatCommand=function(name,fn) commands[name]=fn end
    sampAddChatMessage=function() end
    getGameTimer=function() return ticks end
    addEventHandler=function(name,fn) events[name]=fn end
    thisScript=function() return script end
    print=function(text) logs[#logs+1]=text end
    wait=function(ms) ticks=ticks+ms; coroutine.yield() end
    dofile('moonloader/arizona_pet.lua')
    for _,fn in ipairs(initialize) do fn() end
    local co=coroutine.create(main); local worked,err=coroutine.resume(co); assert(worked,err)
    for _,cmd in ipairs({'pet','petmini','petedit','pethide','petsave'}) do assert(commands[cmd]) end
    commands.pet(); assert(subscriptions[1].Condition())
    local function render()
        for _,sub in ipairs(subscriptions) do if sub.active and sub.Condition() then if sub.before then sub.before() end; sub.draw() end end
    end
    render(); assert(subscriptions[1].LockPlayer)
    commands.pet(); commands.petmini(); render()
    assert(subscriptions[2].Condition() and subscriptions[2].HideCursor and not subscriptions[2].LockPlayer)
    commands.petedit(); render(); assert(not subscriptions[2].HideCursor and subscriptions[2].LockPlayer)
    commands.pethide(); assert(not subscriptions[1].Condition() and not subscriptions[2].Condition())
    for j=1,310 do local ok,e=coroutine.resume(co); assert(ok,e) end
    assert(U.exists(TEST_OUTPUT..'/client/config/arizona_pet/default.json'))
    events.onD3DDeviceLost(); events.onD3DDeviceReset()
    commands.pet(); render(); assert(subscriptions[1].Condition())
    onScriptTerminate(script,false)
    assert(not subscriptions[1].active and not subscriptions[2].active)
    local state=Storage.new(TEST_OUTPUT..'/client/config/arizona_pet/default.json'):load(os.time())
    assert(state.needs.hunger<85) -- simulation ran while completely hidden
    print=oldprint; package.loaded.mimgui=nil
end}
