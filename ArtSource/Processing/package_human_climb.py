"""Package the reviewed ladder cycle as additive palette-aware layers."""
from pathlib import Path
import json, shutil
import numpy as np
from PIL import Image
import package_weapon_techniques as pack
import package_wharf_lookout as human
import package_human_melee as melee
import ie_palette as pal
R=Path(__file__).resolve().parents[2];out=R/'ArtSource/Blender/ShippingRoofOct11/Climb'
plan=json.loads((out/'render_plan.json').read_text());progress=json.loads((out/'render_progress.json').read_text());assert progress['renders']==progress['total']==64 and not progress['errors']
transfer=json.loads((R/'ArtSource/Blender/WharfLookoutOct06/neutral_transfer.json').read_text())
human.TRANSFER=[(transfer[n]['source'],transfer[n]['reference']) for n in human.NAMES];human.OUT=out;melee.OUT=out;pack.OUT=out
frames={};hashes={}
for kind,character in [('body','HumanClimb'),('mail','HumanClimbMail'),('helmet','HumanClimbHelmet')]:
 frames[kind]={}
 for j in plan['jobs']:
  plane=human.encode(j) if kind=='body' else melee.gear(j,kind)
  if kind=='body':plane[plane==1]=0
  frames[kind][j['key']]=plane
 result=pack.pack(character,frames[kind],plan['palette_rows'] if kind=='body' else melee.ROWS,'ShippingRoofOct11/Human_Climb.blend')
 stage=out/'Stage'/character
 target=R/'RainShadow Shared/Resources/Art/IE/Avatars'/character;target.mkdir(exist_ok=True)
 for p in stage.iterdir():
  dest=target/p.name
  if dest.exists():dest.unlink()
  shutil.copy2(p,dest)
 hashes[character]=json.loads((target/'avatar-v02.json').read_text())['blob_sha256']
palette=pal.setup_character_colours(plan['palette_rows'],0,pal.GradientTables.load(),pal.MIXED_LAYOUT)
sheet=Image.new('RGBA',(8*240,2*240),(32,34,39,255))
for i,j in enumerate(plan['jobs']):
 im=Image.fromarray(palette.colors[frames['body'][j['key']]],'RGBA')
 for kind in ['mail','helmet']:im.alpha_composite(Image.fromarray(melee.PALETTE.colors[frames[kind][j['key']]],'RGBA'))
 sheet.alpha_composite(im.resize((240,240),Image.Resampling.NEAREST),((i%8)*240,(i//8)*240))
sheet.save(out/'review.png');(out/'hashes.json').write_text(json.dumps(hashes,indent=2));print(hashes)
