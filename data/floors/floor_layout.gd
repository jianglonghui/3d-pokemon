## FloorLayout — 每一层地牢的布局参数
## 通过 .tres 文件定义，DungeonBuilder 读取并构建场景
## 新增楼层只需新建 floor_XX.tres，不修改代码
extends Resource
class_name FloorLayout

## 楼层基础信息
@export var floor_number: int    = 1
@export var floor_name:   String = ""

## 房间尺寸（格数）
@export var room_width_tiles: int   = 7    ## 东西向格数
@export var room_depth_tiles: int   = 11   ## 南北向格数
@export var tile_size:        float = 2.0  ## 每格世界单位

## Zone 分界（Z 坐标，世界空间）
## Zone01: z > zone01_limit
## Zone02: zone02_limit < z ≤ zone01_limit
## Zone03: z ≤ zone02_limit
@export var zone01_limit: float =  2.0
@export var zone02_limit: float = -4.0

## 各 Zone 填充光颜色与强度
@export var zone01_color:  Color = Color(1.0, 0.549, 0.149)   ## #FF8C26 暖橙
@export var zone01_energy: float = 1.5
@export var zone02_color:  Color = Color(1.0, 0.816, 0.502)   ## #FFD080 蜡黄
@export var zone02_energy: float = 1.2
@export var zone03_color:  Color = Color(1.0, 0.376, 0.063)   ## #FF6010 暗橙红
@export var zone03_energy: float = 2.0

## 背景音乐（留空则不替换当前音乐）
@export var music: AudioStream = null
