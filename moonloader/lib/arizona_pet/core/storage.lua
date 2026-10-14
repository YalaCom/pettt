local JSON = require 'arizona_pet.vendor.json'
local State = require 'arizona_pet.core.state'
local U = require 'arizona_pet.core.util'
local M = {}; M.__index = M
function M.new(path) return setmetatable({path=path},M) end
function M:read(path, now)
    local f=io.open(path,'rb'); if not f then return nil,'Файл не найден' end
    local data=f:read(1024*1024+1); f:close()
    if #data>1024*1024 then return nil,'Сохранение слишком большое' end
    local ok,decoded=pcall(JSON.decode,data)
    if not ok then return nil,'Ошибка JSON' end
    return State.validate(decoded,now)
end
function M:load(now)
    local s,err=self:read(self.path,now)
    if s then return s end
    local bak=self:read(self.path..'.bak',now)
    if bak then return bak,'Восстановлено из резервной копии: '..err end
    if U.exists(self.path) then return State.new(now),'Сохранение повреждено; оригинал оставлен на диске' end
    return State.new(now)
end
function M:save(state, now)
    local snapshot=U.copy(state)
    snapshot.memory.last_seen=now
    snapshot.memory.was_sleeping=state.sleeping
    snapshot.memory.was_hungry=state.needs.hunger<25
    local ok,data=pcall(JSON.encode,snapshot); if not ok then return nil,'Ошибка кодирования JSON' end
    local temp=self.path..'.tmp'
    local f,err=io.open(temp,'wb'); if not f then return nil,err end
    local wrote,werr=f:write(data); local closed,cerr=f:close()
    if not wrote or not closed then return nil,werr or cerr end
    if not self:read(temp,now) then return nil,'Проверка временного файла не пройдена' end
    -- Windows rename cannot replace an existing file. Keep one valid backup.
    if U.exists(self.path) then
        if self:read(self.path,now) then
            if U.exists(self.path..'.bak') then
                local removed,rerr=os.remove(self.path..'.bak'); if not removed then return nil,rerr end
            end
            local moved,merr=os.rename(self.path,self.path..'.bak'); if not moved then return nil,merr end
        else
            local corrupt=self.path..'.corrupt-'..tostring(now)
            if U.exists(corrupt) then return nil,'Архив повреждённого сохранения уже существует' end
            local moved,merr=os.rename(self.path,corrupt); if not moved then return nil,merr end
        end
    end
    local moved,merr=os.rename(temp,self.path)
    if not moved then
        if not U.exists(self.path) and U.exists(self.path..'.bak') then os.rename(self.path..'.bak',self.path) end
        return nil,merr
    end
    state.memory.last_seen=now
    state.memory.was_sleeping=state.sleeping
    state.memory.was_hungry=state.needs.hunger<25
    return true
end
return M
