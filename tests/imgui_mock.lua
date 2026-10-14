-- Strict contract surface: deliberately no invented PushStyleVar/AddText overload.
-- Records actual UI draw calls for offscreen layout/resource diagnostics.
local M={}
function M.new(w,h)
    local i={Col={WindowBg=1},StyleVar={WindowPadding=1,WindowRounding=2},Cond={Always=1},
        WindowFlags={NoDecoration=1,NoResize=2,NoMove=4,NoScrollbar=8,NoScrollWithMouse=16,NoSavedSettings=32,NoBackground=64,NoInputs=128},
        commands={},textures={},mouse={x=-1,y=-1},down=false,click=nil,clicked={},styles=0,colors=0,fontscale=1,
        bg={.97,.98,.95,1},rounding=22}
    local io={DisplaySize={x=w,y=h},DeltaTime=1/60,MouseDelta={x=0,y=0}}
    local cursor={x=0,y=0}; local pos={x=0,y=0}; local size={x=w,y=h}
    local draw={}
    local function record(kind,data) data.kind=kind; i.commands[#i.commands+1]=data end
    function draw:AddTextFontPtr(font,fontsize,point,col,text)
        assert(type(fontsize)=='number' and type(text)=='string')
        record('text',{x=point.x,y=point.y,size=fontsize,col=col,text=text})
    end
    function draw:AddRectFilled(a,b,col,round)
        record('rect',{x=a.x,y=a.y,w=b.x-a.x,h=b.y-a.y,col=col,round=round})
    end
    function draw:AddImage(texture,a,b,uv_a,uv_b,col)
        assert(i.textures[texture],'Freed/missing texture in draw list')
        record('image',{file=texture,x=a.x,y=a.y,w=b.x-a.x,h=b.y-a.y,uv_a=uv_a,uv_b=uv_b,col=col})
    end
    function i.ImVec2(x,y) return {x=x,y=y} end
    function i.ImVec4(r,g,b,a) return {r,g,b,a} end
    function i.ColorConvertFloat4ToU32(c) return c end
    function i.GetIO() return io end
    function i.GetFont() return {} end
    function i.SetDpiScalingMode() end
    function i.ImFontGlyphRangesBuilder() return {AddRanges=function() end,AddText=function() end,BuildRanges=function() end} end
    function i.ImVector_ImWchar() return {[0]={Data={}}} end
    function i.GetMousePos() return i.mouse end
    function i.GetWindowDrawList() return draw end
    function i.CreateTextureFromFile(path)
        local f=io_open(path,'rb'); assert(f,'Missing texture '..path); f:close()
        i.textures[path]=true; return path
    end
    function i.ReleaseTexture(path) i.textures[path]=nil end
    function i.SetNextWindowPos(p) pos=p end
    function i.SetNextWindowSize(s) size=s end
    function i.SetCursorScreenPos(p) cursor=p end
    function i.GetWindowPos() return pos end
    function i.Begin(name,opened,flags)
        i.flags=flags
        if math.floor(flags/64)%2==0 then record('rect',{x=pos.x,y=pos.y,w=size.x,h=size.y,col=i.bg,round=i.rounding}) end
        return true
    end
    function i.End() end
    function i.PushStyleVarVec2() i.styles=i.styles+1 end
    function i.PushStyleVarFloat(key,value) i.styles=i.styles+1; i.rounding=value end
    function i.PopStyleVar(n) i.styles=i.styles-(n or 1); assert(i.styles>=0) end
    function i.PushStyleColor(key,value) i.colors=i.colors+1; i.bg=value end
    function i.PopStyleColor(n) i.colors=i.colors-(n or 1); assert(i.colors>=0) end
    function i.SetWindowFontScale(s) i.fontscale=s end
    function i.CalcTextSize(str)
        local count=0; for _ in str:gmatch('[^\128-\191]') do count=count+1 end
        return {x=count*8*i.fontscale,y=16*i.fontscale}
    end
    function i.InvisibleButton(id,s)
        i.item=id; i.itemrect={x=cursor.x,y=cursor.y,w=s.x,h=s.y}
        return i.click==id
    end
    function i.IsItemClicked() if i.click==i.item and not i.clicked[i.item] then i.clicked[i.item]=true; return true end; return false end
    function i.IsItemHovered() local r=i.itemrect; return i.mouse.x>=r.x and i.mouse.y>=r.y and i.mouse.x<=r.x+r.w and i.mouse.y<=r.y+r.h end
    function i.IsMouseDown() return i.down end
    function i.SetNextItemWidth() end
    function i.SliderInt() return false end
    function i.SliderFloat() return false end
    function i.Checkbox() return false end
    function i.PushTextWrapPos() end
    function i.PopTextWrapPos() end
    function i.TextUnformatted(str) record('text',{x=cursor.x,y=cursor.y,size=16*i.fontscale,col={.08,.22,.23,1},text=str}) end
    i.new={int=function(x) return {[0]=x} end,float=function(x) return {[0]=x} end,bool=function(x) return {[0]=x} end}
    return setmetatable(i,{__index=function(_,k) if k=='click' then return nil end; error('Unsupported mimgui call: '..tostring(k)) end})
end
-- Lua IO is shadowed by mock io above; keep the real open separately.
io_open=io.open
return M
