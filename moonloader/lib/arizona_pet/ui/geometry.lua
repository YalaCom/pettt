local U=require 'arizona_pet.core.util'
local M={}
function M.layout(w,h)
    local scale=math.min(1.25,w*.94/1000,h*.92/720)
    return {scale=scale,w=1000*scale,h=720*scale,x=(w-1000*scale)/2,y=(h-720*scale)/2}
end
function M.hit(x,y,r) return x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end
function M.petRect(x,y,size) return {x=x,y=y,w=size,h=size} end
function M.zone(x,y,r,name)
    local nx,ny=(x-r.x)/r.w,(y-r.y)/r.h
    if name=='head' then return ((nx-.48)/.30)^2+((ny-.42)/.27)^2<=1 end
    if name=='mouth' then return ((nx-.48)/.08)^2+((ny-.57)/.07)^2<=1 end
    return false
end
function M.mini(w,h,settings)
    local size=math.min(settings.mini_size,w*.35,h*.4)
    return {x=U.clamp(w*settings.mini_x,0,w-size),y=U.clamp(h*settings.mini_y,0,h-size),w=size,h=size}
end
return M
