## WorldDirector — 世界内所有过场序列的编排者
## 取代 world.gd 里散落的 _on_encounter / _show_world_dialog
## 由 world.gd 实例化并配置
extends Node

## 外部注入
var player: CharacterBody3D = null

## 信号给 world.gd
signal battle_requested(npc: Node3D)
signal floor_advance_requested()

var _dialog: CanvasLayer = null   # 持久化 dialog overlay 实例
var _builder: Node = null         # DungeonBuilder 引用
var _layout: FloorLayout = null   # 当前楼层数据

# ── 外部接口 ──────────────────────────────────────────────────────────────────

func setup(p: CharacterBody3D) -> void:
	player = p

func setup_lighting(builder: Node, layout: FloorLayout) -> void:
	_builder = builder
	_layout  = layout

## 遭遇触发入口：根据 trainer.id 派发到对应序列
func run_encounter(npc: Node3D) -> void:
	var trainer_id: String = npc.trainer.id if npc.trainer else ""
	var fight := false

	_open_dialog()

	match trainer_id:
		"rude_man":   # 加雷斯
			var seq := preload("res://world/sequences/seq_gareth.gd").new()
			add_child(seq)
			fight = await seq.execute(_make_ctx(npc))
			seq.queue_free()

		"red":        # 阿卡娜
			var seq := preload("res://world/sequences/seq_arcana.gd").new()
			add_child(seq)
			fight = await seq.execute(_make_ctx(npc))
			seq.queue_free()

		"dead_man":   # Vex
			var seq := preload("res://world/sequences/seq_vex.gd").new()
			add_child(seq)
			fight = await seq.execute(_make_ctx(npc))
			seq.queue_free()

		_:
			# 默认：直接显示遭遇对话框
			if npc.trainer and npc.trainer.world_encounter:
				fight = await _dialog.show_encounter(npc.trainer.world_encounter.text)
			else:
				fight = await _dialog.show_encounter("A wild trainer appears!")

	_close_dialog()

	if fight:
		battle_requested.emit(npc)

## 战斗结束后的过场（只在玩家获胜时运行实质内容）
func run_post_battle(npc: Node3D, player_won: bool) -> void:
	if not player_won:
		# 玩家输了——目前没有额外过场
		return

	var trainer_id: String = npc.trainer.id if npc.trainer else ""
	_open_dialog()

	var npc_ctrl := npc as NPCController

	match trainer_id:
		"dead_man":   # Vex — 她站着，没有倒下；8秒沉默；让路；消失
			# 注意：Vex 没有进入 DEFEATED 姿态——她站着
			# 这是刻意的：前两个角色都倒地了，她没有
			var np: Vector3 = npc.global_position
			var pp: Vector3 = player.global_position

			# 平视广角（不俯视）— 强调她站着没有被"压下去"
			await CameraDirector.move_to(
				np + Vector3(4.5, 1.5, 3.5),
				np + Vector3(0.0, 1.2, 0.0),
				0.6
			)

			# 祭坛蜡烛缓缓熄灭（1.5s）
			_tween_light(_get_light("altar_L"), Color(1.0, 0.75, 0.35), 0.0, 1.5)
			_tween_light(_get_light("altar_R"), Color(1.0, 0.75, 0.35), 0.0, 1.5)

			# 8秒沉默 — 她在想某件事，镜头不动，不要用音乐填满
			await _dialog.wait_silent(8.0)

			# 她说话，切她的视线向下看铁皮兽
			if npc_ctrl:
				npc_ctrl.set_state(NPCController.State.TALKING)
			await _dialog.show_monologue("你的铁皮兽背上的印记。", 2.5)

			# 切 — 她的视线：俯视铁皮兽背甲 0.5秒
			CameraDirector.cut_to(
				pp + Vector3(0.0, 1.6, 0.8),
				pp + Vector3(0.0, 0.5, 0.0)
			)
			await get_tree().create_timer(0.5).timeout

			# 切回广角 — 她侧身让路，蓝光第一次清晰地出现在画面里
			# 她挡着终点，她让开了
			if npc_ctrl:
				npc_ctrl.face_direction(Vector3(1.0, 0.0, 0.0))   # 侧身向东
			await CameraDirector.move_to(
				np + Vector3(3.0, 1.5, 2.0),
				Vector3(0.0, 1.2, -10.5),   # 看向beacon蓝光方向
				0.8
			)

			await _dialog.show_line("在你到达底层之前，去弄清楚它是什么。不是为了我，是为了你自己。")
			if npc_ctrl:
				await npc_ctrl.disappear_into_shadow(Vector3(-1.0, 0.0, -1.0).normalized())
			# 信标脉冲：亮→极亮→熄
			var beacon := _get_light("beacon")
			if beacon:
				var tw1 := create_tween()
				tw1.tween_property(beacon, "light_energy", 5.0, 0.5)
				await tw1.finished
				var tw2 := create_tween()
				tw2.tween_property(beacon, "light_energy", 0.0, 1.0)

		"rude_man":   # 加雷斯 — 广角俯视 → 5秒推镜独白 → 他的主观视角目送
			if npc_ctrl:
				npc_ctrl.set_state(NPCController.State.DEFEATED)
			_tween_light(_get_light("gareth_L"), Color(1.0, 0.55, 0.15), 0.6, 2.0)
			_tween_light(_get_light("gareth_R"), Color(1.0, 0.55, 0.15), 0.6, 2.0)

			var np: Vector3 = npc.global_position
			var pp: Vector3 = player.global_position

			# 广角俯视 1秒 — 客观呈现结果，不戏剧化
			CameraDirector.move_to(
				np + Vector3(0.0, 8.0, 5.0),
				np + Vector3(0.0, 0.0, 0.0),
				0.5
			)
			await get_tree().create_timer(1.0).timeout

			# 5秒缓慢推镜至面部特写 — 他单膝跪地，镜头降至0.8m等高
			# 同步说台词：推镜过程中说完，"去吧"时镜头停下
			CameraDirector.move_to(
				np + Vector3(0.0, 0.8, 1.5),
				np + Vector3(0.0, 1.0, 0.0),
				5.0
			)
			await _dialog.show_monologue("比我当年强。", 2.5)
			await _dialog.show_monologue("你比我当年进来时，强得多。", 2.5)
			await _dialog.show_line("前方第二个石柱转角，地板有裂缝，别踩。那是我埋的——不是为了你，是以防更糟糕的东西从深处上来。")
			await _dialog.show_line("……去吧。")

			# 切到加雷斯主观视角 — 他跪着，仰望玩家背影
			# 这是全片第一次用角色主观视角
			CameraDirector.cut_to(
				np + Vector3(0.0, 0.4, 0.3),
				pp + Vector3(0.0, 1.2, 0.0)
			)
			await get_tree().create_timer(3.0).timeout   # 看着走廊，镜头留在原地

		"red":        # 阿卡娜 — 笔记本→印记 match cut → 被看穿的确认
			if npc_ctrl:
				npc_ctrl.set_state(NPCController.State.DEFEATED)
			_tween_light(_get_light("arcana_candle"), Color(0.6, 0.7, 1.0), 0.7, 3.0)

			var np: Vector3 = npc.global_position
			var pp: Vector3 = player.global_position

			# 广角俯视 1秒
			CameraDirector.move_to(
				np + Vector3(0.0, 7.0, 4.0),
				np + Vector3(0.0, 0.0, 0.0),
				0.5
			)
			await get_tree().create_timer(1.0).timeout

			# 切 — 笔记本特写（工作台俯拍，镜头慢慢推近）
			CameraDirector.cut_to(
				Vector3(-3.5, 1.8, 0.3),
				Vector3(-3.5, 0.5, 0.0)
			)
			await CameraDirector.move_to(
				Vector3(-3.5, 0.9, 0.3),
				Vector3(-3.5, 0.5, 0.0),
				1.5
			)

			# 硬切 — 铁皮兽背甲印记（与笔记本同角度，match cut）
			CameraDirector.cut_to(
				pp + Vector3(0.0, 1.4, 0.8),
				pp + Vector3(0.0, 0.6, 0.0)
			)
			await get_tree().create_timer(1.5).timeout

			# 越过玩家肩膀看阿卡娜 — 她在确认，不在问
			await CameraDirector.move_to(
				pp + Vector3(0.6, 1.7, -0.2),
				np + Vector3(0.0, 1.4,  0.0),
				0.5
			)
			await _dialog.show_line("有意思。你的铁皮兽，在你受击的一瞬间，做了一个不属于它本能的动作。")
			await _dialog.show_line("普通的缚灵契约是双向的——人保护灵，灵为人战。但有一种更古老的契约，灵不只是在战，它在……守护某种东西。不是你的身体。")
			# 她把笔记本递过来——切回笔记本特写
			CameraDirector.cut_to(
				Vector3(-3.5, 0.9, 0.3),
				Vector3(-3.5, 0.5, 0.0)
			)
			await get_tree().create_timer(1.0).timeout
			# 切回肩后
			await CameraDirector.move_to(
				pp + Vector3(0.6, 1.7, -0.2),
				np + Vector3(0.0, 1.4,  0.0),
				0.4
			)
			await _dialog.show_line("这个图案出现在一百七十年前的一份地窟档案里。那头缚灵的契约者在第七层失踪了，没有记录他的名字。")
			# 玩家没有回答
			await _dialog.wait_silent(2.0)
			await _dialog.show_line("你知道这个印记的意思，对吗。")
			# 也不是在问，3秒沉默
			await _dialog.wait_silent(3.0)
			await _dialog.show_line("继续走。前方不远处是Vex的领地。她不会解释任何事，但你们会有一次短暂的对话——在战斗之前，注意她说的每一个词。")

		_:
			if npc.trainer and npc.trainer.world_loose:
				await _show_text_resource(npc.trainer.world_loose)

	# 所有战后序列结束，镜头归还给玩家跟随
	CameraDirector.follow(player)
	_close_dialog()

## 石门过场序列（全部击败后进入下一层）
func run_gate_sequence() -> void:
	_open_dialog()
	player.pause_controls = true

	# 询问是否前进（保留选择）
	var proceed: bool = await _dialog.show_encounter(
		"前方是通往第 %d 层的通道。\n继续深入吗？" % (GameState.current_floor + 1),
		"继续 [Enter]"
	)

	if not proceed:
		_close_dialog()
		player.pause_controls = false
		return

	# 石门过场
	var seq := preload("res://world/sequences/seq_gate.gd").new()
	add_child(seq)
	await seq.execute({
		"player": player,
		"camera": CameraDirector,
		"dialog": _dialog,
	})
	seq.queue_free()

	_close_dialog()
	floor_advance_requested.emit()

## 玩家进入新区域时触发（由 DungeonBuilder 的 zone_entered 信号连接）
func on_zone_entered(zone_id: String) -> void:
	var fill := _get_light("zone_fill")
	if fill == null or _layout == null:
		return
	# 各区域填充灯停靠位置（与 dungeon_builder 里的 range=10 配合）
	# 灯只照亮玩家所在区域，其他区域保持黑暗
	var fill_pos := {
		"zone01": Vector3(0.0, 4.5, +12.0),
		"zone02": Vector3(0.0, 4.5,   0.0),
		"zone03": Vector3(0.0, 4.5, -12.0),
	}

	match zone_id:
		"zone01":
			_tween_light(fill, _layout.zone01_color, _layout.zone01_energy, 1.5)
			CameraDirector.ease_follow_height(3.5, 2.0)
		"zone02":
			_tween_light(fill, _layout.zone02_color, _layout.zone02_energy, 1.5)
			CameraDirector.ease_follow_height(3.2, 2.0)
		"zone03":
			_tween_light(fill, _layout.zone03_color, _layout.zone03_energy, 1.5)
			CameraDirector.ease_follow_height(3.0, 2.0)
			# 玩家进入 Zone03，祭坛蜡烛才点亮（Vex "在此久待"的感觉）
			_tween_light(_get_light("altar_L"), Color(1.0, 0.75, 0.35), 1.2, 2.0)
			_tween_light(_get_light("altar_R"), Color(1.0, 0.75, 0.35), 1.2, 2.0)

	# 把填充灯平滑移到当前区域中心
	if fill_pos.has(zone_id):
		var tw := create_tween()
		tw.tween_property(fill, "position", fill_pos[zone_id], 2.0) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

# ── 内部工具 ──────────────────────────────────────────────────────────────────

func _get_light(id: String) -> OmniLight3D:
	if _builder == null or not _builder.has_method("get_light"):
		return null
	return _builder.get_light(id)

func _tween_light(light: OmniLight3D, color: Color, energy: float, duration: float) -> void:
	if not is_instance_valid(light):
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(light, "light_color",  color,  duration)
	tw.tween_property(light, "light_energy", energy, duration)

func _make_ctx(npc: Node3D) -> Dictionary:
	return {
		"player": player,
		"npc":    npc,
		"camera": CameraDirector,
		"dialog": _dialog,
	}

func _open_dialog() -> void:
	if _dialog and is_instance_valid(_dialog):
		return
	_dialog = preload("res://world/dialog_overlay.tscn").instantiate()
	get_parent().add_child(_dialog)

func _close_dialog() -> void:
	if _dialog and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null

func _show_text_resource(text_res: Resource) -> void:
	if text_res == null:
		return
	var text_model = text_res as Object
	if text_model == null or not text_model.get("text"):
		return
	for line in text_model.text.split("\n"):
		if line.strip_edges() != "":
			await _dialog.show_line(line.strip_edges())
