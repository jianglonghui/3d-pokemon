## DungeonBuilder — 纯粹的场景构建，不含任何游戏逻辑
## 取代 world.gd 里的 _build_dungeon()
## 通过 get_light(id) 让 WorldDirector 引用灯光
extends Node

signal exit_zone_entered(body: Node3D)
signal zone_entered(zone_id: String)   # "zone01" / "zone02" / "zone03"

const T_FLOOR   := preload("res://assets/dungeon/floor_tile_large.gltf")
const T_WALL    := preload("res://assets/dungeon/wall.gltf")
const T_CORNER  := preload("res://assets/dungeon/wall_corner.gltf")
const T_PILLAR  := preload("res://assets/dungeon/pillar.gltf")
const T_DOORWAY := preload("res://assets/dungeon/wall_doorway.gltf")
const T_TORCH   := preload("res://assets/dungeon/torch.gltf")
const T_CANDLE  := preload("res://assets/dungeon/candle_triple.gltf")

var TILE: float = 2.0
var RW:   int   = 7
var RD:   int   = 11

var _root: Node3D = null
var _lights: Dictionary = {}   # { "altar_L": OmniLight3D, ... }
var _beacon: OmniLight3D = null
var _layout: FloorLayout = null

func build(layout: FloorLayout) -> void:
	_layout = layout
	TILE = layout.tile_size
	RW   = layout.room_width_tiles
	RD   = layout.room_depth_tiles

	_root = Node3D.new()
	_root.name = "DungeonTiles"
	add_child(_root)

	# 隐藏原始 BoxMesh / PlaneMesh 视觉节点
	for path in ["Floor/Mesh", "Ceiling",
			"WallNorth/Mesh", "WallSouth/Mesh", "WallWest/Mesh", "WallEast/Mesh",
			"Altar/Mesh",
			"PewL1", "PewL2", "PewL3", "PewR1", "PewR2", "PewR3", "Carpet"]:
		var n := get_parent().get_node_or_null(path)
		if n:
			n.visible = false

	_build_floor()
	_build_walls()
	_build_corners()
	_build_pillars()
	_build_torches()
	_build_candles()
	_build_arcana_area()
	_build_placeholder_props()
	_build_exit_zone()
	_build_zone_triggers()

# ── 构建方法 ──────────────────────────────────────────────────────────────────

func _build_floor() -> void:
	for ix in RW:
		for iz in RD:
			var x := (ix - (RW - 1) * 0.5) * TILE
			var z := (iz - (RD - 1) * 0.5) * TILE
			_place(T_FLOOR, Vector3(x, 0.0, z))

func _build_walls() -> void:
	var half_d := RD * TILE * 0.5   # 随 RD 自动算，现在是 18
	var half_w := RW * TILE * 0.5   # 随 RW 自动算，现在是  7

	# 北墙（中心为门洞）
	for ix in RW:
		var x := (ix - (RW - 1) * 0.5) * TILE
		if x == 0.0:
			_place(T_DOORWAY, Vector3(x, 0.0, -half_d))
		else:
			_place(T_WALL, Vector3(x, 0.0, -half_d))

	# 南墙
	for ix in RW:
		var x := (ix - (RW - 1) * 0.5) * TILE
		_place(T_WALL, Vector3(x, 0.0, half_d), Vector3(0.0, PI, 0.0))

	# 西墙
	for iz in RD:
		var z := (iz - (RD - 1) * 0.5) * TILE
		_place(T_WALL, Vector3(-half_w, 0.0, z), Vector3(0.0, PI * 0.5, 0.0))

	# 东墙
	for iz in RD:
		var z := (iz - (RD - 1) * 0.5) * TILE
		_place(T_WALL, Vector3(half_w, 0.0, z), Vector3(0.0, -PI * 0.5, 0.0))

func _build_corners() -> void:
	var half_d := RD * TILE * 0.5
	var half_w := RW * TILE * 0.5
	_place(T_CORNER, Vector3(-half_w, 0.0, -half_d), Vector3(0.0, 0.0,        0.0))
	_place(T_CORNER, Vector3( half_w, 0.0, -half_d), Vector3(0.0, PI * 0.5,  0.0))
	_place(T_CORNER, Vector3( half_w, 0.0,  half_d), Vector3(0.0, PI,        0.0))
	_place(T_CORNER, Vector3(-half_w, 0.0,  half_d), Vector3(0.0, -PI * 0.5, 0.0))

func _build_pillars() -> void:
	# 三道柱门，稀疏分布，感受纵深而非栅栏
	# x=±5 靠近侧墙，走廊中央 10 格宽度完全畅通
	# z=+10：加雷斯身侧（他站在柱门中央，凸显他的存在感）
	# z=+1 ：Zone02 入口（明暗交界，阿卡娜工作区开始）
	# z=-9 ：Zone03 最后一道门（Vex 就在门后 z=-10）
	for pos in [
		Vector3(-5.0, 0.0, +10.0), Vector3(5.0, 0.0, +10.0),
		Vector3(-5.0, 0.0,  +1.0), Vector3(5.0, 0.0,  +1.0),
		Vector3(-5.0, 0.0,  -9.0), Vector3(5.0, 0.0,  -9.0),
	]:
		_place(T_PILLAR, pos)

func _build_torches() -> void:
	# 南墙入口 + Zone01 第一段：暖橙，range=8
	for pos in [Vector3(-5.0, 2.2,  17.8), Vector3(5.0, 2.2,  17.8),
				Vector3(-6.8, 2.2,  13.0), Vector3(6.8, 2.2,  13.0)]:
		_place(T_TORCH, pos)
		var light := OmniLight3D.new()
		light.position     = pos + Vector3(0.0, 0.2, 0.0)
		light.light_color  = Color(1.0, 0.55, 0.15)
		light.light_energy = 1.8
		light.omni_range   = 8.0
		_root.add_child(light)

	# Zone01 深段（加雷斯附近）：range=7
	for pos in [Vector3(-6.8, 2.2,  7.0), Vector3(6.8, 2.2,  7.0)]:
		_place(T_TORCH, pos)
		var light := OmniLight3D.new()
		light.position     = pos + Vector3(0.0, 0.2, 0.0)
		light.light_color  = Color(1.0, 0.55, 0.15)
		light.light_energy = 1.6
		light.omni_range   = 7.0
		_root.add_child(light)

	# Zone02 侧墙：略暗，range=5，不照进 Zone03（Vex 在 z=-10）
	for pos in [Vector3(-6.8, 2.2, -2.0), Vector3(6.8, 2.2, -2.0)]:
		_place(T_TORCH, pos)
		var light := OmniLight3D.new()
		light.position     = pos + Vector3(0.0, 0.2, 0.0)
		light.light_color  = Color(1.0, 0.55, 0.15)
		light.light_energy = 1.4
		light.omni_range   = 5.0
		_root.add_child(light)

	# 北墙门洞两侧：刻意昏暗，只勾勒门洞轮廓
	for pos in [Vector3(-2.5, 2.2, -17.8), Vector3(2.5, 2.2, -17.8)]:
		_place(T_TORCH, pos)
		var light := OmniLight3D.new()
		light.position     = pos + Vector3(0.0, 0.2, 0.0)
		light.light_color  = Color(1.0, 0.38, 0.06)   # 暗红橙
		light.light_energy = 0.8
		light.omni_range   = 3.0
		_root.add_child(light)

	# 加雷斯身后的火把（可被战后调暗）
	_add_named_torch(Vector3(-1.5, 2.0, +7.5), "gareth_L")
	_add_named_torch(Vector3( 1.5, 2.0, +7.5), "gareth_R")

func _add_named_torch(pos: Vector3, id: String) -> void:
	_place(T_TORCH, pos)
	var light := OmniLight3D.new()
	light.position     = pos + Vector3(0.0, 0.2, 0.0)
	light.light_color  = Color(1.0, 0.55, 0.15)
	light.light_energy = 1.2
	light.omni_range   = 5.0
	_root.add_child(light)
	_lights[id] = light

func _build_candles() -> void:
	# 祭坛蜡烛（区域灯，随祭坛移到 z=-14）
	for pos in [Vector3(-2.5, 1.0, -14.0), Vector3(2.5, 1.0, -14.0)]:
		_place(T_CANDLE, pos)

	# 祭坛点光源（初始能量为 0，玩家进入 Zone03 时点亮）
	var altar_L := OmniLight3D.new()
	altar_L.position     = Vector3(-2.5, 2.2, -14.0)
	altar_L.light_color  = Color(1.0, 0.75, 0.35)
	altar_L.light_energy = 0.0
	altar_L.omni_range   = 6.0
	_root.add_child(altar_L)
	_lights["altar_L"] = altar_L

	var altar_R := OmniLight3D.new()
	altar_R.position     = Vector3(2.5, 2.2, -14.0)
	altar_R.light_color  = Color(1.0, 0.75, 0.35)
	altar_R.light_energy = 0.0
	altar_R.omni_range   = 6.0
	_root.add_child(altar_R)
	_lights["altar_R"] = altar_R

	# 信标灯：蓝光在 z=-17 门洞处，range=5，不照到 Vex（z=-10）
	_beacon = OmniLight3D.new()
	_beacon.position     = Vector3(0.0, 1.5, -17.0)
	_beacon.light_color  = Color(0.4, 0.8, 1.0)
	_beacon.light_energy = 2.0
	_beacon.omni_range   = 5.0
	_root.add_child(_beacon)
	_lights["beacon"] = _beacon

	# 区域填充灯：range=12，初始停在 Zone01 中心（z=+12）
	var zone_fill := OmniLight3D.new()
	zone_fill.position     = Vector3(0.0, 4.5, 12.0)
	zone_fill.light_color  = _layout.zone01_color
	zone_fill.light_energy = _layout.zone01_energy
	zone_fill.omni_range   = 12.0
	_root.add_child(zone_fill)
	_lights["zone_fill"] = zone_fill

## G6：阿卡娜研究区场景装饰（随阿卡娜移到 z=0）
func _build_arcana_area() -> void:
	# 三支烛台（不规则摆放，制造仪式感）
	_place(T_CANDLE, Vector3(-3.5, 0.0,  0.5))
	_place(T_CANDLE, Vector3(-3.0, 0.0, -0.5), Vector3(0.0, deg_to_rad(15.0), 0.0))
	_place(T_CANDLE, Vector3(-2.5, 0.0,  0.2))

	# 阿卡娜区域点光源（烛台总光晕，可被战后调色）
	var acl := OmniLight3D.new()
	acl.position     = Vector3(-3.0, 0.8,  0.0)
	acl.light_color  = Color(1.0, 0.816, 0.502)
	acl.light_energy = 1.5
	acl.omni_range   = 5.0
	_root.add_child(acl)
	_lights["arcana_candle"] = acl

	# 西墙拓片区火把（高度错落，营造考古感）
	for pos in [Vector3(-6.5, 1.8,  1.0), Vector3(-6.5, 2.5, -1.5), Vector3(-6.5, 2.0, -4.0)]:
		_place(T_TORCH, pos)
		var light := OmniLight3D.new()
		light.position     = pos + Vector3(0.3, 0.2, 0.0)
		light.light_color  = Color(1.0, 0.62, 0.25)
		light.light_energy = 1.0
		light.omni_range   = 4.0
		_root.add_child(light)

## G9：缺失资产的几何占位（TODO: 替换为真实 gltf）
func _build_placeholder_props() -> void:
	# ── Zone01：倒塌的火把架（战损叙事，暗示荒废多年） ─────────────────────
	var fallen := T_TORCH.instantiate()
	fallen.position = Vector3(-6.5, 0.2, 12.0)
	fallen.rotation = Vector3(0.0, PI * 0.3, PI * 0.5)
	_root.add_child(fallen)

	# ── Zone02：东侧书架（阿卡娜在 z=0，书架在她身后东侧） ─────────────────
	_ph_box(Vector3(0.4, 1.6, 0.8), Vector3(4.5, 0.8,  1.0), Color(0.30, 0.18, 0.10))
	_ph_box(Vector3(0.4, 1.6, 0.8), Vector3(4.5, 0.8, -0.5), Color(0.30, 0.18, 0.10))

	# Zone02：阿卡娜工作台（石台）
	_ph_box(Vector3(1.2, 0.5, 0.7), Vector3(-3.5, 0.25,  0.0), Color(0.45, 0.42, 0.40))

	# Zone02：工作台上的笔记本
	_ph_box(Vector3(0.30, 0.04, 0.22), Vector3(-3.5, 0.52, -0.05), Color(0.90, 0.87, 0.75))

	# Zone02/03 过渡：P7/P8 间蜡烛残迹（z=-4 附近）
	var wax := T_CANDLE.instantiate()
	wax.position = Vector3(0.0, -0.8, -5.0)
	_root.add_child(wax)

	# ── Zone03：下行楼梯（门洞之后，通往第二层） ────────────────────────────
	for i in 5:
		var step_pos := Vector3(0.0, -float(i) * 0.25, -18.6 - float(i) * 0.45)
		_ph_box(Vector3(2.2, 0.25, 0.44), step_pos, Color(0.25, 0.23, 0.22))

## 几何占位辅助：创建带纯色材质的 BoxMesh
func _ph_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	_root.add_child(mi)

func _build_zone_triggers() -> void:
	var z1 := _layout.zone01_limit   # e.g. +2.0
	var z2 := _layout.zone02_limit   # e.g. -4.0
	var half_depth := RD * TILE * 0.5  # e.g. 11.0
	var width      := (RW + 1) * TILE  # full span + margin

	# Zone01：z > z1，从 z1 到 南墙
	var z1_center := (z1 + half_depth) * 0.5
	var z1_size   := half_depth - z1
	_make_zone_trigger("zone01", Vector3(0.0, 1.25, z1_center),  Vector3(width, 2.5, z1_size))

	# Zone02：z2 < z ≤ z1
	var z2_center := (z1 + z2) * 0.5
	var z2_size   := z1 - z2
	_make_zone_trigger("zone02", Vector3(0.0, 1.25, z2_center),  Vector3(width, 2.5, z2_size))

	# Zone03：z ≤ z2，从 z2 到 北墙
	var z3_center := (z2 + (-half_depth)) * 0.5
	var z3_size   := z2 - (-half_depth)
	_make_zone_trigger("zone03", Vector3(0.0, 1.25, z3_center),  Vector3(width, 2.5, z3_size))

func _make_zone_trigger(zone_id: String, pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = zone_id
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	area.add_child(col)
	area.position = pos
	area.body_entered.connect(_on_zone_body_entered.bind(zone_id))
	_root.add_child(area)

func _on_zone_body_entered(body: Node3D, zone_id: String) -> void:
	if body.is_in_group("player"):
		zone_entered.emit(zone_id)

func _build_exit_zone() -> void:
	var exit_zone := Area3D.new()
	exit_zone.name = "ExitZone"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.5, 2.0)
	col.shape = box
	exit_zone.add_child(col)
	var half_d := RD * TILE * 0.5
	exit_zone.position = Vector3(0.0, 1.0, -half_d + 2.5)
	exit_zone.body_entered.connect(_on_exit_zone_entered)
	_root.add_child(exit_zone)

func _on_exit_zone_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		exit_zone_entered.emit(body)

# ── 公开接口 ──────────────────────────────────────────────────────────────────

## 让 WorldDirector 取得灯光引用，用于动态调整
func get_light(light_id: String) -> OmniLight3D:
	return _lights.get(light_id, null)

# ── 工具方法 ──────────────────────────────────────────────────────────────────

func _place(scene: PackedScene, pos: Vector3, euler: Vector3 = Vector3.ZERO) -> void:
	if scene == null:
		return
	var inst := scene.instantiate()
	inst.position = pos
	inst.rotation = euler
	_root.add_child(inst)
