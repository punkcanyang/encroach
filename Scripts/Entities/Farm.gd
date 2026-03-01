## Farm - 农田建筑实体
##
## 职责：一种持续产出食物的建筑。
## 随着交互次数（熟练度）的增加，其生长速度和单次产出会提高。
##
## AI Context: 继承自 Building，重写了 _draw, _process 和 get_status。

extends "res://Scripts/Entities/Building.gd"


## 农田生长进度 (0.0 - 100.0)
var growth: float = 0.0

## 是否成熟可收割
var is_ready: bool = false

## 历史工作交互次数（熟练度机制）
var total_work_count: int = 0

## 伪装成 ResourceType.FOOD 以被 Agent 识别
var resource_type: int = 0

## 基础参数
const BASE_GROWTH_RATE: float = 15.0 # 每秒生长基础值
const BASE_YIELD: int = 150 # 基础产量


func _ready() -> void:
	# 调用基类的 _ready 确保入组
	super._ready()
	# Farm 的类型是 0
	building_type = 0


func _process(delta: float) -> void:
	if is_blueprint:
		return
		
	if not is_ready:
		# 熟练度加成：每 10 次工作增加 10% 生长速度，最高 200% (2倍)
		var speed_multiplier = 1.0 + min(total_work_count / 10.0 * 0.1, 2.0)
		growth += BASE_GROWTH_RATE * speed_multiplier * delta
		
		if growth >= 100.0:
			growth = 100.0
			is_ready = true
			
		queue_redraw()


func _draw() -> void:
	var size = get_size()
	var rect = Rect2(-size / 2.0, size)
	
	if is_blueprint:
		# 基类负责绘制蓝图状态
		super._draw()
	else:
		# 绘制农田土地（深褐色背景）
		draw_rect(rect, Color(0.3, 0.2, 0.1), true)
		
		# 绘制作物生长状态 (4列小植物)
		var col_width = size.x / 4.0
		var plant_height = size.y * 0.8 * (growth / 100.0)
		
		var plant_color = Color(0.2, 0.8, 0.2) if is_ready else Color(0.4, 0.7, 0.3)
		
		if plant_height > 2.0:
			for i in range(4):
				var px = - size.x / 2.0 + col_width * i + col_width / 2.0
				draw_rect(Rect2(px - 3, size.y / 2.0 - plant_height, 6, plant_height), plant_color)
		
		# 绘制高亮边框如果成熟
		if is_ready:
			draw_rect(rect, Color(0.8, 0.8, 0.2, 0.5), false, 2.0)
		else:
			draw_rect(rect, Color(0.2, 0.15, 0.05), false, 1.0)


## 被 Agent 交互/收割时调用（兼容 Resource 的 collect 接口）
func collect(requested_amount: int, _collector: Node2D) -> int:
	if is_blueprint:
		# 蓝图态被敲击相当于推进建造进度
		add_progress(10.0) # 假设每次敲击 10 进度
		return 0 # 返回 0 意味着没采集到东西，Agent 下一帧会继续寻找它并再次敲击
		
	if not is_ready:
		return 0
		
	# 计算熟练度加成的产量
	# 每 10 次工作增加 2 产量
	var bonus: int = floori(total_work_count / 10.0) * 2
	var final_yield: int = BASE_YIELD + bonus
	
	# 重置生长并增加熟练度
	growth = 0.0
	is_ready = false
	total_work_count += 1
	
	queue_redraw()
	
	var actual_yield = min(final_yield, requested_amount)
	
	# 推送日志
	get_tree().call_group("event_log", "add_log", "🌾 农田完成了一次收割 (+%d 食物)" % actual_yield, "#bbffaa")
	
	# 返回实际产量（限制在请求范围内）
	return actual_yield


## 伪装成 Resource 的 is_depleted 接口
func is_depleted() -> bool:
	if is_blueprint:
		return false # 蓝图需要施工，不可视为空
	if not is_ready:
		return true # 生长中，让 Agent 忽略它
	return false # 成熟可收割


## 扩展基类的状态获取
func get_status() -> Dictionary:
	var status = super.get_status()
	status["growth"] = growth
	status["is_ready"] = is_ready
	status["proficiency"] = total_work_count
	
	if not is_blueprint:
		var bonus: int = floori(total_work_count / 10.0) * 2
		status["current_yield"] = BASE_YIELD + bonus
		
	return status


## 回传给 Agent 的吸引力分数 (引力系统)
func get_attraction_weight() -> float:
	if is_blueprint:
		return 0.0 # 蓝图自有 150 基础分
	if is_ready:
		return 2000.0 # 成熟的农田散发极高引力，吸引全图闲余 AI 收割
	return 0.0


# [For Future AI]
# =========================
# 关键假设:
# 1. 农田独立处理 _process 内的生长逻辑，成熟后停止生长
# 2. 如果是蓝图，Agent "harvest" 动作实际上是充当施工
# 3. 熟练度直接绑定在具体建筑实例上
# 4. get_attraction_weight() 会被 HumanAgent 调用以计算采集优先级
