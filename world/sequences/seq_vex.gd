## Vex 遭遇过场序列
## 镜头几乎不主动照顾她——她出现，说话，消失
## 参考 direction/04_vex.md
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

	# ── Shot 1：注视镜头 — 观众先于玩家发现她，制造无声紧张 ─────────────────
	# 机位：zone03入口（z=-4）中高处，面向北方黑暗
	# 画面：黑暗里，Vex的轮廓靠着墙，一动不动，看着南方
	camera.cut_to(
		Vector3(0.0, 2.2, -3.5),
		npc_pos + Vector3(0.0, 1.0, 0.0)
	)
	npc.set_state(npc.State.IDLE)
	npc.face_direction(Vector3(0.0, 0.0, 1.0))
	await get_tree().create_timer(3.0).timeout

	# ── 切回跟随 — 回到玩家背后视角，"回到无知状态" ─────────────────────────
	camera.follow(player)
	await get_tree().create_timer(1.0).timeout   # Vex轮廓从阴影里清晰起来

	# ── 她开口 — 镜头不切，玩家停下 ────────────────────────────────────────
	# 她没有正对镜头，这不是表演给镜头看的台词，是说给玩家听的
	npc.set_state(npc.State.TALKING)
	await dialog.show_line("不管他们告诉你下面有什么——都是谎言。")

	# ── Shot 2：对峙构图 — 全游戏唯一一次，地面高度，二者平等 ─────────────────
	# 前两场刻意回避了这种构图
	# Vex是唯一平等地站在玩家面前的人（不是挡路，不是试探）
	var mid := (player_pos + npc_pos) * 0.5
	await camera.move_to(
		mid + Vector3(4.0, 1.0, 0.0),
		mid + Vector3(0.0, 1.2, 0.0),
		0.7
	)
	# 她没有在警告你，她在告诉你一个事实
	await dialog.show_line("我不是在让你回头。")
	await dialog.show_line("我只是说，你现在认为自己在找的东西……和你真正会找到的东西，不是同一件事。")

	# ── Shot 3：嘴部特写 — "我们来了"从很近的地方说出，贴着耳朵 ────────────
	await camera.move_to(
		npc_pos + Vector3(0.3, 1.25, 0.55),
		npc_pos + Vector3(0.0, 1.25, 0.0),
		0.3
	)
	await dialog.show_line("冕灵。壮者。我们来了。")

	var fight: bool = await dialog.show_encounter("接受挑战？")

	camera.follow(player)
	player.pause_controls = false
	return fight
