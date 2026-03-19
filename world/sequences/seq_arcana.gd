## 阿卡娜遭遇过场序列
## 情绪弧线：好奇被引导 → 智识上的打量 → 被看穿的沉默
## 参考 direction/03_arcana.md
extends Node

## ctx 字段：player, npc, camera, dialog
func execute(ctx: Dictionary) -> bool:
	var camera: Node        = ctx.camera
	var npc: NPCController  = ctx.npc as NPCController
	var dialog: CanvasLayer = ctx.dialog
	var player: Node3D      = ctx.player

	player.pause_controls = true

	var npc_pos:    Vector3 = npc.global_position
	var player_pos: Vector3 = player.global_position

	# ── Shot 1：环境先行 — 先看见蜡烛、石台、西墙刻痕，不急着给人物 ──────────
	# 4秒横摇：蜡烛群 → 笔记台面 → 西墙拓印区
	# 意图：这个空间在说话，她在这里生活了很长时间
	camera.cut_to(
		Vector3(-2.0, 1.5, 2.5),
		Vector3(-3.0, 0.5, 0.0)    # 看向蜡烛群
	)
	await get_tree().create_timer(1.0).timeout
	await camera.move_to(
		Vector3(-5.5, 1.6, 1.0),
		Vector3(-6.5, 1.5, -1.0),  # 横摇至西墙石刻区
		2.5
	)
	await get_tree().create_timer(0.5).timeout

	# ── Shot 2：她的背影 — 轻微向左移，偷偷看侧脸 ─────────────────────────
	# 她还没抬头，背对入口，坐在石台前
	camera.cut_to(
		npc_pos + Vector3(0.6, 1.6, 2.2),
		npc_pos + Vector3(0.0, 1.2, 0.0)
	)
	npc.set_state(npc.State.TALKING)
	await camera.move_to(
		npc_pos + Vector3(-0.3, 1.6, 2.2),
		npc_pos + Vector3( 0.0, 1.2, 0.0),
		1.2
	)

	# 她察觉玩家，但不回头——背影说话，镜头不切
	# 一个不看你就能判断你是谁的人，比直视你更有力量
	await dialog.show_line("你的脚步声不像士兵，也不像盗墓者。")

	# 她转身
	npc.face_direction(Vector3(0.0, 0.0, 1.0))
	await get_tree().create_timer(0.4).timeout

	# 她看见铁皮兽 — 镜头留在 Shot 2 位置，她的声音带着一丝意外
	await dialog.show_line("哦。你有两头缚灵。")

	# ── Shot 3：目光下移追铁皮兽 — 镜头跟随她的视线向下，特写印记 2秒 ──────
	# 这是第一次正式"看见"这个印记
	await camera.move_to(
		player_pos + Vector3(-0.5, 0.8, 1.2),
		player_pos + Vector3( 0.0, 0.5, 0.0),
		0.6
	)
	await get_tree().create_timer(2.0).timeout

	# ── Shot 4：切回她面部特写 — "果然如此"的平静，她早就知道 ──────────────
	await camera.move_to(
		npc_pos + Vector3(0.5, 1.8, 1.5),
		npc_pos + Vector3(0.0, 1.5, 0.0),
		0.4
	)
	await dialog.show_line("我在这里的记录里见过这种甲壳的纹路。")

	# ── Shot 5：她走向铁皮兽 — 镜头跟她，玩家背影在后景 ────────────────────
	# 镜头视角的关键选择：我们站在她的位置上
	var approach_pos := player_pos + Vector3(-1.0, 0.0, 0.8)
	npc.walk_to(approach_pos, 1.5)
	await camera.move_to(
		approach_pos + Vector3(-1.5, 1.8, 1.0),
		player_pos   + Vector3( 0.0, 0.8, 0.0),
		1.5
	)

	# ── Shot 6：三人构图 — 阿卡娜清晰 / 铁皮兽清晰 / 玩家背影在后景失焦 ────
	var mid := (player_pos + npc_pos) * 0.5
	await camera.move_to(
		mid + Vector3(-2.5, 1.8, 2.0),
		mid + Vector3( 0.0, 0.8, 0.0),
		0.5
	)
	await dialog.show_line("……算了，不重要。")
	# 这1秒停留是她没有说出口的名字
	await get_tree().create_timer(1.0).timeout

	# 她退回去，提出条件
	await dialog.show_line("我需要验证一个假设。如果你能赢我，我就告诉你验证结果。")
	await dialog.show_line("如果你输了……也没关系，你只是不是我找的那个人。")

	var fight: bool = await dialog.show_encounter("与阿卡娜对峙？")

	camera.follow(player)
	player.pause_controls = false
	return fight
