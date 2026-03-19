# 灯光设计指南：铁心地窟第一层

---

## 全层灯光叙事弧线

```
入口（z=+8）                              出口（z=-11）
   │                                          │
   ▓▓▓▓▓▓▓▓░░░░░░░▒▒▒▒░░░░░░░░░░▒▒░░░░░░░░░▓
   暖亮                暗                蜡黄  极暗+蓝光

情绪：  [安全感] → [警惕] → [好奇] → [压迫] → [未知]
```

越深越暗，越暗越未知——这是第一层灯光设计的单一原则。
唯一的例外是蓝光，它不代表安全，它代表**谜题的入口**。

---

## 色温分层

| 区域 | 主色温 | Hex参考 | 情绪关键词 |
|------|--------|---------|-----------|
| Zone01 入口大厅 | 暖橙 | `#FF8C26` | 肃穆、熟悉 |
| Zone02 研究区蜡烛 | 蜡黄 | `#FFD080` | 神秘、书卷 |
| Zone03 深处 | 暗橙→暗红 | `#FF6010` | 危险、压迫 |
| 出口 Beacon | 冷蓝 | `#66CCFF` | 异常、召唤 |

---

## 环境光设置（WorldEnvironment）

```
ambient_light_color = Color(0.18, 0.12, 0.08)   # 极暗暖棕，防止纯黑死角
ambient_light_energy = 0.25                       # 足够低，不破坏阴影戏剧感
```

不要提高 ambient_energy——地窟的力量在于阴影，不在于光。

---

## 动态灯光事件

### 事件1：加雷斯被击败
- 他背后的两盏火把（`±1.5, 2.0, 1.0`）能量从 1.2 → 0.6
- 实现：击败加雷斯时，用 `Tween` 过渡，2秒完成
- 意图：他的"权威"消散，对应光线减弱

### 事件2：阿卡娜被击败
- 蜡烛区主光能量从 1.5 → 0.7，蜡烛颜色轻微蓝移（`#FFD080` → `#E8C060`）
- 实现：同上，Tween 3秒
- 意图：她的研究失去了聚焦，变得模糊

### 事件3：Vex 被击败 / 离开
- 祭坛蜡烛双光源同时熄灭（energy → 0），Tween 1.5秒
- 实现：Vex 的 `beat` 信号触发 world.gd 里的灯光控制函数
- 意图：她燃的灯随她而去

### 事件4：铁皮兽触碰门洞
- Beacon 蓝光：`energy 2.0 → 5.0 → 0`，Tween 先0.5秒增强，再1.0秒熄灭
- 铁皮兽身上的小蓝光同时激活再熄灭
- 实现：在 `world.gd` 的 `_on_exit_zone_entered` 里控制

---

## 实现参考（GDScript 片段）

```gdscript
# 击败某个NPC后，渐暗对应光源
func _dim_light(light: OmniLight3D, target_energy: float, duration: float) -> void:
    var t := create_tween()
    t.tween_property(light, "light_energy", target_energy, duration).set_ease(Tween.EASE_OUT)

# Beacon 出口动画
func _beacon_pulse(beacon: OmniLight3D) -> void:
    var t := create_tween()
    t.tween_property(beacon, "light_energy", 5.0, 0.5).set_ease(Tween.EASE_IN)
    t.tween_property(beacon, "light_energy", 0.0, 1.0).set_ease(Tween.EASE_OUT)
    await t.finished
    beacon.queue_free()
```

---

## 禁止事项

- ❌ 不要在 Zone03 加补充火把照明——黑暗是设计意图，不是bug
- ❌ 不要让 beacon 蓝光范围超过 8u——它只能照亮门洞附近，不能照亮整个北段
- ❌ 不要把 ambient_energy 调高于 0.4，否则阴影全部消失，场景失去层次
