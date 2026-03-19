## BrawlerVisual — 壮者：庞大黑红肉山，力量之象征，表面暗火涌动
extends Node3D

var _time: float   = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = position.y
	_build_body()
	_build_muscles()
	_build_glow()

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 0.6) * 0.04
	rotation.y += delta * 0.12

# ── 暗红熔岩主球（慢速大幅呼吸 + 裂缝暗火 Fresnel） ─────────────────────────

func _build_body() -> void:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.50
	mesh.height = 1.00
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)
	mi.material_override = _body_shader(
		Color(0.45, 0.05, 0.05),   # 深暗红
		Color(0.60, 0.08, 0.02),   # 暗橙红内焰
		0.6, 1.2, 0.028            # 沉重呼吸、发光强度、大幅顶点涌动
	)
	add_child(mi)

	# 外层暗红熔岩光晕
	_add_glow_shell(0.56, Color(0.70, 0.12, 0.04), 0.50)

# ── 肌肉凸起 ──────────────────────────────────────────────────────────────────

func _build_muscles() -> void:
	var muscle_mat := StandardMaterial3D.new()
	muscle_mat.albedo_color               = Color(0.40, 0.06, 0.06)
	muscle_mat.roughness                  = 0.85
	muscle_mat.metallic                   = 0.0
	muscle_mat.emission_enabled           = true
	muscle_mat.emission                   = Color(0.35, 0.04, 0.04)
	muscle_mat.emission_energy_multiplier = 0.7

	var bumps := [
		Vector3( 0.45,  0.90,  0.20),
		Vector3(-0.42,  0.85, -0.15),
		Vector3( 0.20,  0.50,  0.48),
		Vector3(-0.18,  0.50, -0.46),
		Vector3( 0.38,  1.10, -0.22),
		Vector3(-0.35,  1.05,  0.30),
	]
	var sizes := [0.18, 0.16, 0.17, 0.15, 0.14, 0.16]

	for j in bumps.size():
		var mi   := MeshInstance3D.new()
		var s    := SphereMesh.new()
		s.radius = sizes[j]
		s.height = sizes[j] * 2.0
		mi.mesh     = s
		mi.position = bumps[j]
		mi.material_override = muscle_mat
		add_child(mi)

func _build_glow() -> void:
	var light := OmniLight3D.new()
	light.position     = Vector3(0.0, 0.7, 0.0)
	light.light_color  = Color(0.9, 0.25, 0.15)
	light.light_energy = 0.5
	light.omni_range   = 2.0
	add_child(light)

func on_hit() -> void:
	var p := CPUParticles3D.new()
	p.one_shot               = true
	p.emitting               = true
	p.amount                 = 28
	p.lifetime               = 0.7
	p.position               = Vector3(0.0, 0.7, 0.0)
	p.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.52
	p.direction              = Vector3(0.0, 0.0, 0.0)
	p.spread                 = 180.0
	p.gravity                = Vector3(0.0, -8.0, 0.0)
	p.initial_velocity_min   = 2.0
	p.initial_velocity_max   = 5.5
	p.scale_amount_min       = 0.04
	p.scale_amount_max       = 0.12
	p.color                  = Color(0.42, 0.08, 0.08, 1.0)
	add_child(p)

	var p2 := CPUParticles3D.new()
	p2.one_shot               = true
	p2.emitting               = true
	p2.amount                 = 18
	p2.lifetime               = 0.5
	p2.position               = Vector3(0.0, 0.1, 0.0)
	p2.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p2.emission_sphere_radius = 0.60
	p2.direction              = Vector3(0.0, 1.0, 0.0)
	p2.spread                 = 85.0
	p2.gravity                = Vector3(0.0, -2.0, 0.0)
	p2.initial_velocity_min   = 0.5
	p2.initial_velocity_max   = 1.8
	p2.scale_amount_min       = 0.05
	p2.scale_amount_max       = 0.14
	p2.color                  = Color(0.30, 0.20, 0.15, 0.8)
	add_child(p2)

	await get_tree().create_timer(p.lifetime + 0.1).timeout
	p.queue_free()
	p2.queue_free()

# ── 共用工具 ──────────────────────────────────────────────────────────────────

func _body_shader(base: Color, emit: Color, breathe_spd: float, emit_str: float, wobble: float) -> ShaderMaterial:
	var mat    := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;
uniform vec4 base_col  : source_color;
uniform vec4 emit_col  : source_color;
uniform float emit_str  = 1.2;
uniform float breathe   = 0.6;
uniform float wob       = 0.028;
void vertex() {
	// 沉重大幅呼吸
	float b = 1.0 + sin(TIME * breathe) * 0.030;
	VERTEX *= b;
	// 表面熔岩涌动
	float r = sin(TIME * 1.5 + VERTEX.y * 3.5 + VERTEX.x * 2.5) * wob;
	float r2 = sin(TIME * 2.3 + VERTEX.z * 4.0) * wob * 0.6;
	VERTEX += NORMAL * (r + r2);
}
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.2);
	// 不均匀脉冲：模拟暗火在裂缝中涌动
	float pulse = 0.65 + 0.35 * sin(TIME * 1.3) * sin(TIME * 0.7 + 1.2);
	ALBEDO      = base_col.rgb;
	ROUGHNESS   = 0.88;
	METALLIC    = 0.05;
	EMISSION    = emit_col.rgb * (fr * 0.45 + 0.55) * pulse * emit_str;
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
uniform vec4 col : source_color;
uniform float alpha_scale = 0.5;
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.6);
	float pulse = 0.55 + 0.45 * sin(TIME * 1.4) * sin(TIME * 0.8);
	ALBEDO   = col.rgb;
	ALPHA    = clamp(fr * pulse * alpha_scale, 0.0, 1.0);
	EMISSION = col.rgb * fr * pulse * 1.8;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("col",         color)
	mat.set_shader_parameter("alpha_scale", alpha_scale)
	mi.material_override = mat
	add_child(mi)
