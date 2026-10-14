"""Actual Lua 5.1 execution via Lupa, PNG QC and strict mimgui contract mocks.
Does not claim to run GTA, MoonLoader, native DX9 or the SA-MP client.
"""
import json
import os
import shutil
import sys
import time
import tempfile
import unittest
from pathlib import Path
from PIL import Image, ImageChops
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
os.environ['TZ'] = 'UTC'
if hasattr(time, 'tzset'): time.tzset()
OUTPUT = ROOT / 'test-output'
OUTPUT.mkdir(exist_ok=True)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = 'moonloader/lib/?.lua;moonloader/lib/?/init.lua;' .. package.path")
TEMP = tempfile.TemporaryDirectory(prefix='arizona-pet-tests-')
lua.globals().TEST_OUTPUT = TEMP.name
client=Path(TEMP.name)/'client'
(client/'config/arizona_pet').mkdir(parents=True)
for directory in [client/'config',client/'config/arizona_pet']:
    (directory/'.directory-marker').touch()
shutil.copytree(ROOT/'moonloader/resource',client/'resource')


class Logic(unittest.TestCase):
    pass


for filename in ['test_logic.lua','test_ui.lua','test_boot.lua']:
    for name, fn in lua.execute((ROOT / 'tests' / filename).read_text()).items():
        def test(self, function=fn): function()
        setattr(Logic, 'test_' + name, test)


class Resources(unittest.TestCase):
    def test_syntax_all_lua51(self):
        from lupa.lua51 import LuaRuntime as Lua51
        check = Lua51(unpack_returned_tuples=True).eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
        files = list((ROOT/'moonloader').rglob('*.lua'))
        self.assertGreater(len(files), 10)
        for path in files:
            ok, error = check(path.read_text(encoding='utf-8'), str(path))
            self.assertTrue(ok, error)

    def test_frames_and_atlas_gutters(self):
        folder = ROOT/'moonloader/resource/arizona_pet/pet'
        manifest = json.loads((folder/'manifest.json').read_text())
        atlas = Image.open(folder/'atlas.png')
        self.assertEqual(list(atlas.size), manifest['atlas'])
        for id, (x, y, w, h) in manifest['frames'].items():
            frame = Image.open(folder/(id+'.png'))
            self.assertEqual(frame.mode, 'RGBA'); self.assertEqual(frame.size, (512,512))
            self.assertIsNone(ImageChops.difference(frame, atlas.crop((x,y,x+w,y+h))).getbbox())
            self.assertIsNone(atlas.getchannel('A').crop((x-2,y-2,x+w+2,y)).getbbox())
            self.assertIsNone(atlas.getchannel('A').crop((x+w,y,x+w+2,y+h)).getbbox())
            self.assertEqual(frame.getpixel((0,0))[3], 0)
        a,b=(Image.open(folder/(id+'.png')).getchannel('A').point(lambda v:255 if v>32 else 0).getbbox() for id in ['open','closed'])
        self.assertLessEqual(abs(a[3]-b[3]),1)  # one rasterization pixel tolerance
        self.assertLessEqual(abs(a[0]-b[0]),1)

    def test_unique_poses_and_cyrillic_font(self):
        folder=ROOT/'moonloader/resource/arizona_pet'
        a=Image.open(folder/'pet/open.png'); b=Image.open(folder/'pet/closed.png')
        self.assertIsNotNone(ImageChops.difference(a.convert('RGB'),b.convert('RGB')).getbbox())
        self.assertGreater((folder/'fonts/OpenSans-Semibold.ttf').stat().st_size, 100000)
        for room in ['living','kitchen','bedroom','bathroom','playroom','living_alt']:
            self.assertEqual(Image.open(folder/'rooms'/f'{room}.png').size, (512,512))
        self.assertNotIn('РџС', (ROOT/'moonloader/arizona_pet.lua').read_text())

    def test_alpha_inspection_rejects_touching_sheet(self):
        sys.path.insert(0,str(ROOT/'tools'))
        from prepare_assets import inspect
        im=Image.new('RGBA',(40,20)); im.paste((255,0,0,255),(0,4,22,16))
        self.assertTrue(inspect(im)['border_touch'])
        two=Image.new('RGBA',(100,100)); two.paste((255,0,0,255),(5,5,35,35)); two.paste((0,255,0,255),(55,55,90,90))
        with self.assertRaisesRegex(ValueError,'Multiple'): inspect(two)
        with self.assertRaisesRegex(ValueError,'Opaque'): inspect(Image.new('RGBA',(10,10),'white'))


if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    diagnostic = Path(TEMP.name) / 'ui-draw.json'
    if diagnostic.exists(): shutil.copyfile(diagnostic, OUTPUT / 'ui-draw.json')
    TEMP.cleanup()
    sys.exit(not result.wasSuccessful())
