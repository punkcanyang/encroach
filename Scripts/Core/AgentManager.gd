## AgentManager - 族群管理器
##
## 职责：管理所有 HumanAgent 的生命周期
## 包括实例化、位置分配、销毁和事件监听

extends Node


## 信号：新 Agent 被添加时发射
signal agent_added(agent: Node2D)

## 信号：Agent 被移除时发射
signal agent_removed(agent: Node2D)


## 配置：HumanAgent 场景的 PackedScene 引用
## 必须在编辑器中指定或通过代码设置
@export var agent_scene: PackedScene

## 配置：最大 Agent 数量限制
@export var max_agents: int = 100


## 内部状态：存储所有活跃的 Agent
var agents: Array[Node2D] = []

## 动态计算当前最大人口上限（基础上限 + 建筑提供）
func get_max_population() -> int:
	var total_cap: int = max_agents
	var world = get_node_or_null("/root/World")
	if world != null:
		var bm = world.get_node_or_null("BuildingManager")
		if bm != null and bm.has_method("get_all_buildings"):
			for building in bm.get_all_buildings():
				if "building_type" in building and bm.has_method("get_building_data"):
					var data = bm.get_building_data(building.building_type)
					total_cap += data.get("pop_cap", 0)
	return total_cap

## 常量：屏幕中心位置（作为初始生成点）
const INITIAL_POSITION: Vector2 = Vector2(500, 300)


func _ready() -> void:
	add_to_group("agent_manager")
	# 加载 HumanAgent 场景
	if agent_scene == null:
		agent_scene = load("res://Scenes/HumanAgent.tscn")
	
	print("AgentManager: 族群管理器初始化完成，基础最大人口: %d" % max_agents)
	
	call_deferred("_setup_building_signals")


var _current_global_max_hp: int = 20

func _setup_building_signals() -> void:
	var world = get_node_or_null("/root/World")
	if world != null:
		var bm = world.get_node_or_null("BuildingManager")
		if bm != null:
			bm.building_placed.connect(_on_building_changed)
			bm.building_removed.connect(_on_building_changed)
			_current_global_max_hp = bm.get_global_max_hp()


func _on_building_changed(_building: Node2D) -> void:
	var world = get_node_or_null("/root/World")
	if world == null: return
	var bm = world.get_node_or_null("BuildingManager")
	if bm == null or not bm.has_method("get_global_max_hp"): return
	
	var new_max_hp = bm.get_global_max_hp()
	if new_max_hp != _current_global_max_hp:
		_current_global_max_hp = new_max_hp
		for a in agents:
			if is_instance_valid(a) and a.has_method("update_max_hp"):
				a.update_max_hp(new_max_hp)


## 动态获取当世最高的科技寿命区间
func _get_global_lifespan_range() -> Vector2:
	var min_y = 10
	var max_y = 20
	var world = get_node_or_null("/root/World")
	if world != null:
		var bm = world.get_node_or_null("BuildingManager")
		if bm != null and bm.has_method("get_all_buildings"):
			var has_wooden = false
			var has_stone = false
			var has_residence = false
			for b in bm.get_all_buildings():
				if "is_blueprint" in b and b.is_blueprint: continue
				if "building_type" in b:
					match b.building_type:
						1: has_wooden = true
						2: has_stone = true
						3: has_residence = true
			if has_residence:
				min_y = 30
				max_y = 80
			elif has_stone:
				min_y = 30
				max_y = 50
			elif has_wooden:
				min_y = 20
				max_y = 30
	return Vector2(min_y, max_y)

func add_agent(position: Vector2, _ignored_min: int = 10, _ignored_max: int = 20) -> Node2D:
	if agents.size() >= get_max_population():
		return null
	
	if agent_scene == null:
		return null
	
	var agent = agent_scene.instantiate()
	add_child(agent)
	agent.position = position
	
	# 从外部赋值重写 HumanAgent 的寿命设定，取决于最高建筑
	var lifespan_range = _get_global_lifespan_range()
	agent.lifespan_days = randi_range(int(lifespan_range.x), int(lifespan_range.y)) * 365
	agent.agent_died.connect(_on_agent_died)
	agent.agent_dropped_items.connect(_on_agent_dropped_items)
	
	agents.append(agent)
	
	if agent.has_method("update_max_hp"):
		agent.update_max_hp(_current_global_max_hp)
	
	agent_added.emit(agent)
	
	var pop_idx = agents.size()
	var lf_years = int(agent.lifespan_days / 365.0)
	get_tree().call_group("event_log", "add_log", "第 %d 名居民誕生了 (壽命約 %d)", "#88ff88" % [pop_idx, lf_years])
	
	return agent


func _on_agent_died(agent: Node2D, cause: String, age: int) -> void:
	print("AgentManager: 收到 Agent 死亡通知: ", agent, " 原因: ", cause, " 享年: ", age)
	agents.erase(agent)
	agent_removed.emit(agent)

func _on_agent_dropped_items(pos: Vector2, type: int, amount: int) -> void:
	var world = get_node_or_null("/root/World")
	if world == null: return
	
	print("AgentManager: 拾荒包裹生成在 %s (物资: %s x %d)" % [str(pos), tr(ResourceTypes.get_type_name(type)), amount])
	
	# 此处通过代码动态实例化，因为我们写了完全自包含的 draw 函数
	var drop = load("res://Scripts/Entities/ResourceDrop.gd").new()
	drop.resource_type = type
	drop.amount = amount
	drop.position = pos
	world.add_child(drop)


func remove_agent(agent: Node2D) -> void:
	if agent in agents:
		agents.erase(agent)
		agent_removed.emit(agent)
		agent.queue_free()


func get_all_agents() -> Array[Node2D]:
	return agents


## 获取全局 Agent 的统计数据，供 UI 面板展示
func get_agents_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_count": 0,
		"critical_hunger_count": 0,
		"average_hunger": 0.0,
		"average_age_years": 0.0,
		"state_counts": {}
	}
	
	if agents.size() == 0:
		return stats
		
	var total_hunger: float = 0.0
	var total_age: float = 0.0
	
	for a in agents:
		if not is_instance_valid(a): continue
		
		stats["total_count"] += 1
		
		var h = a.hunger if "hunger" in a else 100.0
		total_hunger += h
		if h <= 25.0: # HUNGER_THRESHOLD_CRITICAL
			stats["critical_hunger_count"] += 1
			
		var age = a.age_years if "age_years" in a else 0
		total_age += age
		
		if "current_state" in a:
			var state_str = a._get_state_string(a.current_state) if a.has_method("_get_state_string") else str(a.current_state)
			if not stats["state_counts"].has(state_str):
				stats["state_counts"][state_str] = 1
			else:
				stats["state_counts"][state_str] += 1
				
	if stats["total_count"] > 0:
		stats["average_hunger"] = total_hunger / stats["total_count"]
		stats["average_age_years"] = total_age / stats["total_count"]
		
	return stats
