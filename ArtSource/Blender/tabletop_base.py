"""Run in the live Blender MCP session; creates only its own isolated scene.

Source recipe for a 25 mm resin base, 2 mm bevel, 0.25 mm faction pin line.
No existing scene, character mesh, rig or material is modified.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path


def build(output):
    scene = bpy.data.scenes.new('Tabletop_Base_25mm')
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.world = bpy.data.worlds.new('Tabletop studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.28,.34,.45,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .35
    scene.view_settings.view_transform = 'AgX'
    def material(name,color,metal=0,rough=.65):
        m = bpy.data.materials.new(name); m.use_nodes = True
        p = m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value = (*color,1)
        p.inputs['Metallic'].default_value = metal; p.inputs['Roughness'].default_value = rough
        return m
    ink = material('Miniature ink-black resin',(.012,.015,.02))
    stone = material('Miniature wet slate',(.075,.09,.115),0,.42)
    pin = material('Miniature faction pin',(.44,.28,.095),.65,.3)
    # Lathed radial profile; each ring remains actual bevelled 3D geometry.
    rings = [(12.5,0),(12.5,.8),(12.45,1.05),(12.1,1.3),(11.4,2.4),(11.1,2.5)]
    verts = [(r*math.cos(i*math.tau/128),r*math.sin(i*math.tau/128),z) for r,z in rings for i in range(128)]
    faces = []; slots = []
    for j in range(len(rings)-1):
        for i in range(128):
            faces.append((j*128+i,j*128+(i+1)%128,(j+1)*128+(i+1)%128,(j+1)*128+i))
            slots.append(2 if j==1 else 0)
    faces.append(tuple(range(128*(len(rings)-1),128*len(rings)))); slots.append(1)
    mesh = bpy.data.meshes.new('25mm bevelled resin');mesh.from_pydata(verts,[],faces);mesh.update()
    obj = bpy.data.objects.new('25mm miniature base',mesh);scene.collection.objects.link(obj)
    for m in [ink,stone,pin]:mesh.materials.append(m)
    for f,slot in zip(mesh.polygons,slots):f.material_index=slot;f.use_smooth=len(f.vertices)==4
    # Broad stone seams at miniature scale, no texture noise.
    nodes=stone.node_tree.nodes;links=stone.node_tree.links;p=nodes['Principled BSDF']
    tex=nodes.new('ShaderNodeTexBrick');tex.inputs['Scale'].default_value=5
    tex.inputs['Mortar Size'].default_value=.025
    tex.inputs['Color1'].default_value=(.06,.075,.095,1);tex.inputs['Color2'].default_value=(.11,.13,.15,1)
    tex.inputs['Mortar'].default_value=(.018,.021,.026,1)
    links.new(tex.outputs['Color'],p.inputs['Base Color'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.3;bump.inputs['Distance'].default_value=.12
    links.new(tex.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])
    cam=bpy.data.cameras.new('Miniature fixed 48.59 degree camera');cam.type='ORTHO';cam.ortho_scale=30;cam.clip_start=.001
    camera=bpy.data.objects.new(cam.name,cam);scene.collection.objects.link(camera)
    camera.location=(0,-60*math.sqrt(1-.75**2),45)
    camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
    for name,pos,power,color,size in [('Cold softbox',(-25,-20,50),1800,(.73,.83,1),35),('Practical lamp',(25,-15,30),1100,(1,.7,.4),20)]:
        light=bpy.data.lights.new(name,'AREA');light.energy=power;light.color=color;light.shape='DISK';light.size=size
        ob=bpy.data.objects.new(name,light);scene.collection.objects.link(ob);ob.location=pos
        ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
    # Light wattage is relative to metre-sized scene units; scale geometry to metres.
    for ob in scene.objects:ob.location*=.001
    obj.scale=(.001,)*3;cam.ortho_scale*=.001
    for ob in scene.objects:
        if ob.type=='LIGHT':ob.data.size*=.001;ob.data.energy*=.000001
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    Path(output).mkdir(parents=True,exist_ok=True)
    for name,col,metal in [('ally',(.44,.28,.095),.65),('hostile',(.195,.012,.017),.1),('neutral',(.012,.015,.02),0)]:
        p=pin.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*col,1);p.inputs['Metallic'].default_value=metal
        scene.render.filepath=str(Path(output)/('base_'+name+'.png'))
        bpy.ops.render.render(write_still=True,scene=scene.name)
    return scene
