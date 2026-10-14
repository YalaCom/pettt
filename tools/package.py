"""Build a deterministic install archive from actual runtime files, not sources/saves."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT=Path(__file__).resolve().parents[1]
DIST=ROOT/'dist'
DIST.mkdir(exist_ok=True)
files=[ROOT/'README.md',*(ROOT/'docs').glob('*.md'),*(ROOT/'docs').glob('LICENSE-*.txt')]
files += [p for p in (ROOT/'moonloader').rglob('*') if p.is_file() and 'config' not in p.relative_to(ROOT/'moonloader').parts]
files=sorted(files)
assert (ROOT/'moonloader/arizona_pet.lua') in files
manifest=json.loads((ROOT/'moonloader/resource/arizona_pet/pet/manifest.json').read_text())
for id in manifest['frames']:
    assert (ROOT/f'moonloader/resource/arizona_pet/pet/{id}.png').is_file()
for name in ['living','kitchen','bedroom','bathroom','playroom']:
    assert (ROOT/f'moonloader/resource/arizona_pet/rooms/{name}.png').is_file()
checksums=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(ROOT).as_posix()+'\n' for p in files)
archive=DIST/'ARIZONA-PET-0.1.0.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as z:
    for name,data in [(p.relative_to(ROOT).as_posix(),p.read_bytes()) for p in files]+[('SHA256SUMS.txt',checksums.encode())]:
        info=zipfile.ZipInfo(name,(2026,10,14,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
        z.writestr(info,data)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for line in z.read('SHA256SUMS.txt').decode().splitlines():
        digest,name=line.split('  ',1); assert hashlib.sha256(z.read(name)).hexdigest()==digest
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(DIST/'SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n')
print(f'{archive}: {len(files)} files, {archive.stat().st_size} bytes, SHA256 {digest}')
