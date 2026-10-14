local U = require 'arizona_pet.core.util'
local M={}; M.__index=M
function M.new(kind,rng)
    local g=setmetatable({kind=kind,t=0,score=0,done=false,rng=rng or math.random,items={},spawn=0,
        basket=.5,misses=0,y=0,velocity=0,obstacles={},speed=.32,cards={},picked={},matches=0,moves=0},M)
    if kind=='pairs' then
        g.cards={1,1,2,2,3,3,4,4,5,5,6,6}
        for i=#g.cards,2,-1 do local j=g.rng(i); g.cards[i],g.cards[j]=g.cards[j],g.cards[i] end
    end
    return g
end
function M:flip(i)
    if self.done or self.kind~='pairs' or i<1 or i>#self.cards or #self.picked>=2 or self.cards[i]==0 then return false end
    if self.picked[1]==i then return false end
    self.picked[#self.picked+1]=i
    if #self.picked==2 then
        self.moves=self.moves+1
        if self.cards[self.picked[1]]==self.cards[self.picked[2]] then
            self.cards[self.picked[1]]=0; self.cards[self.picked[2]]=0
            self.picked={}; self.matches=self.matches+1
            if self.matches==6 then self.done=true; self.score=math.max(12,60-self.moves*2) end
        else self.unflip=self.t+.7 end
    end
    return true
end
function M:jump()
    if self.kind=='jump' and self.y==0 and not self.done then self.velocity=1.35 end
end
function M:step(dt)
    if self.done then return end
    self.t=self.t+dt
    if self.kind=='pairs' then
        if self.unflip and self.t>=self.unflip then self.picked={}; self.unflip=nil end
        if self.t>=180 then self.done=true; self.score=self.matches*4 end
    elseif self.kind=='catch' then
        self.spawn=self.spawn-dt
        if self.spawn<=0 then self.spawn=.7; self.items[#self.items+1]={x=.08+self.rng()*.84,y=-.08} end
        for i=#self.items,1,-1 do
            local item=self.items[i]; item.y=item.y+dt*.35
            if item.y>=.87 then
                if math.abs(item.x-self.basket)<.10 then self.score=self.score+2 else self.misses=self.misses+1 end
                table.remove(self.items,i)
            end
        end
        if self.t>=30 then self.done=true end
    elseif self.kind=='jump' then
        self.y=math.max(0,self.y+self.velocity*dt); self.velocity=self.velocity-3.2*dt
        if self.y==0 and self.velocity<0 then self.velocity=0 end
        self.spawn=self.spawn-dt
        if self.spawn<=0 then self.spawn=1.6+self.rng()*.6; self.obstacles[#self.obstacles+1]={x=1.1} end
        for i=#self.obstacles,1,-1 do
            local o=self.obstacles[i]; o.x=o.x-dt*self.speed
            if o.x<.29 and o.x>.16 and self.y<.13 then self.done=true end
            if o.x<0 then table.remove(self.obstacles,i); self.score=self.score+4 end
        end
        self.speed=.32+self.t*.002
        if self.t>=30 then self.done=true end
    end
end
function M:update(dt)
    dt=U.clamp(dt,0,.25)
    while dt>0 do local step=math.min(dt,1/120); self:step(step); dt=dt-step end
end
return M
