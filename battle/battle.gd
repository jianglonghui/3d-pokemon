extends Control

signal done

@export var player: TrainerModel
@export var enemy: TrainerModel

# ── UI refs ───────────────────────────────────────────────────────────────────
@onready var info_box_: RichTextLabel    = $BottomBar/InfoBox
@onready var confirm_btn_: Button        = $BottomBar/ConfirmButton
@onready var action_menu_: Control       = $BottomBar/ActionMenu

@onready var enemy_sprite_: ColorRect    = $EnemySide/Sprite
@onready var enemy_name_: Label          = $EnemySide/InfoPanel/NameLabel
@onready var enemy_level_: Label         = $EnemySide/InfoPanel/LevelLabel
@onready var enemy_hp_label_: Label      = $EnemySide/InfoPanel/HPLabel
@onready var enemy_hp_bar_: ProgressBar  = $EnemySide/InfoPanel/HPBar

@onready var player_sprite_: ColorRect   = $PlayerSide/Sprite
@onready var player_name_: Label         = $PlayerSide/InfoPanel/NameLabel
@onready var player_level_: Label        = $PlayerSide/InfoPanel/LevelLabel
@onready var player_hp_label_: Label     = $PlayerSide/InfoPanel/HPLabel
@onready var player_hp_bar_: ProgressBar = $PlayerSide/InfoPanel/HPBar

# ── State ─────────────────────────────────────────────────────────────────────
var waiting_confirm_ := false
var action_chosen_: int = -1

func _ready() -> void:
	action_menu_.visible = false
	confirm_btn_.visible = false
	confirm_btn_.pressed.connect(_on_confirm_pressed)
	action_menu_.get_node("Fight").pressed.connect(_on_fight)
	action_menu_.get_node("Run").pressed.connect(_on_run)
	_hide_pokemon_ui()
	game_()

# ── Pokemon UI ────────────────────────────────────────────────────────────────

func _hide_pokemon_ui() -> void:
	enemy_name_.text = ""
	player_name_.text = ""

func _refresh_enemy(mon: PokemonModel) -> void:
	enemy_name_.text = mon.name
	enemy_level_.text = "Lv.%d" % mon.level
	enemy_hp_label_.text = "HP: %d / %d" % [max(0, mon.hp), mon.max_hp]
	enemy_hp_bar_.max_value = mon.max_hp
	enemy_hp_bar_.value = max(0, mon.hp)
	_tint_hp_bar(enemy_hp_bar_, mon.hp, mon.max_hp)

func _refresh_player(mon: PokemonModel) -> void:
	player_name_.text = mon.name
	player_level_.text = "Lv.%d" % mon.level
	player_hp_label_.text = "HP: %d / %d" % [max(0, mon.hp), mon.max_hp]
	player_hp_bar_.max_value = mon.max_hp
	player_hp_bar_.value = max(0, mon.hp)
	_tint_hp_bar(player_hp_bar_, mon.hp, mon.max_hp)

func _tint_hp_bar(bar: ProgressBar, hp: int, max_hp: int) -> void:
	var ratio := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var c: Color
	if ratio > 0.5:
		c = Color(0.2, 0.85, 0.2)
	elif ratio > 0.25:
		c = Color(0.95, 0.75, 0.1)
	else:
		c = Color(0.9, 0.15, 0.15)
	bar.modulate = c

# ── Animations ────────────────────────────────────────────────────────────────

func _animate_hp(bar: ProgressBar, label: Label, mon: PokemonModel) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "value", max(0, mon.hp), 0.5).set_ease(Tween.EASE_OUT)
	await tween.finished
	label.text = "HP: %d / %d" % [max(0, mon.hp), mon.max_hp]
	_tint_hp_bar(bar, mon.hp, mon.max_hp)

func _shake(node: Control) -> void:
	var origin := node.position
	var tween := create_tween()
	tween.tween_property(node, "position", origin + Vector2(12, 0), 0.05)
	tween.tween_property(node, "position", origin - Vector2(12, 0), 0.05)
	tween.tween_property(node, "position", origin + Vector2(8, 0),  0.04)
	tween.tween_property(node, "position", origin - Vector2(8, 0),  0.04)
	tween.tween_property(node, "position", origin,                  0.04)
	await tween.finished

func _flash(node: Control) -> void:
	var tween := create_tween().set_loops(3)
	tween.tween_property(node, "modulate", Color(1, 1, 1, 0.1), 0.07)
	tween.tween_property(node, "modulate", Color(1, 1, 1, 1.0), 0.07)
	await tween.finished

# ── Text / confirm ────────────────────────────────────────────────────────────

func show_text(text: String) -> void:
	info_box_.text = "[color=white]" + text + "[/color]"

func show_confirm(text: String) -> void:
	show_text(text)
	confirm_btn_.visible = true
	waiting_confirm_ = true
	await _wait_confirm()
	confirm_btn_.visible = false

func _wait_confirm() -> void:
	while waiting_confirm_:
		await get_tree().process_frame

func _on_confirm_pressed() -> void:
	waiting_confirm_ = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and waiting_confirm_:
		waiting_confirm_ = false

# ── Action menu ────────────────────────────────────────────────────────────────

func show_action_menu() -> void:
	action_chosen_ = -1
	action_menu_.visible = true
	while action_chosen_ == -1:
		await get_tree().process_frame
	action_menu_.visible = false

func _on_fight() -> void:
	action_chosen_ = 0

func _on_run() -> void:
	action_chosen_ = 1

# ── Damage formula ─────────────────────────────────────────────────────────────

func damage_(atk: PokemonModel, def_: PokemonModel, move: MoveModel) -> int:
	var t1 := (2.0 * atk.level / 5.0) + 2.0
	var t2 := float(atk.attack) / float(def_.defense)
	return int((t1 * move.power * t2) / 50.0 + 2.0)

# ── Apply attack with animations ───────────────────────────────────────────────

func do_attack(
		atk: PokemonModel, def_: PokemonModel,
		atk_sprite: Control, def_sprite: Control,
		def_hp_bar: ProgressBar, def_hp_label: Label,
		atk_label: String) -> void:

	if atk.moves.is_empty():
		return

	var move: MoveModel = atk.moves[0]
	show_text("%s%s used %s!" % [atk_label, atk.name, move.name])

	# Attacker lunges forward
	var atk_origin := atk_sprite.position
	var lunge_dir := Vector2(1 if atk_label == "" else -1, 0) * 30
	var tween := create_tween()
	tween.tween_property(atk_sprite, "position", atk_origin + lunge_dir, 0.1)
	tween.tween_property(atk_sprite, "position", atk_origin, 0.15)
	await tween.finished

	# Defender shake + flash + HP drain
	var crit := randf() > 0.9
	var dmg := damage_(atk, def_, move)
	if crit:
		dmg = dmg * 2
	def_.hp -= dmg

	await _shake(def_sprite)
	await _flash(def_sprite)
	await _animate_hp(def_hp_bar, def_hp_label, def_)

	if crit:
		await show_confirm("Critical hit!")

# ── Main battle flow ───────────────────────────────────────────────────────────

func game_() -> void:
	if enemy == null:
		await show_confirm("(No trainer data assigned to NPC)")
		done.emit()
		return

	await show_confirm("%s wants to fight!" % enemy.name)

	# Set active pokemon
	if enemy.pokemon.size() > 0:
		enemy.active_pokemon = enemy.pokemon[0]
	if player != null and player.pokemon.size() > 0:
		player.active_pokemon = player.pokemon[0]

	# Show intro
	if enemy.active_pokemon:
		_refresh_enemy(enemy.active_pokemon)
		await show_confirm("%s sent out %s!" % [enemy.name, enemy.active_pokemon.name])
	if player != null and player.active_pokemon:
		_refresh_player(player.active_pokemon)
		await show_confirm("Go! %s!" % player.active_pokemon.name)

	while true:
		var e_mon: PokemonModel = enemy.active_pokemon
		var p_mon: PokemonModel = player.active_pokemon if player else null

		show_text("What will you do?")
		await show_action_menu()

		# ── Run ──────────────────────────────────────────────────────────────
		if action_chosen_ == 1:
			await show_confirm("Got away safely!")
			break

		# ── Fight ────────────────────────────────────────────────────────────
		if p_mon and not p_mon.moves.is_empty():
			await do_attack(
				p_mon, e_mon,
				player_sprite_, enemy_sprite_,
				enemy_hp_bar_, enemy_hp_label_,
				"")
		else:
			await show_confirm("No moves available!")

		# Enemy fainted?
		if e_mon.is_dead():
			await _faint_anim(enemy_sprite_)
			await show_confirm("Enemy %s fainted!" % e_mon.name)
			if p_mon:
				var exp_gained := int(e_mon.get_exp_if_beat())
				p_mon.xp += exp_gained
				await show_confirm("%s gained %d EXP!" % [p_mon.name, exp_gained])
				_refresh_player(p_mon)
			if enemy.is_dead():
				await show_confirm("%s is defeated!" % enemy.name)
				break
			var idx := enemy.pokemon.find(e_mon) + 1
			if idx < enemy.pokemon.size():
				enemy.active_pokemon = enemy.pokemon[idx]
				_refresh_enemy(enemy.active_pokemon)
				await show_confirm("%s sent out %s!" % [enemy.name, enemy.active_pokemon.name])
			continue

		# Enemy attacks back
		if not e_mon.moves.is_empty():
			await do_attack(
				e_mon, p_mon if p_mon else e_mon,
				enemy_sprite_, player_sprite_,
				player_hp_bar_, player_hp_label_,
				"Enemy ")

		# Player fainted?
		if p_mon and p_mon.is_dead():
			await _faint_anim(player_sprite_)
			await show_confirm("%s fainted!" % p_mon.name)
			if player == null or player.is_dead():
				await show_confirm("You blacked out!")
				break

	show_text("")
	done.emit()

func _faint_anim(sprite: Control) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y + 80, 0.4)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await tween.finished
