extends CharacterBody3D

## 格子移动：左右旋转，上下前进/后退
## 摄像机控制已委托给 CameraDirector（Autoload）

const TILE_SIZE := 2.0
const SPEED     := 10.0

@onready var ray_: RayCast3D = $RayCast3D

var moving_to_: Vector3 = Vector3(INF, INF, INF)
var pause_controls := false
var _animator: CharacterAnimator = null

var face_dir_ := Vector3(0, 0, -1)   # 初始朝北（-Z）
var rotate_timer_ := 0.0
const ROTATE_REPEAT := 0.36

func _ready() -> void:
	add_to_group("player")
	var model := get_node_or_null("CharModel")
	if model:
		model.rotation.y = atan2(face_dir_.x, face_dir_.z)
		_animator = CharacterAnimator.new()
		_animator.setup(model)
		_animator.play_idle()
	# 注册到 CameraDirector，进入跟随模式
	CameraDirector.follow(self)

func floor_vec3(v: Vector3) -> Vector3:
	return Vector3(
		round(v.x / TILE_SIZE) * TILE_SIZE,
		v.y,
		round(v.z / TILE_SIZE) * TILE_SIZE
	)

func _rotate_face(clockwise: bool) -> void:
	if clockwise:
		face_dir_ = Vector3(-face_dir_.z, 0, face_dir_.x)
	else:
		face_dir_ = Vector3(face_dir_.z,  0, -face_dir_.x)
	var model := get_node_or_null("CharModel")
	if model:
		model.rotation.y = atan2(face_dir_.x, face_dir_.z)

func _physics_process(delta: float) -> void:
	# ── 左右旋转 ─────────────────────────────────────────────────────────────
	rotate_timer_ = max(rotate_timer_ - delta, 0.0)
	if not pause_controls:
		var turn_right := Input.is_action_pressed("ui_right")
		var turn_left  := Input.is_action_pressed("ui_left")
		if turn_right or turn_left:
			if Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_left") \
					or rotate_timer_ == 0.0:
				_rotate_face(turn_right)
				rotate_timer_ = ROTATE_REPEAT
		else:
			rotate_timer_ = 0.0

	# ── 前后移动 ─────────────────────────────────────────────────────────────
	var walk_dir := Vector3.ZERO
	if not pause_controls:
		if Input.is_action_pressed("ui_up"):
			walk_dir = face_dir_
		elif Input.is_action_pressed("ui_down"):
			walk_dir = -face_dir_

	if moving_to_ == Vector3(INF, INF, INF) and walk_dir != Vector3.ZERO:
		ray_.target_position = walk_dir * TILE_SIZE
		ray_.force_raycast_update()
		if not ray_.is_colliding():
			moving_to_ = floor_vec3(global_position) + walk_dir * TILE_SIZE

	# ── 执行格子移动 ──────────────────────────────────────────────────────────
	if moving_to_ != Vector3(INF, INF, INF):
		var towards := global_position.move_toward(moving_to_, SPEED * delta)
		velocity = (towards - global_position) / delta
		move_and_slide()
		if _animator and not _animator.is_playing("Walking_A"):
			_animator.play_walk()
		if global_position.distance_to(moving_to_) <= 0.05:
			global_position = moving_to_
			moving_to_      = Vector3(INF, INF, INF)
	else:
		velocity = Vector3.ZERO
		if _animator and not _animator.is_playing("Idle_A"):
			_animator.play_idle()

	# ── 重力 ─────────────────────────────────────────────────────────────────
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		move_and_slide()

	# ── 委托摄像机 yaw 给 CameraDirector ────────────────────────────────────
	CameraDirector.update_face_dir(face_dir_, delta)
