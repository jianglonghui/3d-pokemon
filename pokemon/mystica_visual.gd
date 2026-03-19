## MysticaVisual — 幻灵：半透明等离子态，多层叠加，形态飘忽
extends Node3D

var _time: float   = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = position.y
	_build_outer()
	_build_mid()
	_build_core()
	_build_wisps()

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 1.4) * 0.18
	rotation.y += delta * 0.5

# ── 三层叠加球（additive 混合，中心透、边缘亮） ───────────────────────────────

func _build_outer() -> void:
	_add_layer(0.48, _ghost_shader(Color(0.35, 0.60, 1.0), 1.4, 2.2))

func _build_mid() -> void:
	_add_layer(0.32, _ghost_shader(Color(0.55, 0.78, 1.0), 1.2, 3.0))

func _add_layer(radius: float, mat: ShaderMaterial) -> void:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)
	mi.material_override = mat
	add_child(mi)

func _ghost_shader(color: Color, wobble: float, speed: float) -> ShaderMaterial:
	var mat    := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
uniform vec4 col : source_color = vec4(0.4, 0.65, 1.0, 1.0);
uniform float wobble_amt = 1.4;
uniform float wobble_spd = 2.2;
void vertex() {
	float w = sin(TIME * wobble_spd + VERTEX.y * 5.0 + VERTEX.x * 3.0) * 0.028 * wobble_amt;
	VERTEX.x += w;
	VERTEX.z += w * 0.7;
}
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.4);
	float pulse = 0.7 + 0.3 * sin(TIME * 3.5);
	ALBEDO   = col.rgb;
	ALPHA    = clamp(fr * pulse * 0.9, 0.0, 1.0);
	EMISSION = col.rgb * fr * 1.8 * pulse;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("col",        color)
	mat.set_shader_parameter("wobble_amt", wobble)
	mat.set_shader_parameter("wobble_spd", speed)
	return mat

# ── 实心冷白核心 ──────────────────────────────────────────────────────────────

func _build_core() -> void:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)
	var mat := StandardMaterial3D.new()
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color               = Color(0.9, 0.95, 1.0, 0.0)
	mat.emission_enabled           = true
	mat.emission                   = Color(0.7, 0.88, 1.0)
	mat.emission_energy_multiplier = 5.0
	mi.material_override = mat
	add_child(mi)

# ── 全方向等离子粒子 ──────────────────────────────────────────────────────────

func _build_wisps() -> void:
	var p := CPUParticles3D.new()
	p.emitting               = true
	p.amount                 = 32
	p.lifetime               = 1.8
	p.position               = Vector3(0.0, 0.7, 0.0)
	p.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.46
	p.direction              = Vector3(0.0, 1.0, 0.0)
	p.spread                 = 180.0
	p.gravity                = Vector3(0.0, 0.04, 0.0)
	p.initial_velocity_min   = 0.04
	p.initial_velocity_max   = 0.22
	p.scale_amount_min       = 0.03
	p.scale_amount_max       = 0.08
	p.color                  = Color(0.5, 0.78, 1.0, 0.9)
	add_child(p)

func on_hit() -> void:
	var p := CPUParticles3D.new()
	p.one_shot               = true
	p.emitting               = true
	p.amount                 = 20
	p.lifetime               = 0.6
	p.position               = Vector3(0.0, 0.7, 0.0)
	p.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.spread                 = 180.0
	p.gravity                = Vector3(0.0, 0.2, 0.0)
	p.initial_velocity_min   = 0.5
	p.initial_velocity_max   = 2.0
	p.scale_amount_min       = 0.04
	p.scale_amount_max       = 0.10
	p.color                  = Color(0.6, 0.85, 1.0, 1.0)
	add_child(p)
	await get_tree().create_timer(p.lifetime + 0.1).timeout
	p.queue_free()
