local U=require 'arizona_pet.core.util'
local M={}; M.__index=M
function M.new(imgui,root,diagnostic)
    return setmetatable({imgui=imgui,root=root,cache={},failed={},clock=0,max=16,diagnostic=diagnostic},M)
end
function M:get(relative)
    if type(relative)~='string' or relative:find('..',1,true) then return nil end
    self.clock=self.clock+1
    local hit=self.cache[relative]
    if hit then hit.used=self.clock; return hit.texture end
    if self.failed[relative] then return nil end
    local path=self.root..'/'..relative
    local ok,texture=false,nil
    if U.exists(path) then ok,texture=pcall(self.imgui.CreateTextureFromFile,path) end
    if not ok or texture==nil then
        self.failed[relative]=true
        self.diagnostic('Не загружена текстура: '..relative)
        return nil
    end
    -- Eviction only between frames: never free a texture referenced by this frame's draw list.
    self.cache[relative]={texture=texture,used=self.clock}
    return texture
end
function M:trim()
    local count=0; for _ in pairs(self.cache) do count=count+1 end
    while count>self.max do
        local oldest,key=math.huge,nil
        for k,v in pairs(self.cache) do if v.used<oldest then oldest,key=v.used,k end end
        local v=self.cache[key]; self.imgui.ReleaseTexture(v.texture); self.cache[key]=nil; count=count-1
    end
end
function M:clear()
    for _,v in pairs(self.cache) do pcall(self.imgui.ReleaseTexture,v.texture) end
    self.cache={}; self.failed={}
end
return M
