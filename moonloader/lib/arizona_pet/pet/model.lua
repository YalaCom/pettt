local C = require 'arizona_pet.core.config'
local U = require 'arizona_pet.core.util'
local M = {}; M.__index=M
function M.new(state, now)
    return setmetatable({s=state,now=now,session=0,events={},message='Привет! Я Бублик. Давай дружить.',
        message_until=now+12,offended_until=0,refuse_until=0,action_until=0,decision=0},M)
end
function M:level() return math.floor(math.sqrt(self.s.xp / 80)) + 1 end
function M:xp(n) self.s.xp=U.clamp(self.s.xp+n,0,1e9) end
function M:change(k,v) self.s.needs[k]=U.clamp(self.s.needs[k]+v,0,100) end
function M:emit(id, text, cooldown, animation)
    local last=self.s.memory.cooldowns[id] or 0
    if last>self.now then last=self.now-(cooldown or 0) end -- clock moved back
    if self.now-last < (cooldown or 0) then return false end
    self.s.memory.cooldowns[id]=self.now
    self.message=text; self.message_until=self.now+12
    local h=self.s.memory.history
    h[#h+1]={time=self.now,text=text}
    while #h>C.history_limit do table.remove(h,1) end
    self.events[#self.events+1]={id=id,animation=animation or id}
    while #self.events>4 do table.remove(self.events,1) end
    return true
end
function M:resume(now)
    local s,m=self.s,self.s.memory
    local departure=m.last_seen
    local elapsed=math.max(0,now-departure)
    self.now=now
    local h=math.min(elapsed,C.offline_cap)/3600
    self:change('hunger',-h*5); self:change('clean',-h*3)
    self:change('energy',m.was_sleeping and h*12 or -h*5)
    self:change('mood',-math.min(h*3,18)); self:change('bond',-math.min(h*.3,2))
    -- Never kill or make recovery expensive after absence.
    s.needs.hunger=math.max(10,s.needs.hunger); s.needs.energy=math.max(15,s.needs.energy)
    s.needs.clean=math.max(15,s.needs.clean); s.needs.health=math.max(25,s.needs.health)
    s.needs.mood=math.max(20,s.needs.mood)
    local hour=tonumber(os.date('%H',now)); local exitHour=tonumber(os.date('%H',departure))
    local o=s.settings
    if elapsed>=C.no_restart_penalty and U.inHours(exitHour,o.night_start,o.night_end)
        and U.inHours(hour,o.morning_start,o.morning_end)
        and (U.day(now)~=U.day(departure) or exitHour<o.night_end)
        and m.consumed_departure~=departure then
        m.consumed_departure=departure
        if m.was_sleeping then
            s.sleeping=false; self:change('energy',20); self:change('mood',8)
            self:emit('rested','Доброе утро! Спасибо, что уложил меня спать.',0,'stretch')
        else
            s.sleeping=false; self:change('mood',-8)
            self.offended_until=now+120; self.refuse_until=now+5
            self:emit('night_offense','Ты вчера даже спать меня не уложил!',0,'offended')
        end
    elseif elapsed>=C.long_absence then
        s.sleeping=false
        self:emit('return','Ты где пропадал?! Я тебя уже заждался!',0,'welcome')
    end
    m.last_seen=now
    if now<m.last_care then m.last_care=now end
    return elapsed
end
function M:care(kind)
    local m=self.s.memory
    m.last_care=self.now; m.care_count=m.care_count+1; m.ignored=0
    self:change('bond',1.2); self:change('mood',4)
    self.offended_until=math.max(self.now,self.offended_until-45)
    self:xp(4)
    if m.care_count>=25 then self.s.achievements.friend=true end
end
function M:action(kind, arg)
    local s,m=self.s,self.s.memory
    if self.now<self.action_until then return false,'Подожди немного.' end
    if s.sleeping and kind~='wake' then return false,'Бублик спит. Сначала аккуратно разбуди его.' end
    if kind=='pet' and self.now<self.refuse_until then return false,'Дай мне пару секунд, я ещё обижаюсь.' end
    if kind=='feed' then
        local item=C.items[arg]
        if not item or not item.hunger or (s.inventory[arg] or 0)<1 then return false,'Нет этой еды в холодильнике.' end
        if s.needs.hunger>=98 then
            self:emit('food_refusal','Я уже сыт! Оставим на потом?',15,'refuse_food')
            return false,'Бублик уже сыт.'
        end
        s.inventory[arg]=s.inventory[arg]-1
        self:change('hunger',item.hunger); self:change('health',item.health or 0); self:change('mood',item.mood or 0)
        m.last_feed=self.now; m.foods[arg]=(m.foods[arg] or 0)+1
        if m.foods[arg]>=3 then self:change('mood',3) end
        self:care(kind); self:emit('feed','М-м-м! '..item.label..' — вкусно!',0,'eat')
    elseif kind=='pet' then
        m.last_pet=self.now; s.traits.affection=math.min(100,s.traits.affection+.5)
        self:care(kind); self:emit('pet','Мур-р! Как же хорошо рядом с тобой.',0,'pet')
    elseif kind=='sleep' then
        s.sleeping=true; m.last_sleep=self.now; m.sleep_count=m.sleep_count+1
        s.traits.sleepy=math.min(100,s.traits.sleepy+.3)
        self:care(kind); self:emit('sleep','Спокойной ночи. Не забудь выключить свет.',0,'sleep')
        if m.sleep_count>=7 then s.achievements.sleepy=true end
    elseif kind=='wake' then
        s.sleeping=false; self:emit('wake','Я проснулся! Чем займёмся?',0,'wake')
    elseif kind=='wash' then
        self:change('clean',65); self:care(kind); self:emit('wash','Теперь я снова пушистый и чистый!',0,'wash')
    elseif kind=='play' then
        if s.needs.energy<15 then return false,'Сначала нужно отдохнуть.' end
        m.play_count=m.play_count+1; self:change('energy',-7); self:change('mood',12)
        s.traits.playful=math.min(100,s.traits.playful+.5)
        self:care(kind); self:emit('play','Лови! Давай ещё раз!',0,'play')
        if (s.inventory.ball or 0)>0 then self:change('mood',6); self:xp(2) end
    else return false,'Неизвестное действие' end
    self.action_until=self.now+(kind=='pet' and 3 or 2)
    return true
end
function M:buy(id)
    local item=C.items[id]
    if not item then return false,'Неизвестный предмет' end
    if self:level()<(item.level or 1) then return false,'Предмет откроется на уровне '..item.level end
    if not item.hunger and (self.s.inventory[id] or 0)>0 then return false,'Уже куплено' end
    if self.s.coins<item.cost then return false,'Нужно больше монет питомца.' end
    self.s.coins=self.s.coins-item.cost
    self.s.inventory[id]=math.min(9999,(self.s.inventory[id] or 0)+1)
    return true
end
function M:reward(game,score)
    score=math.floor(U.number(score,0,0,10000))
    self.s.records[game]=math.max(self.s.records[game] or 0,score)
    local coins=math.min(40,math.floor(score/2))
    self.s.coins=U.clamp(self.s.coins+coins,0,1e9)
    self:xp(math.min(30,score)); self:change('mood',8)
    self.s.memory.play_count=self.s.memory.play_count+1
    if score>=20 then self.s.achievements.player=true end
    return coins
end
function M:game_event(id,value)
    if not self.s.settings.reactions then return end
    if id=='income' then self:emit(id,'Ух ты, хороший заработок! Мечтаю о новой игрушке.',120,'celebrate')
    elseif id=='loss' then self:emit(id,'Эх, а я уже новую игрушку присмотрел...',120,'sad')
    elseif id=='death' then self:emit(id,'Ты там осторожнее, я переживаю!',60,'scared')
    elseif id=='afk' then self:emit(id,'Я пока поиграю с хвостом. Возвращайся!',600,'bored')
    elseif id=='active' then self:emit(id,'О, ты снова здесь!',120,'welcome')
    elseif id=='vehicle' then self:emit(id,'Поехали! Я буду смотреть в окошко.',900,'look')
    elseif id=='game_night' then self:emit(id,'В игре уже ночь. Может, заглянем в спальню?',1800,'yawn') end
end
function M:tick(dt,now)
    dt=U.clamp(dt,0,10); self.now=now; self.session=self.session+dt
    local n=self.s.needs
    local h=dt/3600
    self:change('hunger',-h*6); self:change('clean',-h*4)
    self:change('energy',h*(self.s.sleeping and 22 or -8))
    self:change('mood',-h*(n.hunger<20 and 6 or 2))
    self:change('health',h*((n.hunger<10 or n.clean<10) and -3 or 1))
    n.health=math.max(20,n.health)
    self.decision=self.decision+dt
    if self.decision<30 then return end
    self.decision=0
    if self.s.sleeping then return end
    local gap=math.max(0,now-self.s.memory.last_care)
    if n.hunger<25 then self:emit('hungry','Живот урчит. Найдётся что-нибудь в холодильнике?',self.s.settings.notifications,'beg_food')
    elseif n.energy<25 then self:emit('tired','Я уже сонный. Уложишь меня в спальне?',self.s.settings.notifications,'yawn')
    elseif gap>7200 then
        local interval=math.max(self.s.settings.notifications,math.min(7200,1800*(1+self.s.memory.ignored)))
        if self:emit('attention','Я тут! Может, погладишь меня?',interval,'offended') then
            self.s.memory.ignored=math.min(10,self.s.memory.ignored+1)
            self:change('mood',-2)
            if self.s.memory.ignored>=3 then self.offended_until=now+60 end
        end
    elseif self.session>7200 then self:emit('long_session','Мы уже столько играем. Может, отдохнём?',7200,'yawn')
    elseif self.s.traits.affection>65 and n.bond>60 then
        if self:emit('gift','Нашёл для тебя монетку. Ты мой лучший друг!',86400,'happy') then self.s.coins=self.s.coins+3 end
    elseif math.random()<.15 then self:emit('curious','Интересно, что мы будем делать дальше?',600,'look') end
end
function M:emotion()
    if self.s.sleeping then return 'sleep' end
    if self.now<self.offended_until then return 'offended' end
    if self.s.needs.energy<25 then return 'sleepy' end
    if self.s.needs.hunger<25 then return 'hungry' end
    if self.s.needs.mood<30 then return 'sad' end
    return 'idle'
end
return M
