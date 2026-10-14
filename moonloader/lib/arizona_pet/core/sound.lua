local U=require 'arizona_pet.core.util'
local M={}; M.__index=M
function M.new(api,root) return setmetatable({api=api,root=root,cache={},missing={}},M) end
function M:play(name,settings)
    local a=self.api
    if not settings.sound or settings.volume<=0 then return end
    if type(a.loadAudioStream)~='function' or type(a.setAudioStreamState)~='function' then return end
    if self.missing[name] then return end
    local stream=self.cache[name]
    if not stream then
        local path=self.root..'/sounds/'..name..'.wav'
        if not U.exists(path) then self.missing[name]=true; return end
        local ok,result=pcall(a.loadAudioStream,path)
        if not ok or not result or result==0 then self.missing[name]=true; return end
        stream=result; self.cache[name]=stream
    end
    if type(a.setAudioStreamVolume)=='function' then pcall(a.setAudioStreamVolume,stream,settings.volume) end
    pcall(a.setAudioStreamState,stream,0)
    pcall(a.setAudioStreamState,stream,1)
end
function M:clear()
    if type(self.api.releaseAudioStream)=='function' then for _,s in pairs(self.cache) do pcall(self.api.releaseAudioStream,s) end end
    self.cache={}
end
return M
