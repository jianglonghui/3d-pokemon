## battle_3d.gd — 战斗场景协调器（薄层）
## 创建 BattleGame（逻辑）和 BattleDirector（视觉），注入引用，启动战斗
extends Node3D

signal battle_done(player_won: bool)

@export var player_trainer: TrainerModel
@export var enemy_trainer: TrainerModel

# ── 3D 引用 ───────────────────────────────────────────────────────────────────
@onready var camera_:      Camera3D    = $Camera3D
@onready var player_slot_: Node3D      = $PlayerSlot
@onready var enemy_slot_:  Node3D      = $EnemySlot

# ── 音效 ──────────────────────────────────────────────────────────────────────
@onready var sfx_enter_:   AudioStreamPlayer = $SfxEnter
@onready var sfx_faint_:   AudioStreamPlayer = $SfxFaint
@onready var sfx_hit_:     AudioStreamPlayer = $SfxHit
@onready var sfx_begin_:   AudioStreamPlayer = $SfxBegin
@onready var sfx_confirm_: AudioStreamPlayer = $SfxConfirm

# ── UI 引用 ───────────────────────────────────────────────────────────────────
@onready var info_box_:    RichTextLabel = $UI/BottomBar/InfoBox
@onready var confirm_btn_: Button        = $UI/BottomBar/ConfirmButton
@onready var action_menu_: Control       = $UI/BottomBar/ActionMenu
@onready var move_menu_:   Control       = $UI/BottomBar/MoveMenu

@onready var e_name_:    Label       = $UI/EnemyPanel/NameLabel
@onready var e_hp_bar_:  ProgressBar = $UI/EnemyPanel/HPRow/HPBar
@onready var e_hp_num_:  Label       = $UI/EnemyPanel/HPNumLabel

@onready var p_name_:    Label       = $UI/PlayerPanel/NameLabel
@onready var p_hp_bar_:  ProgressBar = $UI/PlayerPanel/HPRow/HPBar
@onready var p_hp_num_:  Label       = $UI/PlayerPanel/HPNumLabel

# ── 材质常量 ──────────────────────────────────────────────────────────────────
const PLAYER_COLOR := Color(0.2, 0.5, 0.95)
const ENEMY_COLOR  := Color(0.9, 0.2, 0.2)

var player_mat_: StandardMaterial3D
var enemy_mat_:  StandardMaterial3D

# ── Player left-front, enemy right-back ──────────────────────────────────────
const PLAYER_ORIGIN := Vector3(-3.5, 0.95,  1.0)
const ENEMY_ORIGIN  := Vector3( 3.5, 0.95, -1.0)

# ── 设置 ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# 战斗 UI 中文字体：UI 是 CanvasLayer，把 Theme 分别挂到三个 Control 子节点
	var cjk := _load_cjk_font()
	if cjk:
		var theme := Theme.new()
		theme.set_font("font",        "Button",        cjk)
		theme.set_font("font",        "Label",         cjk)
		theme.set_font("normal_font", "RichTextLabel", cjk)
		theme.set_font_size("font_size",        "Button",        22)
		theme.set_font_size("font_size",        "Label",         18)
		theme.set_font_size("normal_font_size", "RichTextLabel", 26)
		for path in ["UI/EnemyPanel", "UI/PlayerPanel", "UI/BottomBar"]:
			var ctrl := get_node_or_null(path) as Control
			if ctrl:
				ctrl.theme = theme

	# 替换模型
	if enemy_trainer and enemy_trainer.battle_graphic:
		_swap_model(enemy_slot_, enemy_trainer.battle_graphic)
	if player_trainer and player_trainer.battle_graphic:
		_swap_model(player_slot_, player_trainer.battle_graphic)

	# 隐藏双方默认占位模型，换上缚灵专属视觉
	for slot in [player_slot_, enemy_slot_]:
		var dm: Node = slot.get_node_or_null("PokemonMesh")
		if dm:
			dm.visible = false

	# 玩家：铁皮兽
	var ironhide = preload("res://pokemon/ironhide_visual.gd").new()
	ironhide.name     = "IronhideVisual"
	ironhide.position = Vector3(0.0, -0.7, 0.0)
	player_slot_.add_child(ironhide)

	# 敌方：根据第一只缚灵名字选择视觉
	_spawn_enemy_spirit()

	# 战斗摄像机取代世界摄像机
	camera_.make_current()
	camera_.position = Vector3(0, 5, 8)
	camera_.look_at(Vector3(0, 1, 0), Vector3.UP)
	# 注：CameraDirector 仍是 Autoload 的活动摄像机；
	# 战斗场景使用自己的 Camera3D，它调用 make_current() 后在这个场景里生效

	# 复制材质（用于颜色闪烁）
	var enemy_mesh := _find_mesh(enemy_slot_.get_node("PokemonMesh"))
	var player_mesh := _find_mesh(player_slot_.get_node("PokemonMesh"))
	player_mat_ = _dup_mat(player_mesh, PLAYER_COLOR)
	enemy_mat_  = _dup_mat(enemy_mesh,  ENEMY_COLOR)

	# 朝向
	player_slot_.get_node("PokemonMesh").rotation.y =  PI * 0.5
	enemy_slot_.get_node("PokemonMesh").rotation.y  = -PI * 0.5

	# 初始 UI 状态
	action_menu_.visible = false
	move_menu_.visible   = false
	confirm_btn_.visible = false

	# 初始位置（离屏，等待滑入动画）
	player_slot_.position = PLAYER_ORIGIN + Vector3(-10, 0, 0)
	enemy_slot_.position  = ENEMY_ORIGIN  + Vector3( 10, 0, 0)

	sfx_begin_.play()

	# ── 创建 BattleGame ────────────────────────────────────────────────────
	var game := BattleGame.new()
	game.name = "BattleGame"
	add_child(game)

	game.player_trainer = player_trainer
	game.enemy_trainer  = enemy_trainer
	game.player_slot    = player_slot_
	game.enemy_slot     = enemy_slot_
	game.player_origin  = PLAYER_ORIGIN
	game.enemy_origin   = ENEMY_ORIGIN

	# UI 注入
	game.info_box    = info_box_
	game.confirm_btn = confirm_btn_
	game.action_menu = action_menu_
	game.move_menu   = move_menu_
	game.e_name      = e_name_
	game.e_hp_bar    = e_hp_bar_
	game.e_hp_num    = e_hp_num_
	game.p_name      = p_name_
	game.p_hp_bar    = p_hp_bar_
	game.p_hp_num    = p_hp_num_
	game.sfx_confirm = sfx_confirm_

	# ── 创建 BattleDirector ────────────────────────────────────────────────
	var director := BattleDirector.new()
	director.name = "BattleDirector"
	add_child(director)

	director.camera       = camera_
	director.player_slot  = player_slot_
	director.enemy_slot   = enemy_slot_
	director.player_mat   = player_mat_
	director.enemy_mat    = enemy_mat_
	director.sfx_enter    = sfx_enter_
	director.sfx_faint    = sfx_faint_
	director.sfx_hit      = sfx_hit_

	# 设置动画
	director.player_anim = CharacterAnimator.new()
	director.player_anim.setup(player_slot_.get_node("PokemonMesh"))
	director.player_anim.play_idle()

	director.enemy_anim = CharacterAnimator.new()
	director.enemy_anim.setup(enemy_slot_.get_node("PokemonMesh"))
	director.enemy_anim.play_idle()

	# 绑定视觉切换
	game.switch_visual_requested.connect(_on_switch_visual)

	# 绑定信号（BattleGame → BattleDirector）
	director.bind_game(game)

	# 监听战斗结束
	game.battle_ended.connect(_on_battle_ended)

	# 启动
	game.start()

func _on_battle_ended(player_won: bool) -> void:
	battle_done.emit(player_won)

const _VISUAL_SCRIPTS := {
	"铁皮兽": "res://pokemon/ironhide_visual.gd",
	"刺背":   "res://pokemon/thornback_visual.gd",
	"幻灵":   "res://pokemon/mystica_visual.gd",
	"冕灵":   "res://pokemon/regalia_visual.gd",
	"壮者":   "res://pokemon/brawler_visual.gd",
}

func _on_switch_visual(slot: Node3D, pokemon_name: String) -> void:
	# 移除旧视觉
	for child in slot.get_children():
		if child.name.ends_with("Visual"):
			child.queue_free()
	# 生成新视觉
	if not _VISUAL_SCRIPTS.has(pokemon_name):
		return
	var script: GDScript = load(_VISUAL_SCRIPTS[pokemon_name])
	var visual: Node3D = script.new()
	visual.name  = pokemon_name + "Visual"
	visual.position = Vector3(0.0, -0.7, 0.0)
	slot.add_child(visual)

func _spawn_enemy_spirit() -> void:
	var spirit_name := ""
	if enemy_trainer and enemy_trainer.pokemon.size() > 0:
		spirit_name = (enemy_trainer.pokemon[0] as PokemonModel).name

	var visual: Node3D
	match spirit_name:
		"刺背":
			visual = preload("res://pokemon/thornback_visual.gd").new()
			visual.name = "ThornbackVisual"
		"幻灵":
			visual = preload("res://pokemon/mystica_visual.gd").new()
			visual.name = "MysticaVisual"
		"冕灵":
			visual = preload("res://pokemon/regalia_visual.gd").new()
			visual.name = "RegaliaVisual"
		"壮者":
			visual = preload("res://pokemon/brawler_visual.gd").new()
			visual.name = "BrawlerVisual"
		_:
			return   # 其他缚灵暂无专属视觉，保留隐藏状态

	visual.position = Vector3(0.0, -0.7, 0.0)
	enemy_slot_.add_child(visual)

func _load_cjk_font() -> Font:
	for p in ["/System/Library/Fonts/PingFang.ttc",
			"/System/Library/Fonts/STHeiti Light.ttc",
			"/System/Library/Fonts/Hiragino Sans GB.ttc"]:
		if FileAccess.file_exists(p):
			var ff := FontFile.new()
			if ff.load_dynamic_font(p) == OK:
				return ff
	return null

# ── 工具方法 ──────────────────────────────────────────────────────────────────

func _swap_model(slot: Node3D, graphic: PackedScene) -> void:
	if graphic == null:
		return
	var old := slot.get_node_or_null("PokemonMesh")
	if old:
		old.free()   # 立即释放，防止名称冲突
	var inst := graphic.instantiate()
	inst.name = "PokemonMesh"
	slot.add_child(inst)

static func _find_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null

func _dup_mat(mesh: MeshInstance3D, fallback_color: Color) -> StandardMaterial3D:
	if mesh == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = fallback_color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return m
	var mat: Material = mesh.get_surface_override_material(0)
	if mat == null:
		mat = mesh.get_active_material(0)
	var result: StandardMaterial3D
	if mat is StandardMaterial3D:
		result = (mat as StandardMaterial3D).duplicate()
	else:
		result = StandardMaterial3D.new()
		result.albedo_color = fallback_color
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.set_surface_override_material(0, result)
	return result
