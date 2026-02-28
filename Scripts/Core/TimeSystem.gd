## TimeSystem - 时间推进系统
## 
## 职责：推进游戏时间，发射 Tick 和 Day 信号
## 这是世界的心跳，所有系统都依赖此信号进行更新

extends Node


## 信号：每个 Tick 结束时发射，携带当前 Tick 编号
signal tick_passed(current_tick: int)

## 信号：每天开始时发射，携带当前天数
signal day_passed(current_day: int)


## 配置参数：多少真实秒数 = 1 个 Tick
@export var seconds_per_tick: float = 0.5

## 配置参数：多少个 Tick = 1 天
@export var ticks_per_day: int = 3


## 内部状态：当前 Tick 编号（从 1 开始）
var current_tick: int = 0

## 内部状态：当前天数（从 1 开始）
var current_day: int = 0

## 内部状态：累加的时间计时器
var _time_accumulator: float = 0.0

## 内部状态：当前 Tick 内的进度计数
var _tick_counter: int = 0


func _ready() -> void:
	add_to_group("time_system")
	# 初始化状态
	current_tick = 0
	current_day = 0
	_time_accumulator = 0.0
	_tick_counter = 0


func _process(delta: float) -> void:
	# 累加经过的真实时间
	_time_accumulator += delta
	
	# 检查是否达到一个 Tick 的时间
	if _time_accumulator >= seconds_per_tick:
		# 重置累加器，减去已消耗的时间
		_time_accumulator -= seconds_per_tick
		
		# 推进 Tick
		_advance_tick()


func _advance_tick() -> void:
	# Tick 编号加 1
	current_tick += 1
	_tick_counter += 1
	
	# 发射 Tick 信号，通知所有监听者
	tick_passed.emit(current_tick)
	
	# 检查是否完成一天（达到 ticks_per_day）
	if _tick_counter >= ticks_per_day:
		_advance_day()


func _advance_day() -> void:
	# 天数加 1
	current_day += 1
	
	# 重置 Tick 计数器，为下一天做准备
	_tick_counter = 0
	
	# 发射 Day 信号，通知所有监听者
	day_passed.emit(current_day)


## 获取当前的时间状态，用于调试或 UI 显示
func get_time_status() -> Dictionary:
	var status: Dictionary = {}
	status["tick"] = current_tick
	status["day"] = current_day
	status["tick_in_day"] = _tick_counter
	status["total_ticks_per_day"] = ticks_per_day
	return status


## 暂停时间推进
func pause() -> void:
	set_process(false)


## 恢复时间推进
func resume() -> void:
	set_process(true)


## 检查时间系统是否在运行
func is_running() -> bool:
	return is_processing()


# [For Future AI]
# =========================
# 关键假设:
# 1. _process(delta) 会被 Godot 引擎稳定调用
# 2. delta 的值是可靠的，不会出现极端值
# 3. 信号发射顺序：先 tick_passed，后 day_passed（同 Tick 内）
#
# 潜在边界情况:
# 1. 如果 delta 过大（如游戏暂停后恢复），可能导致时间跳跃 - 目前未处理
# 2. _time_accumulator 可能因浮点数精度问题累积误差 - 长期运行需注意
# 3. 如果 seconds_per_tick 或 ticks_per_day 在运行时被修改，行为未定义
#
# 依赖模块:
# - 无（此模块为独立核心模块，不依赖其他系统）
