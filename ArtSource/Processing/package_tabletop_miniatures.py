"""Import rigid, full-colour miniatures from approved Blender renders.

No native-row reduction, indexed quantisation, dithering or embedded IE shadow.
The paint plane stores material, continuous ramp coordinate and coverage so
existing save-game colour choices can recolour a sculpt without losing relief.
Run with Python + numpy + Pillow. Does not modify any legacy avatar bundle.
"""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image
import ie_palette as pal
import package_rustic_voss_sep30 as voss

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'RainShadow Shared/Resources/Art/IE/Tabletop'
BODY = ROOT / 'ArtSource/Blender/SwordMaterialsV8Oct01/AnimationProduction'
DIRS = ['s','ssw','sw','wsw','w','wnw','nw','nnw','n','nne','ne','ene','e','ese','se','sse']
TABLES = pal.GradientTables.load()


def ramps(rows):
    return np.array([TABLES.get_palette16(r)[:12,:3] for r in rows], dtype=float)


def paint(rgb, owner, shades, alpha, rows):
    result = np.zeros((*owner.shape, 4), np.uint8)
    if rgb is None:
        rgb = np.zeros((*owner.shape, 3))
        for slot, ramp in enumerate(ramps(rows)):
            region = owner == slot
            for c in range(3):
                rgb[:,:,c][region] = np.interp(shades[region], np.arange(12), ramp[:,c])
    result[:,:,:3] = np.clip(np.rint(rgb), 0, 255)
    result[:,:,3] = alpha
    plane = np.zeros_like(result)
    plane[:,:,0] = owner + 1
    plane[:,:,1] = np.clip(np.rint(shades / 11 * 255), 0, 255)
    plane[:,:,3] = alpha
    return result, plane


def fit(rgb, rows, mask=None, slots=range(7)):
    # Project onto ramp segments rather than quantising to twelve colours.
    choices = ramps(rows)
    best = np.full(rgb.shape[:2], np.inf)
    owner = np.zeros(rgb.shape[:2], np.uint8)
    shade = np.zeros(rgb.shape[:2])
    for slot, ramp in enumerate(choices):
        if slot not in slots: continue
        for step in range(11):
            start, delta = ramp[step], ramp[step+1]-ramp[step]
            t = np.clip(((rgb-start)*delta).sum(-1)/max(float(delta@delta), 1), 0, 1)
            error = ((rgb-start-t[:,:,None]*delta)**2).sum(-1)
            use = error < best
            if mask is not None: use &= mask == slot+1
            best[use] = error[use]; owner[use] = slot; shade[use] = step+t[use]
    return owner, shade


def register(a, job, nearest=False, padding=0):
    size = 512
    left, top, right, bottom = job['registration_box']
    scale = voss.DENSITY * 1.72 / size
    w, h = round((right-left)*scale), round((bottom-top)*scale)
    root_y = size*(.5+.82*np.sqrt(1-.75**2)/1.72)
    x, y = round(64-(size/2-left)*scale), round(82-(root_y-top)*scale)
    # The current winged helmet/mail passes have a 256px camera window plus
    # 64px overscan on each edge. Overscan is translation, never extra scale.
    ratio = (a.shape[1]-2*padding)/size
    sx, sy = (right-left)*ratio/w, (bottom-top)*ratio/h
    affine = (sx/4,0,left*ratio+padding-x*sx,0,sy/4,top*ratio+padding-y*sy)
    return np.array(Image.fromarray(a).transform((512,512),Image.Transform.AFFINE,affine,
        Image.Resampling.NEAREST if nearest else Image.Resampling.BILINEAR))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = {j['key']:j for j in json.loads((BODY/'render_plan.json').read_text())['jobs']}
    specs = {}
    provenance = {}
    def save(character, key, rgba, plane, pivot, display, rows, sources):
        folder = OUT/character; folder.mkdir(exist_ok=True)
        height, width = rgba.shape[:2]
        y, x = np.where(rgba[:,:,3] > 0)
        left, top, right, bottom = int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)
        rgba = rgba[top:bottom,left:right].copy(); plane = plane[top:bottom,left:right].copy()
        pivot = [(pivot[0]*width-left)/(right-left), (pivot[1]*height-(height-bottom))/(bottom-top)]
        display = [display*(right-left)/width,display*(bottom-top)/height]
        # Raw planes avoid colour-management changing categorical paint bytes.
        (folder/(key+'.rgba')).write_bytes(rgba.tobytes())
        (folder/(key+'.paint')).write_bytes(plane.tobytes())
        specs[character+'/'+key] = dict(width=rgba.shape[1], height=rgba.shape[0], pivot=pivot,
                                display=display, colors=rows)
        for src in sources: provenance[str(src.relative_to(ROOT))] = hashlib.sha256(src.read_bytes()).hexdigest()
    for d in DIRS:
        key = 'idle_'+d+'_00'; job = jobs[key]
        paths = [BODY/'Renders'/(key+'_ids.png'), BODY/'Renders'/(key+'_neutral.png')]
        ids, neutral = [np.array(Image.open(p).convert('RGBA')) for p in paths]
        owner = ((ids[:,:,:3].astype(float)[:,:,None,:]-voss.COLORS)**2).sum(-1).argmin(-1)
        light = neutral[:,:,:3].mean(-1)
        shades = np.zeros(owner.shape)
        for i,n in enumerate(voss.NAMES):
            m = owner == i; shades[m] = np.interp(light[m],voss.CURVES[n]['light'],voss.CURVES[n]['shade'])
        rgba, plane = paint(None,owner,shades,neutral[:,:,3],voss.ROWS)
        save('VossCHMF',key,register(rgba,job),register(plane,job,True),[.5,46/128],140.625,voss.ROWS,paths)
        lila = ROOT/'ArtSource/Blender/LilaDesertSentinelOct02'
        paths = [lila/'Renders'/(key+'_color.png'),lila/'Renders'/(key+'_mask.npz')]
        a = np.array(Image.open(paths[0]).convert('RGBA')); mask = np.load(paths[1])['mask']
        rows = json.loads((lila/'palette_fit.json').read_text())['rows']
        owner, shade = fit(a[:,:,:3].astype(float),rows,mask)
        rgba, plane = paint(a[:,:,:3],owner,shade,a[:,:,3],rows)
        save('LilaSentinel',key,rgba,plane,[.5,(64-.82*np.sqrt(1-.75**2)*128/2.88)/128],140.625,rows,paths)
        gear = [
            ('VossLanternShortsword','SwordMaterialsV8Oct01/Renders',False),
            ('VossSplintMail','WingedEquipmentRuntimeOct05/Renders/splint_mail',False),
            ('VossIronHelmet','WingedEquipmentRuntimeOct05/Renders/helmet',False),
            ('VossIronHelmet','WingedEquipmentRuntimeOct05/Renders/helmet_unarmored',True),
            ('VossElvenCourtBow','ElvenCourtBowRuntimeOct06/Renders',False),
            ('VossElvenCourtArrow','ElvenCourtArrowRuntimeOct06/Renders',False)]
        for character, folder, unarmored in gear:
            src = ROOT/'ArtSource/Blender'/folder/(key+'.png')
            rows = json.loads((ROOT/'RainShadow Shared/Resources/Art/IE/Avatars'/character/'avatar-v02.json').read_text())['colors']
            a = np.array(Image.open(src).convert('RGBA'))
            owner, shade = fit(a[:,:,:3].astype(float),rows,
                               slots=range(1 if character == 'VossIronHelmet' else 3))
            rgba, plane = paint(a[:,:,:3],owner,shade,a[:,:,3],rows)
            padding = 64 if folder.startswith('WingedEquipmentRuntimeOct05/') else 0
            padding_file = src.parent.parent/'padded_views.json'
            if padding_file.exists():
                factor = json.loads(padding_file.read_text()).get(key,1)
                padding = (a.shape[1]-a.shape[1]/factor)/2
                provenance[str(padding_file.relative_to(ROOT))] = hashlib.sha256(padding_file.read_bytes()).hexdigest()
            save(character,('unarmored_' if unarmored else '')+key,register(rgba,job,padding=padding),register(plane,job,True,padding),[.5,46/128],140.625,rows,[src])
        src = ROOT/'ArtSource/Blender/BearFormOct06/Renders'/(key+'.png')
        manifest = json.loads((ROOT/'RainShadow Shared/Resources/Art/IE/Avatars/BearGuardian/avatar-v02.json').read_text())
        rows = manifest['colors']; a = np.array(Image.open(src).convert('RGBA'))
        owner, shade = fit(a[:,:,:3].astype(float),rows)
        rgba, plane = paint(a[:,:,:3],owner,shade,a[:,:,3],rows)
        pivot = [n/128 for n in manifest['source_pivot_from_canvas_bottom_left_px']]
        save('BearGuardian',key,rgba,plane,pivot,manifest['compatibility_display_size'][0],rows,[src])
    for source in [Path(__file__), BODY/'render_plan.json', voss.CALIBRATION/'material_shade_curves.json']:
        provenance[str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
    (OUT/'miniatures.json').write_text(json.dumps(specs,indent=2)+'\n')
    (OUT/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
    print(f'Imported {len(specs)} sculpt/equipment views, continuous paint and alpha.')


if __name__ == '__main__': main()
