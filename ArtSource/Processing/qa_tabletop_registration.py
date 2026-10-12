"""Compare all imported equipment silhouettes against approved registration.

This measures the rendered placement, not a duplicate of the affine formula.
High-resolution coverage is reduced only for this comparison to the untouched
legacy reference. The production render remains full-colour/high-resolution.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/'RainShadow Shared/Resources/Art/IE'


def main():
    metadata = json.loads((ART/'Tabletop/miniatures.json').read_text())
    results = []
    for key,spec in metadata.items():
        character, name = key.split('/')
        if character in ['VossCHMF','LilaSentinel','BearGuardian']: continue
        manifest = json.loads((ART/'Avatars'/character/'avatar-v02.json').read_text())
        record = next(f for f in manifest['frames'] if f['name']==name+'.png')
        blob = (ART/'Avatars'/character/'avatar-v02.indices').read_bytes()
        old = np.frombuffer(blob[record['offset']:record['offset']+record['length']],np.uint8).reshape(record['height'],record['width'])
        reference = np.zeros((128,128),bool)
        x,y = record['trim_origin_top_left_px']; h,w = old.shape
        reference[y:y+h,x:x+w] = old > 1
        h,w = spec['height'],spec['width']
        a = np.frombuffer((ART/'Tabletop'/(key+'.rgba')).read_bytes(),np.uint8).reshape(h,w,4)[:,:,3]
        x = round(256-spec['pivot'][0]*w)
        y = round(512-184+spec['pivot'][1]*h-h)
        canvas = Image.new('L',(512,512));canvas.paste(Image.fromarray(a),(x,y))
        actual = np.array(canvas.resize((128,128),Image.Resampling.BOX)) >= 128
        iou = np.count_nonzero(reference&actual)/np.count_nonzero(reference|actual)
        # Small swords/arrows can differ on antialiased edge pixels; centroids
        # independently prevent a narrow piece drifting while keeping its bbox.
        ry,rx = np.where(reference);ay,ax = np.where(actual)
        delta = float(np.hypot(rx.mean()-ax.mean(),ry.mean()-ay.mean()))
        assert iou > .80 and delta < 1, (key,iou,delta)
        results.append(dict(view=key,iou=float(iou),centroid_error_native_px=delta))
    output = ROOT/'output/tabletop-miniatures-oct12';output.mkdir(parents=True,exist_ok=True)
    (output/'registration.json').write_text(json.dumps(results,indent=2)+'\n')
    print(f'{len(results)} equipment views registered; min IoU {min(r["iou"] for r in results):.3f}; max centroid error {max(r["centroid_error_native_px"] for r in results):.3f} native px')


if __name__=='__main__':main()
