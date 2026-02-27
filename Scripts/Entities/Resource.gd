## Resource - 资源实体
##
## 职责：代表世界中的一个可采集资源节点（食物或矿物）
## 使用 _draw() 绘制外观，可被 Agent 采集
## 食物绘制为红色爱心，矿物绘制为不规则晶体
##
## AI Context: 资源类型按 TODO 精简为 FOOD/DIRT/IND_METAL/PREC_METAL 四种

extends Node2D


## 信号：当资源被采集时发射
signal resource_collected(amount: int, collector: Node2D)

## 信号：当资源耗尽时发射
signal resource_depleted()


## 枚举：资源类型（按 TODO 精简为4大基础资源）
enum ResourceType {
	FOOD, ## 食物 - 红色爱心
	DIRT, ## 土矿 - 灰色晶体
	IND_METAL, ## 工业金属矿 - 白色晶体
	PREC_METAL ## 贵金属矿 - 金黄色晶体
}

## 资源类型
@export var resource_type: ResourceType = ResourceType.FOOD

## 资源数量
@export var amount: int = 10

## 资源最大容量
@export var max_amount: int = 100

## 采集难度（影响采集速度，MVP 暂不实现）
@export var difficulty: int = 1

## 采集半径（Agent 需要在此范围内才能采集）
@export var collection_radius: float = 30.0


## 颜色常量
const FOOD_COLOR: Color = Color(0.9, 0.2, 0.2) ## 红色爱心
const DIRT_COLOR: Color = Color(0.55, 0.55, 0.55) ## 灰色土矿
const IND_METAL_COLOR: Color = Color(0.9, 0.92, 0.95) ## 白色工业金属
const PREC_METAL_COLOR: Color = Color(0.95, 0.8, 0.2) ## 金黄贵金属

## 美术常量
const RESOURCE_SIZE: float = 6.0


func _ready() -> void:
	add_to_group("inspectable")
	queue_redraw()
	# 关闭空跑进程以节省性能
	set_process(false)
	set_physics_process(false)
	
	# print("Resource: 生成 %s 资源，数量: %d，位置: %s" % [
	# 	_get_type_name(),
	# 	amount,
	# 	str(global_position)
	# ])


func _draw() -> void:
	# 根据资源量调整大小（200-5000范围，映射放大倍数）
	var current_size: float = RESOURCE_SIZE * (1.0 + (amount / 5000.0) * 2.0)
	
	if resource_type == ResourceType.FOOD:
		_draw_heart(current_size)
	else:
		# 矿物统一使用晶体绘制
		_draw_crystal(current_size, _get_resource_color())


## 绘制食物：红色爱心
func _draw_heart(size: float) -> void:
	var heart_color: Color = FOOD_COLOR
	var points = PackedVector2Array([
		Vector2(0, size * 0.8), # 底部尖刺
		Vector2(size * 1.2, -size * 0.2), # 右侧宽部
		Vector2(size * 0.6, -size * 1.0), # 右上圆弧
		Vector2(0, -size * 0.4), # 凹陷中心
		Vector2(-size * 0.6, -size * 1.0), # 左上圆弧
		Vector2(-size * 1.2, -size * 0.2) # 左侧宽部
	])
	draw_polygon(points, PackedColorArray([heart_color]))
	
	# 白色边线增加质感
	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		draw_line(points[i], points[next_i], Color.WHITE, 1.0)


## 绘制矿物：三个方块叠在一起的不规则晶体
## 由三个倾斜的四边形叠加组成，模拟晶簇效果
func _draw_crystal(size: float, color: Color) -> void:
	# 颜色变体：用于不同晶体块产生层次感
	var dark_color: Color = color.darkened(0.25)
	var light_color: Color = color.lightened(0.15)
	
	# 晶体 1（底部，最大，稍偏左）
	var crystal_1 = PackedVector2Array([
		Vector2(-size * 0.8, size * 0.6), # 左下
		Vector2(-size * 0.3, -size * 1.0), # 左上尖
		Vector2(size * 0.2, -size * 0.7), # 右上
		Vector2(size * 0.1, size * 0.6) # 右下
	])
	draw_polygon(crystal_1, PackedColorArray([dark_color]))
	
	# 晶体 2（中间，稍偏右，更高）
	var crystal_2 = PackedVector2Array([
		Vector2(-size * 0.2, size * 0.5), # 左下
		Vector2(size * 0.1, -size * 1.3), # 左上尖（最高点）
		Vector2(size * 0.6, -size * 0.9), # 右上
		Vector2(size * 0.5, size * 0.5) # 右下
	])
	draw_polygon(crystal_2, PackedColorArray([color]))
	
	# 晶体 3（右侧最小，矮胖）
	var crystal_3 = PackedVector2Array([
		Vector2(size * 0.3, size * 0.6), # 左下
		Vector2(size * 0.5, -size * 0.5), # 上尖
		Vector2(size * 0.9, -size * 0.3), # 右上
		Vector2(size * 0.85, size * 0.6) # 右下
	])
	draw_polygon(crystal_3, PackedColorArray([light_color]))
	
	# 边线勾勒（只画最外层轮廓以节省性能）
	var outline_color: Color = Color.WHITE.darkened(0.3)
	for crystal in [crystal_1, crystal_2, crystal_3]:
		for i in range(crystal.size()):
			var next_i: int = (i + 1) % crystal.size()
			draw_line(crystal[i], crystal[next_i], outline_color, 1.0)


## 尝试采集资源
func collect(requested_amount: int, collector: Node2D) -> int:
	assert(requested_amount > 0, "Resource: 采集数量必须大于 0")
	assert(collector != null, "Resource: 采集者不能为空")
	
	if amount <= 0:
		return 0
	
	var actual_amount: int = min(requested_amount, amount)
	amount -= actual_amount
	
	resource_collected.emit(actual_amount, collector)
	
	if amount <= 0:
		resource_depleted.emit()
		print("Resource: %s 资源已耗尽，位置: %s - 正在消失" % [_get_type_name(), str(global_position)])
		call_deferred("_deferred_free")
	
	return actual_amount


## 延迟销毁
func _deferred_free() -> void:
	queue_free()


## 补充资源
func replenish(add_amount: int) -> void:
	assert(add_amount > 0, "Resource: 补充数量必须大于 0")
	amount = min(amount + add_amount, max_amount)
	queue_redraw()


## 检查资源是否耗尽
func is_depleted() -> bool:
	return amount <= 0


## 获取资源类型名称（多语言键）
func _get_type_name() -> String:
	match resource_type:
		ResourceType.FOOD: return "RESOURCE_FOOD"
		ResourceType.DIRT: return "RESOURCE_DIRT"
		ResourceType.IND_METAL: return "RESOURCE_IND_METAL"
		ResourceType.PREC_METAL: return "RESOURCE_PREC_METAL"
		_: return "RESOURCE_UNKNOWN"


## 获取资源类型对应的颜色
func _get_resource_color() -> Color:
	match resource_type:
		ResourceType.FOOD: return FOOD_COLOR
		ResourceType.DIRT: return DIRT_COLOR
		ResourceType.IND_METAL: return IND_METAL_COLOR
		ResourceType.PREC_METAL: return PREC_METAL_COLOR
		_: return Color.GRAY


## 获取资源状态
func get_status() -> Dictionary:
	var status: Dictionary = {}
	status["type"] = _get_type_name()
	status["amount"] = amount
	status["max_amount"] = max_amount
	status["position"] = global_position
	status["depleted"] = is_depleted()
	return status


## 将资源限制在世界边界内
func clamp_to_world_bounds(world_rect: Rect2) -> void:
	global_position.x = clamp(global_position.x, world_rect.position.x, world_rect.position.x + world_rect.size.x)
	global_position.y = clamp(global_position.y, world_rect.position.y, world_rect.position.y + world_rect.size.y)


## 检查资源是否在世界边界内
func is_in_world_bounds(world_rect: Rect2) -> bool:
	return world_rect.has_point(global_position)


# [For Future AI]
# =========================
# 关键假设:
# 1. 资源类型精简为4种：FOOD, DIRT, IND_METAL, PREC_METAL
# 2. 食物用红色爱心绘制，矿物用不规则晶体绘制（三个倾斜方块叠加）
# 3. 土矿灰色、工业金属白色、贵金属金黄色
# 4. 采集操作会减少资源数量，耗尽时节点自动销毁
#
# 潜在边界情况:
# 1. 矿物目前不能被 Agent 采集（需要规则集2的前置：饱腹度>=80 才允许采非食物）
# 2. 高级矿物降级机制尚未实现（贵金属->工业金属->土矿）
#
# 依赖模块:
# - WorldGenerator: 负责生成不同类型的资源
# - HumanAgent: 目前只采集食物
