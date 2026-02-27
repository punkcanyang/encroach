## Cave - 山洞（基地）
##
## 职责：作为族群的基地，储存所有类型的资源并生成新人类
## 每种资源独立储存，各有上限。繁殖只消耗食物。
##
## AI Context: 多资源储存版本。storage 字典按 ResourceTypes.Type 分类管理

extends Node2D


## 信号：当任意资源储存量变化时发射
signal storage_changed(building: Node2D, resource_type: int, new_amount: int)

## 信号：当某类资源储存满时发射
signal storage_full(resource_type: int)

## 信号：当人类被生成时发射
signal human_spawned(human: Node2D)

## 信号：当尝试生成人类但食物不足时发射
signal spawn_failed(reason: String)


## 常量：住所人口容量上限（山洞阶段为6人）
const MAX_POPULATION: int = 6

## 常量：每种资源的基础最大储存量
const BASE_MAX_STORAGE_PER_TYPE: int = 100

## 常量：每种资源的最大储存量
const MAX_STORAGE_PER_TYPE: int = 100

## 常量：生成一个人类所需的食物
const FOOD_COST_PER_HUMAN: int = 50

## 常量：生成人类的间隔（天）
const SPAWN_INTERVAL_DAYS: int = 3650
const DAYS_PER_YEAR: int = 365

## 常量：山洞绘制大小
const CAVE_SIZE: float = 40.0

## 常量：山洞颜色
const CAVE_COLOR: Color = Color(0.4, 0.3, 0.2)

## 常量：各资源类型的指示器颜色
const STORAGE_COLORS: Dictionary = {
	0: Color(0.2, 0.8, 0.2, 0.5), # FOOD - 绿色
	1: Color(0.55, 0.55, 0.55, 0.5), # DIRT - 灰色
	2: Color(0.9, 0.92, 0.95, 0.5), # IND_METAL - 白色
	3: Color(0.95, 0.8, 0.2, 0.5) # PREC_METAL - 金色
}


## 属性：所有资源的储存量（Dictionary: Type -> int）
var storage: Dictionary = {}

## 属性：上次生成人类的年份
var last_spawn_year: int = 0

## 建筑系统字段 (兼容蓝图)
var building_type: int = 4 # BuildingType.CAVE
var is_blueprint: bool = false
var construction_progress: float = 0.0
var work_required: float = 100.0

## 内部引用
var _time_system: Node = null
var _agent_manager: Node = null


func _ready() -> void:
	add_to_group("inspectable")
	add_to_group("building")
	set_process(false)

	# WHY: 初始化每种资源的独立储存槽，食物给 50 初始值
	storage = ResourceTypes.create_empty_storage()
	storage[ResourceTypes.Type.FOOD] = 50

	last_spawn_year = 0
	_connect_to_systems()
	queue_redraw()

	print("🏠 Cave: 山洞已建立！初始食物: %d/%d，每10年将自动繁殖（消耗50食物）" % [
		storage[ResourceTypes.Type.FOOD], get_max_storage_per_type(ResourceTypes.Type.FOOD)
	])


## 动态计算当前的全局人口上限
## 包含山洞基础下限 + 所有已竣工住所提供的上限
func get_max_population() -> int:
	var total_cap: int = 0
	
	var world = get_node_or_null("/root/World")
	if world != null:
		var bm = world.get_node_or_null("BuildingManager")
		if bm != null and bm.has_method("get_all_buildings"):
			for building in bm.get_all_buildings():
				if "building_type" in building and bm.has_method("get_building_data"):
					var data = bm.get_building_data(building.building_type)
					total_cap += data.get("pop_cap", 0)
					
	# WHY: 保证至少有初始的6个人口上限，无论玩家有没有拆掉最初的山洞
	return max(MAX_POPULATION, total_cap)


## 动态计算当前全局指定资源储存上限
## 包含山洞基础上限 + 所有已竣工的住所提供的上限，并校验许可存储项
func get_max_storage_per_type(type: int) -> int:
	# 始祖山洞保底能存 Food 和 Dirt，上限100。如果后续升到木屋就不走这个了。
	if type == ResourceTypes.Type.FOOD or type == ResourceTypes.Type.DIRT:
		return BASE_MAX_STORAGE_PER_TYPE
		
	return 0


func _connect_to_systems() -> void:
	var world: Node = get_node("/root/World")
	if world == null:
		push_warning("Cave: 无法找到 World 节点")
		return

	_time_system = world.get_node("TimeSystem")
	if _time_system != null:
		_time_system.day_passed.connect(_on_day_passed)
	else:
		push_warning("Cave: 无法找到 TimeSystem 节点")

	_agent_manager = world.get_node("AgentManager")
	if _agent_manager == null:
		push_warning("Cave: 无法找到 AgentManager 节点")


func _draw() -> void:
	if is_blueprint:
		var size = Vector2(80, 80)
		var rect = Rect2(-size / 2.0, size)
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.3), true)
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 2.0)
		
		# 进度条
		draw_rect(Rect2(-size.x / 2, size.y / 2 + 5, size.x, 6), Color(0.2, 0.2, 0.2))
		var progress_width = size.x * (construction_progress / max(work_required, 1.0))
		draw_rect(Rect2(-size.x / 2, size.y / 2 + 5, progress_width, 6), Color(0.2, 0.8, 0.2))
		return

	# 绘制山洞本体（三角形表示山洞入口）
	var triangle_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -CAVE_SIZE * 0.8),
		Vector2(-CAVE_SIZE * 0.7, CAVE_SIZE * 0.5),
		Vector2(CAVE_SIZE * 0.7, CAVE_SIZE * 0.5)
	])
	draw_polygon(triangle_points, PackedColorArray([CAVE_COLOR]))

	# 绘制边框
	draw_line(triangle_points[0], triangle_points[1], Color.WHITE, 2.0)
	draw_line(triangle_points[1], triangle_points[2], Color.WHITE, 2.0)
	draw_line(triangle_points[2], triangle_points[0], Color.WHITE, 2.0)

	# WHY: 在山洞底部绘制每种资源的小指示器，从左到右排列
	var indicator_x_offset: float = - CAVE_SIZE * 0.5
	var indicator_spacing: float = CAVE_SIZE * 0.35
	var current_max: int = 0
	for type in ResourceTypes.get_all_types():
		current_max = get_max_storage_per_type(type)
		if current_max <= 0: continue
		
		var amount: int = storage.get(type, 0)
		var ratio: float = float(amount) / float(current_max)
		var radius: float = CAVE_SIZE * 0.15 * ratio
		if radius > 0.5:
			var color: Color = STORAGE_COLORS.get(type, Color.WHITE)
			draw_circle(Vector2(indicator_x_offset, CAVE_SIZE * 0.1), radius, color)
		indicator_x_offset += indicator_spacing

	# 绘制食物数量标签（保留最关键的食物信息）
	var font = ThemeDB.fallback_font
	var font_size = 12
	var food_amount: int = storage.get(ResourceTypes.Type.FOOD, 0)
	var text = "🍎%d" % food_amount
	var text_size = font.get_string_size(text, font_size)
	draw_string(font, Vector2(-text_size.x * 0.5, CAVE_SIZE + 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _on_day_passed(current_day: int) -> void:
	if current_day > 0 and current_day % SPAWN_INTERVAL_DAYS == 0:
		_try_spawn_human()


## 尝试生成新人类
func _try_spawn_human() -> void:
	if _agent_manager != null and _agent_manager.agents.size() >= get_max_population():
		spawn_failed.emit("人口已达上限 (%d)" % get_max_population())
		print("🏠 Cave: 10年繁殖周期到达，但人口已达上限 %d，暂停繁殖" % get_max_population())
		return

	var food: int = storage.get(ResourceTypes.Type.FOOD, 0)

	if food < FOOD_COST_PER_HUMAN:
		spawn_failed.emit("食物不足（需要 %d，现有 %d）" % [FOOD_COST_PER_HUMAN, food])
		print("🏠 Cave: 10年繁殖周期到达，但食物不足（需要 %d，现有 %d），无法生成新人类" % [FOOD_COST_PER_HUMAN, food])
		return

	if _agent_manager == null:
		spawn_failed.emit("AgentManager 不可用")
		return

	# 扣除食物
	storage[ResourceTypes.Type.FOOD] -= FOOD_COST_PER_HUMAN
	storage_changed.emit(self , ResourceTypes.Type.FOOD, storage[ResourceTypes.Type.FOOD])

	var spawn_offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var spawn_position: Vector2 = global_position + spawn_offset

	var new_human: Node2D = _agent_manager.add_agent(spawn_position, 20, 30)
	if new_human != null:
		human_spawned.emit(new_human)
		print("🏠 Cave: 新人类已生成！消耗食物 %d，剩余 %d/%d" % [
			FOOD_COST_PER_HUMAN, storage[ResourceTypes.Type.FOOD], get_max_storage_per_type(ResourceTypes.Type.FOOD)
		])
		queue_redraw()
	else:
		# 生成失败，返还食物
		storage[ResourceTypes.Type.FOOD] += FOOD_COST_PER_HUMAN
		storage_changed.emit(self , ResourceTypes.Type.FOOD, storage[ResourceTypes.Type.FOOD])
		spawn_failed.emit("AgentManager 生成失败")


## 添加指定类型的资源到山洞
## 返回：实际添加的数量
func add_resource(type: int, amount: int) -> int:
	assert(amount > 0, "Cave: 添加数量必须大于 0")

	var current: int = storage.get(type, 0)
	var max_cap: int = get_max_storage_per_type(type)
	if max_cap <= 0:
		# WHY: 返回0代表容量不可用（当前建筑配置下不允许存储该类型）
		return 0
		
	var space: int = max_cap - current
	if space <= 0:
		storage_full.emit(type)
		print("Cave: 无法添加 %s - 储存已满 (%d/%d)" % [
			ResourceTypes.get_type_name(type), current, max_cap
		])
		return 0

	var actual: int = min(amount, space)
	storage[type] = current + actual
	storage_changed.emit(self , type, storage[type])

	if actual < amount:
		storage_full.emit(type)

	var current_max_cap: int = get_max_storage_per_type(type)
	print("Cave: %s +%d，当前 %d/%d" % [
		ResourceTypes.get_type_name(type), actual, storage[type], current_max_cap
	])
	queue_redraw()
	return actual


## 消耗指定类型的资源
## 返回：实际消耗的数量
func consume_resource(type: int, amount: int) -> int:
	if amount <= 0:
		return 0

	var current: int = storage.get(type, 0)
	if current <= 0:
		return 0

	var actual: int = min(amount, current)
	storage[type] = current - actual
	storage_changed.emit(self , type, storage[type])

	queue_redraw()
	return actual


## 向后兼容：添加食物（旧接口包装）
func add_food(amount: int) -> int:
	return add_resource(ResourceTypes.Type.FOOD, amount)


## 向后兼容：消耗食物（旧接口包装）
func consume_food(amount: int) -> int:
	return consume_resource(ResourceTypes.Type.FOOD, amount)


## 获取指定类型的储存量
func get_stored(type: int) -> int:
	return storage.get(type, 0)


## 向后兼容：获取食物储存量
func get_stored_food() -> int:
	return get_stored(ResourceTypes.Type.FOOD)


## 检查指定类型是否已满
func is_storage_full_for(type: int) -> bool:
	return storage.get(type, 0) >= get_max_storage_per_type(type)


## 向后兼容
func is_storage_full() -> bool:
	return is_storage_full_for(ResourceTypes.Type.FOOD)


## 获取剩余储存空间
func get_remaining_space(type: int) -> int:
	return get_max_storage_per_type(type) - storage.get(type, 0)


## 获取山洞状态
func get_status() -> Dictionary:
	var status: Dictionary = {}
	
	if is_blueprint:
		status["is_blueprint"] = true
		status["progress"] = construction_progress
		status["work_required"] = work_required
		var manager = get_node_or_null("/root/World/BuildingManager")
		if manager != null and manager.has_method("get_building_data"):
			var data = manager.get_building_data(building_type)
			status["name"] = data.get("name", "CAVE_TITLE")
		else:
			status["name"] = "CAVE_TITLE"
		return status
		
	# WHY: 返回所有资源的库存，UI 层按需提取
	status["storage"] = storage.duplicate()
	
	var max_caps: Dictionary = {}
	for t in ResourceTypes.get_all_types():
		max_caps[t] = get_max_storage_per_type(t)
	status["max_storage"] = max_caps
	
	status["position"] = global_position
	# 向后兼容
	status["stored_food"] = storage.get(ResourceTypes.Type.FOOD, 0)
	status["can_spawn_human"] = storage.get(ResourceTypes.Type.FOOD, 0) >= FOOD_COST_PER_HUMAN
	return status


## 蓝图鸭子类型接口
func start_construction(required: float) -> void:
	is_blueprint = true
	construction_progress = 0.0
	work_required = required
	queue_redraw()

func add_progress(amount: float) -> void:
	if not is_blueprint: return
	construction_progress += amount
	if construction_progress >= work_required:
		finish_construction()
	queue_redraw()

func finish_construction() -> void:
	if is_blueprint:
		is_blueprint = false
		construction_progress = work_required
		var manager = get_node_or_null("/root/World/BuildingManager")
		if manager != null and manager.has_method("finalize_blueprint"):
			manager.finalize_blueprint(self )
		queue_redraw()

# [For Future AI]
# =========================
# 关键假设:
# 1. 每种资源上限随新建住所建筑动态增加 (get_max_storage_per_type)
# 2. 繁殖只消耗食物（FOOD），不消耗矿物
# 3. 保留 add_food / consume_food / get_stored_food 向后兼容接口
# 4. storage 字典格式: { ResourceTypes.Type.FOOD: int, ... }
#
# 潜在边界情况:
# 1. 不同资源上限未来可能需要差异化
# 2. 多山洞场景每个山洞独立管理
#
# 依赖模块:
# - ResourceTypes: 全局枚举定义
# - TimeSystem: 繁殖周期
# - AgentManager: 生成人类
# - 被 HumanAgent 依赖: 存取资源
