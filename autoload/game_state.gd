## GameState — 跨场景持久化数据容器
## 取代 FlagDB，通过方法访问而非直接操作字典
extends Node

var current_floor: int = 1

# 已击败的 NPC
var defeated: Dictionary = {}

# 故事旗帜（触发特殊事件/对话）
var story_flags: Dictionary = {}

func defeat(npc_id: String) -> void:
	defeated[npc_id] = true

func is_defeated(npc_id: String) -> bool:
	return defeated.get(npc_id, false)

func set_flag(key: String) -> void:
	story_flags[key] = true

func has_flag(key: String) -> bool:
	return story_flags.get(key, false)
