#!/usr/bin/env python3
"""Generate original tileable-ish, high-frequency bitmap PBR materials for KARTON EU IV.
Pillow and NumPy only; output PNGs are real Godot-importable textures (not runtime pixels).
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
OUT.mkdir(parents=True, exist_ok=True)
S = 512
rng = np.random.default_rng(6918)
Y, X = np.mgrid[0:S, 0:S]

def tile_noise(period=32, amp=1.0):
    # low-resolution random tiles upscaled + blur for multi-scale variation
    size = max(2, S // period)
    small = rng.integers(0,256,(size,size),dtype=np.uint8)
    img = Image.fromarray(small,'L').resize((S,S),Image.Resampling.BICUBIC)
    return np.asarray(img,dtype=np.float32)/255*amp

def multi():
    return 0.43*tile_noise(80) + 0.30*tile_noise(24) + 0.15*tile_noise(8) + 0.12*rng.random((S,S))

def blend(base, dark, mask):
    t=np.clip(mask,0,1)[...,None]
    a=np.array(base,dtype=np.float32);b=np.array(dark,dtype=np.float32)
    return a*(1-t)+b*t

def save(name, arr, height, roughness=0.8):
    arr=np.clip(arr,0,255).astype('uint8')
    Image.fromarray(arr,'RGB').save(OUT / f'{name}_albedo.png', optimize=True)
    gradient_y,gradient_x=np.gradient(height.astype(np.float32))
    nx=np.clip(-gradient_x*3.0,-1,1);ny=np.clip(-gradient_y*3.0,-1,1)
    nz=np.ones_like(nx)*0.7
    length=np.sqrt(nx*nx+ny*ny+nz*nz)
    norm=np.stack([(nx/length*.5+.5)*255,(ny/length*.5+.5)*255,(nz/length*.5+.5)*255],axis=-1)
    Image.fromarray(np.uint8(norm),'RGB').save(OUT/f'{name}_normal.png',optimize=True)
    var=(multi()-.5)*0.18
    rough=np.clip((roughness+var)*255,0,255).astype('uint8')
    Image.fromarray(rough,'L').save(OUT/f'{name}_roughness.png',optimize=True)

n=multi();specks=rng.random((S,S));
cracks=(np.sin(X/68+tile_noise(32)*1.7)>0.995)&(Y%7<2)
h=(n*0.5+specks*0.2+cracks*.3)
p=blend((101,103,103),(38,43,44),np.clip((n-.25)*.85+np.where(specks>.985,.65,0)+cracks*.4,0,1))
p=np.where((specks>.99)[...,None],np.array((184,178,163)),p)
save('asphalt',p,h,.96)

n=multi();joint=((X%232<3)|(Y%236<3)); chip=(rng.random((S,S))>.997)
h=.3*n+.2*joint+.07*chip
p=blend((173,174,168),(103,108,106),n*.45+joint*.55+chip*.16)
save('concrete',p,h,.9)

n=multi();rib=((X%21<4)*.29)+(np.sin((X%21)/21*np.pi*2)*.055)
seam=(Y%224<3).astype(float)*.22
rust=np.maximum(0,tile_noise(64)-.64)*2.5
h=.12*n+rib+seam
p=blend((178,189,192),(71,81,91),rib*.5+seam*.4+n*.2)
p=blend((p if False else (176,189,195)),(78,88,93),rib*.5+seam*.4+n*.22)
p=np.clip(p+rust[...,None]*np.array((31,-35,-58)),0,255)
save('sheetmetal',p,h,.5)

n=multi();rib=(np.cos(X*2*np.pi/18)+1)*.09
seam=(X%192<4)*.5+(Y%256<3)*.36
h=n*.13+rib+seam
p=blend((187,191,188),(96,101,107),n*.31+rib*.62+seam*.52)
save('roof',p,h,.68)

n=multi();fibres=(np.cos(Y*.98)+np.cos(Y*2.4))*0.02
vertical_fold=(X%192<2)*.32
h=n*.16+fibres+vertical_fold
p=blend((204,157,94),(115,77,43),n*.35+fibres*1.4+vertical_fold*.57)
# subtle printable batch dashes and mechanical paper grain
p=np.where(((Y%128>114)&(Y%128<118)&(X%28<12))[...,None],p*.75,p)
save('cardboard',p,h,.94)

n=multi();grain=np.sin(X*.065+np.sin(Y*.011)*2+tile_noise(66)*2)*.45+.5
seam=(Y%140<3)*.25
h=.27*grain+.10*n+seam
p=blend((178,127,75),(79,51,28),grain*.49+n*.1+seam*.6)
save('wood',p,h,.83)

n=multi();streak=(X%138<2)*.15
scratches=(rng.random((S,S))>.994)*(np.maximum(0,np.sin(Y*.3))*.23)
h=n*.15+scratches+streak
p=blend((126,138,145),(50,62,72),n*.3+scratches*.9+streak*.25)
save('steel',p,h,.5)

n=multi();oxidation=np.maximum(0,tile_noise(55)-.63)*2
scratches=((Y%71<2)&(X%140>20)&(X%140<115))*.3
h=n*.11+scratches
p=blend((121,153,149),(55,82,84),n*.4+scratches*.7)
p=np.clip(p+oxidation[...,None]*np.array((73,-20,-39)),0,255)
save('machine',p,h,.54)

n=multi();pavers=((Y%72<5)|((X+(Y//72%2)*82)%164<5))
material=blend((169,136,108),(113,93,75),n*.45)
p=np.where(pavers[...,None],np.array((83,77,70)),material)
h=n*.18+pavers*.23
save('brick',p,h,.89)

n=multi();tiles=((X%72<3)|(Y%72<3))
scuffs=np.maximum(0,tile_noise(36)-.57)*.26
h=n*.09+tiles*.1
p=blend((91,96,93),(45,51,53),n*.3+scuffs)
p=np.where(tiles[...,None],p*.66,p)
save('rubber',p,h,.86)

n=multi();stripe=((X+Y)//49)%2
nicks=(rng.random((S,S))>.998)
h=n*.15+stripe*.05+nicks*.2
p=np.where(stripe[...,None]==0, np.array((215,171,52)), np.array((31,32,30))).astype(float)
p=np.clip(p*(.87+n[...,None]*.18)-nicks[...,None]*31,0,255)
save('hazard',p,h,.69)

n=multi();weave=(np.sin(X*.23)*np.sin(Y*.23))*.15+.4
h=n*.13+weave*.18
p=blend((112,118,134),(49,58,72),n*.26+weave*.43)
save('fabric',p,h,.96)

print(f"Generated {len(list(OUT.glob('*.png')))} original PBR maps in {OUT}")
