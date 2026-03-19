extends Resource
class_name FlagMutation

@export var flag: String = ""
@export var value: bool = true

func apply() -> void:
	FlagDB.flags[flag] = value
