## CameraDirector — 全局唯一摄像机控制权威
## 作为 Autoload，管理自己的 Camera3D，持久跨场景
## 三种模式：FOLLOW（跟随）/ CINEMATIC（过场）/ BATTLE（战斗）
extends Node

enum CameraMode { FOLLOW, CINEMATIC, BATTLE }

var mode: CameraMode = CameraMode.FOLLOW

var _camera: Camera3D = null

# FOLLOW 模式参数
var _follow_target: Node3D = null
var _follow_height: float  = 3.5
var _follow_dist: float    = 5.0
var _cam_yaw: float        = 0.0
var _height_tween: Tween   = null

const CAM_SMOOTH  := 4.0
const CAM_LOOK_UP := 1.0

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()

# ── 模式设置 ──────────────────────────────────────────────────────────────────

func set_mode(new_mode: CameraMode) -> void:
	mode = new_mode

## 进入跟随模式，摄像机跟着 target 移动
func follow(target: Node3D, height: float = 5.0, dist: float = 7.0) -> void:
	_follow_target = target
	_follow_height = height
	_follow_dist   = dist
	mode = CameraMode.FOLLOW

## 每帧由 player.gd 调用，更新朝向驱动摄像机 yaw
func update_face_dir(face_dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-face_dir.x, -face_dir.z)
	var diff       := wrapf(target_yaw - _cam_yaw, -PI, PI)
	_cam_yaw       += diff * min(CAM_SMOOTH * delta, 1.0)

func _process(_delta: float) -> void:
	if mode == CameraMode.FOLLOW and _camera and _follow_target:
		# 靠近出口（z < -8）时镜头缓慢升高，玩家显得渺小
		var eff_height := _follow_height
		var pz := _follow_target.global_position.z
		if pz < -13.0:
			var t := clampf((-13.0 - pz) / 4.0, 0.0, 1.0)
			eff_height += lerp(0.0, 4.0, t)

		var offset := Vector3(
			sin(_cam_yaw) * _follow_dist,
			eff_height,
			cos(_cam_yaw) * _follow_dist
		)
		_camera.global_position = _follow_target.global_position + offset
		_camera.look_at(
			_follow_target.global_position + Vector3(0, CAM_LOOK_UP, 0),
			Vector3.UP
		)

# ── 过场指令（awaitable）────────────────────────────────────────────────────

## 平滑移动摄像机到 pos，然后朝向 look_at_pos
func move_to(pos: Vector3, look_at_pos: Vector3, duration: float) -> void:
	mode = CameraMode.CINEMATIC
	var tween := create_tween()
	tween.tween_property(_camera, "global_position", pos, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	if _camera.global_position.distance_to(look_at_pos) > 0.01:
		_camera.look_at(look_at_pos, Vector3.UP)

## 推镜：摄像机向 target 靠近，最终距离 target amount 单位
func push_toward(target: Node3D, amount: float, duration: float) -> void:
	mode = CameraMode.CINEMATIC
	var dir  := (_camera.global_position - target.global_position).normalized()
	var dest := target.global_position + dir * amount
	var tween := create_tween()
	tween.tween_property(_camera, "global_position", dest, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	var look := target.global_position + Vector3(0, 1.0, 0)
	if _camera.global_position.distance_to(look) > 0.01:
		_camera.look_at(look, Vector3.UP)

## 瞬间切换机位（无过渡）
func cut_to(pos: Vector3, look_at_pos: Vector3) -> void:
	mode = CameraMode.CINEMATIC
	_camera.global_position = pos
	if _camera.global_position.distance_to(look_at_pos) > 0.01:
		_camera.look_at(look_at_pos, Vector3.UP)

## 缓慢过渡跟随高度（进入不同区域时调用）
func ease_follow_height(height: float, duration: float) -> void:
	if _height_tween:
		_height_tween.kill()
	_height_tween = create_tween()
	_height_tween.tween_property(self, "_follow_height", height, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

## 摄像机震动（战斗击中感）
func shake(intensity: float, duration: float) -> void:
	var origin := _camera.global_position
	var tween  := create_tween()
	var steps  := int(duration / 0.06)
	for _i in steps:
		var off := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			0.0
		)
		tween.tween_property(_camera, "global_position", origin + off, 0.06)
	tween.tween_property(_camera, "global_position", origin, 0.06)
	await tween.finished
