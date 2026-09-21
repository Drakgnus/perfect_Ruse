class_name ModularCharacter
extends RefCounted

const MODEL := preload("res://assets/models/characters/modular/citizen.glb")
const HATS := {"cap": "Cap", "beanie": "Beanie", "cowboy": "Cowboy", "tophat": "Cowboy", "helmet": "Helmet", "headphones": "Headphones", "police": "PoliceCap"}
const OPTIONAL := ["Cap", "Beanie", "Cowboy", "Helmet", "Headphones", "PoliceCap", "PoliceBadge", "PoliceBelt", "PoliceBuckle", "Bag", "Hair", "HairBob", "HairBun", "Glasses", "Jacket"]
const CONTACT = preload("res://scripts/ground_contact_profiles.gd")
static var material_cache: Dictionary = {}
static var contact_libraries: Dictionary = {}

static func build(outfit: Dictionary, undressed: bool = false) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ModularVisual"
	var model: Node3D = MODEL.instantiate()
	model.name = "Citizen"
	model.set_script(preload("res://scripts/character_contact.gd"))
	# Contact is sampled from animated soles, rather than the rest-pose AABB.
	var kind := "bare" if undressed else "shoes"
	model.position.y = float(CONTACT.DATA[kind]["idle"]["offsets"][0])
	_apply_contact_animation(model, kind)
	holder.add_child(model)
	var is_police: bool = outfit.get("hat", "none") == "police"
	var active_hat: String = HATS.get(str(outfit.get("hat", "none")), "")
	var active_hair: String = {"short": "Hair", "bob": "HairBob", "bun": "HairBun"}.get(str(outfit.get("hair", "short")), "")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var piece := String(mesh.name)
		if piece in ["BootL", "BootR"]:
			mesh.visible = not undressed
		if piece in ["FootL", "FootR"]:
			mesh.visible = undressed
		if piece in OPTIONAL:
			mesh.visible = not undressed and (piece == active_hat or
				(piece == active_hair and active_hat in ["", "Headphones"]) or
				(piece == "Glasses" and outfit.get("glasses", "none") != "none") or
				(piece == "Bag" and outfit.get("backpack", "none") != "none" and not is_police) or
				(piece == "Jacket" and outfit.get("jacket", false)) or
				(piece in ["PoliceBadge", "PoliceBelt", "PoliceBuckle"] and is_police))
		if not mesh.visible:
			continue
		for index in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(index)
			if source == null:
				continue
			var zone := String(source.resource_name)
			var key: String = {"Skin": "skin", "Shirt": "shirt", "Pants": "pants", "PantsLower": "pants", "Shoes": "shoes", "Hair": "hair_color", "Glasses": "glasses_color", "Hat": "hat_color", "Jacket": "jacket_color", "Bag": "backpack_color"}.get(zone, "")
			if key.is_empty():
				continue
			var color := Color(String(outfit.get(key, "33404d")))
			if undressed and zone in ["Shirt", "Shoes", "PantsLower"]:
				color = Color(String(outfit.get("skin", "e8b58f")))
			elif undressed and zone == "Pants":
				color = Palette.UNDERWEAR
			var cache_key := color.to_html()
			if not material_cache.has(cache_key):
				material_cache[cache_key] = Palette.flat_material(color)
			mesh.set_surface_override_material(index, material_cache[cache_key])
	return holder

# One shared immutable library per footwear state; no baking/readback in gameplay.
static func _apply_contact_animation(model: Node3D, kind: String) -> void:
	var ap := animation_player(model)
	if not contact_libraries.has(kind):
		var library := AnimationLibrary.new()
		for name in ap.get_animation_list():
			var clip: Animation = ap.get_animation(name).duplicate()
			if CONTACT.DATA[kind].has(str(name)):
				var profile: Dictionary = CONTACT.DATA[kind][str(name)]
				var offsets: Array = profile["offsets"]
				var track := clip.add_track(Animation.TYPE_VALUE)
				clip.track_set_path(track, NodePath(".:position"))
				for i in offsets.size():
					clip.track_insert_key(track, float(profile["duration"]) * i / (offsets.size() - 1), Vector3(0, float(offsets[i]), 0))
			library.add_animation(name, clip)
		contact_libraries[kind] = library
	for name in ap.get_animation_library_list():
		ap.remove_animation_library(name)
	ap.add_animation_library("", contact_libraries[kind])

static func animation_player(model: Node3D) -> AnimationPlayer:
	return model.find_child("AnimationPlayer", true, false) as AnimationPlayer

static func play_motion(anim: AnimationPlayer, speed: float, stopped: bool) -> void:
	if not is_instance_valid(anim):
		return
	var clip := "idle" if stopped or speed < 0.15 else ("run" if speed >= 3.5 else "walk")
	if anim.current_animation != clip:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(clip, 0.18)
			anim.get_node(anim.root_node).begin_contact_blend(0.20)
	anim.speed_scale = 1.0 if clip == "idle" else clampf(speed / (4.6 if clip == "run" else 1.6), 0.65, 1.65)
