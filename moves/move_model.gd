extends Resource
class_name MoveModel

enum Type {
	normal,
	fire,
	water,
	electric
}

@export var name: String = ""
@export var power: int = 1
@export var accuracy: float = 1.0
@export var type: Type = Type.normal
@export var sfx: AudioStream
@export var fx: PackedScene
