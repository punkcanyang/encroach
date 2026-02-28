## BuildingManager - 建筑管理器
##
## 职责：管理所有建筑的数据定义、蓝图放置、实例管理及空间碰撞检测
##
## AI Context: 作为建筑系统的核心，统筹蓝图的生命周期并保证空间合理性

extends Node


signal building_placed(building: Node2D)
signal building_removed(building: Node2D)
signal blueprint_placed(blueprint: Node2D)


## 建筑类型枚举
enum BuildingType {
	FARM = 0,
	WOODEN_HUT = 1,
	STONE_HOUSE = 2,
	RESIDENCE_BUILDING = 3,
	CAVE = 4
}

## 建筑数据配置
const BUILDING_DATA: Dictionary = {
	BuildingType.FARM: {
		"id": "FARM",
		"name": "RESOURCE_FARM",
		"size": Vector2(60, 60),
		"cost": {1: 100, 0: 50}, # DIRT=1, FOOD=0
		"pop_cap": 0,
		"storage_cap": 0,
		"allowed_storage": [],
		"spawn_human": 0,
		"scene_path": "res://Scenes/Farm.tscn",
		"work_required": 100.0
	},
	BuildingType.WOODEN_HUT: {
		"id": "WOODEN_HUT",
		"name": "BUILDING_WOODEN_HUT",
		"size": Vector2(40, 40),
		"cost": {1: 200, 0: 100}, # DIRT=1, FOOD=0
		"pop_cap": 15,
		"storage_cap": 500,
		"allowed_storage": [0, 1, 2],
		"spawn_human": 2,
		"scene_path": "res://Scenes/Residence.tscn",
		"work_required": 200.0
	},
	BuildingType.STONE_HOUSE: {
		"id": "STONE_HOUSE",
		"name": "BUILDING_STONE_HOUSE",
		"size": Vector2(60, 60),
		"cost": {1: 500, 0: 200, 2: 200}, # DIRT=1, FOOD=0, IND_METAL=2
		"pop_cap": 24,
		"storage_cap": 2000,
		"allowed_storage": [0, 1, 2, 3],
		"spawn_human": 3,
		"scene_path": "res://Scenes/Residence.tscn",
		"work_required": 400.0
	},
	BuildingType.RESIDENCE_BUILDING: {
		"id": "RESIDENCE_BUILDING",
		"name": "BUILDING_RESIDENCE_BUILDING",
		"size": Vector2(80, 80),
		"cost": {1: 1000, 0: 500, 2: 500, 3: 200}, # DIRT=1, FOOD=0, IND_METAL=2, PREC_METAL=3
		"pop_cap": 144,
		"storage_cap": 5000,
		"allowed_storage": [0, 1, 2, 3],
		"spawn_human": 10,
		"scene_path": "res://Scenes/Residence.tscn",
		"work_required": 1000.0
	},
	BuildingType.CAVE: {
		"id": "CAVE",
		"name": "CAVE_TITLE",
		"size": Vector2(80, 80), # 和 _get_entity_rect 里的一致
		"cost": {1: 80, 0: 50}, # DIRT=1, FOOD=0
		"pop_cap": 6,
		"storage_cap": 100,
		"allowed_storage": [0, 1],
		"spawn_human": 1,
		"scene_path": "res://Scenes/Cave.tscn", # 新建一个场景或用别的，我将修改一下让蓝图用正确的
		"work_required": 100.0
	}
}


@export var max_buildings: int = 100

## 已完成的建筑实体
var buildings: Array[Node2D] = []

## 正在施工的蓝图
var blueprints: Array[Node2D] = []

var _world: Node = null


func _ready() -> void:
	# 延迟获取 World 引用，以确保能够跨系统访问节点
	call_deferred("_cache_world")


func _cache_world() -> void:
	_world = get_node_or_null("/root/World")


## 获取所有已竣工的建筑
func get_all_buildings() -> Array[Node2D]:
	return buildings


## 获取所有蓝图
func get_all_blueprints() -> Array[Node2D]:
	return blueprints


## 获取指定的建筑配置数据
func get_building_data(type: int) -> Dictionary:
	return BUILDING_DATA.get(type, {})


## 检查指定区域是否有任何物理重叠（返回 true 表示有碰撞，不允许放置）
func check_collision(rect: Rect2, ignore_node: Node2D = null) -> bool:
	if _world == null:
		print(" BuildingManager[Collision]: World 不存在")
		return true # 未初始化前不允许放置
	
	# 检查与世界边界的碰撞
	var generator = _world.get_node_or_null("WorldGenerator")
	if generator != null and generator.has_method("get_world_rect"):
		var world_rect: Rect2 = generator.get_world_rect()
		if not world_rect.encloses(rect):
			print(" BuildingManager[Collision]: 越界，候选 %s 不在世界 %s 范围内" % [str(rect), str(world_rect)])
			return true
	
	# 检查与其他建筑的碰撞
	for entity in buildings + blueprints:
		if entity == ignore_node or not is_instance_valid(entity):
			continue
		var entity_rect: Rect2 = _get_entity_rect(entity)
		if rect.intersects(entity_rect):
			print(" BuildingManager[Collision]: 与其他建筑重叠 -> %s (位置: %s，大小: %s)" % [entity.name, str(entity_rect.position), str(entity_rect.size)])
			return true
	
	# 检查与山洞的碰撞
	var cave = _world.get_node_or_null("Cave")
	if cave != null and cave != ignore_node and is_instance_valid(cave):
		var cave_rect: Rect2 = _get_entity_rect(cave)
		if rect.intersects(cave_rect):
			print(" BuildingManager[Collision]: 与山洞重叠 -> (位置: %s, 大小: %s)" % [str(cave_rect.position), str(cave_rect.size)])
			return true
			
	# 检查与野生资源的碰撞 (假设大小大概 10x10)
	var resources = get_tree().get_nodes_in_group("inspectable")
	for res in resources:
		if res == ignore_node or not is_instance_valid(res):
			continue
		if res.has_method("collect") and not res.name.begins_with("Human"):
			# 这是个野生资源
			var res_rect: Rect2 = Rect2(res.global_position - Vector2(10, 10), Vector2(20, 20))
			if rect.intersects(res_rect):
				print(" BuildingManager[Collision]: 与野生资源重叠 -> %s" % res.name)
				return true
				
	return false


## 获取实体的估算碰撞矩形
func _get_entity_rect(entity: Node2D) -> Rect2:
	var size = Vector2(40, 40) # 默认大小
	if entity.has_method("get_size"):
		size = entity.get_size()
	elif "building_type" in entity:
		var data = get_building_data(entity.building_type)
		if data.has("size"):
			size = data["size"]
	elif entity.name == "Cave":
		size = Vector2(80, 80)
		
	return Rect2(entity.global_position - size / 2.0, size)


## 放置一个建筑（通常初始作为蓝图）
func place_building(type: int, position: Vector2, is_instant: bool = false) -> Node2D:
	var data: Dictionary = get_building_data(type)
	if data.is_empty():
		push_error("BuildingManager: 未找到建筑类型 %d 的数据" % type)
		return null
		
	var size: Vector2 = data.get("size", Vector2(40, 40))
	var placement_rect: Rect2 = Rect2(position - size / 2.0, size)
	
	if check_collision(placement_rect):
		print("BuildingManager: 放置失败，位置产生碰撞 %s，矩形: %s" % [str(position), str(placement_rect)])
		return null
		
	var scene_path: String = data.get("scene_path", "")
	# WHY: 处理如果是山洞，由于可能没有独立的 Cave.tscn(原本是 WorldGenerator 动态添加的 Node2D 配 Cave.gd)
	# 为了统一放置，如果有预制体就加载，没有就在这里手动创建
	var scene: PackedScene = load(scene_path) if scene_path != "" and ResourceLoader.exists(scene_path) else null
	
	var building: Node2D = null
	if scene != null:
		building = scene.instantiate()
	else:
		if type == BuildingType.CAVE:
			building = Node2D.new()
			building.name = "Cave"
			building.set_script(load("res://Scripts/Entities/Cave.gd"))
		else:
			push_error("BuildingManager: 无法加载建筑场景 %s" % scene_path)
			return null
	building.position = position
	if "building_type" in building:
		building.building_type = type
		
	# 确保生成的名称唯一以防止节点树同级冲突和引用混乱
	building.name = "%s_%d" % [data.get("id", "Building"), Time.get_ticks_msec()]
		
	add_child(building)
	
	# 设置状态
	if is_instant:
		if building.has_method("finish_construction"):
			building.finish_construction()
		buildings.append(building)
		building_placed.emit(building)
	else:
		if building.has_method("start_construction"):
			building.start_construction(data.get("work_required", 100.0))
		blueprints.append(building)
		blueprint_placed.emit(building)
		
	return building


## 当蓝图完成施工，转为正式建筑
func finalize_blueprint(building: Node2D) -> void:
	if building in blueprints:
		blueprints.erase(building)
		buildings.append(building)
		building_placed.emit(building)
		print("BuildingManager: 蓝图施工完成并转为正式建筑")
		
		# WHY: 按照配置赠送新建人口
		if "building_type" in building:
			var data = get_building_data(building.building_type)
			var spawn_count = data.get("spawn_human", 0)
			if spawn_count > 0:
				var agent_mgr = _world.get_node_or_null("AgentManager")
				if agent_mgr != null:
					for i in range(spawn_count):
						var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
						agent_mgr.add_agent(building.global_position + offset, 20, 30)
					print("BuildingManager: 建筑落成，自动生成 %d 个人口" % spawn_count)


## 移除建筑（拆除）
func remove_building(building: Node2D) -> void:
	if building in buildings:
		buildings.erase(building)
		building_removed.emit(building)
		building.queue_free()
	elif building in blueprints:
		blueprints.erase(building)
		building.queue_free()


# [For Future AI]
# =========================
# 关键假设:
# 1. 建筑有两阶段生命周期: Blueprint -> Finalized
# 2. check_collision 返回 true 表示不可放置
# 3. Entity 需要自行实现 get_size(), finish_construction(), start_construction()  (见 Building.gd 基类)
# 4. cost 资源尚未在此扣除，应在 UIManager/PlayerController 请求放置时扣除
