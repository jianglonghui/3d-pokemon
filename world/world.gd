## world.gd — 世界场景根节点（薄协调层）
## 流程控制委托给 WorldDirector
## 场景构建委托给 DungeonBuilder
## 游戏状态通过 GameState（Autoload）持久化
extends Node3D

@onready var player_: CharacterBody3D = $Player
@onready var music_:  AudioStreamPlayer = $Music

const PLAYER_TRAINER  := preload("res://trainer/player_trainer.tres")
const BATTLE_SCENE    := preload("res://battle/battle_scene.tscn")
const FLOOR_LAYOUT_01_PATH := "res://data/floors/floor_01.tres"

var director_: Node      # WorldDirector
var builder_:  Node      # DungeonBuilder
var _exiting   := false

func _ready() -> void:
	music_.play()

	# ── 加载楼层数据 ────────────────────────────────────────────────────────
	var layout: FloorLayout = _load_layout(GameState.current_floor)

	# ── DungeonBuilder：构建地牢 ───────────────────────────────────────────
	builder_ = preload("res://world/dungeon_builder.gd").new()
	builder_.name = "DungeonBuilder"
	add_child(builder_)
	builder_.build(layout)
	builder_.exit_zone_entered.connect(_on_exit_zone_entered)

	# ── WorldDirector：编排流程 ────────────────────────────────────────────
	director_ = preload("res://world/world_director.gd").new()
	director_.name = "WorldDirector"
	add_child(director_)
	director_.setup(player_)
	director_.setup_lighting(builder_, layout)
	builder_.zone_entered.connect(director_.on_zone_entered)
	director_.battle_requested.connect(_on_battle_requested)
	director_.floor_advance_requested.connect(_on_floor_advance)

	# 连接所有 NPC 的 encounter 信号到 WorldDirector
	for npc in get_tree().get_nodes_in_group("trainer"):
		npc.encounter.connect(director_.run_encounter.bind(npc))

	# 玩家随行缚灵：根据 trainer 数据动态生成，左右各一
	_spawn_player_companions()

	# 入场建立镜头（不等待，作为协程并发运行）
	_run_entry_shot()

# ── 战斗流程 ──────────────────────────────────────────────────────────────────

func _on_battle_requested(npc: Node3D) -> void:
	player_.pause_controls = true
	get_tree().paused = true
	visible = false

	var battle: Node3D = BATTLE_SCENE.instantiate()
	battle.process_mode   = Node.PROCESS_MODE_ALWAYS
	battle.enemy_trainer  = npc.trainer
	battle.player_trainer = _get_player_trainer()
	get_tree().root.add_child(battle)

	var player_won: bool = await battle.battle_done
	battle.queue_free()

	visible = true
	get_tree().paused = false

	# 战后过场（WorldDirector 处理）
	await director_.run_post_battle(npc, player_won)

	# 标记 NPC 为已击败（Vex 可能已通过 disappear_into_shadow 销毁自己）
	if not is_instance_valid(npc):
		player_.pause_controls = false
		_check_all_defeated()
		return
	if npc.trainer:
		GameState.defeat(npc.trainer.id)
	npc.beat.emit()
	npc.visible = false
	if npc.has_node("DetectionArea"):
		npc.get_node("DetectionArea").monitoring = false

	player_.pause_controls = false
	_check_all_defeated()

func _check_all_defeated() -> void:
	var alive := get_tree().get_nodes_in_group("trainer").filter(
		func(n): return is_instance_valid(n) and n.visible)
	if alive.is_empty():
		await get_tree().create_timer(0.5).timeout
		var dialog := preload("res://world/dialog_overlay.tscn").instantiate()
		add_child(dialog)
		await dialog.show_line("你击败了所有人！")
		await dialog.show_line("地下城陷入沉寂……")
		dialog.queue_free()
		music_.stop()

# ── 出口区域 ──────────────────────────────────────────────────────────────────

func _on_exit_zone_entered(body: Node3D) -> void:
	if _exiting or not body.is_in_group("player"):
		return

	# 检查是否全部击败
	var alive := get_tree().get_nodes_in_group("trainer").filter(func(n): return n.visible)
	if not alive.is_empty():
		player_.pause_controls = true
		var dialog := preload("res://world/dialog_overlay.tscn").instantiate()
		add_child(dialog)
		await dialog.show_line("击败所有敌人后方可通行！")
		dialog.queue_free()
		player_.pause_controls = false
		return

	_exiting = true
	await director_.run_gate_sequence()

func _on_floor_advance() -> void:
	get_tree().reload_current_scene()

# ── 工具 ──────────────────────────────────────────────────────────────────────

## 入场建立镜头：南端高处俯视整个地窟 3 秒，然后切跟随
## direction/01_exploration.md — "玩家只是其中一个很小的点"
func _run_entry_shot() -> void:
	player_.pause_controls = true
	# 南端高处，俯视向北，玩家已在画面南侧
	CameraDirector.cut_to(
		Vector3(0.0, 16.0, 22.0),   # 南端更高更远，地窟更深，玩家更渺小
		Vector3(0.0,  0.0,  0.0)    # 看向地窟中轴
	)
	await get_tree().create_timer(3.0).timeout
	CameraDirector.follow(player_)
	player_.pause_controls = false

const _VISUAL_MAP := {
	"铁皮兽": "res://pokemon/ironhide_visual.gd",
	"刺背":   "res://pokemon/thornback_visual.gd",
	"幻灵":   "res://pokemon/mystica_visual.gd",
	"冕灵":   "res://pokemon/regalia_visual.gd",
	"壮者":   "res://pokemon/brawler_visual.gd",
}

# 随行位置：最多2只，左右对称；超出2只则排成行
const _COMPANION_OFFSETS := [
	Vector3(-1.2, 0.0,  0.4),   # 左前
	Vector3( 1.2, 0.0,  0.4),   # 右前
	Vector3(-1.2, 0.0, -0.5),   # 左后（预留）
	Vector3( 1.2, 0.0, -0.5),   # 右后（预留）
]

func _spawn_player_companions() -> void:
	var trainer := PLAYER_TRAINER
	var idx := 0
	for poke in trainer.pokemon:
		if idx >= _COMPANION_OFFSETS.size():
			break
		var poke_name: String = (poke as PokemonModel).name
		if not _VISUAL_MAP.has(poke_name):
			idx += 1
			continue
		var script: GDScript = load(_VISUAL_MAP[poke_name])
		var visual: Node3D = script.new()
		visual.name = "Companion_%s" % poke_name
		visual.position = _COMPANION_OFFSETS[idx]
		player_.add_child(visual)
		idx += 1

func _load_layout(floor_num: int) -> FloorLayout:
	var path := "res://data/floors/floor_%02d.tres" % floor_num
	if ResourceLoader.exists(path):
		return load(path) as FloorLayout
	return load(FLOOR_LAYOUT_01_PATH) as FloorLayout

func _get_player_trainer() -> TrainerModel:
	var t := PLAYER_TRAINER.duplicate(false)
	var arr: Array[Resource] = []
	for p in PLAYER_TRAINER.pokemon:
		var copy: PokemonModel = p.duplicate(true)
		copy.hp = copy.max_hp
		arr.append(copy)
	t.pokemon = arr
	return t
