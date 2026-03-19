## RegaliaVisual — 冕灵：金冠圣光，治愈系，王者之姿
extends Node3D

var _time: float   = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = position.y
	_build_body()
	_build_crown()
	_build_halo()
	_build_particles()

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 0.8) * 0.12
	rotation.y += delta * 0.22

# ── 白金主球（柔光呼吸 + 圣光 Fresnel） ──────────────────────────────────────

func _build_body() -> void:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.76
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)
	mi.material_override = _body_shader(
		Color(0.95, 0.92, 0.80),   # 珍珠白金
		Color(0.95, 0.80, 0.35),   # 金光
		0.8, 2.0, 0.014            # 缓慢呼吸、强发光、微幅顶点
	)
	add_child(mi)

	# 外层金色圣光壳
	_add_glow_shell(0.43, Color(1.0, 0.85, 0.30), 0.65)

# ── 王冠刺（顶部圆形排列 8 根） ──────────────────────────────────────────────

func _build_crown() -> void:
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color               = Color(1.0, 0.82, 0.18)
	crown_mat.metallic                   = 0.85
	crown_mat.roughness                  = 0.12
	crown_mat.emission_enabled           = true
	crown_mat.emission                   = Color(1.0, 0.72, 0.10)
	crown_mat.emission_energy_multiplier = 1.5

	var count := 8
	for i in count:
		var angle := (float(i) / float(count)) * TAU
		var r := 0.28

		var mi   := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius    = 0.0
		mesh.bottom_radius = 0.035
		mesh.height        = 0.30 + (0.08 if i % 2 == 0 else 0.0)
		mi.mesh = mesh

		var base := Vector3(sin(angle) * r, 1.08, cos(angle) * r)
		mi.position = base
		var tip_dir := Vector3(sin(angle) * 0.5, 1.0, cos(angle) * 0.5).normalized()
		mi.look_at(base + tip_dir, Vector3.UP)
		mi.rotate_object_local(Vector3(1, 0, 0), PI * 0.5)

		mi.material_override = crown_mat
		add_child(mi)

# ── 脉冲圣光环 ────────────────────────────────────────────────────────────────

func _build_halo() -> void:
	var mi   := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius  = 0.38
	mesh.outer_radius  = 0.46
	mesh.rings         = 32
	mesh.ring_segments = 10
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)

	var mat    := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
void fragment() {
	float pulse = 0.6 + 0.4 * sin(TIME * 2.8);
	ALBEDO   = vec3(1.0, 0.88, 0.35);
	ALPHA    = pulse * 0.7;
	EMISSION = vec3(1.0, 0.78, 0.2) * pulse * 1.2;
}
"""
	mat.shader = shader
	mi.material_override = mat
	add_child(mi)

# ── 圣光粒子 ──────────────────────────────────────────────────────────────────

func _build_particles() -> void:
	var p := CPUParticles3D.new()
	p.emitting               = true
	p.amount                 = 24
	p.lifetime               = 2.2
	p.position               = Vector3(0.0, 0.7, 0.0)
	p.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.30
	p.direction              = Vector3(0.0, 1.0, 0.0)
	p.spread                 = 25.0
	p.gravity                = Vector3(0.0, 0.08, 0.0)
	p.initial_velocity_min   = 0.3
	p.initial_velocity_max   = 0.9
	p.scale_amount_min       = 0.04
	p.scale_amount_max       = 0.10
	p.color                  = Color(1.0, 0.90, 0.50, 0.85)
	add_child(p)

	var p2 := CPUParticles3D.new()
	p2.emitting               = true
	p2.amount                 = 16
	p2.lifetime               = 1.5
	p2.position               = Vector3(0.0, 0.7, 0.0)
	p2.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p2.emission_sphere_radius = 0.42
	p2.direction              = Vector3(0.0, 1.0, 0.0)
	p2.spread                 = 180.0
	p2.gravity                = Vector3(0.0, 0.03, 0.0)
	p2.initial_velocity_min   = 0.05
	p2.initial_velocity_max   = 0.18
	p2.scale_amount_min       = 0.03
	p2.scale_amount_max       = 0.06
	p2.color                  = Color(0.9, 0.75, 0.3, 0.6)
	add_child(p2)

	var light := OmniLight3D.new()
	light.position     = Vector3(0.0, 0.7, 0.0)
	light.light_color  = Color(1.0, 0.90, 0.55)
	light.light_energy = 0.6
	light.omni_range   = 2.5
	add_child(light)

func on_hit() -> void:
	var p := CPUParticles3D.new()
	p.one_shot               = true
	p.emitting               = true
	p.amount                 = 20
	p.lifetime               = 0.8
	p.position               = Vector3(0.0, 0.7, 0.0)
	p.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction              = Vector3(0.0, 1.0, 0.0)
	p.spread                 = 180.0
	p.gravity                = Vector3(0.0, 0.5, 0.0)
	p.initial_velocity_min   = 0.8
	p.initial_velocity_max   = 2.5
	p.scale_amount_min       = 0.04
	p.scale_amount_max       = 0.10
	p.color                  = Color(1.0, 0.88, 0.3, 1.0)
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
uniform vec4 base_col  : source_color;
uniform vec4 emit_col  : source_color;
uniform float emit_str  = 2.0;
uniform float breathe   = 0.8;
uniform float wob       = 0.014;
void vertex() {
	float b = 1.0 + sin(TIME * breathe) * 0.02;
	VERTEX *= b;
	float r = sin(TIME * 1.8 + VERTEX.y * 4.5 + VERTEX.x * 3.0) * wob;
	VERTEX += NORMAL * r;
}
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.3);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.6);
	ALBEDO      = base_col.rgb;
	ROUGHNESS   = 0.22;
	METALLIC    = 0.5;
	EMISSION    = emit_col.rgb * (fr * 0.5 + 0.5) * pulse * emit_str;
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
uniform float alpha_scale = 0.65;
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.8);
	float pulse = 0.65 + 0.35 * sin(TIME * 1.9);
	ALBEDO   = col.rgb;
	ALPHA    = clamp(fr * pulse * alpha_scale, 0.0, 1.0);
	EMISSION = col.rgb * fr * pulse * 1.5;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("col",         color)
	mat.set_shader_parameter("alpha_scale", alpha_scale)
	mi.material_override = mat
	add_child(mi)
