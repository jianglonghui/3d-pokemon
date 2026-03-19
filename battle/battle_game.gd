## BattleGame — 战斗逻辑层
## 负责：伤害计算、回合顺序、胜负判定、UI数据更新
## 与 BattleDirector 通过信号通信，不直接调用其方法
extends Node
class_name BattleGame

# ── 向 BattleDirector 发出的视觉请求信号 ──────────────────────────────────────
signal enter_requested(slot: Node3D, origin: Vector3)
signal attack_requested(atk_slot: Node3D, atk_origin: Vector3, def_slot: Node3D, move: MoveModel)
signal faint_requested(slot: Node3D)
signal victory_requested()

# ── BattleDirector 完成后回发的确认信号 ──────────────────────────────────────
signal enter_visual_done
signal attack_visual_done
signal faint_visual_done
signal victory_visual_done

# ── 最终结果 ──────────────────────────────────────────────────────────────────
signal battle_ended(player_won: bool)

# ── 训练师 ────────────────────────────────────────────────────────────────────
var player_trainer: TrainerModel = null
var enemy_trainer: TrainerModel  = null

# ── 槽位原点（由 battle_3d.gd 注入）──────────────────────────────────────────
var player_slot: Node3D = null
var enemy_slot: Node3D  = null
var player_origin := Vector3(-3.5, 0.95,  1.0)
var enemy_origin  := Vector3( 3.5, 0.95, -1.0)

# ── UI 引用（由 battle_3d.gd 注入）──────────────────────────────────────────
var info_box: RichTextLabel = null
var confirm_btn: Button     = null
var action_menu: Control    = null
var move_menu: Control      = null
var e_name: Label           = null
var e_hp_bar: ProgressBar   = null
var e_hp_num: Label         = null
var p_name: Label           = null
var p_hp_bar: ProgressBar   = null
var p_hp_num: Label         = null
var sfx_confirm: AudioStreamPlayer = null

# ── 交互状态 ──────────────────────────────────────────────────────────────────
var waiting_confirm := false
var action_chosen   := -1
var move_chosen: MoveModel = null
var move_done       := false

# ── 入口 ──────────────────────────────────────────────────────────────────────

func start() -> void:
	confirm_btn.pressed.connect(func(): waiting_confirm = false)
	action_menu.get_node("Fight").pressed.connect(func(): action_chosen = 0)
	action_menu.get_node("Run").pressed.connect(func(): action_chosen = 1)
	game_()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and waiting_confirm:
		waiting_confirm = false

# ── UI 助手 ──────────────────────────────────────────────────────────────────

func show_text(txt: String) -> void:
	info_box.text = "[color=white]" + txt + "[/color]"

func show_confirm(txt: String) -> void:
	show_text(txt)
	if sfx_confirm:
		sfx_confirm.play()
	confirm_btn.visible = true
	confirm_btn.grab_focus()
	waiting_confirm = true
	while waiting_confirm:
		await get_tree().process_frame
	confirm_btn.visible = false

func show_action_menu() -> void:
	action_chosen = -1
	action_menu.visible = true
	action_menu.get_node("Fight").grab_focus()
	while action_chosen == -1:
		await get_tree().process_frame
	action_menu.visible = false

func show_move_menu(pokemon: PokemonModel) -> MoveModel:
	for child in move_menu.get_children():
		child.queue_free()
	move_chosen = null
	move_done   = false
	for move in pokemon.moves:
		var m := move as MoveModel
		if m == null:
			continue
		var btn := Button.new()
		btn.text = m.name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_move_picked.bind(m))
		move_menu.add_child(btn)
		btn.add_theme_font_size_override("font_size", 20)
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_move_back)
	move_menu.add_child(back_btn)
	back_btn.add_theme_font_size_override("font_size", 20)
	move_menu.visible = true
	if move_menu.get_child_count() > 0:
		move_menu.get_child(0).grab_focus()
	while not move_done:
		await get_tree().process_frame
	move_menu.visible = false
	for child in move_menu.get_children():
		child.queue_free()
	return move_chosen

func _on_move_picked(m: MoveModel) -> void:
	move_chosen = m
	move_done   = true

func _on_move_back() -> void:
	move_done = true

# ── HP 面板 ──────────────────────────────────────────────────────────────────

func refresh_panels() -> void:
	if enemy_trainer and enemy_trainer.active_pokemon:
		var m := enemy_trainer.active_pokemon
		e_name.text       = m.name
		e_hp_bar.max_value = m.max_hp
		e_hp_bar.value    = max(0, m.hp)
		e_hp_num.text     = "%d / %d" % [max(0, m.hp), m.max_hp]
		_tint_bar(e_hp_bar, m.hp, m.max_hp)
	if player_trainer and player_trainer.active_pokemon:
		var m := player_trainer.active_pokemon
		p_name.text       = m.name
		p_hp_bar.max_value = m.max_hp
		p_hp_bar.value    = max(0, m.hp)
		p_hp_num.text     = "%d / %d" % [max(0, m.hp), m.max_hp]
		_tint_bar(p_hp_bar, m.hp, m.max_hp)

func _tint_bar(bar: ProgressBar, hp: int, max_hp: int) -> void:
	var r := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	if r > 0.5:
		bar.modulate = Color(0.2, 0.9, 0.2)
	elif r > 0.25:
		bar.modulate = Color(0.95, 0.75, 0.1)
	else:
		bar.modulate = Color(0.95, 0.15, 0.15)

func animate_hp(bar: ProgressBar, num_label: Label, mon: PokemonModel) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "value", max(0, mon.hp), 0.5).set_ease(Tween.EASE_OUT)
	await tween.finished
	num_label.text = "%d / %d" % [max(0, mon.hp), mon.max_hp]
	_tint_bar(bar, mon.hp, mon.max_hp)

# ── 伤害公式 ─────────────────────────────────────────────────────────────────

func calc_damage(atk: PokemonModel, def_: PokemonModel, move: MoveModel) -> int:
	var t1 := (2.0 * atk.level / 5.0) + 2.0
	var t2 := float(atk.attack) / float(def_.defense)
	return int((t1 * move.power * t2) / 50.0 + 2.0)

# ── 主战斗循环 ────────────────────────────────────────────────────────────────

func game_() -> void:
	if enemy_trainer == null:
		await show_confirm("(No trainer assigned)")
		battle_ended.emit(false)
		return

	# ── 开场白 ─────────────────────────────────────────────────────────────
	if enemy_trainer.battle_begin and enemy_trainer.battle_begin.get("text"):
		for line in enemy_trainer.battle_begin.text.split("\n"):
			if line.strip_edges() != "":
				await show_confirm(line.strip_edges())
	else:
		await show_confirm("%s 发出了挑战！" % enemy_trainer.name)

	if enemy_trainer.pokemon.size() > 0:
		enemy_trainer.active_pokemon = enemy_trainer.pokemon[0]
	if player_trainer and player_trainer.pokemon.size() > 0:
		player_trainer.active_pokemon = player_trainer.pokemon[0]

	# 双方登场动画（信号驱动）
	enter_requested.emit(enemy_slot,  enemy_origin)
	await enter_visual_done
	enter_requested.emit(player_slot, player_origin)
	await enter_visual_done

	refresh_panels()

	if enemy_trainer.active_pokemon:
		await show_confirm("%s 派出了 %s！" % [enemy_trainer.name, enemy_trainer.active_pokemon.name])
	if player_trainer and player_trainer.active_pokemon:
		await show_confirm("%s，上！" % player_trainer.active_pokemon.name)

	# ── 战斗循环 ──────────────────────────────────────────────────────────
	var player_won := false
	while true:
		var e_mon: PokemonModel = enemy_trainer.active_pokemon
		var p_mon: PokemonModel = player_trainer.active_pokemon if player_trainer else null

		show_text("下达指令？")
		await show_action_menu()

		# 撤退
		if action_chosen == 1:
			await show_confirm("成功撤退！")
			break

		# 出击
		if action_chosen == 0:
			var move: MoveModel = null
			if p_mon and p_mon.moves.size() > 1:
				move = await show_move_menu(p_mon)
			elif p_mon and not p_mon.moves.is_empty():
				move = p_mon.moves[0] as MoveModel

			if move == null:
				continue

			show_text("%s 使用了 %s！" % [p_mon.name, move.name])
			await get_tree().create_timer(0.4).timeout

			var dmg := calc_damage(p_mon, e_mon, move)
			var crit := randf() > 0.9
			if crit:
				dmg = dmg * 2
			e_mon.hp -= dmg

			# 请求 BattleDirector 播放攻击动画
			attack_requested.emit(player_slot, player_origin, enemy_slot, move)
			await attack_visual_done

			if crit:
				await show_confirm("要害一击！")

			# HP 动画
			await animate_hp(e_hp_bar, e_hp_num, e_mon)

		# 敌方缚灵倒下？
		if e_mon.is_dead():
			faint_requested.emit(enemy_slot)
			await faint_visual_done
			await show_confirm("对方的 %s 倒下了！" % e_mon.name)
			if p_mon:
				var exp_gained := int(e_mon.get_exp_if_beat())
				p_mon.xp += exp_gained
				refresh_panels()
				await show_confirm("%s 获得了 %d 经验值！" % [p_mon.name, exp_gained])
			if enemy_trainer.is_dead():
				player_won = true
				await show_confirm("%s 败北了！" % enemy_trainer.name)
				break
			# 下一只缚灵登场
			var idx := enemy_trainer.pokemon.find(e_mon) + 1
			if idx < enemy_trainer.pokemon.size():
				enemy_trainer.active_pokemon = enemy_trainer.pokemon[idx]
				enemy_slot.position = enemy_origin + Vector3(10, 0, 0)
				refresh_panels()
				enter_requested.emit(enemy_slot, enemy_origin)
				await enter_visual_done
				await show_confirm("%s 派出了 %s！" % [enemy_trainer.name, enemy_trainer.active_pokemon.name])
			continue

		# 敌方反击
		if not e_mon.moves.is_empty():
			var move: MoveModel = e_mon.moves[0] as MoveModel
			show_text("对方的 %s 使用了 %s！" % [e_mon.name, move.name])
			await get_tree().create_timer(0.4).timeout

			var dmg := calc_damage(e_mon, p_mon if p_mon else e_mon, move)
			if p_mon:
				p_mon.hp -= dmg
				attack_requested.emit(enemy_slot, enemy_origin, player_slot, move)
				await attack_visual_done
				await animate_hp(p_hp_bar, p_hp_num, p_mon)

		# 玩家缚灵倒下？
		if p_mon and p_mon.is_dead():
			faint_requested.emit(player_slot)
			await faint_visual_done
			await show_confirm("%s 倒下了！" % p_mon.name)
			if player_trainer == null or player_trainer.is_dead():
				await show_confirm("你的缚灵全部倒下了……")
				break

	# ── 胜利处理 ──────────────────────────────────────────────────────────
	if player_won:
		victory_requested.emit()
		await victory_visual_done
		if enemy_trainer.battle_loose and enemy_trainer.battle_loose.get("text"):
			for line in enemy_trainer.battle_loose.text.split("\n"):
				if line.strip_edges() != "":
					await show_confirm(line.strip_edges())
		await show_confirm("战斗胜利！")

	show_text("")
	battle_ended.emit(player_won)
