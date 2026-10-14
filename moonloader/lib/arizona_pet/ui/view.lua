local C=require 'arizona_pet.core.config'
local U=require 'arizona_pet.core.util'
local G=require 'arizona_pet.ui.geometry'
local Frames=require 'arizona_pet.animation.frames'
local Games=require 'arizona_pet.pet.games'
local M={}; M.__index=M
local rooms={{'living','Гостиная'},{'kitchen','Кухня'},{'bedroom','Спальня'},{'bathroom','Ванная'},{'playroom','Игровая'}}
local color={ink={.08,.22,.23,1},muted={.35,.48,.46,1},green={.10,.65,.49,1},gold={.94,.69,.25,1},white={1,1,1,1}}
function M.new(imgui,model,player,textures,save)
    return setmetatable({i=imgui,model=model,player=player,tex=textures,save=save,open=false,edit=false,room=1,
        menu=nil,elapsed=0,blink=0,toast='',toast_until=0,wash_step=0,light=true},M)
end
function M:rgba(c,alpha)
    return self.i.ColorConvertFloat4ToU32(self.i.ImVec4(c[1],c[2],c[3],(c[4] or 1)*(alpha or 1)))
end
function M:v(x,y) return self.i.ImVec2(x,y) end
function M:text(x,y,str,ink,size)
    self.draw:AddTextFontPtr(self.i.GetFont(),(size or 16)*self.s,self:v(x,y),self:rgba(ink or color.ink),str)
end
function M:rect(x,y,w,h,c,round)
    self.draw:AddRectFilled(self:v(x,y),self:v(x+w,y+h),self:rgba(c),round or 12*self.s)
end
function M:image(file,x,y,w,h,alpha)
    local texture=self.tex:get(file)
    if texture then self.draw:AddImage(texture,self:v(x,y),self:v(x+w,y+h),self:v(0,0),self:v(1,1),self:rgba(color.white,alpha)) end
end
function M:button(id,label,x,y,w,h,active)
    local i=self.i
    i.SetCursorScreenPos(self:v(x,y)); i.InvisibleButton(id,self:v(w,h))
    self:image(active and 'ui/active.png' or 'ui/button.png',x,y,w,h)
    if i.IsItemHovered() then self:rect(x,y,w,h,{.15,.8,.63,.12},12*self.s) end
    local textSize=i.CalcTextSize(label)
    self:text(x+(w-textSize.x)/2,y+(h-18*self.s)/2,label,nil,16)
    return i.IsItemClicked(0)
end
function M:notify(text)
    self.toast=text or ''; self.toast_until=self.model.now+5
end
function M:action(kind,arg)
    local ok,err=self.model:action(kind,arg)
    if ok then self.effect={kind=kind,time=self.elapsed}; self.save() else self:notify(err) end
    return ok
end
function M:update(dt)
    self.elapsed=self.elapsed+dt; self.blink=self.blink+dt
    if self.menu~='game' then self.game=nil end
    if self.game then
        self.game:update(dt)
        if self.game.done and not self.game.rewarded then
            self.game.rewarded=true
            self.game.coins=self.model:reward(self.game.kind,self.game.score); self.save()
        end
    end
    local emotion=self.model:emotion()
    if emotion=='sleep' and self.player.state~='sleep' then self.player:play('sleep',true)
    elseif emotion~='sleep' and self.player.state=='sleep' then self.player:play('wake',true)
    elseif emotion~='offended' and self.player.state=='offended' then self.player:play('idle',true)
    elseif self.player.state=='idle' and self.blink>4.8 then self.player:play('blink'); self.blink=0
    elseif self.player.state=='idle' and emotion~='idle' then self.player:play(emotion) end
    self.player:update(dt,self.model.s.settings.animation_speed)
end
function M:pet(r)
    local f=Frames.frames[self.player:frame()] or Frames.frames.open
    local tex=self.tex:get('pet/atlas.png'); if not tex then return end
    local ax,ay=Frames.atlas[1],Frames.atlas[2]
    local breath=self.model.s.settings.quality>1 and math.sin(self.elapsed*2)*.0035 or 0
    local h=r.h*(1+breath)
    local anchorY=Frames.anchor[2]/Frames.height
    local y=r.y+r.h*anchorY-h*anchorY -- fixed authored paws anchor, not alpha bbox
    local function frame(id,alpha)
        local q=Frames.frames[id] or f
        self.draw:AddImage(tex,self:v(r.x,y),self:v(r.x+r.w,y+h),self:v((q[1]+.5)/ax,(q[2]+.5)/ay),
            self:v((q[1]+q[3]-.5)/ax,(q[2]+q[4]-.5)/ay),self:rgba(color.white,alpha))
    end
    if self.player.previous and self.player.blend<1 and self.model.s.settings.quality>1 then
        frame(self.player.previous,1-self.player.blend)
    end
    frame(self.player:frame(),self.player.blend)
    if self.model.s.equipped.ribbon and (self.model.s.inventory.ribbon or 0)>0 then
        self:image('ui/heart.png',r.x+r.w*.46,r.y+r.h*.67,r.w*.07,r.h*.07)
    end
end
function M:interact(r)
    local i=self.i; local p=i.GetMousePos()
    if not self.drag_food and i.IsMouseDown(0) and G.zone(p.x,p.y,r,'head') then
        if self.last_mouse and math.abs(p.x-self.last_mouse.x)+math.abs(p.y-self.last_mouse.y)>2*self.s then self:action('pet') end
    end
    self.last_mouse={x=p.x,y=p.y}
    if self.drag_food then
        self:image('ui/food.png',p.x-20*self.s,p.y-20*self.s,40*self.s,40*self.s)
        if not i.IsMouseDown(0) then
            if G.zone(p.x,p.y,r,'mouth') then self:action('feed',self.drag_food) else self:notify('Поднеси еду ко рту Бублика.') end
            self.drag_food=nil
        end
    end
end
function M:stats(x,y)
    local s=self.s; local needs=self.model.s.needs
    for j,k in ipairs(C.needs) do
        local row=y+(j-1)*49*s
        self:image('ui/'..({'food','sleep','wash','heart','heart','heart'})[j]..'.png',x,row-2*s,18*s,18*s)
        self:text(x+24*s,row,C.labels[k],color.muted,14)
        self:text(x+164*s,row,tostring(math.floor(needs[k]))..'%',color.ink,14)
        self:rect(x,row+24*s,200*s,7*s,{.83,.89,.86,1},4*s)
        self:rect(x,row+24*s,200*s*math.max(.01,needs[k]/100),7*s,needs[k]<25 and {.91,.42,.36,1} or color.green,4*s)
    end
end
function M:roomActions(x,y,w)
    local s=self.s
    if self.room==1 then
        if self:button('pet','Погладить',x,y,w/2-5*s,42*s) then self:action('pet') end
        if self:button('toy',(self.model.s.inventory.ball or 0)>0 and 'Мяч' or 'Играть',x+w/2+5*s,y,w/2-5*s,42*s) then self:action('play') end
        self:text(x,y+54*s,'Проведи мышкой по голове Бублика.',color.muted,14)
    elseif self.room==2 then
        self:text(x,y-5*s,'Холодильник · перетащи еду ко рту',color.muted,14)
        local j=0
        for _,id in ipairs({'apple','cookie','fish'}) do
            local label=C.items[id].label..' ×'..(self.model.s.inventory[id] or 0)
            if self:button('food'..id,label,x+j*w/3,y+22*s,w/3-5*s,40*s) then self.drag_food=id end
            j=j+1
        end
    elseif self.room==3 then
        if self:button('bed',self.model.s.sleeping and 'Разбудить' or 'Уложить спать',x,y,w/2-5*s,42*s) then
            self:action(self.model.s.sleeping and 'wake' or 'sleep')
        end
        if self:button('light',self.light and 'Выключить свет' or 'Включить свет',x+w/2+5*s,y,w/2-5*s,42*s) then self.light=not self.light end
        self:text(x,y+54*s,'Во сне энергия восстанавливается.',color.muted,14)
    elseif self.room==4 then
        local labels={'Нанести шампунь','Смыть пену','Вытереть полотенцем'}
        if self:button('bath',labels[self.wash_step+1],x,y,w,42*s) then
            if self.model.s.sleeping then self:notify('Бублик спит.')
            elseif self.wash_step==2 then if self:action('wash') then self.wash_step=0 end
            else self.wash_step=self.wash_step+1 end
        end
        self:text(x,y+54*s,'Уход в три шага · без спешки',color.muted,14)
    elseif self.room==5 then
        for j,info in ipairs({{'catch','Лови еду'},{'jump','Прыжки'},{'pairs','Найди пару'}}) do
            if self:button('start'..info[1],info[2],x+(j-1)*w/3,y,w/3-5*s,42*s) then
                if not self.model.s.sleeping then self.game=Games.new(info[1]); self.menu='game' else self:notify('Сначала разбуди Бублика.') end
            end
        end
        self:text(x,y+54*s,'Монеты только внутри ARIZONA PET',color.muted,14)
    end
end
function M:settings(x,y,w)
    local i,s=self.i,self.s; local st=self.model.s.settings
    self:text(x,y,'Настройки',nil,22)
    local row=y+44*s
    local function slider(label,key,lo,hi,integer)
        self:text(x,row,label,color.muted,13)
        i.SetCursorScreenPos(self:v(x,row+18*s)); i.SetNextItemWidth(w)
        local value=integer and i.new.int(st[key]) or i.new.float(st[key])
        local changed
        if integer then changed=i.SliderInt('##'..key,value,lo,hi) else changed=i.SliderFloat('##'..key,value,lo,hi,'%.2f') end
        if changed then st[key]=value[0]; self.save() end
        row=row+46*s
    end
    local function check(label,key)
        i.SetCursorScreenPos(self:v(x,row)); local value=i.new.bool(st[key])
        if i.Checkbox(label,value) then st[key]=value[0]; self.save() end
        row=row+28*s
    end
    slider('Размер мини-питомца','mini_size',80,320,true)
    slider('Качество (1–3)','quality',1,3,true)
    slider('Скорость анимации','animation_speed',.5,2)
    slider('Громкость','volume',0,1)
    slider('Уведомления, сек.','notifications',60,3600,true)
    check('Показывать мини-питомца','mini')
    check('Игровые реакции','reactions')
    check('Звуки','sound')
    if self:button('editmini','Настроить позицию /petedit',x,row,w,40*s) then self.open=false; st.mini=true; self.edit=true end
    self:text(x,row+54*s,'Ночь: '..st.night_start..':00–'..st.night_end..':00',color.muted,14)
    self:text(x,row+76*s,'Периоды меняются в файле сохранения.',color.muted,14)
end
function M:shop(x,y,w)
    local s=self.s
    self:text(x,y,'Лавка Бублика',nil,22)
    local row=y+44*s
    for _,id in ipairs({'apple','cookie','fish','ball','ribbon','interior'}) do
        local item=C.items[id]
        self:text(x,row,item.label..' · '..item.cost..' монет',nil,16)
        if self:button('buy'..id,'Купить',x+w-100*s,row-5*s,100*s,32*s) then
            local ok,err=self.model:buy(id)
            if ok then self:notify('Куплено: '..item.label); self.save() else self:notify(err) end
        end
        self:text(x,row+24*s,'Уровень '..(item.level or 1)..' · есть '..(self.model.s.inventory[id] or 0),color.muted,13)
        row=row+57*s
    end
    if (self.model.s.inventory.ribbon or 0)>0 and self:button('wear','Надеть / снять ленту',x,row,w,36*s) then
        self.model.s.equipped.ribbon=not self.model.s.equipped.ribbon; self.save()
    end
end
function M:journal(x,y,w)
    local s=self.s
    self:text(x,y,'Бублик помнит',nil,22)
    local m=self.model.s.memory
    self:text(x,y+38*s,'Уход: '..m.care_count..' · игр: '..m.play_count..' · снов: '..m.sleep_count,color.muted,14)
    local row=y+76*s
    for j=#m.history,math.max(1,#m.history-5),-1 do
        self:text(x,row,os.date('%d.%m %H:%M',m.history[j].time),color.muted,12)
        local text=m.history[j].text
        self.i.SetCursorScreenPos(self:v(x,row+19*s)); self.i.PushTextWrapPos((x+w)-self.i.GetWindowPos().x)
        self.i.TextUnformatted(text); self.i.PopTextWrapPos(); row=row+64*s
    end
    local count=0; for _,v in pairs(self.model.s.achievements) do if v then count=count+1 end end
    self:text(x,y+460*s,'Достижения: '..count..' / 3',color.muted,14)
end
function M:gamePanel(x,y,w,h)
    local i,s=self.i,self.s; local game=self.game
    if not game then return end
    self:text(x,y,'Игровая · '..({catch='Лови еду',jump='Прыжки',pairs='Найди пару'})[game.kind],nil,22)
    self:text(x,y+32*s,'Счёт: '..game.score..' · '..math.floor(game.t)..' сек.',color.muted,14)
    local bx,by,bw,bh=x,y+70*s,w,h-155*s
    self:rect(bx,by,bw,bh,{.86,.95,.91,1},18*s)
    if game.kind=='pairs' then
        local cw,ch=(bw-30*s)/4,(bh-25*s)/3
        local icons={'food','sleep','wash','play','heart','coin'}
        for j,v in ipairs(game.cards) do
            local xx,yy=bx+8*s+(j-1)%4*cw,by+8*s+math.floor((j-1)/4)*ch
            local selected=v==0 or game.picked[1]==j or game.picked[2]==j
            if self:button('card'..j,selected and '' or '?',xx,yy,cw-8*s,ch-8*s,selected) then game:flip(j) end
            if selected and v>0 then self:image('ui/'..icons[v]..'.png',xx+cw/2-20*s,yy+ch/2-22*s,40*s,40*s) end
        end
    elseif game.kind=='catch' then
        i.SetCursorScreenPos(self:v(bx,by)); i.InvisibleButton('catchfield',self:v(bw,bh))
        if i.IsItemHovered() and not game.done then game.basket=U.clamp((i.GetMousePos().x-bx)/bw,.1,.9) end
        for _,item in ipairs(game.items) do self:image('ui/food.png',bx+item.x*bw-14*s,by+item.y*bh,28*s,28*s) end
        self:image('ui/dark.png',bx+game.basket*bw-bw*.1,by+bh*.91,bw*.2,bh*.07)
        self:text(bx+10*s,by+10*s,'Води корзиной мышкой. 30 секунд.',color.muted,13)
    elseif game.kind=='jump' then
        i.SetCursorScreenPos(self:v(bx,by)); i.InvisibleButton('jumpfield',self:v(bw,bh))
        if i.IsItemClicked(0) then game:jump() end
        local petSize=bw*.15
        self:pet({x=bx+bw*.17,y=by+bh*.9-petSize*(Frames.anchor[2]/Frames.height)-game.y*bh,w=petSize,h=petSize})
        for _,ob in ipairs(game.obstacles) do self:image('ui/play.png',bx+ob.x*bw,by+bh*.9-bw*.08,bw*.08,bw*.08) end
        self:rect(bx,by+bh*.9,bw,3*s,{.26,.59,.45,1},0)
        self:text(bx+10*s,by+10*s,'Нажимай в поле, чтобы прыгать.',color.muted,13)
    end
    if game.done then
        self:rect(bx,by+bh/2-36*s,bw,72*s,{.06,.23,.24,.94})
        self:text(bx+20*s,by+bh/2-20*s,'Результат: '..game.score..' · +'..(game.coins or 0)..' монет',color.white,20)
    end
    if self:button('exitgame','Вернуться',x,y+h-60*s,w,42*s) then self.game=nil; self.menu=nil end
end
function M:main()
    local i=self.i; local io=i.GetIO(); local l=G.layout(io.DisplaySize.x,io.DisplaySize.y)
    self.s=l.scale; local s=self.s
    i.SetNextWindowPos(self:v(l.x,l.y),i.Cond.Always)
    i.SetNextWindowSize(self:v(l.w,l.h),i.Cond.Always)
    i.PushStyleVarVec2(i.StyleVar.WindowPadding,self:v(0,0)); i.PushStyleVarFloat(i.StyleVar.WindowRounding,22*s)
    i.PushStyleColor(i.Col.WindowBg,i.ImVec4(.97,.98,.95,1))
    local flags=i.WindowFlags.NoDecoration+i.WindowFlags.NoResize+i.WindowFlags.NoMove+i.WindowFlags.NoScrollbar+i.WindowFlags.NoScrollWithMouse+i.WindowFlags.NoSavedSettings
    i.Begin('##arizona_pet_main',nil,flags)
    i.SetWindowFontScale(s)
    self.draw=i.GetWindowDrawList()
    local x,y=l.x,l.y
    self:text(x+26*s,y+18*s,'ARIZONA PET',color.green,15)
    self:text(x+26*s,y+43*s,self.model.s.name,nil,26)
    self:text(x+253*s,y+40*s,'Уровень '..self.model:level()..'  ·  '..self.model.s.xp..' опыта',color.muted,16)
    self:image('ui/coin.png',x+693*s,y+29*s,30*s,30*s)
    self:text(x+733*s,y+34*s,tostring(self.model.s.coins),nil,20)
    if self:button('close','Закрыть',x+858*s,y+24*s,117*s,40*s) then self.open=false; self.drag_food=nil; self.game=nil; if self.menu=='game' then self.menu=nil end; self.save() end
    if self:button('store','Лавка',x+26*s,y+91*s,90*s,34*s,self.menu=='shop') then self.menu=self.menu=='shop' and nil or 'shop' end
    if self:button('settings','Настройки',x+126*s,y+91*s,113*s,34*s,self.menu=='settings') then self.menu=self.menu=='settings' and nil or 'settings' end
    if self:button('journal','Память',x+249*s,y+91*s,90*s,34*s,self.menu=='journal') then self.menu=self.menu=='journal' and nil or 'journal' end
    for j,r in ipairs(rooms) do
        if self:button('room'..r[1],r[2],x+(365+(j-1)*123)*s,y+91*s,115*s,34*s,self.room==j and not self.menu) then
            self.room=j; self.menu=nil; self.game=nil; self.drag_food=nil; self.wash_step=0
        end
    end
    self:stats(x+26*s,y+160*s)
    self:text(x+26*s,y+477*s,'Характер',color.muted,14)
    local traits=self.model.s.traits; local biggest,best='curious',0
    for k,v in pairs(traits) do if v>best then biggest,best=k,v end end
    local traitsRu={affection='Ласковый',playful='Игривый',stubborn='Упрямый',sleepy='Соня',curious='Любопытный'}
    self:text(x+26*s,y+502*s,traitsRu[biggest],nil,19)
    if self:button('togglemini',self.model.s.settings.mini and 'Скрыть мини' or 'Мини-компаньон',x+26*s,y+563*s,210*s,40*s) then
        self.model.s.settings.mini=not self.model.s.settings.mini; self.save()
    end
    self:text(x+26*s,y+618*s,'/pet · /petmini · /petedit',color.muted,12)
    local rx,ry,rw,rh=x+265*s,y+147*s,709*s,544*s
    if self.menu then
        self:rect(rx,ry,rw,rh,{1,.99,.96,1})
        if self.menu=='shop' then self:shop(rx+28*s,ry+24*s,rw-56*s)
        elseif self.menu=='settings' then self:settings(rx+28*s,ry+24*s,rw-56*s)
        elseif self.menu=='journal' then self:journal(rx+28*s,ry+24*s,rw-56*s)
        elseif self.menu=='game' then self:gamePanel(rx+28*s,ry+20*s,rw-56*s,rh-30*s) end
    else
        local roomName=rooms[self.room][1]
        if roomName=='living' and (self.model.s.inventory.interior or 0)>0 then roomName='living_alt' end
        self:image('rooms/'..roomName..'.png',rx,ry,rw,426*s)
        if self.room==3 and not self.light then self:rect(rx,ry,rw,426*s,{.03,.07,.18,.60},0) end
        local pr={x=rx+(rw-340*s)/2,y=ry+55*s,w=340*s,h=340*s}
        self:pet(pr); self:interact(pr)
        if self.room==1 and self.effect and self.effect.kind=='play' and (self.model.s.inventory.ball or 0)>0 then
            local age=self.elapsed-self.effect.time
            if age<1.5 then self:image('ui/play.png',rx+rw*.55+math.sin(age*3)*80*s,ry+360*s-math.abs(math.sin(age*6))*40*s,48*s,48*s) end
        end
        if self.room==4 and self.wash_step==1 then self:image('ui/wash.png',rx+rw*.65,ry+270*s,64*s,64*s) end
        if self.model.now<self.model.message_until then
            self:rect(rx+14*s,ry+10*s,rw-28*s,38*s,{.99,.99,.95,.91})
            self:text(rx+25*s,ry+20*s,self.model.message,color.ink,13)
        end
        self:roomActions(rx+20*s,ry+448*s,rw-40*s)
    end
    if self.model.now<self.toast_until then
        self:rect(x+275*s,y+649*s,688*s,34*s,{.06,.23,.24,.95})
        self:text(x+290*s,y+658*s,self.toast,color.white,13)
    end
    i.End(); i.PopStyleColor(); i.PopStyleVar(2)
end
function M:mini()
    local i=self.i; local io=i.GetIO(); local st=self.model.s.settings
    local r=G.mini(io.DisplaySize.x,io.DisplaySize.y,st)
    self.s=1
    i.SetNextWindowPos(self:v(r.x,r.y),i.Cond.Always)
    i.SetNextWindowSize(self:v(r.w,r.h),i.Cond.Always)
    i.PushStyleVarVec2(i.StyleVar.WindowPadding,self:v(0,0))
    local flags=i.WindowFlags.NoDecoration+i.WindowFlags.NoBackground+i.WindowFlags.NoScrollbar+i.WindowFlags.NoScrollWithMouse+i.WindowFlags.NoSavedSettings+i.WindowFlags.NoMove
    if not self.edit then flags=flags+i.WindowFlags.NoInputs end
    i.Begin('##arizona_pet_mini',nil,flags); self.draw=i.GetWindowDrawList()
    self:pet(r)
    if self.edit then
        i.SetCursorScreenPos(self:v(r.x,r.y)); i.InvisibleButton('minidrag',self:v(r.w,r.h))
        local p=i.GetMousePos()
        if i.IsItemClicked(0) then self.drag_mini={dx=p.x-r.x,dy=p.y-r.y,moved=false} end
        if self.drag_mini and i.IsMouseDown(0) then
            if math.abs(io.MouseDelta.x)+math.abs(io.MouseDelta.y)>1 then self.drag_mini.moved=true end
            st.mini_x=U.clamp((p.x-self.drag_mini.dx)/io.DisplaySize.x,0,1)
            st.mini_y=U.clamp((p.y-self.drag_mini.dy)/io.DisplaySize.y,0,1)
        elseif self.drag_mini then
            if not self.drag_mini.moved then
                if G.zone(p.x,p.y,r,'head') then self:action('pet') else self.open=true; self.edit=false end
            end
            self.drag_mini=nil; self.save()
        end
        self:text(r.x+4,r.y+4,'/petedit — выйти',color.white,12)
    end
    i.End(); i.PopStyleVar()
end
return M
