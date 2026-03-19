extends CanvasLayer

var visible_: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel.visible = false
	$Panel/VBox/Resume.pressed.connect(_resume)
	$Panel/VBox/Quit.pressed.connect(get_tree().quit)

func _resume() -> void:
	visible_ = false
	$Panel.visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		visible_ = not visible_
		$Panel.visible = visible_
		get_tree().paused = visible_
		if visible_:
			$Panel/VBox/Resume.grab_focus()
