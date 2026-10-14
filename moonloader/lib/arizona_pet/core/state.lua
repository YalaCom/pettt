local U = require 'arizona_pet.core.util'
local C = require 'arizona_pet.core.config'
local M = {}
function M.new(now)
    return {
        schema=C.schema, name='Бублик', xp=0, coins=100,
        needs={hunger=85,energy=85,clean=90,mood=85,health=100,bond=30},
        traits={affection=50,playful=50,stubborn=25,sleepy=40,curious=60},
        sleeping=false, emotion='idle', inventory={apple=3,cookie=1,fish=1},
        achievements={}, records={}, equipped={},
        memory={last_seen=now,last_care=now,last_feed=0,last_pet=0,last_sleep=0,
            foods={},history={},cooldowns={},ignored=0,care_count=0,sleep_count=0,play_count=0},
        settings={mini=false,mini_x=.83,mini_y=.65,mini_size=170,quality=2,
            animation_speed=1,volume=.4,sound=true,reactions=true,notifications=900,
            night_start=21,night_end=5,morning_start=5,morning_end=12},
    }
end
function M.validate(s, now)
    if type(s) ~= 'table' or s.schema ~= C.schema or type(s.needs) ~= 'table' or type(s.memory) ~= 'table' then
        return nil, 'Несовместимое или повреждённое сохранение'
    end
    local r = M.new(now)
    if type(s.name)=='string' and #s.name > 0 and #s.name<=96 and not s.name:find('[%z\1-\31]') then r.name=s.name end
    r.xp = math.floor(U.number(s.xp, 0, 0, 1e9)); r.coins=math.floor(U.number(s.coins,100,0,1e9))
    r.sleeping=s.sleeping == true
    for k,v in pairs(r.needs) do r.needs[k]=U.number(s.needs[k],v,0,100) end
    for k,v in pairs(r.traits) do r.traits[k]=U.number(type(s.traits)=='table' and s.traits[k],v,0,100) end
    for k in pairs(C.items) do
        r.inventory[k]=math.floor(U.number(type(s.inventory)=='table' and s.inventory[k], r.inventory[k] or 0, 0, 9999))
    end
    for _,group in ipairs({'records','achievements','equipped'}) do
        if type(s[group])=='table' then
            for k,v in pairs(s[group]) do
                if type(k)=='string' and #k<40 and (type(v)=='boolean' or type(v)=='number' or type(v)=='string') then
                    r[group][k]=type(v)=='number' and U.number(v,0,0,1e9) or v
                end
            end
        end
    end
    local sm=s.memory
    for _,k in ipairs({'last_seen','last_care','last_feed','last_pet','last_sleep','ignored','care_count','sleep_count','play_count','consumed_departure'}) do
        r.memory[k]=U.number(sm[k],r.memory[k] or 0,0,1e11)
    end
    r.memory.was_sleeping=sm.was_sleeping==true
    r.memory.was_hungry=sm.was_hungry==true
    for k in pairs(C.items) do r.memory.foods[k]=math.floor(U.number(type(sm.foods)=='table' and sm.foods[k],0,0,1e6)) end
    if type(sm.history)=='table' then
        for i=math.max(1,#sm.history-C.history_limit+1),math.min(#sm.history,10000) do
            local e=sm.history[i]
            if type(e)=='table' and type(e.text)=='string' and #e.text<512 then
                r.memory.history[#r.memory.history+1]={time=U.number(e.time,now,0,1e11),text=e.text}
            end
        end
    end
    if type(sm.cooldowns)=='table' then
        for k,v in pairs(sm.cooldowns) do if type(k)=='string' and #k<48 then r.memory.cooldowns[k]=U.number(v,0,0,1e11) end end
    end
    if type(s.settings)=='table' then
        for k,v in pairs(r.settings) do
            if type(v)=='boolean' then r.settings[k]=s.settings[k]==true
            else
                local ranges={mini_x={0,1},mini_y={0,1},mini_size={80,320},quality={1,3},animation_speed={.5,2},volume={0,1},notifications={60,3600},
                    night_start={0,23},night_end={0,23},morning_start={0,23},morning_end={0,23}}
                r.settings[k]=U.number(s.settings[k],v,unpack(ranges[k]))
                if k=='quality' or k:find('start') or k:find('end') then r.settings[k]=math.floor(r.settings[k]) end
            end
        end
    end
    return r
end
return M
