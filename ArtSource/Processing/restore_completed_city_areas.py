"""Restore reviewed native packages without rerendering or changing other wards."""
from pathlib import Path
import hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'ArtSource/Generated/CityDistrict'
OUT = BASE / 'RuntimeRestoreSep27'
RES = ROOT / 'RainShadow Shared/Resources'

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text())

def main():
    sources = {}
    rv = BASE / 'RiversideNoirFantasySep26/DormersV13'
    for rel, expected in read(rv/'installation_receipt.json')['installedSHA256'].items():
        sources[ROOT/rel] = (rv/'payload'/Path(rel).relative_to('RainShadow Shared/Resources'), expected)
    wh = BASE/'WharfLadderNoirFantasySep25'
    for rel, expected in read(wh/'IntegrationV19/installation_receipt.json')['installedSHA256'].items():
        sources[ROOT/rel] = (wh/'IntegrationV19/payload'/Path(rel).relative_to('RainShadow Shared/Resources'), expected)
    for rel, expected in read(wh/'MaterialsV20/installation_receipt.json')['installedSHA256'].items():
        sources[ROOT/rel] = (wh/'MaterialsV20/payload'/Path(rel).name, expected)
    # Preserve the later, material-only puddle update over the historical V20 art.
    puddles = BASE / 'WharfLadderPuddlesOct10'
    if (puddles/'installation_receipt.json').exists():
        for rel, expected in read(puddles/'installation_receipt.json')['installedSHA256'].items():
            sources[ROOT/rel] = (puddles/'payload'/Path(rel).name, expected)
    shapes = puddles / 'ShapesV2'
    if (shapes/'installation_receipt.json').exists():
        for rel, expected in read(shapes/'installation_receipt.json')['installedSHA256'].items():
            sources[ROOT/rel] = (shapes/'payload'/Path(rel).name, expected)
    lamps = BASE / 'WharfLadderLampsOct10'
    if (lamps/'installation_receipt.json').exists():
        for rel, expected in read(lamps/'installation_receipt.json')['installedSHA256'].items():
            sources[ROOT/rel] = (lamps/'payload'/Path(rel).name, expected)
    roof = BASE / 'ShippingRoofOct11'
    for receipt, folder in [('installation_receipt.json', 'payload'), ('navigation_installation_receipt.json', 'navigation_payload')]:
        if (roof/receipt).exists():
            for rel, expected in read(roof/receipt)['installedSHA256'].items():
                sources[ROOT/rel] = (roof/folder/Path(rel).name, expected)
    sa = BASE/'SableRowNoirFantasySep23/ArtMatchV30'
    for rel, expected in read(sa/'installation_receipt.json')['sha256'].items():
        name = Path(rel).name
        sub = 'animations' if '/Animations/' in rel else 'lightmaps' if name.endswith('.lm.png') else 'pages'
        source = sa/'staged'/sub/name
        if name.endswith('.area.json'): source = sa/'staged'/name
        sources[ROOT/rel] = (source, expected)
    for name in ['sable_noir.sr.png','sable_noir.ht.png']:
        source = sa/'RuntimeBackup/RainShadow Shared/Resources/Areas'/name
        sources[RES/'Areas'/name] = (source, digest(source))
    # Validate every archived byte before replacing any live resource.
    for dest,(source,expected) in sources.items():
        assert source.exists() and digest(source)==expected, str(source)
    for dest,(source,expected) in sources.items():
        backup=OUT/'Before'/dest.relative_to(ROOT)
        if dest.exists() and not backup.exists():
            backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,backup)
        dest.parent.mkdir(parents=True,exist_ok=True);dest.unlink(missing_ok=True)
        shutil.copyfile(source,dest)
    # The archived Rooms exit sat one clearance cell too near the floor edge.
    # Keep its painted strip; operate it from the adjacent authored arrival.
    roompath=RES/'Areas/interior_iron_stairs.area.json'
    room=read(roompath)
    next(r for r in room['area']['regions'] if r['id']=='portal.return')['approachPoint']={'x':344,'y':222}
    roompath.write_text(json.dumps(room,indent=2)+'\n')
    # Promote Sable's reviewed playtest to the existing world-map identity.
    record=read(RES/'Areas/sable_noir.area.json');area=record['area']
    area['id']='city_sable_row'
    area['searchMapName']='city_sable_row.sr';area['heightMapName']='city_sable_row.ht'
    area['lightMapName']='city_sable_row.lm'
    area['arrivalHint']='SABLE ROW  •  Voss’s office, the public well and the ward’s narrow lanes.'
    notes={n['label']:n['point'] for n in area['notes']}
    for edge,label in {'west':'West street','east':'East street','north':'North ward gate','south':'South lane'}.items():
        area['entrances'].append({'name':'from.'+edge,'point':notes[label]})
    area['ambients']=[{'id':'amb.rain','assetName':'amb_rain_exterior','volume':0.34,'isLooping':True,'isGlobal':True}]
    for srcname,dstname in [('sable_noir.sr.png','city_sable_row.sr.png'),('sable_noir.ht.png','city_sable_row.ht.png')]:
        dest=RES/'Areas'/dstname;backup=OUT/'Before'/dest.relative_to(ROOT)
        if not backup.exists():backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,backup)
        dest.unlink();shutil.copyfile(RES/'Areas'/srcname,dest);sources[dest]=(RES/'Areas'/srcname,digest(dest))
    dest=RES/'Areas/city_sable_row.lm.png';backup=OUT/'Before'/dest.relative_to(ROOT)
    if dest.exists() and not backup.exists():backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,backup)
    dest.unlink(missing_ok=True)
    shutil.copyfile(RES/'Art/Areas/sable_noir_day.lm.png',dest);sources[dest]=(RES/'Art/Areas/sable_noir_day.lm.png',digest(dest))
    dest=RES/'Areas/city_sable_row.area.json';backup=OUT/'Before'/dest.relative_to(ROOT)
    if not backup.exists():backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,backup)
    dest.unlink();dest.write_text(json.dumps(record,indent=2)+'\n');sources[dest]=(sa/'staged/sable_noir.area.json',digest(dest))
    # Both app targets use explicit synchronized resource membership.
    project=ROOT/'RainShadow.xcodeproj/project.pbxproj';text=project.read_text()
    entries=[str(p.relative_to(ROOT/'RainShadow Shared')) for p in sources]
    entries.append('Gameplay/Navigation/RebuiltCityAreas.swift')
    for target in ['DAAF9D58300A69350071746D','DAAF9D62300A69350071746D']:
        start=text.index(target+' /* Exceptions');end=text.index('target = ',start)
        block=text[start:end];missing=[e for e in entries if e+',' not in block]
        pos=text.index('membershipExceptions = (',start)+len('membershipExceptions = (')
        text=text[:pos]+''.join('\n\t\t\t\t'+e+',' for e in missing)+text[pos:]
    project.write_text(text)
    (OUT/'installation_receipt.json').write_text(json.dumps({'files':{str(p.relative_to(ROOT)):digest(p) for p in sources}, 'authoringCorrections':{'interior_iron_stairs.portal.return.approachPoint':{'before':[328,210],'after':[344,222],'reason':'Reachable approach on unchanged search map; original did not have actor clearance.'}}},indent=2)+'\n')
    print('Restored',len(sources),'resources; native art is unchanged.')

if __name__=='__main__':main()
