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


func add_agent(position: Vector2, min_lifespan: int = 20, max_lifespan: int = 30) -> Node2D:
	if agents.size() >= get_max_population():
		return null
	
	if agent_scene == null:
		return null
	
	var agent = agent_scene.instantiate()
	add_child(agent)
	agent.position = position
	
	# 从外部赋值重写 HumanAgent 的寿命设定
	agent.lifespan_days = randi_range(min_lifespan, max_lifespan) * 365
	agent.agent_died.connect(_on_agent_died)
	
	agents.append(agent)
	
	if agent.has_method("update_max_hp"):
		agent.update_max_hp(_current_global_max_hp)
	
	agent_added.emit(agent)
	return agent


func _on_agent_died(agent: Node2D, _cause: String, _age: int) -> void:
	# 由 agent 自己去 queue_free 即可，Manager 只负责从数组移除和发事件
	if agent in agents:
		agents.erase(agent)
		agent_removed.emit(agent)


func remove_agent(agent: Node2D) -> void:
	if agent in agents:
		agents.erase(agent)
		agent_removed.emit(agent)
		agent.queue_free()


func get_all_agents() -> Array[Node2D]:
	return agents
