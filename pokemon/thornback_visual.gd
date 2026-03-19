## ThornbackVisual — 刺背：橄榄绿骨刺兽，速度感强，表面有机涌动
extends Node3D

var _time: float   = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	_base_y = position.y
	_build_body()
	_build_spikes()
	_build_glow()

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.2) * 0.08
	rotation.y += delta * 0.55

# ── 有机涌动主球（ShaderMaterial：更快的表面扭动 + 绿色 Fresnel） ────────────

func _build_body() -> void:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.34
	mesh.height = 0.68
	mi.mesh     = mesh
	mi.position = Vector3(0.0, 0.7, 0.0)
	mi.material_override = _body_shader(
		Color(0.25, 0.45, 0.18),   # 橄榄绿
		Color(0.12, 0.38, 0.06),   # 绿色内焰
		2.2, 1.0, 0.022            # 快速呼吸、发光强度、顶点扭动
	)
	add_child(mi)

	# 外层绿色有机光晕
	_add_glow_shell(0.38, Color(0.20, 0.65, 0.10), 0.45)

# ── 骨刺阵列 ─────────────────────────────────────────────────────────────────

func _build_spikes() -> void:
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color               = Color(0.72, 0.60, 0.30)
	spike_mat.roughness                  = 0.65
	spike_mat.emission_enabled           = true
	spike_mat.emission                   = Color(0.3, 0.25, 0.08)
	spike_mat.emission_energy_multiplier = 0.6

	var count := 14
	for i in count:
		var t     := float(i) / float(count)
		var theta := acos(1.0 - 2.0 * t)
		var phi   := 2.0 * PI * i * 0.618033988749895

		var dir := Vector3(
			sin(theta) * cos(phi),
			cos(theta),
			sin(theta) * sin(phi)
		)

		var mi   := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius    = 0.0
		mesh.bottom_radius = 0.045
		mesh.height        = 0.28 + randf() * 0.12
		mi.mesh = mesh

		mi.position = Vector3(0.0, 0.7, 0.0) + dir * 0.38
		mi.look_at(Vector3(0.0, 0.7, 0.0) + dir * 2.0, Vector3.UP)
		mi.rotate_object_local(Vector3(1, 0, 0), PI * 0.5)

		mi.material_override = spike_mat
		add_child(mi)

func _build_glow() -> void:
	var light := OmniLight3D.new()
	light.position     = Vector3(0.0, 0.7, 0.0)
	light.light_color  = Color(0.4, 0.9, 0.3)
	light.light_energy = 0.4
	light.omni_range   = 2.0
	add_child(light)

func on_hit() -> void:
	var p := CPUParticles3D.new()
	p.one_shot               = true
	p.emitting               = true
	p.amount                 = 16
	p.lifetime               = 0.4
	p.position               = Vector3(0.0, 0.7, 0.0)
	p.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.36
	p.direction              = Vector3(0.0, 1.0, 0.0)
	p.spread                 = 180.0
	p.gravity                = Vector3(0.0, -3.0, 0.0)
	p.initial_velocity_min   = 1.0
	p.initial_velocity_max   = 3.5
	p.scale_amount_min       = 0.02
	p.scale_amount_max       = 0.06
	p.color                  = Color(0.55, 0.45, 0.22, 1.0)
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
uniform float emit_str  = 1.0;
uniform float breathe   = 2.2;
uniform float wob       = 0.022;
void vertex() {
	float b = 1.0 + sin(TIME * breathe) * 0.022;
	VERTEX *= b;
	float r = sin(TIME * 3.5 + VERTEX.y * 6.0 + VERTEX.z * 4.0) * wob;
	VERTEX += NORMAL * r;
}
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.4);
	float pulse = 0.70 + 0.30 * sin(TIME * 2.8);
	ALBEDO      = base_col.rgb;
	ROUGHNESS   = 0.78;
	METALLIC    = 0.08;
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
uniform float alpha_scale = 0.45;
void fragment() {
	float fr    = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float pulse = 0.55 + 0.45 * sin(TIME * 3.0);
	ALBEDO   = col.rgb;
	ALPHA    = clamp(fr * pulse * alpha_scale, 0.0, 1.0);
	EMISSION = col.rgb * fr * pulse * 1.4;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("col",         color)
	mat.set_shader_parameter("alpha_scale", alpha_scale)
	mi.material_override = mat
	add_child(mi)
