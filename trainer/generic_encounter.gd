extends Game
class_name GenericEncounter

var text: TextModel

func _ready() -> void:
	if text:
		for line in text.text.split("\n"):
			print(line)  # Replace with info_box display when integrated
	done.emit()
