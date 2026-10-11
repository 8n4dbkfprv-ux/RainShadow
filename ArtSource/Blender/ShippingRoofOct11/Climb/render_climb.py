"""Retained production recipe. Execute through Blender MCP in the reviewed scene.
This is not a standalone Blender launcher. The baked action in Human_Run_Animated.blend
is the pose authority; this recipe renders its fixed projection and holdout layers.
"""
import bpy, json, math
from mathutils import Vector
from pathlib import Path
out=Path('/Users/laurensvanoorschot/RainShadow/ArtSource/Blender/ShippingRoofOct11/Climb')
s=bpy.context.scene
assert s.name=='Human_Climb_Oct11'
assert not bpy.app.is_job_running('RENDER')
body=next(o for o in s.objects if 'Voss_Rustic_Clean' in o.name)
weapon=next((o for o in s.objects if 'Lantern_Service_Shortsword' in o.name), None)
# Review hides the bow/arrow; include them when rebuilding the equipment passes.
for obj in s.objects:
    if obj.name.startswith('Reaction_'):obj.hide_render=False
meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
helm=next(o for o in meshes if 'Iron_Helmet' in o.name)
bow=next((o for o in s.objects if o.name.startswith('Reaction_bow')), None);arrow=next((o for o in s.objects if o.name.startswith('Reaction_arrow')), None)
mail=[o for o in meshes if 'Splint' in o.name]
original={o:list(o.data.materials) for o in meshes}
visibility={o:o.hide_viewport for o in s.objects if o.type=='MESH'}
for o in visibility:o.hide_viewport=True
ids=[]
for i,c in enumerate([(1,0,0),(0,1,0),(0,0,1),(1,1,0),(1,0,1),(0,1,1),(1,1,1)]):
    m=bpy.data.materials.new('Melee_ID_'+str(i));m.use_nodes=True;m.node_tree.nodes.clear()
    e=m.node_tree.nodes.new('ShaderNodeEmission');e.inputs[0].default_value=(*c,1)
    n=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(e.outputs[0],n.inputs[0]);ids.append(m)
neutral=bpy.data.materials.new('Melee_Neutral');neutral.use_nodes=True
p=neutral.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.5,.5,.5,1);p.inputs['Roughness'].default_value=.7
hold=bpy.data.materials.new('Melee_Holdout');hold.use_nodes=True;hold.node_tree.nodes.clear()
h=hold.node_tree.nodes.new('ShaderNodeHoldout');n=hold.node_tree.nodes.new('ShaderNodeOutputMaterial');hold.node_tree.links.new(h.outputs[0],n.inputs[0])
plan=json.loads((out/'render_plan.json').read_text());jobs=sorted(plan['jobs'],key=lambda j:(j['clip'],j['frame'],j['angle']));kinds=['neutral','ids','mail','helmet']
state={'renders':0,'total':len(jobs)*len(kinds),'errors':[]}
(out/'FinalRenders').mkdir(exist_ok=True)
def setup(kind):
    for o,mats in original.items():
        o.hide_render=o!=body and not (kind=='sword' and o==weapon or kind=='mail' and o in mail or kind=='helmet' and o==helm or kind=='bow' and o==bow or kind=='arrow' and o==arrow)
        for i,m in enumerate(mats):o.data.materials[i]=(neutral if kind=='neutral' else ids[i] if kind=='ids' else hold) if o==body else m
        o.data.update_tag()
    s.view_settings.view_transform='Standard' if kind=='ids' else 'AgX'
    s.cycles.samples=4;s.cycles.use_denoising=kind!='ids'
    s.render.use_persistent_data=False
    s.render.resolution_x=s.render.resolution_y=320;s.render.resolution_percentage=100;s.render.film_transparent=True
    bpy.context.view_layer.update()
s.cycles.device='CPU' # Faster for these small passes on the authoring machine.
pose_cache=None
def clear_pose_cache():
    global pose_cache
    if not pose_cache:return
    for obj in pose_cache['copies']:
        mesh=obj.data;bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
    for obj,(render,viewport) in pose_cache['visibility'].items():
        obj.hide_render=render;obj.hide_viewport=viewport
    pose_cache=None

def begin_pose_cache(key):
    if pose_cache and pose_cache['key']!=key:clear_pose_cache()

def prepare_pose_cache(key):
    global pose_cache
    if pose_cache:return
    active=[obj for obj in s.objects if obj.type in ['MESH','CURVE'] and not obj.hide_render]
    visibility={obj:(obj.hide_render,obj.hide_viewport) for obj in active}
    for obj in active:obj.hide_viewport=False
    s.view_layers[0].update();dg=bpy.context.evaluated_depsgraph_get();copies=[]
    for obj in active:
        evaluated=obj.evaluated_get(dg)
        mesh=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=dg)
        copy=bpy.data.objects.new('Render cache • '+obj.name,mesh);s.collection.objects.link(copy)
        copy.matrix_world=evaluated.matrix_world.copy();copy.hide_viewport=True;copies.append(copy)
        obj.hide_render=True;obj.hide_viewport=True
    pose_cache={'key':key,'copies':copies,'visibility':visibility}
    s.render.use_persistent_data=True

def tick():
    try:
        count=state['renders'];kind=kinds[count//len(jobs)];j=jobs[count%len(jobs)]
        key=(kind,j['clip'],j['frame']);begin_pose_cache(key)
        if count%len(jobs)==0:setup(kind)
        else:s.render.use_persistent_data=True
        bpy.context.window.scene=s
        rig=next(o for o in s.objects if o.type=='ARMATURE');action=bpy.data.actions['HumanClimb_'+j['clip']]
        if rig.animation_data.action!=action or s.frame_current!=j['frame']:
            rig.animation_data.action=action;s.frame_set(j['frame'])
        s.view_layers[0].update();a=j['angle'];s.camera.data.ortho_scale=j['ortho_scale'];s.render.resolution_x=s.render.resolution_y=372 if j['ortho_scale']>3.1 else 320
        s.camera.location=(math.sin(a)*4*math.sqrt(1-.75**2),-math.cos(a)*4*math.sqrt(1-.75**2),3.82)
        s.camera.rotation_euler=(Vector((0,0,.82))-s.camera.location).to_track_quat('-Z','Y').to_euler()
        s.render.filepath=str(out/'FinalRenders'/(j['key']+'_'+kind+'.png'))
        prepare_pose_cache(key)
        bpy.ops.render.render(write_still=True,scene=s.name);state['renders']+=1
    except Exception as e:state['errors'].append(str(e))
    (out/'render_progress.json').write_text(json.dumps(state))
    if state['errors'] or state['renders']>=state['total']:
        clear_pose_cache()
        for o,mats in original.items():
            o.hide_render=False
            for i,m in enumerate(mats):o.data.materials[i]=m
        for o,v in visibility.items():o.hide_viewport=v
        s.view_settings.view_transform='AgX';s.render.use_persistent_data=False
        return None
    return .02
def burst_tick():
 for _ in range(16):
  delay=tick()
  if delay is None:return None
  if delay>=1:return delay
 return .02
bpy.app.driver_namespace['runRender']=(burst_tick,state)
bpy.app.timers.register(burst_tick,first_interval=.1)
result=state
