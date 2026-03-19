# 技术架构文档

> 本文定义重构目标架构。不描述现有实现，描述应该存在的系统。
> 每个系统包含：职责边界、对外接口、与其他系统的关系。

---

## 架构总览

```
┌─────────────────────────────────────────────────────┐
│                     World Scene                     │
│                                                     │
│  ┌──────────┐   ┌──────────┐   ┌────────────────┐  │
│  │  Player  │   │   NPC    │   │ DungeonBuilder │  │
│  │ (移动/镜头)│   │ (状态机) │   │  (场景构建)    │  │
│  └────┬─────┘   └────┬─────┘   └───────┬────────┘  │
│       │              │                  │           │
│  ┌────▼──────────────▼──────────────────▼────────┐  │
│  │              WorldDirector                    │  │
│  │     (过场序列 / 灯光事件 / 游戏流程控制)         │  │
│  └────────────────────┬──────────────────────────┘  │
│                       │                             │
│  ┌────────────────────▼──────────────────────────┐  │
│  │              DialogSystem                     │  │
│  │        (对话 / 独白 / 选择 / 沉默)              │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
           │ battle signal
┌──────────▼──────────────────────────────────────────┐
│                   Battle Scene                      │
│   BattleDirector (镜头) + BattleGame (逻辑)          │
└─────────────────────────────────────────────────────┘

跨场景持久化：GameState (Autoload)
```

---

## 系统一：GameState（Autoload）

**取代现有**：`FlagDB`（只是一个裸字典）

**职责**：
- 持久化所有跨场景/跨楼层数据
- 不含任何逻辑，只是数据容器

**数据结构**：
```gdscript
class_name GameState
extends Node

# 楼层进度
var current_floor: int = 1

# 已击败的 NPC（取代 trainer_id + "_beat"）
var defeated: Dictionary = {}          # { "rude_man": true, ... }

# 玩家队伍（持久化缚灵状态，楼层间保留受伤）
var party: Array[PokemonModel] = []

# 解锁的故事旗帜（用于触发特殊对话/事件）
var story_flags: Dictionary = {}       # { "seen_ironhide_mark": true, ... }
```

**接口**：
```gdscript
func defeat(npc_id: String) -> void
func is_defeated(npc_id: String) -> bool
func set_flag(key: String) -> void
func has_flag(key: String) -> bool
```

**原则**：其他任何系统只通过这四个方法读写游戏状态，不直接访问字典。

---

## 系统二：WorldDirector

**取代现有**：`world.gd` 中散落的 `_on_encounter`、`_on_exit_zone_entered`、`_show_world_dialog`

**职责**：
- 编排世界内的所有过场序列
- 管理灯光事件
- 控制游戏流程（遭遇 → 战斗 → 战后 → 下一层）
- **不**处理具体的移动/渲染细节，委托给下级系统

**核心概念：Sequence（序列）**

一个 Sequence 是一组有序的步骤，每个步骤可以是：

```gdscript
# 抽象步骤类型（不是真实代码，是设计意图）
enum StepType {
    MOVE_CAMERA,      # 移动镜头到指定位置/朝向，用时N秒
    MOVE_NPC,         # 移动NPC到指定位置
    SET_NPC_STATE,    # 切换NPC状态（idle/talking/defeated/hiding）
    SHOW_DIALOG,      # 显示一段对话（可带选项）
    SHOW_MONOLOGUE,   # 显示独白（无按钮，自动推进或等固定时间）
    WAIT,             # 纯等待N秒（用于Vex的8秒沉默）
    TWEEN_LIGHT,      # 渐变某个灯光的能量/颜色
    EMIT_SIGNAL,      # 触发外部信号（如"开始战斗"）
    PLAY_SFX,         # 播放音效
}
```

**WorldDirector 的接口**：
```gdscript
func run_sequence(sequence_id: String) -> void  # 运行预定义序列，await 直到完成
func tween_light(light: OmniLight3D, target_energy: float, duration: float) -> void
func enter_battle(npc: Node) -> void
func enter_next_floor() -> void
```

**它不应该做的**：直接操作 Camera3D 的 position。它发出指令，CameraDirector 执行。

---

## 系统三：CameraDirector

**取代现有**：`player.gd` 里的 `_update_camera()` + `battle_3d.gd` 里的 `camera_.make_current()`

**职责**：
- 全局唯一的摄像机控制权威
- 在"跟随模式"和"过场模式"之间切换
- 执行所有镜头动作（推、拉、切、跟随）

**模式**：
```gdscript
enum CameraMode {
    FOLLOW,       # 跟随玩家，带平滑yaw（世界探索常态）
    CINEMATIC,    # 过场控制，接受来自Sequence的指令
    BATTLE,       # 战斗固定机位，带震动能力
}
```

**接口**：
```gdscript
func set_mode(mode: CameraMode) -> void
func follow(target: Node3D, height: float, dist: float) -> void
func move_to(pos: Vector3, look_at: Vector3, duration: float) -> void  # awaitable
func push_toward(target: Node3D, amount: float, duration: float) -> void  # awaitable
func cut_to(pos: Vector3, look_at: Vector3) -> void  # 瞬间切换
func shake(intensity: float, duration: float) -> void  # 战斗击中感
```

**关键设计**：CameraDirector 是 Autoload 或场景根节点的单例，所有场景共享同一个实例，避免"切场景时摄像机控制权混乱"的问题（这是现有 bug 的根源之一）。

---

## 系统四：DialogSystem

**取代现有**：`dialog_overlay.gd`（只支持打字机+按钮）

**职责**：处理所有文字呈现，支持四种模式：

```gdscript
# 模式1：对话行（有确认按钮，玩家主动推进）
func show_line(text: String) -> void          # await 直到玩家确认

# 模式2：选择（有两个按钮，返回选择结果）
func show_choice(text: String, opt_a: String, opt_b: String) -> bool  # await

# 模式3：独白（无按钮，固定时间自动消失，或等待玩家跳过）
func show_monologue(text: String, auto_seconds: float = 0.0) -> void  # await

# 模式4：纯等待（黑屏/空屏上的沉默，用于Vex的8秒）
func wait_silent(seconds: float) -> void      # await
```

**与现有的差异**：
- `show_monologue` 对应加雷斯战败后的独白（不能被"OK"按钮打断节奏）
- `wait_silent` 对应 Vex 战败后的8秒沉默（不显示任何UI，只是等待）
- 所有方法都是 `await`able，WorldDirector 的 Sequence 可以按顺序组合调用

---

## 系统五：NPCController

**取代现有**：`npc.gd`（只有可见/不可见）

**职责**：管理单个 NPC 的所有状态和行为

**状态机**：
```gdscript
enum NPCState {
    IDLE,          # 站立idle动画，面朝玩家
    WALKING,       # 移动到目标位置（用于阿卡娜走到中央）
    TALKING,       # 对话中（可能有特殊动画）
    DEFEATED,      # 战败姿态（加雷斯单膝、Vex站立）
    HIDING,        # 退场（走进阴影消失，或queue_free）
}
```

**接口**：
```gdscript
func set_state(state: NPCState) -> void
func walk_to(target_pos: Vector3, duration: float) -> void   # awaitable
func face_toward(target: Node3D) -> void
func face_direction(dir: Vector3) -> void
func disappear_into_shadow(direction: Vector3) -> void       # awaitable，Vex专用
```

**信号**（保持现有）：
```gdscript
signal encounter    # 玩家进入检测范围
signal beat         # 战斗结束，玩家胜利
```

---

## 系统六：DungeonBuilder

**取代现有**：`world.gd` 里的 `_build_dungeon()`

**职责**：纯粹的场景构建，不含任何游戏逻辑

**接口**：
```gdscript
func build(floor_number: int) -> void
func get_light(light_id: String) -> OmniLight3D   # 让 WorldDirector 能引用灯光
```

**楼层数据**：每一层的布局通过 Resource 定义（`FloorLayout`），而不是硬编码在函数里。这样后续添加新楼层只需要新增 Resource，不改代码。

```gdscript
class_name FloorLayout
extends Resource

@export var floor_number: int
@export var npc_positions: Array[Vector3]
@export var light_configs: Array[LightConfig]
@export var special_tiles: Array[TilePlacement]   # 覆盖默认tile的特殊位置
```

---

## 系统七：BattleDirector

**取代现有**：`battle_3d.gd` 里混在一起的镜头控制、UI更新、战斗逻辑

**职责**：只负责战斗场景内的镜头语言（见 `direction/06_battle.md`）

**与 BattleGame 的分工**：
```
BattleDirector  →  镜头、模型动画、视觉特效、音效时机
BattleGame      →  伤害计算、回合顺序、胜负判定、UI数据更新
```

两者通过信号通信，不互相调用方法。

**BattleDirector 监听的信号**：
```gdscript
BattleGame.attack_started(attacker, move)    # → 触发攻击动画+侧面镜头
BattleGame.hit_landed(defender, damage)      # → 触发受击动画+镜头震动
BattleGame.pokemon_fainted(slot)             # → 触发濒死特写
BattleGame.battle_ended(player_won)          # → 触发胜利/失败镜头
```

---

## 系统间通信规则

```
规则1：系统只通过信号向上通知，通过方法向下指令。
       NPC 发出 encounter 信号 → WorldDirector 响应并指挥
       WorldDirector 调用 CameraDirector.move_to() → Camera 执行

规则2：GameState 是唯一允许被任何系统直接读写的共享对象。
       其他系统之间不共享状态，只传递事件。

规则3：所有"时间性操作"（动画、等待、移动）必须是 awaitable 的。
       Sequence 的每一步都要能 await，才能保证顺序执行。
```

---

## 文件结构（目标）

```
godot-pokemon-3d/
├── autoload/
│   ├── game_state.gd          # 取代 flag_db.gd
│   └── camera_director.gd     # 全局摄像机控制
│
├── world/
│   ├── world_director.gd      # 取代 world.gd 的流程控制部分
│   ├── dungeon_builder.gd     # 取代 world.gd 的场景构建部分
│   ├── npc_controller.gd      # 取代 npc.gd
│   ├── player.gd              # 保留，移除摄像机控制部分
│   └── sequences/             # 每个过场序列的脚本
│       ├── seq_gareth.gd
│       ├── seq_arcana.gd
│       ├── seq_vex.gd
│       └── seq_gate.gd
│
├── dialog/
│   ├── dialog_system.gd       # 取代 dialog_overlay.gd
│   └── dialog_overlay.tscn    # UI场景（复用）
│
├── battle/
│   ├── battle_director.gd     # 镜头+动画
│   ├── battle_game.gd         # 逻辑（取代 battle_3d.gd 的逻辑部分）
│   └── battle_scene.tscn      # 保留
│
└── data/
    └── floors/
        ├── floor_01.tres      # 第一层布局数据
        └── floor_layout.gd    # FloorLayout Resource 定义
```

---

## 重构顺序建议

```
第一阶段（基础）：
  1. GameState          取代 FlagDB，接口不变但更安全
  2. DialogSystem       扩展现有 dialog_overlay，向后兼容
  3. NPCController      扩展现有 npc.gd，加状态机

第二阶段（核心）：
  4. CameraDirector     从 player.gd 提取，新增过场能力
  5. WorldDirector      从 world.gd 提取流程控制
  6. Sequence 系统      实现第一个序列：加雷斯遭遇

第三阶段（完善）：
  7. BattleDirector     从 battle_3d.gd 分离镜头逻辑
  8. DungeonBuilder     提取并支持 FloorLayout 数据驱动
  9. 石门过场序列        seq_gate.gd
```
