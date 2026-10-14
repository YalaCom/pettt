"""Explicit anchors, alpha QC, guarded crops, padded atlas, PNG/GIF diagnostics.

Only image preparation: never invents missing animation poses. Rectangle crops
touching alpha borders fail unless explicitly acknowledged in the manifest.
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'moonloader/resource/arizona_pet'


def components(alpha, threshold=16):
    """4-connected components; reports disconnected substantial figures."""
    a = alpha.point(lambda v: 255 if v > threshold else 0)
    w, h = a.size
    pixels = bytearray(a.tobytes())
    found = []
    for start in range(w * h):
        if not pixels[start]:
            continue
        pixels[start] = 0
        stack, count = [start], 0
        x0 = x1 = start % w
        y0 = y1 = start // w
        while stack:
            i = stack.pop()
            x, y = i % w, i // w
            count += 1
            x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
            neighbours = []
            if x: neighbours.append(i - 1)
            if x + 1 < w: neighbours.append(i + 1)
            if y: neighbours.append(i - w)
            if y + 1 < h: neighbours.append(i + w)
            for n in neighbours:
                if pixels[n]:
                    pixels[n] = 0
                    stack.append(n)
        if count >= 16:
            found.append({'area': count, 'bbox': [x0, y0, x1 + 1, y1 + 1]})
    return sorted(found, key=lambda c: -c['area'])


def inspect(im):
    alpha = im.getchannel('A')
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError('Empty frame')
    if alpha.getextrema() == (255, 255):
        raise ValueError('Opaque background; segment source before importing')
    cs = components(alpha)
    major = [c for c in cs if c['area'] > im.width * im.height * .025]
    if len(major) > 1:
        raise ValueError('Multiple substantial disconnected figures; segment manually')
    border = (alpha.crop((0, 0, im.width, 1)).getbbox() or
              alpha.crop((0, im.height - 1, im.width, im.height)).getbbox() or
              alpha.crop((0, 0, 1, im.height)).getbbox() or
              alpha.crop((im.width - 1, 0, im.width, im.height)).getbbox())
    return {'bbox': list(bbox), 'border_touch': bool(border), 'components': cs}


def prepare(manifest, output):
    spec = json.loads(Path(manifest).read_text(encoding='utf-8'))
    size = tuple(spec['canvas'])
    anchor = spec['anchor']
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    images, diagnostics, ids = [], [], set()
    for frame in spec['frames']:
        if frame['id'] in ids: raise ValueError('Duplicate frame ID')
        ids.add(frame['id'])
        im = Image.open(ROOT / frame['source']).convert('RGBA')
        # Explicitly discard near-invisible generator background dust only.
        im.putalpha(im.getchannel('A').point(lambda a: 0 if a <= 2 else a))
        if 'rect' in frame:
            im = im.crop(tuple(frame['rect']))
        qc = inspect(im)
        if qc['border_touch'] and not frame.get('allow_border_touch', False):
            raise ValueError(f"{frame['id']}: figure touches crop edge; possible neighbour or missing pixels")
        scale = spec['scale']  # ONE scale across ALL frames, never fit each bbox
        scaled = im.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)
        pos = (round(anchor[0] - frame['anchor'][0] * scale),
               round(anchor[1] - frame['anchor'][1] * scale))
        b = qc['bbox']
        if any([pos[0] + b[0] * scale < 2, pos[1] + b[1] * scale < 2,
                pos[0] + b[2] * scale > size[0] - 2,
                pos[1] + b[3] * scale > size[1] - 2]):
            raise ValueError(f"{frame['id']}: canvas would clip character")
        canvas = Image.new('RGBA', size)
        canvas.alpha_composite(scaled, pos)
        canvas.save(output / (frame['id'] + '.png'))
        images.append(canvas)
        diagnostics.append({'id': frame['id'], **qc, 'anchor': anchor, 'scale': scale})
    pad = 2
    cols = min(4, len(images))
    rows = math.ceil(len(images) / cols)
    # Power-of-two textures avoid implicit resizing on older DirectX 9 devices.
    aw, ah = (size[0] + pad * 2) * cols, (size[1] + pad * 2) * rows
    aw, ah = 1 << (aw-1).bit_length(), 1 << (ah-1).bit_length()
    atlas = Image.new('RGBA', (aw, ah))
    rects = []
    for i, im in enumerate(images):
        x = (i % cols) * (size[0] + pad * 2) + pad
        y = (i // cols) * (size[1] + pad * 2) + pad
        atlas.alpha_composite(im, (x, y))
        rects.append([x, y, size[0], size[1]])
    atlas.save(output / 'atlas.png')
    if max(atlas.size) > 2048: raise ValueError('Atlas exceeds DX9 conservative 2048 limit; split into pages')
    data = {'canvas': list(size), 'anchor': anchor, 'atlas': list(atlas.size),
            'frames': {f['id']: r for f, r in zip(spec['frames'], rects)}, 'diagnostics': diagnostics}
    (output / 'manifest.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    lua = ['return {width=%d,height=%d,anchor={%d,%d},atlas={%d,%d},frames={' % (*size, *anchor, *atlas.size)]
    lua += ['  %s={%s},' % (f['id'], ','.join(map(str, r))) for f, r in zip(spec['frames'], rects)]
    lua += ['}}\n']
    (ROOT / 'moonloader/lib/arizona_pet/animation/frames.lua').write_text('\n'.join(lua))
    # Diagnostic GIF uses a checkerboard ONLY in preview, never in game textures.
    previews = []
    blink_index=next((i for i,f in enumerate(spec['frames']) if f['id']=='closed'),len(images)-1)
    for im in [images[0], images[blink_index], images[0]]:
        bg = Image.new('RGB', size, '#ebe9e3')
        draw = ImageDraw.Draw(bg)
        for x in range(0, size[0], 16):
            for y in range(0, size[1], 16):
                if (x // 16 + y // 16) % 2: draw.rectangle((x, y, x+15, y+15), fill='#d6d3cd')
        bg.paste(im, mask=im.getchannel('A'))
        ImageDraw.Draw(bg).line((0, anchor[1], size[0], anchor[1]), fill='#ed5864')
        previews.append(bg)
    previews[0].save(output / 'diagnostic.gif', save_all=True, append_images=previews[1:], duration=[1600, 120, 300], loop=0)
    return data


def rooms():
    im = Image.open(ROOT / 'assets/source/rooms.png').convert('RGB')
    assert im.size == (1536, 1024), 'Recheck exact panel boundaries before slicing changed source'
    for i, name in enumerate(['living', 'kitchen', 'bedroom', 'bathroom', 'playroom', 'living_alt']):
        x, y = i % 3 * 512, i // 3 * 512
        im.crop((x, y, x+512, y+512)).save(OUT / 'rooms' / (name + '.png'))


def ui():
    # These are real reusable UI textures, not an image of a pretend interface.
    for name, color in [('button', '#f5faf7'), ('active', '#c1efdf'), ('card', '#fffaf0'), ('dark', '#133f40')]:
        im = Image.new('RGBA', (192, 64))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((2, 3, 189, 63), 20, fill='#00000028')
        d.rounded_rectangle((2, 0, 189, 58), 20, fill=color)
        im.save(OUT / 'ui' / (name + '.png'))
    sheet = Image.open(ROOT / 'assets/source/ui-icons.png').convert('RGBA')
    assert sheet.size == (1536, 1024), 'Check icon sheet boundaries before slicing'
    for i, name in enumerate(['food', 'sleep', 'wash', 'play', 'heart', 'coin']):
        x, y = i % 3 * 512, i // 3 * 512
        im = sheet.crop((x, y, x+512, y+512))
        im.putalpha(im.getchannel('A').point(lambda a: 0 if a<=2 else a))
        # Compound icons intentionally contain multiple objects (moon+star,
        # shampoo+bubbles). Cell boundaries still must be transparent.
        alpha = im.getchannel('A')
        assert not any(alpha.crop(r).getbbox() for r in [(0,0,512,1),(0,511,512,512),(0,0,1,512),(511,0,512,512)]), name+' touches neighbour'
        im = im.resize((64,64), Image.Resampling.LANCZOS)
        im.save(OUT / 'ui' / (name+'.png'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', default=str(ROOT / 'assets/frames.json'))
    parser.add_argument('--output', default=str(OUT / 'pet'))
    parser.add_argument('--all', action='store_true')
    args = parser.parse_args()
    result = prepare(args.manifest, args.output)
    if args.all: rooms(); ui()
    print('Prepared', len(result['frames']), 'unique poses, anchor', result['anchor'], 'atlas', result['atlas'])
