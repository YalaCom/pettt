local State=require 'arizona_pet.core.state'
local Model=require 'arizona_pet.pet.model'
local Storage=require 'arizona_pet.core.storage'
local Player=require 'arizona_pet.animation.player'
local Games=require 'arizona_pet.pet.games'
local Integration=require 'arizona_pet.integration.game'
local G=require 'arizona_pet.ui.geometry'
local U=require 'arizona_pet.core.util'
local function timestamp(day,hour,min)
    return os.time{year=2026,month=10,day=day,hour=hour,min=min or 0,sec=0}
end
local now=timestamp(15,8)
local function fresh(t) return Model.new(State.new(t or now),t or now) end
local function near(a,b) assert(math.abs(a-b)<.0001,tostring(a)..' != '..tostring(b)) end
local tests={}
tests.night_offense_once=function()
    local exit=timestamp(14,23,30); local p=fresh(exit)
    p.s.memory.was_sleeping=false; p:resume(now)
    assert(p.message:find('спать')); assert(p:emotion()=='offended')
    assert(not p:action('pet')); p.now=now+6; assert(p:action('pet'))
    local count=#p.s.memory.history; p:resume(now+10); assert(#p.s.memory.history==count)
end
tests.bedtime_restores=function()
    local p=fresh(timestamp(14,23,30)); p.s.memory.was_sleeping=true; p.s.sleeping=true
    p:resume(now); assert(p:emotion()=='idle'); assert(p.s.needs.energy==100)
    assert(p.message:find('Спасибо'))
end
tests.short_restart_no_penalty=function()
    local p=fresh(timestamp(15,4,59)); p:resume(timestamp(15,5,2)); assert(p.offended_until==0)
end
tests.daytime_exit_no_night_penalty=function()
    local p=fresh(timestamp(14,18)); p:resume(now); assert(p.offended_until==0)
end
tests.after_midnight_exit=function()
    local p=fresh(timestamp(15,1)); p:resume(now); assert(p.offended_until>now)
end
tests.local_time_configuration=function()
    local p=fresh(timestamp(14,18)); p.s.settings.night_start=18; p:resume(now); assert(p.offended_until>now)
end
tests.backward_clock_safe=function()
    local p=fresh(now+86400); local before=U.copy(p.s.needs); p:resume(now)
    for k,v in pairs(before) do near(p.s.needs[k],v) end
    assert(p.offended_until==0)
end
tests.offline_penalty_cap=function()
    local a,b=fresh(now-6*3600),fresh(now-30*86400)
    a:resume(now); b:resume(now)
    for _,k in ipairs({'hunger','energy','clean','bond'}) do near(a.s.needs[k],b.s.needs[k]) end
    assert(b.message:find('заждался'))
end
tests.nonfatal_neglect=function()
    local p=fresh(); p.s.needs.hunger=0; p.s.needs.clean=0; p.s.needs.health=20
    for j=1,1000 do p:tick(10,now+j*10) end
    assert(p.s.needs.health>=20)
end
tests.sleep_blocks_care=function()
    local p=fresh(); assert(p:action('sleep')); local count=p.s.inventory.apple
    p.now=now+4; assert(not p:action('feed','apple')); assert(p.s.inventory.apple==count)
    assert(p:action('wake')); assert(not p.s.sleeping)
end
tests.sleep_restoration=function()
    local p=fresh(); p.s.needs.energy=20; p.s.sleeping=true
    for j=1,360 do p:tick(10,now+j*10) end
    near(p.s.needs.energy,42)
end
tests.food_consumption_and_memory=function()
    local p=fresh(); p.s.needs.hunger=20
    assert(p:action('feed','fish')); assert(p.s.inventory.fish==0); near(p.s.needs.hunger,55)
    assert(p.s.memory.last_feed==now); assert(p.s.memory.foods.fish==1)
    p.now=now+3; assert(not p:action('feed','fish'))
end
tests.food_refusal_no_charge=function()
    local p=fresh(); p.s.needs.hunger=100; assert(not p:action('feed','apple')); assert(p.s.inventory.apple==3)
end
tests.care_cooldown=function()
    local p=fresh(); assert(p:action('pet')); local xp=p.s.xp; assert(not p:action('pet')); assert(p.s.xp==xp)
end
tests.reconciliation=function()
    local p=fresh(); p.offended_until=now+120; p.refuse_until=now+5; p.now=now+6
    assert(p:action('pet')); assert(p.offended_until<now+120)
end
tests.shop_level_and_balance=function()
    local p=fresh(); assert(not p:buy('ball')); assert(p:buy('apple')); assert(p.s.coins==92)
    p.s.xp=80; assert(p:buy('ball')); assert(not p:buy('ball'))
    assert(not p:buy('unknown'))
    p.s.needs.mood=10; assert(p:action('play')); near(p.s.needs.mood,32); assert(p.s.xp==86)
end
tests.rewards_and_records=function()
    local p=fresh(); assert(p:reward('catch',30)==15); assert(p.s.records.catch==30)
    p:reward('catch',10); assert(p.s.records.catch==30)
end
tests.history_bounded=function()
    local p=fresh(); for j=1,100 do p:emit('event'..j,'Событие',0) end
    assert(#p.s.memory.history==60); assert(#p.events<=4)
end
tests.requests_throttled=function()
    local p=fresh(); p.s.needs.hunger=10
    for j=1,20 do p:tick(10,now+j*10) end
    assert(#p.s.memory.history==1)
end
tests.hidden_needs_continue=function()
    local p=fresh(); local old=p.s.needs.hunger; p:tick(10,now+10); assert(p.s.needs.hunger<old)
end
tests.player_priority_and_wake=function()
    local p=Player.new(); assert(p:play('sleep')); assert(not p:play('blink')); assert(p:frame()=='closed')
    assert(p:play('wake')); p:update(1.01); assert(p.state=='idle')
end
tests.animation_time_independent=function()
    for _,fps in ipairs({30,60,100}) do
        local p=Player.new(); p:play('blink')
        for j=1,math.floor(.12*fps) do p:update(1/fps) end
        assert(p:frame()=='closed')
        for j=1,fps do p:update(1/fps) end
        assert(p.state=='idle')
    end
end
tests.anger_resolves_to_offense=function()
    local p=Player.new(); p:play('furious'); p:update(1.6); assert(p.state=='offended')
end
tests.pairs_complete=function()
    local g=Games.new('pairs')
    for v=1,6 do
        local match={}; for i,c in ipairs(g.cards) do if c==v then match[#match+1]=i end end
        assert(g:flip(match[1])); assert(not g:flip(match[1])); assert(g:flip(match[2]))
    end
    assert(g.done and g.score==48 and g.matches==6)
end
tests.pairs_mismatch_and_timeout=function()
    local g=Games.new('pairs'); local a,b=1,2
    while g.cards[a]==g.cards[b] do b=b+1 end
    g:flip(a); g:flip(b); assert(#g.picked==2); assert(not g:flip(12))
    for j=1,4 do g:update(.25) end
    assert(#g.picked==0)
    for j=1,720 do g:update(.25) end; assert(g.done)
end
tests.catch_collision_and_duration=function()
    local g=Games.new('catch',function() return .5 end)
    for j=1,30*60+1 do g:update(1/60) end
    assert(g.done); assert(g.score>0); assert(#g.items<10)
end
tests.jump_collision=function()
    local g=Games.new('jump'); g.obstacles={{x=.24}}; g:update(.02); assert(g.done)
end
tests.jump_avoids_obstacle=function()
    local g=Games.new('jump'); g.y=.25; g.velocity=.2; g.obstacles={{x=.24}}
    g:update(.1); assert(not g.done)
end
tests.games_fps_independent=function()
    local score
    for _,fps in ipairs({30,60,100}) do
        local g=Games.new('catch',function() return .5 end)
        for j=1,31*fps do g:update(1/fps) end
        if score then assert(g.score==score) end; score=g.score
    end
end
tests.optional_integrations_absent=function()
    local p=fresh(); local a=Integration.new({PLAYER_PED=0},p,function() end)
    a:update(1); assert(#p.s.memory.history==0)
    assert(not a:confirmed_economy('income',10000,nil)); assert(not a:confirmed_economy('income',10,'verified adapter'))
end
tests.integration_edges_and_no_initial_death=function()
    local p=fresh(); local dead,car=false,false
    local api={PLAYER_PED=0,isCharDead=function() return dead end,isCharInAnyCar=function() return car end}
    local a=Integration.new(api,p,function() end); a:update(1); assert(#p.s.memory.history==0)
    dead=true; a:update(1); assert(p.s.memory.history[1].text:find('осторожнее'))
    a:update(1); assert(#p.s.memory.history==1)
    car=true; a:update(1); assert(#p.s.memory.history==2)
end
tests.integration_exception_disables=function()
    local calls=0; local p=fresh(); local a=Integration.new({PLAYER_PED=0,isCharDead=function() calls=calls+1; error('unavailable') end},p,function() end)
    a:update(1); a:update(1); assert(calls==1)
end
tests.integration_reactions_disabled=function()
    local p=fresh(); p.s.settings.reactions=false; p:game_event('death'); assert(#p.s.memory.history==0)
end
tests.afk_and_return=function()
    local p=fresh(); local a=Integration.new({},p,function() end)
    a:activity(false,301); assert(a.afk); a:activity(true,1); assert(not a.afk)
    assert(#p.s.memory.history==2)
end
tests.layout_resolutions=function()
    for _,wh in ipairs({{1920,1080},{1280,720},{800,600},{640,480}}) do
        local l=G.layout(wh[1],wh[2]); assert(l.x>=0 and l.y>=0 and l.x+l.w<=wh[1] and l.y+l.h<=wh[2])
        local r=G.mini(wh[1],wh[2],{mini_size=320,mini_x=1,mini_y=1}); assert(r.x+r.w<=wh[1] and r.y+r.h<=wh[2])
    end
end
tests.hit_zones=function()
    local r={x=100,y=100,w=512,h=512}
    assert(G.zone(346,315,r,'head')); assert(not G.zone(105,105,r,'head'))
    assert(G.zone(346,392,r,'mouth')); assert(not G.zone(346,180,r,'mouth'))
end
tests.validation_and_defaults=function()
    local s=State.new(now); s.needs.hunger=1000; s.coins=-1; s.settings.mini_x=90; s.settings.quality=2.7
    local r=assert(State.validate(s,now)); assert(r.needs.hunger==100 and r.coins==0 and r.settings.mini_x==1 and r.settings.quality==2)
    assert(not State.validate({},now)); assert(not State.validate({schema=999,needs={},memory={}},now))
end
tests.nan_and_infinity_sanitized=function()
    local s=State.new(now); s.needs.energy=0/0; s.xp=math.huge; local r=State.validate(s,now)
    assert(r.needs.energy==85 and r.xp==0)
end
tests.storage_roundtrip_and_backup=function()
    local path=TEST_OUTPUT..'/save.json'; os.remove(path); os.remove(path..'.bak')
    local store=Storage.new(path); local p=fresh(); p.s.name='Бублик'; assert(store:save(p.s,now))
    p.s.coins=999; assert(store:save(p.s,now+1))
    local loaded=store:load(now+2); assert(loaded.coins==999 and loaded.name=='Бублик')
    local f=assert(io.open(path,'wb')); f:write('{ broken'); f:close()
    local recovered,warning=store:load(now+3); assert(recovered.coins==100 and warning)
    assert(store:save(recovered,now+3)); assert(U.exists(path..'.corrupt-'..(now+3)))
    assert(store:load(now+4).coins==100)
end
tests.storage_error_preserves_primary=function()
    local path=TEST_OUTPUT..'/safe.json'; local store=Storage.new(path); local p=fresh()
    assert(store:save(p.s,now)); local original=assert(io.open(path,'rb')); local data=original:read('*a'); original:close()
    local oldrename=os.rename; os.rename=function() return nil,'simulated Windows rename failure' end
    p.s.coins=200; local worked=store:save(p.s,now+1); os.rename=oldrename
    assert(not worked); local f=assert(io.open(path,'rb')); assert(f:read('*a')==data); f:close()
end
tests.sleep_and_memory_saved=function()
    local store=Storage.new(TEST_OUTPUT..'/sleep.json'); local p=fresh(timestamp(14,23,30)); p:action('sleep')
    assert(store:save(p.s,p.now)); local loaded=store:load(now); local q=Model.new(loaded,now); q:resume(now)
    assert(q.message:find('Спасибо')); assert(not q.s.sleeping)
end
tests.backup_restored_when_primary_missing=function()
    local store=Storage.new(TEST_OUTPUT..'/missing.json'); local p=fresh(); assert(store:save(p.s,now)); assert(store:save(p.s,now+1))
    os.remove(store.path); local state,warning=store:load(now+2); assert(state.coins==100 and warning)
end
return tests
