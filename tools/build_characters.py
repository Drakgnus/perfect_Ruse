"""Reproducible character asset; reads the author's blend without overwriting it."""
import bpy, math, pathlib, json
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
import os
SOURCE=os.environ.get('PERFECT_RUSE_SOURCE_BLEND',str(ROOT.parent/'Personagens/movimentos/Chibi_running.blend'))
OUT=ROOT/'assets/models/characters/modular/citizen.glb'
bpy.ops.wm.open_mainfile(filepath=SOURCE)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
arm.data.pose_position='REST'
bpy.context.view_layer.update()
meshes={o.name.split('.')[0]:o for o in list(bpy.data.objects) if o.type=='MESH'}
keep={'Body','Boot_L','Boot_R','Glasses','Hair'}
for key,o in list(meshes.items()):
    if key not in keep:
        bpy.data.objects.remove(o,do_unlink=True)
        del meshes[key]
for o in list(bpy.data.objects):
    if o.type not in ('MESH','ARMATURE') or (o.type=='ARMATURE' and o!=arm):
        bpy.data.objects.remove(o,do_unlink=True)

def material(name,color):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=.78
    return m
mats={k:material(k,c) for k,c in {
    'Skin':(.72,.43,.26),'Shirt':(.035,.31,.57),'Pants':(.035,.065,.11),
    'Shoes':(.85,.52,.025),'Sole':(.025,.03,.04),'Hair':(.055,.025,.014),
    'Glasses':(.65,.035,.025),'Eyes':(.012,.016,.021),'White':(.92,.90,.84),
    'Hat':(.04,.16,.40),'Jacket':(.91,.48,.025),'Metal':(.92,.60,.055),
    'Bag':(.17,.085,.035),'Underwear':(.035,.04,.05),'PantsLower':(.035,.065,.11)}.items()}
body=meshes['Body']
import bmesh
# Cut exact zone boundaries BEFORE assigning colors. Triangle-centroid masks
# alone create a zigzag neckline/hem and ragged jacket opening.
bm=bmesh.new(); bm.from_mesh(body.data)
inverse=body.matrix_world.inverted()
for co,no in [((0,0,.50),(0,0,1)),((0,0,.65),(0,0,1)),((0,0,1.055),(0,0,1)),((0,0,1.15),(0,0,1)),((.22,0,0),(1,0,0)),((-.22,0,0),(1,0,0)),((.455,0,0),(1,0,0)),((-.455,0,0),(1,0,0)),((.07,0,0),(1,0,0)),((-.07,0,0),(1,0,0)),((0,-.045,0),(0,1,0)),((0,0,.14),(0,0,1))]:
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=inverse@Vector(co),plane_no=body.matrix_world.to_3x3().transposed()@Vector(no))
low=[f for f in bm.faces if (body.matrix_world@f.calc_center_median()).z<.14]
bmesh.ops.delete(bm,geom=low,context='FACES')
bm.to_mesh(body.data); bm.free(); body.data.update()
body.data.materials.clear()
for key in ['Skin','Shirt','Pants','PantsLower']:
    body.data.materials.append(mats[key])
for p in body.data.polygons:
    co=body.matrix_world@p.center
    # Rest-pose segmentation, so clothing follows the existing Mixamo weights.
    if co.z<.50: p.material_index=3
    elif co.z<.65: p.material_index=2
    elif abs(co.x)<.455 and (co.z<1.055 or (abs(co.x)>.22 and co.z<1.15)): p.material_index=1
    else: p.material_index=0

# Jacket is derived from the weighted shirt: no second rig / retarget required.
jacket=body.copy(); jacket.data=body.data.copy(); bpy.context.collection.objects.link(jacket)
jacket.name='Jacket'
bm=bmesh.new(); bm.from_mesh(jacket.data)
remove=[]
for f in bm.faces:
    c=jacket.matrix_world@f.calc_center_median()
    if f.material_index!=1 or (c.y<-.045 and abs(c.x)<.07): remove.append(f)
bmesh.ops.delete(bm,geom=remove,context='FACES')
bm.to_mesh(jacket.data); bm.free()
jacket.data.materials.clear(); jacket.data.materials.append(mats['Jacket'])
for p in jacket.data.polygons: p.material_index=0
for v in jacket.data.vertices: v.co+=v.normal*.012
meshes['Jacket']=jacket

for name,o in meshes.items():
    o.name=name; o.data.name=name
    if name not in ('Body','Jacket'):
        o.data.materials.clear()
        slot='Shoes' if name.startswith('Boot') else name
        o.data.materials.append(mats[slot])
        if name.startswith('Boot'): o.data.materials.append(mats['Sole'])
        for p in o.data.polygons:
            c=o.matrix_world@p.center
            p.material_index=1 if name.startswith('Boot') and c.z<.035 else 0
    # Keep the authored silhouette, but reduce crowd cost substantially.
    ratio={'Body':.35,'Jacket':.65,'Boot_L':.09,'Boot_R':.09,'Hair':.5,'Glasses':.3}[name]
    bpy.context.view_layer.objects.active=o
    bm=bmesh.new(); bm.from_mesh(o.data)
    borders=[e for e in bm.edges if len(e.link_faces)==2 and e.link_faces[0].material_index!=e.link_faces[1].material_index]
    if borders: bmesh.ops.split_edges(bm,edges=borders)
    bm.to_mesh(o.data); bm.free()
    mod=o.modifiers.new('Crowd budget','DECIMATE'); mod.ratio=ratio
    mod.delimit={'MATERIAL','SEAM'}
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons: p.use_smooth=True

parts={}
def uv(name,loc,scale,mat,bone='mixamorig:Head',segments=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=12,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mats[mat])
    for p in o.data.polygons: p.use_smooth=True
    bind(o,bone)
    parts.setdefault(name.split('_')[0],[]).append(o)
    return o
def box(name,loc,scale,mat,bone='mixamorig:Head',bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mats[mat])
    mod=o.modifiers.new('Soft toy edges','BEVEL'); mod.width=bevel; mod.segments=3
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons: p.use_smooth=True
    bind(o,bone); parts.setdefault(name.split('_')[0],[]).append(o)
    return o
def bind(o,bone):
    world=o.matrix_world.copy(); o.parent=arm; o.matrix_world=world
    g=o.vertex_groups.new(name=bone); g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Shared skeleton','ARMATURE'); mod.object=arm

# Small facial features remain visible for every skin color.
# The scanned skull is ~3 mm asymmetric, so fixed coordinates leave one eye
# floating off the cheek and casting a hard shadow. Seat every feature against
# the real surface instead, side by side.
def skin_front(x,z,fallback):
    inv=body.matrix_world.inverted()
    origin=inv@Vector((x,-1.0,z))
    direction=(inv.to_3x3()@Vector((0,1,0))).normalized()
    hit,loc,nor,idx=body.ray_cast(origin,direction)
    return (body.matrix_world@loc).y if hit else fallback
EYE_Z=1.297          # eye line, measured down from the original 1.322: it sat too high on the face
BROW_Z=EYE_Z+.057    # brow keeps its distance above the eye
for side in [-1,1]:
    ex=.082*side
    eye_y=skin_front(ex,EYE_Z,-.251)+.002   # cut near the sphere equator: clean oval, never detached
    uv('Face_eye',(ex,eye_y,EYE_Z),(.023,.014,.028),'Eyes')  # wider: seating hides the rim, so keep the read
    uv('Face_glint',(ex-.004*side,eye_y-.010,EYE_Z+.008),(.004,.003,.005),'White',segments=12)
    brow_y=skin_front(ex,BROW_Z,-.235)-.002
    box('Face_brow',(ex,brow_y,BROW_Z),(.044,.012,.011),'Hair',bevel=.005)
# The authored smile is retained; no painted mark across the nose.

# Replace scanned lace-heavy boots and layered hair with clean toy geometry.
for key in ['Boot_L','Boot_R','Hair']:
    bpy.data.objects.remove(meshes.pop(key),do_unlink=True)
for side,bone,label in [(1,'mixamorig:LeftFoot','BootL'),(-1,'mixamorig:RightFoot','BootR')]:
    uv(label+'_sole',(.148*side,-.048,.041),(.125,.215,.041),'Sole',bone)
    uv(label+'_upper',(.148*side,-.04,.11),(.12,.20,.09),'Shoes',bone)
    uv(label+'_toe',(.148*side,-.183,.09),(.112,.069,.043),'White',bone)
    box(label+'_strap',(.148*side,-.09,.178),(.165,.047,.015),'White',bone,.008)
    uv(('FootL' if side>0 else 'FootR')+'_bare',(.148*side,-.04,.092),(.085,.16,.095),'Skin',bone)
uv('Hair_crown',(0,.06,1.49),(.273,.258,.162),'Hair')
for i in range(4):
    o=uv('Hair_fringe',(-.16+i*.095,-.142,1.505),(.076,.073,.099),'Hair')
    o.rotation_euler.y=-.32
uv('HairBob_crown',(0,.06,1.49),(.275,.259,.17),'Hair')
for side in [-1,1]:
    uv('HairBob_side',(.24*side,.075,1.32),(.077,.23,.23),'Hair')
uv('HairBob_fringe',(-.095,-.15,1.49),(.15,.064,.078),'Hair')
uv('HairBun_crown',(0,.07,1.48),(.27,.26,.166),'Hair')
uv('HairBun_bun',(0,.282,1.57),(.12,.115,.12),'Hair')

# Mutually exclusive headwear; solid simple shapes match the reference.
uv('Cap_crown',(0,.025,1.57),(.274,.267,.155),'Hat')
uv('Cap_brim',(0,-.23,1.54),(.27,.20,.025),'Hat')
uv('Beanie_crown',(0,.015,1.58),(.275,.27,.18),'Hat')
uv('Beanie_band',(0,.015,1.53),(.284,.276,.044),'Hat')
uv('Cowboy_brim',(0,.015,1.55),(.39,.34,.03),'Hat')
uv('Cowboy_crown',(0,.015,1.63),(.235,.23,.18),'Hat')
uv('Helmet_crown',(0,.015,1.58),(.286,.275,.17),'Hat')
uv('Helmet_brim',(0,.015,1.54),(.31,.30,.026),'Hat')
box('Helmet_ridge',(0,.015,1.722),(.038,.37,.035),'Hat',bevel=.016)
uv('PoliceCap_crown',(0,.015,1.59),(.275,.263,.125),'Hat')
uv('PoliceCap_band',(0,.015,1.53),(.276,.26,.04),'Hat')
uv('PoliceCap_brim',(0,-.22,1.51),(.25,.19,.022),'Eyes')
uv('PoliceCap_badge',(0,-.249,1.60),(.04,.012,.05),'Metal')
for side in [-1,1]:
    uv('Headphones_cup',(.294*side,.018,1.36),(.043,.084,.10),'Hat')
    box('Headphones_arm',(.284*side,.028,1.48),(.025,.035,.23),'Eyes',bevel=.012)
box('Headphones_band',(0,.028,1.612),(.56,.036,.026),'Eyes',bevel=.012)
box('Bag_main',(0,.245,.86),(.32,.14,.34),'Bag','mixamorig:Spine2',.06)
box('Bag_pocket',(0,.33,.82),(.24,.05,.13),'Hat','mixamorig:Spine2',.025)
for side in [-1,1]:
    box('Bag_strap',(.137*side,-.125,.86),(.035,.028,.26),'Bag','mixamorig:Spine2',.012)
box('PoliceBadge',( .115,-.178,.93),(.05,.018,.066),'Metal','mixamorig:Spine2',.012)
box('PoliceBelt',(0,.01,.659),(.43,.32,.045),'Eyes','mixamorig:Hips',.025)
box('PoliceBuckle',(0,-.157,.66),(.045,.02,.04),'Metal','mixamorig:Hips',.008)

for name,objs in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.join(); o=bpy.context.object; o.name=name; o.data.name=name
    meshes[name]=o

arm.data.pose_position='POSE'
arm.animation_data.action=None
# Source already contains the three cleaned, in-place NLA tracks.
for tr in arm.animation_data.nla_tracks:
    tr.mute=False
    for strip in tr.strips: strip.action.use_fake_user=True
bpy.ops.object.select_all(action='DESELECT')
for o in [arm]+list(meshes.values()): o.select_set(True)
OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_yup=True,export_apply=False)
print('CHARACTER_EXPORT',OUT,'faces',sum(len(o.data.polygons) for o in meshes.values()))
# Editable source. The export above contains all options, the source opens with
# only one clean civilian visible. Original author blend is never overwritten.
for name,o in meshes.items():
    o.hide_set(name not in ['Body','BootL','BootR','Hair','Face','Glasses','Jacket'])
    o.hide_render=o.hide_get()
for tr in arm.animation_data.nla_tracks: tr.mute=tr.name!='idle'
bpy.context.scene.frame_set(1)
(ROOT/'source').mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/citizen.blend'))
