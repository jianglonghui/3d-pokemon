## 石门过场序列 — 6镜头，无台词结尾
## 铁皮兽先走 → match cut（门徽记→背部印记）→ 触碰发光 → 门开 → 走进黑暗 → 推镜至黑
## 参考 direction/05_gate.md
extends Node

## ctx 字段：player, camera, dialog
func execute(ctx: Dictionary) -> void:
	var camera: Node        = ctx.camera
	var player: Node3D      = ctx.player
	var dialog: CanvasLayer = ctx.dialog

	var player_pos: Vector3 = player.global_position
	var gate_pos   := Vector3(0.0, 1.5, -11.0)   # 北墙门洞位置

	# ── Shot 1：铁皮兽走向石门 — 镜头从玩家后方俯视，跟随方向感 ──────────────
	await camera.move_to(
		player_pos + Vector3(0.0, 3.5, 5.0),
		gate_pos   + Vector3(0.0, 0.5, 0.0),
		1.8
	)
	await get_tree().create_timer(0.5).timeout

	# ── Shot 2a：Match cut — 靠近石门上的徽记 ─────────────────────────────
	camera.cut_to(
		gate_pos + Vector3(0.0, 1.8, 2.0),
		gate_pos + Vector3(0.0, 1.5, 0.0)
	)
	await get_tree().create_timer(1.2).timeout

	# ── Shot 2b：Match cut 切到玩家背部印记 ──────────────────────────────────
	# （占位符：靠近玩家背部，模拟印记特写）
	camera.cut_to(
		player_pos + Vector3(0.0, 1.8, 2.0),
		player_pos + Vector3(0.0, 0.8, 0.0)
	)
	await get_tree().create_timer(1.0).timeout

	# ── Shot 3：触碰发光 — 门和印记共鸣 ──────────────────────────────────────
	await camera.move_to(
		gate_pos + Vector3(0.0, 1.6, 3.0),
		gate_pos + Vector3(0.0, 1.2, 0.0),
		0.9
	)

	await dialog.show_monologue("印记在掌心跳动。", 2.5)
	await dialog.show_monologue("石门以同样的节律回应。", 2.5)

	# ── Shot 4：门开 — 广角，双方都在画面里 ──────────────────────────────────
	await camera.move_to(
		gate_pos + Vector3(0.0, 2.5, 5.0),
		gate_pos + Vector3(0.0, 0.0, 0.0),
		1.2
	)

	await dialog.show_monologue("石块研磨，通道打开。", 3.0)

	# ── Shot 5：走进黑暗 — 镜头推进，跟随玩家进入门洞 ───────────────────────
	await camera.move_to(
		gate_pos + Vector3(0.0, 1.5, 1.5),
		gate_pos + Vector3(0.0, 0.5, -4.0),
		2.5
	)

	# ── Shot 6：推镜至黑 — 镜头持续推进，进入虚空 ───────────────────────────
	# 直接推进到黑暗中（无目标节点，向前推）
	var dark_dest := gate_pos + Vector3(0.0, 1.0, -8.0)
	await camera.move_to(
		dark_dest,
		dark_dest + Vector3(0.0, 0.0, -3.0),
		3.0
	)

	# 黑屏静默
	await dialog.wait_silent(1.2)
