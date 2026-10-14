"""Rasterizes recorded Lua draw calls. Diagnostic only: not a GTA screenshot."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
commands=json.loads((ROOT/'test-output/ui-draw.json').read_text())
canvas=Image.new('RGBA',(1280,900),'#153236')
font_path=ROOT/'moonloader/resource/arizona_pet/fonts/OpenSans-Semibold.ttf'
for cmd in commands:
    x,y=round(cmd['x']),round(cmd['y'])
    color=tuple(round(v*255) for v in cmd['col'])
    if cmd['kind']=='image':
        im=Image.open(ROOT/cmd['file']).convert('RGBA')
        ua,ub=cmd['uv_a'],cmd['uv_b']
        im=im.crop((round(ua['x']*im.width),round(ua['y']*im.height),round(ub['x']*im.width),round(ub['y']*im.height)))
        im=im.resize((max(1,round(cmd['w'])),max(1,round(cmd['h']))),Image.Resampling.LANCZOS)
        if color[3]<255: im.putalpha(im.getchannel('A').point(lambda a:round(a*color[3]/255)))
        canvas.alpha_composite(im,(x,y))
    else:
        layer=Image.new('RGBA',canvas.size)
        d=ImageDraw.Draw(layer)
        if cmd['kind']=='rect':
            if cmd['w']<=0 or cmd['h']<=0: continue
            d.rounded_rectangle((x,y,x+round(cmd['w']),y+round(cmd['h'])),radius=round(cmd['round']),fill=color)
        else:
            font=ImageFont.truetype(str(font_path),round(cmd['size']))
            d.text((x,y),cmd['text'],font=font,fill=color,anchor='lt')
        canvas.alpha_composite(layer)
canvas.convert('RGB').save(ROOT/'test-output/ui-diagnostic.png')
print('Offscreen Lua draw-list diagnostic: test-output/ui-diagnostic.png')
