extends Resource
class_name TrainerModel

@export var id: String = ""
@export var name: String = ""
@export var pokemon: Array[Resource] = []
@export var items: Array[Resource] = []
@export var is_player: bool = false
@export var world_encounter: Resource
@export var battle_begin: Resource
@export var battle_loose: Resource
@export var world_loose: Resource
@export var beat_flag_mutations: Array[Resource] = []
@export var loose_flag_mutations: Array[Resource] = []
@export var battle_graphic: PackedScene
@export var world_graphic: PackedScene

var active_pokemon: PokemonModel = null

func is_dead() -> bool:
	for p in pokemon:
		if p.hp > 0:
			return false
	return true
