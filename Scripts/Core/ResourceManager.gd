## ResourceManager - 资源管理器（多资源类型统计版本）
##
## 职责：按资源类型追踪世界中的资源统计信息
## 食物储存和管理由 Cave 实体负责，此模块主要用于统计和全局查询
##
## AI Context: 统计数据按 ResourceTypes.Type 分类

extends Node


## 信号：当统计信息更新时发射
signal stats_updated(stats: Dictionary)


## 按类型统计数据
var _resources_by_type: Dictionary = {} ## { Type: count }
var _collected_by_type: Dictionary = {} ## { Type: total_ever }
var _total_food_in_caves: int = 0


func _ready() -> void:
	# WHY: 初始化每种类型的统计计数器
	_resources_by_type = ResourceTypes.create_empty_storage()
	_collected_by_type = ResourceTypes.create_empty_storage()
	print("ResourceManager: 资源管理器初始化（多资源类型统计模式）")


## 更新统计数据
func update_stats() -> void:
	_calculate_stats()
	stats_updated.emit(get_stats())


## 计算当前统计
func _calculate_stats() -> void:
	# 重置所有类型计数
	for type in ResourceTypes.get_all_types():
		_resources_by_type[type] = 0
	_total_food_in_caves = 0

	var world: Node = get_node("/root/World")
	if world == null:
		return

	for child in world.get_children():
		# WHY: 按类型统计野外未耗尽的资源点数量
		if child.has_method("is_depleted") and not child.is_depleted():
			var res_type: int = child.resource_type if "resource_type" in child else 0
			_resources_by_type[res_type] = _resources_by_type.get(res_type, 0) + 1

		# 统计山洞中的食物（向后兼容）
		if child.has_method("get_stored_food"):
			_total_food_in_caves += child.get_stored_food()


## 获取统计信息
func get_stats() -> Dictionary:
	_calculate_stats()

	var total_resources: int = 0
	for type in ResourceTypes.get_all_types():
		total_resources += _resources_by_type.get(type, 0)

	var total_collected: int = 0
	for type in ResourceTypes.get_all_types():
		total_collected += _collected_by_type.get(type, 0)

	return {
		"resources_in_world": total_resources,
		"resources_by_type": _resources_by_type.duplicate(),
		"food_in_caves": _total_food_in_caves,
		"total_collected_ever": total_collected,
		"collected_by_type": _collected_by_type.duplicate()
	}


## 记录采集（按类型统计）
func record_collection(amount: int, type: int = ResourceTypes.Type.FOOD) -> void:
	_collected_by_type[type] = _collected_by_type.get(type, 0) + amount


## 获取 Cave 的引用（便利方法）
func get_cave() -> Node2D:
	var world: Node = get_node("/root/World")
	if world == null:
		return null
	for child in world.get_children():
		if child.name == "Cave":
			return child
	return null


# [For Future AI]
# =========================
# 关键假设:
# 1. 统计数据按 ResourceTypes.Type 分类
# 2. record_collection 需要传入 type 参数
# 3. 向后兼容 resources_in_world / total_collected_ever 总计字段
#
# 依赖模块:
# - ResourceTypes: 类型枚举
# - Cave: get_stored_food()
# - Resource: resource_type / is_depleted()
