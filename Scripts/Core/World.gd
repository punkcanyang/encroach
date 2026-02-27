## World - 游戏世界根节点
##
## 职责：
## 1. 作为场景树的根节点
## 2. 监听并响应各子系统的信号
## 3. 输出全局日志信息
##
## 设计哲学：World 不发号施令，只负责观察和记录

extends Node2D


## 子系统引用
@onready var time_system: Node = $TimeSystem
@onready var agent_manager: Node = $AgentManager
@onready var building_manager: Node = $BuildingManager
@onready var rule_evaluator: Node = $RuleEvaluator
@onready var resource_manager: Node = $ResourceManager
@onready var settings_manager: Node = $SettingsManager
@onready var world_generator: Node = $WorldGenerator


## 内部状态：是否已初始化信号连接
var _signals_connected: bool = false


func _ready() -> void:
	# 验证所有子系统节点存在
	_validate_child_nodes()
	
	# 连接 TimeSystem 的信号到本节点的处理函数
	_connect_time_signals()
	
	# 标记初始化完成
	_signals_connected = true
	
	# 输出启动日志
	print("[World] 系统初始化完成")
	print("[World] 等待时间系统信号...")


func _process(_delta: float) -> void:
	# World 节点本身不进行逻辑处理
	# 所有逻辑由子系统通过信号驱动
	pass


## 验证所有必需的子节点都存在
func _validate_child_nodes() -> void:
	assert(time_system != null, "[World] TimeSystem 节点不存在")
	assert(agent_manager != null, "[World] AgentManager 节点不存在")
	assert(building_manager != null, "[World] BuildingManager 节点不存在")
	assert(rule_evaluator != null, "[World] RuleEvaluator 节点不存在")
	assert(resource_manager != null, "[World] ResourceManager 节点不存在")
	assert(settings_manager != null, "[World] SettingsManager 节点不存在")
	assert(world_generator != null, "[World] WorldGenerator 节点不存在")


## 连接时间系统的信号到本地处理函数
func _connect_time_signals() -> void:
	# 连接 Tick 信号 - 用于输出 Tick 日志
	var tick_result: int = time_system.connect("tick_passed", _on_tick_passed)
	assert(tick_result == OK, "[World] 连接 tick_passed 信号失败")
	
	# 连接 Day 信号 - 用于输出 Day 日志
	var day_result: int = time_system.connect("day_passed", _on_day_passed)
	assert(day_result == OK, "[World] 连接 day_passed 信号失败")


## Tick 信号处理函数
## 参数 tick_num: 当前的 Tick 编号
func _on_tick_passed(tick_num: int) -> void:
	print("Tick: " + str(tick_num))


## Day 信号处理函数
## 参数 day_num: 当前的天数
func _on_day_passed(day_num: int) -> void:
	print("========== Day " + str(day_num) + " 降临 ==========")


# [For Future AI]
# =========================
# 关键假设:
# 1. TimeSystem 是 World 的直接子节点，路径为 $TimeSystem
# 2. TimeSystem 在 _ready() 时已经完成初始化
# 3. 信号连接不会失败（如果失败会触发 assert）
#
# 潜在边界情况:
# 1. 如果子节点被手动删除，后续信号连接会失败
# 2. 如果 TimeSystem 的脚本被替换，信号名称可能不匹配
# 3. print 输出在 Release 模式下可能被禁用 - 需考虑日志系统
#
# 依赖模块:
# - TimeSystem: 提供 tick_passed 和 day_passed 信号
# - AgentManager: 当前仅作为子节点存在，未来会连接信号
# - BuildingManager: 当前仅作为子节点存在，未来会连接信号
# - RuleEvaluator: 当前仅作为子节点存在，未来会连接信号
