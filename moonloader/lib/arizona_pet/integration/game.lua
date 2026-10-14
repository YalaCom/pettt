-- Read-only optional MoonLoader/GTA functions. No packet hooks or input injection.
local M={}; M.__index=M
function M.new(api,model,diagnostic)
    return setmetatable({api=api,model=model,diagnostic=diagnostic,failed={},capabilities={},idle=0,afk=false},M)
end
function M:call(name,...)
    if type(self.api[name])~='function' then self.capabilities[name]=false; return nil end
    if self.failed[name] then return nil end
    local result={pcall(self.api[name],...)}
    if not result[1] then
        self.failed[name]=true; self.capabilities[name]=false
        self.diagnostic('Отключена интеграция '..name..': '..tostring(result[2]))
        return nil
    end
    self.capabilities[name]=true
    return unpack(result,2)
end
function M:confirmed_economy(kind,amount,source)
    -- Only a caller with a validated server-specific event may use this hook.
    -- Balance deltas do not establish earnings: deliberately not polled here.
    if (kind~='income' and kind~='loss') or type(amount)~='number' or amount<10000 or type(source)~='string' then return false end
    self.model:game_event(kind,amount); return true
end
function M:update(dt)
    local ped=self.api.PLAYER_PED
    if ped==nil then return end
    local dead=self:call('isCharDead',ped)
    if dead==true and self.dead==false then self.model:game_event('death') end
    if dead~=nil then self.dead=dead end
    local vehicle=self:call('isCharInAnyCar',ped)
    if vehicle==true and self.vehicle==false then self.model:game_event('vehicle') end
    if vehicle~=nil then self.vehicle=vehicle end
    local hour=self:call('getTimeOfDay')
    if type(hour)=='number' and hour>=21 and self.hour and self.hour<21 then self.model:game_event('game_night') end
    self.hour=hour
    local x,y,z=self:call('getCharCoordinates',ped)
    local active=false
    if type(x)=='number' and type(y)=='number' and type(z)=='number' then
        if self.pos then active=(x-self.pos[1])^2+(y-self.pos[2])^2+(z-self.pos[3])^2>.01 end
        self.pos={x,y,z}
    end
    if type(self.api.isKeyDown)=='function' then
        for _,key in ipairs({1,2,13,16,17,32,65,68,83,87,37,38,39,40}) do
            if self:call('isKeyDown',key)==true then active=true; break end
        end
    end
    self:activity(active,dt)
end
function M:activity(active,dt)
    if active then
        self.idle=0
        if self.afk then self.afk=false; self.model:game_event('active') end
    else
        self.idle=self.idle+dt
        if self.idle>300 and not self.afk then self.afk=true; self.model:game_event('afk') end
    end
end
return M
