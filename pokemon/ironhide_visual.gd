## IronhideVisual — 铁皮兽：金属甲壳，防御极强，呼吸感沉重
extends Node3D

var _time: float   = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = position.y
	_build_shell()
	_build_armor_rings()
	_build_glow()

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 0.55) * 0.025
	rotation.y += delta * 0.18

# ── 活体金属主球（ShaderMaterial：呼吸 + 表面微震 + Fresnel 钢蓝边缘） ────

func _build_shell() -> void:
	# 实心内核
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.40
	mesh.height = 0.80
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)
	mi.material_override = _body_shader(
		Color(0.52, 0.58, 0.64),   # 钢铁色
		Color(0.30, 0.42, 0.60),   # 钢蓝发光
		0.55, 1.2, 0.012           # 呼吸速度、发光强度、顶点抖动量
	)
	add_child(mi)

	# 外层柔光壳（additive，Fresnel 边缘蓝）
	_add_glow_shell(0.44, Color(0.30, 0.50, 0.90), 0.55)

func _build_armor_rings() -> void:
	var configs := [
		Vector3(0.0,        0.0,   0.0),
		Vector3(PI * 0.35,  0.0,   0.0),
		Vector3(0.0,        0.0,   PI * 0.35),
	]
	for rot in configs:
		var mi   := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius  = 0.37
		mesh.outer_radius  = 0.44
		mesh.rings         = 24
		mesh.ring_segments = 12
		mi.mesh     = mesh
		mi.position = Vector3(0.0, 0.7, 0.0)
		mi.rotation = rot
		var mat := StandardMaterial3D.new()
		mat.albedo_color               = Color(0.28, 0.32, 0.36)
		mat.metallic                   = 0.8
		mat.roughness                  = 0.15
		mat.emission_enabled           = true
		mat.emission                   = Color(0.15, 0.18, 0.22)
		mat.emission_energy_multiplier = 0.8
		mi.material_override = mat
		add_child(mi)

func _build_glow() -> void:
	var light := OmniLight3D.new()
	light.position     = Vector3(0.0, 0.7, 0.0)
	light.light_color  = Color(0.75, 0.85, 1.0)
	light.light_energy = 0.35
	light.omni_range   = 2.2
	add_child(light)

func on_hit() -> void:
	var p := CPUParticles3D.new()
	p.one_shot               = true
	p.emitting               = true
	p.amount                 = 22
	p.lifetime               = 0.55
	p.position               = Vector3(0.0, 0.7, 0.0)
	p.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.42
	p.direction              = Vector3(0.0, 1.0, 0.0)
	p.spread                 = 180.0
	p.gravity                = Vector3(0.0, -5.0, 0.0)
	p.initial_velocity_min   = 1.5
	p.initial_velocity_max   = 4.0
	p.scale_amount_min       = 0.02
	p.scale_amount_max       = 0.05
	p.color                  = Color(1.0, 0.82, 0.2, 1.0)
	add_child(p)
	await get_tree().create_timer(p.lifetime + 0.1).timeout
	p.queue_free()

# ── 共用工具 ──────────────────────────────────────────────────────────────────

func _body_shader(base: Color, emit: Color, breathe_spd: float, emit_str: float, wobble: float) -> ShaderMaterial:
	var mat    := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;
uniform vec4 base_col  : source_color = vec4(0.5, 0.6, 0.65, 1.0);
uniform vec4 emit_col  : source_color = vec4(0.3, 0.42, 0.6, 1.0);
uniform float emit_str  = 1.2;
uniform float breathe   = 0.55;
uniform float wob       = 0.012;
void vertex() {
	float b = 1.0 + sin(TIME * breathe) * 0.018;
	VERTEX *= b;
	float r = sin(TIME * 2.8 + VERTEX.y * 5.0 + VERTEX.x * 3.7) * wob;
	VERTEX += NORMAL * r;
}
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.6);
	float pulse = 0.72 + 0.28 * sin(TIME * 1.8);
	ALBEDO      = base_col.rgb;
	ROUGHNESS   = 0.28;
	METALLIC    = 0.65;
	EMISSION    = emit_col.rgb * (fr * 0.55 + 0.45) * pulse * emit_str;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("base_col",  base)
	mat.set_shader_parameter("emit_col",  emit)
	mat.set_shader_parameter("emit_str",  emit_str)
	mat.set_shader_parameter("breathe",   breathe_spd)
	mat.set_shader_parameter("wob",       wobble)
	return mat

func _add_glow_shell(radius: float, color: Color, alpha_scale: float) -> void:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)
	var mat    := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
uniform vec4 col : source_color = vec4(0.3, 0.5, 0.9, 1.0);
uniform float alpha_scale = 0.55;
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float pulse = 0.6 + 0.4 * sin(TIME * 2.2);
	ALBEDO  = col.rgb;
	ALPHA   = clamp(fr * pulse * alpha_scale, 0.0, 1.0);
	EMISSION = col.rgb * fr * pulse * 1.2;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("col",         color)
	mat.set_shader_parameter("alpha_scale", alpha_scale)
	mi.material_override = mat
	add_child(mi)
