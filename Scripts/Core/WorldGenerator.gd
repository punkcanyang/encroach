## WorldGenerator - 世界生成器
##
## 职责：生成游戏世界的初始状态
## 包括地图边界、食物资源、矿物资源、山洞基地和初始人类
##
## AI Context: 在游戏启动时运行，创建初始世界布局

extends Node


## 信号：当世界生成完成时发射
signal world_generation_completed(stats: Dictionary)


## 配置：世界大小（像素）
@export var world_width: float = 24000.0
@export var world_height: float = 18000.0

## 配置：食物资源点数量
@export var initial_food_count: int = 500

## 配置：矿物资源点数量
@export var initial_dirt_count: int = 500
@export var initial_ind_metal_count: int = 300
@export var initial_prec_metal_count: int = 100

## 配置：食物量范围
@export var min_food_amount: int = 200
@export var max_food_amount: int = 5000

## 配置：矿物量范围
@export var min_mineral_amount: int = 100
@export var max_mineral_amount: int = 3000

## 配置：生成边距
@export var margin: float = 100.0

## 配置：山洞安全区半径（不生成资源）
@export var cave_safe_zone: float = 500.0


## 场景引用
@export var resource_scene: PackedScene
@export var cave_scene: PackedScene

## 内部引用
var _world: Node2D
var _agent_manager: Node


func _ready() -> void:
	call_deferred("_generate_world")


func _generate_world() -> void:
	print("\n========== 世界生成开始 ==========")
	
	_world = get_node("/root/World")
	if _world == null:
		push_error("WorldGenerator: 无法找到 World 节点")
		return
	
	_agent_manager = _world.get_node("AgentManager")
	if _agent_manager == null:
		push_error("WorldGenerator: 无法找到 AgentManager")
		return
	
	var total_resources: int = initial_food_count + initial_dirt_count + initial_ind_metal_count + initial_prec_metal_count
	
	var stats: Dictionary = {
		"world_size": Vector2(world_width, world_height),
		"cave_position": Vector2.ZERO,
		"food_count": initial_food_count,
		"dirt_count": initial_dirt_count,
		"ind_metal_count": initial_ind_metal_count,
		"prec_metal_count": initial_prec_metal_count,
		"total_resources": total_resources
	}
	
	# 步骤 1: 绘制世界边界
	_draw_world_boundaries()
	
	# 步骤 2: 在世界中心生成山洞
	var cave_position: Vector2 = Vector2(world_width / 2.0, world_height / 2.0)
	_generate_cave(cave_position)
	stats["cave_position"] = cave_position
	
	# 步骤 3: 生成食物资源
	_generate_typed_resources(cave_position, 0, initial_food_count, min_food_amount, max_food_amount)
	
	# 步骤 4: 生成土矿
	_generate_typed_resources(cave_position, 1, initial_dirt_count, min_mineral_amount, max_mineral_amount)
	
	# 步骤 5: 生成工业金属矿
	_generate_typed_resources(cave_position, 2, initial_ind_metal_count, min_mineral_amount, max_mineral_amount)
	
	# 步骤 6: 生成贵金属矿
	_generate_typed_resources(cave_position, 3, initial_prec_metal_count, min_mineral_amount, max_mineral_amount)
	
	# 步骤 7: 在山洞旁生成初始人类
	_generate_initial_human(cave_position)
	
	# 步骤 8: 设置相机
	_setup_camera(cave_position)
	
	world_generation_completed.emit(stats)
	
	print("========== 世界生成完成 ==========")
	print("世界大小: %s" % str(stats["world_size"]))
	print("山洞位置: %s" % str(stats["cave_position"]))
	print("食物资源: %d 处（每处 %d-%d）" % [initial_food_count, min_food_amount, max_food_amount])
	print("土矿: %d 处 | 工业金属: %d 处 | 贵金属: %d 处" % [initial_dirt_count, initial_ind_metal_count, initial_prec_metal_count])
	print("矿物量范围: %d-%d" % [min_mineral_amount, max_mineral_amount])
	print("初始人口: 1 人")
	var time_system = get_node_or_null("/root/World/TimeSystem")
	var ticks = 3 if time_system == null else time_system.ticks_per_day
	print("时间系统: %d ticks = 1 天, 365 天 = 1 年" % ticks)
	print("繁殖规则: 每10年(3650天)自动繁殖，消耗50食物")
	print("消耗速度: 每天从山洞进食一次")
	print("提示: 鼠标悬停在物件上查看详细信息\n")


func _draw_world_boundaries() -> void:
	var boundary_node: Node2D = Node2D.new()
	boundary_node.name = "WorldBoundaries"
	boundary_node.set_script(BoundaryVisualizerScript)
	boundary_node.set_meta("width", world_width)
	boundary_node.set_meta("height", world_height)
	_world.add_child(boundary_node)


func _generate_cave(position: Vector2) -> void:
	if cave_scene == null:
		cave_scene = load("res://Scenes/Cave.tscn")
	
	if cave_scene == null:
		push_error("WorldGenerator: 无法加载 Cave.tscn")
		return
	
	var cave: Node2D = cave_scene.instantiate()
	cave.name = "Cave"
	cave.position = position
	_world.add_child(cave)
	
	print("WorldGenerator: 山洞已生成在 %s" % str(position))


## 生成指定类型的资源
## resource_type_int: 0=FOOD, 1=DIRT, 2=IND_METAL, 3=PREC_METAL
func _generate_typed_resources(
	cave_position: Vector2,
	resource_type_int: int,
	count: int,
	min_amount: int,
	max_amount: int
) -> void:
	if resource_scene == null:
		resource_scene = load("res://Scenes/Resource.tscn")
	
	if resource_scene == null:
		push_error("WorldGenerator: 无法加载 Resource.tscn")
		return
	
	for i in range(count):
		var pos: Vector2 = _get_safe_position(cave_position)
		
		var resource: Node2D = resource_scene.instantiate()
		resource.position = pos
		
		# 设置资源类型
		resource.resource_type = resource_type_int
		
		# 设置资源数量
		var res_amount: int = randi_range(min_amount, max_amount)
		resource.amount = res_amount
		resource.max_amount = res_amount
		
		_world.add_child(resource)


## 获取一个远离山洞安全区的随机位置
func _get_safe_position(cave_position: Vector2) -> Vector2:
	var pos: Vector2 = _get_random_position_in_world(margin)
	
	# 如果落在安全区内则推远
	if pos.distance_to(cave_position) < cave_safe_zone:
		var push_dir = (pos - cave_position).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.RIGHT
		pos = cave_position + push_dir * randf_range(cave_safe_zone, cave_safe_zone * 3.0)
		
		# 确保不超出世界
		pos.x = clamp(pos.x, margin, world_width - margin)
		pos.y = clamp(pos.y, margin, world_height - margin)
	
	return pos


func _generate_initial_human(cave_position: Vector2) -> void:
	var offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var pos: Vector2 = cave_position + offset
	
	var human: Node2D = _agent_manager.add_agent(pos)
	if human != null:
		print("WorldGenerator: 初始人类已生成在 %s" % str(pos))


func _setup_camera(position: Vector2) -> void:
	var existing_camera: Camera2D = _world.get_node_or_null("WorldCamera")
	if existing_camera != null:
		return
	
	var camera: Camera2D = Camera2D.new()
	camera.name = "WorldCamera"
	camera.set_script(WorldCameraScript)
	camera.position = position
	
	camera.set_meta("limit_left", 0)
	camera.set_meta("limit_top", 0)
	camera.set_meta("limit_right", world_width)
	camera.set_meta("limit_bottom", world_height)
	
	_world.add_child(camera)
	camera.make_current()
	
	print("WorldGenerator: 相机已设置")


## 获取世界内的随机位置
func _get_random_position_in_world(margin_distance: float = 0.0) -> Vector2:
	var x: float = randf_range(margin_distance, world_width - margin_distance)
	var y: float = randf_range(margin_distance, world_height - margin_distance)
	return Vector2(x, y)


## 检查位置是否在世界范围内
func is_position_in_world(pos: Vector2, margin_distance: float = 0.0) -> bool:
	return pos.x >= margin_distance and pos.x <= world_width - margin_distance and \
		   pos.y >= margin_distance and pos.y <= world_height - margin_distance


## 获取世界边界矩形
func get_world_rect() -> Rect2:
	return Rect2(0, 0, world_width, world_height)


const BoundaryVisualizerScript: GDScript = preload("res://Scripts/Core/BoundaryVisualizer.gd")
const WorldCameraScript: GDScript = preload("res://Scripts/Core/WorldCamera.gd")


# [For Future AI]
# =========================
# 关键假设:
# 1. 食物 500 处，土矿 500 处，工业金属 300 处，贵金属 100 处
# 2. 所有资源点距离山洞至少 500 像素（安全区）
# 3. resource_type 直接用 int 赋值对应 ResourceType 枚举的序号
#
# 潜在边界情况:
# 1. 总共 1400 个资源节点 + 500 draw call 可能对性能有影响
# 2. 安全区推远后可能导致地图边缘资源密度偏高
#
# 依赖模块:
# - Resource.gd: 资源实体（枚举 FOOD=0, DIRT=1, IND_METAL=2, PREC_METAL=3）
# - Cave.tscn: 山洞场景
# - BoundaryVisualizer.gd / WorldCamera.gd: 边界和相机
