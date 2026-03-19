extends Resource
class_name PokemonModel

signal name_changed
@warning_ignore("unused_signal")
signal level_changed
signal hp_changed
signal max_hp_changed
signal xp_changed

@export var name: String:
	set(value):
		var old := name
		name = value
		name_changed.emit(old, value)
		changed.emit()

@export var hp: int:
	set(value):
		var old := hp
		hp = max(0, value)
		hp_changed.emit(old, hp)
		changed.emit()

@export var max_hp: int:
	set(value):
		var old := max_hp
		max_hp = value
		max_hp_changed.emit(old, value)
		changed.emit()

@export var xp: int = 1:
	set(value):
		var old := xp
		xp = value
		xp_changed.emit(old, value)
		changed.emit()

@export var exp_stat: int = 1
@export var attack: int = 1
@export var defense: int = 1
@export var speed: int = 1
@export var wild: bool = false
@export var moves: Array[Resource] = []
@export var moves_to_learn: Dictionary = {}
@export var battle_graphics: PackedScene

func is_dead() -> bool:
	return hp <= 0

func get_exp_if_beat() -> float:
	return float(get_level()) * float(exp_stat) * (1.0 if wild else 1.5)

const exp_table_ = {
	"fast": [100, 51, 21, 6, 0]
}

func get_level() -> int:
	for i in exp_table_.fast.size():
		if xp >= exp_table_.fast[i]:
			return exp_table_.fast.size() - i
	return 1

var level: int:
	get:
		return get_level()
	set(_v):
		pass
