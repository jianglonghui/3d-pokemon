## 加雷斯遭遇过场序列
## 情绪弧线：陌生的威慑 → 沉默的权威 → 意外的善意
## 参考 direction/02_gareth.md
extends Node

## ctx 字段：player, npc, camera, dialog
func execute(ctx: Dictionary) -> bool:
	var camera: Node        = ctx.camera
	var npc: NPCController  = ctx.npc as NPCController
	var dialog: CanvasLayer = ctx.dialog
	var player: Node3D      = ctx.player

	player.pause_controls = true
	npc.set_state(npc.State.TALKING)
	npc.face_direction(Vector3(0.0, 0.0, 1.0))   # 面朝南，迎着玩家

	var npc_pos:    Vector3 = npc.global_position
	var player_pos: Vector3 = player.global_position

	# ── Shot 1：触发后退 — 生理本能的退步，极轻微，0.5秒 ───────────────────
	# 镜头从玩家后方略向后拉，玩家在画面中变小约5%
	camera.cut_to(
		player_pos + Vector3(0.0, 2.0, 3.5),
		player_pos + Vector3(0.0, 0.8, 0.0)
	)
	await camera.move_to(
		player_pos + Vector3(0.0, 2.2, 5.0),
		player_pos + Vector3(0.0, 0.8, 0.0),
		0.5
	)

	# ── Shot 2：低角度仰视加雷斯 — 约0.9m高，微仰，背后火把逆光 ──────────
	# 他空手挡路，比拔剑更有力量
	await camera.move_to(
		npc_pos + Vector3(0.0, 0.3, 2.8),
		npc_pos + Vector3(0.0, 1.6, 0.0),
		0.6
	)
	await dialog.show_line("站住。没有人可以随意穿越这里。")

	# ── Shot 3：侧面近景 — 从东侧斜前方切入，绕开玩家背影 ─────────────────
	# 镜头在 NPC 右前方 45°，高于帽檐，斜看脸部
	await camera.move_to(
		npc_pos + Vector3(2.2, 2.1, 1.2),
		npc_pos + Vector3(0.0, 1.85, 0.0),
		0.3
	)
	await get_tree().create_timer(2.0).timeout
	await dialog.show_line("我拦住过数十个比你看起来更强的人。他们没有一个回来。")

	# ── Shot 4：切回肩后中景 — 双人同框，选择权在玩家 ──────────────────────
	# 第一次在同一个画面里出现两个角色
	await camera.move_to(
		player_pos + Vector3(0.8, 1.8, 0.8),
		npc_pos    + Vector3(0.0, 1.4, 0.0),
		0.4
	)
	await dialog.show_line("离开。趁你还能走出去。")

	# 选择界面期间：镜头极缓慢向加雷斯推进（后台运行，世界没有停下来等玩家）
	camera.push_toward(npc, 0.9, 3.5)
	var fight: bool = await dialog.show_encounter("挑战加雷斯？")

	if fight:
		await dialog.show_line("……好。那就让我看看，你的缚灵值不值得你这一身执念。")

	camera.follow(player)
	player.pause_controls = false
	return fight
