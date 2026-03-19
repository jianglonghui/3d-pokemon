## CharacterAnimator
## Loads KayKit animation GLBs at runtime and applies them to a character GLB.
## All KayKit medium characters share the same skeleton, so we remap track paths.
extends RefCounted
class_name CharacterAnimator

const ANIM_GENERAL  := "res://assets/animations/Rig_Medium_General.glb"
const ANIM_MOVEMENT := "res://assets/animations/Rig_Medium_MovementBasic.glb"
const ANIM_COMBAT   := "res://assets/animations/Rig_Medium_CombatMelee.glb"

var _anim_player: AnimationPlayer = null
var _character:   Node            = null

# ── Setup ──────────────────────────────────────────────────────────────────────

func setup(character_root: Node) -> void:
	_character = character_root

	# Find or create AnimationPlayer on the character
	_anim_player = _find_typed(character_root, "AnimationPlayer") as AnimationPlayer
	if _anim_player == null:
		_anim_player = AnimationPlayer.new()
		character_root.add_child(_anim_player)

	# Find skeleton in character
	var char_skel: Skeleton3D = _find_typed(character_root, "Skeleton3D")
	if char_skel == null:
		push_warning("CharacterAnimator: no Skeleton3D found in character")
		return

	var char_skel_path := str(_anim_player.get_path_to(char_skel))

	# Load and merge each animation pack
	for glb_path in [ANIM_GENERAL, ANIM_MOVEMENT, ANIM_COMBAT]:
		_load_pack(glb_path, char_skel_path)

# ── Playback ───────────────────────────────────────────────────────────────────

func play(anim_name: String, blend: float = 0.2) -> void:
	if _anim_player == null:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name, blend)

func play_idle() -> void:
	play("Idle_A", 0.3)

func play_walk() -> void:
	play("Walking_A", 0.2)

func play_attack() -> void:
	play("Melee_Unarmed_Attack_Punch_A", 0.1)

func play_hit() -> void:
	play("Hit_A", 0.05)

func play_death() -> void:
	play("Death_A", 0.1)

func is_playing(anim_name: String) -> bool:
	return _anim_player != null and _anim_player.current_animation == anim_name

# ── Internal ───────────────────────────────────────────────────────────────────

func _load_pack(glb_path: String, char_skel_path: String) -> void:
	var packed := load(glb_path) as PackedScene
	if packed == null:
		return

	var instance := packed.instantiate()

	var src_player: AnimationPlayer = _find_typed(instance, "AnimationPlayer")
	var src_skel:   Skeleton3D      = _find_typed(instance, "Skeleton3D")

	if src_player == null or src_skel == null:
		instance.queue_free()
		return

	var src_skel_path := str(src_player.get_path_to(src_skel))

	# Ensure a default library exists on the target player
	if not _anim_player.has_animation_library(""):
		_anim_player.add_animation_library("", AnimationLibrary.new())
	var lib: AnimationLibrary = _anim_player.get_animation_library("")

	for anim_name in src_player.get_animation_list():
		if lib.has_animation(anim_name):
			continue  # don't overwrite

		var src_anim: Animation = src_player.get_animation(anim_name)
		var dst_anim: Animation = _remap_anim(src_anim, src_skel_path, char_skel_path)
		lib.add_animation(anim_name, dst_anim)

	instance.queue_free()

func _remap_anim(src: Animation, from_path: String, to_path: String) -> Animation:
	var dst := Animation.new()
	dst.length    = src.length
	dst.loop_mode = src.loop_mode

	for ti in src.get_track_count():
		var track_path := str(src.track_get_path(ti))

		# Remap skeleton path prefix
		if from_path != to_path:
			if track_path.begins_with(from_path):
				track_path = to_path + track_path.substr(from_path.length())

		var new_ti := dst.add_track(src.track_get_type(ti))
		dst.track_set_path(new_ti, NodePath(track_path))
		dst.track_set_interpolation_type(new_ti, src.track_get_interpolation_type(ti))
		dst.track_set_interpolation_loop_wrap(new_ti, src.track_get_interpolation_loop_wrap(ti))

		for ki in src.track_get_key_count(ti):
			var time  := src.track_get_key_time(ti, ki)
			var value: Variant = src.track_get_key_value(ti, ki)
			var trans := src.track_get_key_transition(ti, ki)
			dst.track_insert_key(new_ti, time, value, trans)

	return dst

static func _find_typed(root: Node, type_name: String) -> Node:
	if root.get_class() == type_name:
		return root
	for child in root.get_children():
		var found := _find_typed(child, type_name)
		if found:
			return found
	return null
