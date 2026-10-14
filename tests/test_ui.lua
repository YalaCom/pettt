local State=require 'arizona_pet.core.state'
local Model=require 'arizona_pet.pet.model'
local Player=require 'arizona_pet.animation.player'
local Textures=require 'arizona_pet.animation.textures'
local View=require 'arizona_pet.ui.view'
local Games=require 'arizona_pet.pet.games'
local JSON=require 'arizona_pet.vendor.json'
local Mock=dofile('tests/imgui_mock.lua')
local function setup(w,h)
    local i=Mock.new(w or 1920,h or 1080)
    local model=Model.new(State.new(os.time()),os.time())
    local t=Textures.new(i,'moonloader/resource/arizona_pet',function(s) error(s) end)
    local saves=0
    local v=View.new(i,model,Player.new(),t,function() saves=saves+1 end)
    return v,i,model,t,function() return saves end
end
local tests={}
tests.ui_draw_all_rooms_and_menus=function()
    for _,res in ipairs({{1920,1080},{1280,720},{800,600},{640,480}}) do
        local v,i,model=setup(res[1],res[2])
        for j=1,5 do
            v.room=j; v:main(); assert(i.styles==0 and i.colors==0)
        end
        for _,menu in ipairs({'shop','settings','journal'}) do v.menu=menu; v:main(); assert(i.styles==0 and i.colors==0) end
        for _,kind in ipairs({'catch','pairs','jump'}) do v.menu='game'; v.game=Games.new(kind); v:main() end
        for _,c in ipairs(i.commands) do
            assert(c.x>=0 and c.y>=0,'negative draw coordinate')
            if c.kind~='text' then assert(c.x+c.w<=res[1]+1 and c.y+c.h<=res[2]+1,'UI clipped at screen edge') end
        end
    end
end
tests.overlay_input_flags_and_position=function()
    local v,i=setup(); v:mini(); assert(i.flags>=128); assert(i.styles==0)
    v.edit=true; v:mini(); assert(i.flags<128)
    local st=v.model.s.settings
    i.click='minidrag'; i.down=true; i.mouse={x=1650,y=800}; v:mini()
    i.click=nil; i.mouse={x=1550,y=700}; i.GetIO().MouseDelta={x=-100,y=-100}; v:mini()
    i.down=false; v:mini(); assert(st.mini_x<.83 and st.mini_y<.65)
end
tests.texture_cached_and_release_once=function()
    local v,i,p,t=setup(); v:main(); local initial=0; for _ in pairs(i.textures) do initial=initial+1 end
    v:main(); local later=0; for _ in pairs(i.textures) do later=later+1 end; assert(initial==later)
    t:clear(); assert(next(i.textures)==nil)
end
tests.ui_room_and_close_buttons=function()
    local v,i,model,t,count=setup(); v.open=true; i.click='roomkitchen'; v:main(); assert(v.room==2)
    i.click='close'; v:main(); assert(not v.open and count()>0)
end
tests.ui_shop_purchases=function()
    local v,i,model=setup(); v.menu='shop'; i.click='buyapple'; v:main(); assert(model.s.coins==92)
end
tests.ui_food_drop_requires_mouth=function()
    local v,i,model=setup(); model.s.needs.hunger=10; v.room=2; v.drag_food='apple'
    i.mouse={x=0,y=0}; i.down=false; v:main(); assert(model.s.inventory.apple==3)
    v.drag_food='apple'; v:main()
    local G=require 'arizona_pet.ui.geometry'; local l=G.layout(1920,1080); local s=l.scale
    local rx,ry,rw=l.x+265*s,l.y+147*s,709*s
    local r={x=rx+(rw-340*s)/2,y=ry+55*s,w=340*s,h=340*s}
    v.drag_food='apple'; i.mouse={x=r.x+r.w*.48,y=r.y+r.h*.57}; v:main()
    assert(model.s.inventory.apple==2)
end
tests.ui_bath_requires_three_steps=function()
    local v,i,model=setup(); v.room=4; model.s.needs.clean=20; i.click='bath'
    v:main(); assert(v.wash_step==1 and model.s.needs.clean==20)
    i.clicked={}; v:main(); assert(v.wash_step==2 and model.s.needs.clean==20)
    i.clicked={}; v:main(); assert(v.wash_step==0 and model.s.needs.clean==85)
end
tests.ui_minigame_reward_once=function()
    local v,i,model=setup(); v.menu='game'; v.game=Games.new('catch'); v.game.done=true; v.game.score=20
    v:update(.1); local coins=model.s.coins; v:update(.1); assert(model.s.coins==coins and coins==110)
end
tests.save_offscreen_draw_commands=function()
    local v,i=setup(1280,900); v:main()
    local f=assert(io.open(TEST_OUTPUT..'/ui-draw.json','wb')); f:write(JSON.encode(i.commands)); f:close()
end
return tests
