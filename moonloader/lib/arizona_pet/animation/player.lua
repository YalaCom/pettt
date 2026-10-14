local Default = require 'arizona_pet.animation.catalog'
local M={}; M.__index=M
function M.new(catalog) return setmetatable({catalog=catalog or Default,state='idle',time=0,blend=1,previous=nil},M) end
function M:play(state,force)
    if not self.catalog[state] then return false end
    local current=self.catalog[self.state]
    if not force and self.catalog[state].priority<current.priority then return false end
    if self.state==state then return true end
    self.previous=self:frame(); self.state=state; self.time=0; self.blend=0
    return true
end
function M:update(dt,speed)
    dt=math.max(0,dt)*(speed or 1)
    self.blend=math.min(1,self.blend+dt/.12)
    local clip=self.catalog[self.state]; local total=0
    for _,f in ipairs(clip.frames) do total=total+f[2] end
    self.time=self.time+dt
    if self.time>=total then
        if clip.loop then self.time=self.time%total
        else
            local excess=self.time-total
            self:play(clip.next or 'idle',true); self.time=excess
        end
    end
end
function M:frame()
    local clip=self.catalog[self.state]; local t=self.time
    for _,f in ipairs(clip.frames) do if t<f[2] then return f[1] end; t=t-f[2] end
    return clip.frames[#clip.frames][1]
end
return M
