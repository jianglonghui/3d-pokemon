## BattleDirector — 战斗视觉层
## 负责：镜头语言、模型动画、视觉特效、音效时机
## 监听 BattleGame 的信号，执行视觉响应，再发回确认信号
extends Node
class_name BattleDirector

# ── 引用（由 battle_3d.gd 注入）─────────────────────────────────────────────
var camera: Camera3D                = null   # 战斗场景专属摄像机
var player_slot: Node3D             = null
var enemy_slot: Node3D              = null
var player_anim: CharacterAnimator  = null
var enemy_anim: CharacterAnimator   = null
var player_mat: StandardMaterial3D  = null
var enemy_mat: StandardMaterial3D   = null
var sfx_enter: AudioStreamPlayer    = null
var sfx_faint: AudioStreamPlayer    = null
var sfx_hit: AudioStreamPlayer      = null

const PLAYER_COLOR := Color(0.2, 0.5, 0.95)
const ENEMY_COLOR  := Color(0.9, 0.2, 0.2)

var _game: BattleGame = null

# ── 与 BattleGame 绑定 ────────────────────────────────────────────────────────

func bind_game(game: BattleGame) -> void:
	_game = game
	game.enter_requested.connect(_on_enter_requested)
	game.attack_requested.connect(_on_attack_requested)
	game.faint_requested.connect(_on_faint_requested)
	game.victory_requested.connect(_on_victory_requested)

# ── 信号处理器（BattleGame 的视觉请求）──────────────────────────────────────

func _on_enter_requested(slot: Node3D, origin: Vector3) -> void:
	await enter_anim(slot, origin)
	_game.enter_visual_done.emit()

func _on_attack_requested(atk_slot: Node3D, atk_origin: Vector3, def_slot: Node3D, move: MoveModel) -> void:
	# 根据方向确定 mat 和颜色
	var def_mat := player_mat if def_slot == player_slot else enemy_mat
	var def_orig_color := PLAYER_COLOR if def_slot == player_slot else ENEMY_COLOR
	await attack_anim(atk_slot, atk_origin, def_slot, def_mat, def_orig_color, move)
	_game.attack_visual_done.emit()

func _on_faint_requested(slot: Node3D) -> void:
	var mat := player_mat if slot == player_slot else enemy_mat
	await faint_anim(slot, mat)
	# 濒死特写：推近镜头 2 秒，然后切回主机位
	if camera:
		var origin_pos := camera.global_position
		var origin_look := Vector3(0, 1, 0)
		# 推近至濒死缚灵
		var dir := (camera.global_position - slot.global_position).normalized()
		var close_pos := slot.global_position + dir * 1.8
		var t_in := create_tween()
		t_in.tween_property(camera, "global_position", close_pos, 0.4).set_ease(Tween.EASE_OUT)
		await t_in.finished
		camera.look_at(slot.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		await get_tree().create_timer(2.0).timeout
		# 切回主机位
		camera.global_position = origin_pos
		camera.look_at(origin_look, Vector3.UP)
	_game.faint_visual_done.emit()

func _on_victory_requested() -> void:
	await victory_flash()
	_game.victory_visual_done.emit()

# ── 3D 动画 ───────────────────────────────────────────────────────────────────

func _anim_for(slot: Node3D) -> CharacterAnimator:
	return player_anim if slot == player_slot else enemy_anim

func enter_anim(slot: Node3D, origin: Vector3) -> void:
	if sfx_enter:
		sfx_enter.play()
	var tween := create_tween()
	tween.tween_property(slot, "position", origin, 0.55) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished
	_anim_for(slot).play_idle()

func attack_anim(
		atk_slot: Node3D, atk_origin: Vector3,
		def_slot: Node3D,
		def_mat: StandardMaterial3D, def_orig_color: Color,
		move: MoveModel) -> void:

	# 攻击方冲锋
	_anim_for(atk_slot).play_attack()
	var charge_dir  := (def_slot.position - atk_slot.position).normalized()
	var charge_dest := def_slot.position - charge_dir * 0.7
	var t_charge := create_tween()
	t_charge.tween_property(atk_slot, "position", charge_dest, 0.22).set_ease(Tween.EASE_IN)
	await t_charge.finished

	# 命中
	_play_move_sfx(move)
	_anim_for(def_slot).play_hit()
	# 缚灵受击特效
	for child in def_slot.get_children():
		if child.has_method("on_hit"):
			child.on_hit()
			break
	# 镜头轻微震动
	if camera:
		_shake_camera(0.06, 0.18)

	# 攻击方回位
	var t_back := create_tween()
	t_back.tween_property(atk_slot, "position", atk_origin, 0.28).set_ease(Tween.EASE_OUT)
	await t_back.finished
	_anim_for(atk_slot).play_idle()

	# 防御方抖动
	var def_orig := def_slot.position
	var t_shake := create_tween()
	t_shake.tween_property(def_slot, "position", def_orig + Vector3( 0.35, 0, 0), 0.05)
	t_shake.tween_property(def_slot, "position", def_orig + Vector3(-0.35, 0, 0), 0.05)
	t_shake.tween_property(def_slot, "position", def_orig + Vector3( 0.2,  0, 0), 0.04)
	t_shake.tween_property(def_slot, "position", def_orig,                        0.04)

	# 防御方白色闪烁
	var t_flash := create_tween()
	for _i in 3:
		t_flash.tween_callback(func(): def_mat.albedo_color = Color.WHITE)
		t_flash.tween_interval(0.07)
		t_flash.tween_callback(func(): def_mat.albedo_color = def_orig_color)
		t_flash.tween_interval(0.07)

	await t_shake.finished
	_anim_for(def_slot).play_idle()

func faint_anim(slot: Node3D, mat: StandardMaterial3D) -> void:
	if sfx_faint:
		sfx_faint.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(slot, "position:y", slot.position.y - 2.0, 0.5) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	await tween.finished

func victory_flash() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(1, 1, 1, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 找到 UI CanvasLayer 添加覆盖层
	var ui := _find_ui()
	if ui:
		ui.add_child(overlay)
	var t := create_tween()
	t.tween_property(overlay, "color:a", 0.85, 0.1)
	t.tween_property(overlay, "color:a", 0.0,  0.4)
	await t.finished
	overlay.queue_free()

func _find_ui() -> Control:
	if get_parent():
		return get_parent().get_node_or_null("UI")
	return null

func _shake_camera(intensity: float, duration: float) -> void:
	if camera == null:
		return
	var origin := camera.position
	var tween  := create_tween()
	var steps  := int(duration / 0.06)
	for _i in steps:
		tween.tween_property(camera, "position",
			origin + Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0), 0.06)
	tween.tween_property(camera, "position", origin, 0.06)

func _play_move_sfx(move: MoveModel) -> void:
	if sfx_hit == null:
		return
	if move and move.get("sfx") and move.sfx:
		sfx_hit.stream = move.sfx
	else:
		sfx_hit.stream = load("res://moves/hit.wav")
	sfx_hit.play()
