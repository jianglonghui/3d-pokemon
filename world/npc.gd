## NPCController — NPC 状态机
## 取代旧版只有可见/不可见的 npc.gd
## 管理单个 NPC 的所有状态和行为
extends Node3D
class_name NPCController

enum State { IDLE, WALKING, TALKING, DEFEATED, HIDING }

signal encounter
@warning_ignore("unused_signal")
signal beat

@export var trainer: TrainerModel:
	set(value):
		trainer = value

var _state: State = State.IDLE
var _animator: CharacterAnimator = null

func _ready() -> void:
	add_to_group("trainer")

	# 启动 idle 动画，面朝玩家
	var model := get_node_or_null("CharModel")
	if model:
		_animator = CharacterAnimator.new()
		_animator.setup(model)
		_animator.play_idle()
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var dir := ((players[0] as Node3D).global_position - global_position)
			dir.y = 0
			if dir.length() > 0.01:
				model.rotation.y = atan2(dir.x, dir.z)

	if has_node("DetectionArea"):
		$DetectionArea.body_entered.connect(_on_body_entered)

	# 已被击败则隐藏
	if trainer and GameState.is_defeated(trainer.id):
		visible = false
		if has_node("DetectionArea"):
			$DetectionArea.monitoring = false

	# 随行缚灵：在 NPC 右侧生成第一只缚灵的视觉
	_spawn_companion()

# ── 随行缚灵 ──────────────────────────────────────────────────────────────────

const _VISUAL_MAP := {
	"刺背": "res://pokemon/thornback_visual.gd",
	"幻灵": "res://pokemon/mystica_visual.gd",
	"冕灵": "res://pokemon/regalia_visual.gd",
	"壮者": "res://pokemon/brawler_visual.gd",
	"铁皮兽": "res://pokemon/ironhide_visual.gd",
}

func _spawn_companion() -> void:
	if trainer == null or trainer.pokemon.size() == 0:
		return
	var poke_name: String = (trainer.pokemon[0] as PokemonModel).name
	if not _VISUAL_MAP.has(poke_name):
		return
	var script: GDScript = load(_VISUAL_MAP[poke_name])
	var visual: Node3D = script.new()
	visual.name = "CompanionVisual"
	# 偏移到 NPC 右侧稍后方，缩小至 0.65 以符合随行比例
	visual.position = Vector3(0.85, 0.0, 0.35)
	visual.scale    = Vector3(0.65, 0.65, 0.65)
	add_child(visual)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		encounter.emit()

# ── 状态机 ────────────────────────────────────────────────────────────────────

func set_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.IDLE:
			if _animator:
				_animator.play_idle()
		State.WALKING:
			if _animator:
				_animator.play_walk()
		State.TALKING:
			if _animator:
				_animator.play_idle()   # 暂用 idle，后续可替换为专属动画
		State.DEFEATED:
			if _animator:
				_animator.play_death()
		State.HIDING:
			pass   # 由 disappear_into_shadow 驱动

# ── 移动接口（awaitable）──────────────────────────────────────────────────────

## NPC 走到 target_pos，duration 秒，结束后回到 IDLE
func walk_to(target_pos: Vector3, duration: float) -> void:
	set_state(State.WALKING)
	var model := get_node_or_null("CharModel")
	if model:
		var dir := (target_pos - global_position)
		dir.y = 0
		if dir.length() > 0.01:
			model.rotation.y = atan2(dir.x, dir.z)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	set_state(State.IDLE)

## 面朝某个节点
func face_toward(target: Node3D) -> void:
	var model := get_node_or_null("CharModel")
	if model == null:
		return
	var dir := (target.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.01:
		model.rotation.y = atan2(dir.x, dir.z)

## 面朝某个方向向量
func face_direction(dir: Vector3) -> void:
	var model := get_node_or_null("CharModel")
	if model and dir.length() > 0.01:
		model.rotation.y = atan2(dir.x, dir.z)

## Vex 专用：走进阴影中消失（awaitable）
func disappear_into_shadow(direction: Vector3) -> void:
	set_state(State.HIDING)
	if _animator:
		_animator.play_walk()
	var dest := global_position + direction.normalized() * 10.0
	var tween := create_tween()
	tween.tween_property(self, "global_position", dest, 2.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	queue_free()
