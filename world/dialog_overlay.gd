extends CanvasLayer

signal line_confirmed
signal _anim_done

@onready var label_: RichTextLabel  = $Panel/Label
@onready var btn_ok_: Button        = $Panel/OKButton
@onready var btn_leave_: Button     = $Panel/LeaveButton
@onready var sfx_: AudioStreamPlayer = $SFX

const TYPEWRITER_SPEED := 0.04
var _confirming := false
var _choice := true   # true = fight/confirm, false = leave/cancel
var _tween: Tween = null

func _ready() -> void:
	# Pokemon Classic.ttf 无 CJK 字形；直接加载 macOS 系统 CJK 字体
	var cjk := _load_cjk_font()
	label_.add_theme_font_override("normal_font", cjk)
	label_.add_theme_font_size_override("normal_font_size", 42)
	label_.add_theme_color_override("default_color", Color(0.92, 0.95, 1.0, 1))
	btn_ok_.pressed.connect(_confirm)
	btn_leave_.pressed.connect(_leave)

## 按优先级尝试 macOS 内置 CJK 字体，返回第一个成功加载的
func _load_cjk_font() -> Font:
	var paths := [
		"/System/Library/Fonts/PingFang.ttc",
		"/System/Library/Fonts/STHeiti Light.ttc",
		"/System/Library/Fonts/STHeiti Medium.ttc",
		"/System/Library/Fonts/Hiragino Sans GB.ttc",
	]
	for p in paths:
		if FileAccess.file_exists(p):
			var ff := FontFile.new()
			if ff.load_dynamic_font(p) == OK:
				return ff
	push_warning("DialogOverlay: 未找到 CJK 字体，中文可能显示为方块")
	return ThemeDB.fallback_font

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if label_.visible_ratio < 1.0:
			_skip_typewriter()
		# buttons visible: let the focused button handle Enter naturally
	elif event.is_action_pressed("ui_cancel"):
		if label_.visible_ratio < 1.0:
			_skip_typewriter()
		elif btn_leave_.visible:
			_leave()
		else:
			_confirm()

func _skip_typewriter() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	label_.visible_ratio = 1.0
	_anim_done.emit()

func _confirm() -> void:
	if not _confirming:
		_confirming = true
		_choice = true
		line_confirmed.emit()

func _leave() -> void:
	if not _confirming:
		_confirming = true
		_choice = false
		line_confirmed.emit()

# Plain info line — no Leave button (used for post-battle text etc.)
func show_line(text: String) -> void:
	_confirming = false
	label_.text = text
	label_.visible_ratio = 0.0
	btn_ok_.text = "OK [Enter]"
	btn_ok_.visible = false
	btn_leave_.visible = false

	_tween = create_tween()
	_tween.tween_property(label_, "visible_ratio", 1.0,
		label_.text.length() * TYPEWRITER_SPEED).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _anim_done.emit())
	_play_ticks(label_.text.length())
	await _anim_done

	btn_ok_.visible = true
	btn_ok_.grab_focus()
	await line_confirmed

# Encounter line — shows Fight + Leave buttons, returns true = fight
func show_encounter(text: String, confirm_label: String = "Fight [Enter]") -> bool:
	_confirming = false
	label_.text = text
	label_.visible_ratio = 0.0
	btn_ok_.text = confirm_label
	btn_ok_.visible = false
	btn_leave_.visible = false

	_tween = create_tween()
	_tween.tween_property(label_, "visible_ratio", 1.0,
		label_.text.length() * TYPEWRITER_SPEED).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _anim_done.emit())
	_play_ticks(label_.text.length())
	await _anim_done

	btn_ok_.visible = true
	btn_leave_.visible = true
	btn_ok_.grab_focus()

	await line_confirmed
	return _choice

func _play_ticks(char_count: int) -> void:
	for i in char_count:
		await get_tree().create_timer(TYPEWRITER_SPEED * i).timeout
		if sfx_ and not sfx_.playing:
			sfx_.play()

# ── 新增模式 ─────────────────────────────────────────────────────────────────

# 模式3：独白（无按钮，自动推进或等待玩家跳过）
# auto_seconds <= 0 表示等待玩家按确认键跳过
func show_monologue(text: String, auto_seconds: float = 0.0) -> void:
	_confirming = false
	label_.text = text
	label_.visible_ratio = 0.0
	btn_ok_.visible = false
	btn_leave_.visible = false

	_tween = create_tween()
	_tween.tween_property(label_, "visible_ratio", 1.0,
		label_.text.length() * TYPEWRITER_SPEED).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _anim_done.emit())
	await _anim_done

	if auto_seconds > 0.0:
		# 固定时间后自动消失，玩家可提前按键跳过
		var timer := get_tree().create_timer(auto_seconds)
		timer.timeout.connect(func(): line_confirmed.emit(), CONNECT_ONE_SHOT)
		await line_confirmed
	# else: 文字全部显示后直接返回（调用方决定何时继续）

# 模式4：纯等待（不显示任何 UI，只是等待 seconds 秒）
# 用于 Vex 战败后的 8 秒沉默
func wait_silent(seconds: float) -> void:
	label_.text = ""
	label_.visible_ratio = 0.0
	btn_ok_.visible = false
	btn_leave_.visible = false
	await get_tree().create_timer(seconds).timeout
