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


## ==========================================
## ECS-lite: 族群資料導向儲存 (SoA - Structure of Arrays)
## ==========================================
# 每個 Agent 都是同一個 Index 下的多組數據。Index 也就是 Agent ID。
var agent_active: PackedByteArray = PackedByteArray()       # 0=Dead/Empty, 1=Alive
var agent_positions: PackedVector2Array = PackedVector2Array() # Agent 當前座標
var agent_targets: PackedVector2Array = PackedVector2Array()   # Agent 移動目標座標
var agent_states: PackedByteArray = PackedByteArray()       # 對應 HumanAgent.AgentState
var agent_hp: PackedFloat32Array = PackedFloat32Array()     # 當前血量
var agent_max_hp: PackedFloat32Array = PackedFloat32Array() # 最大血量
var agent_hunger: PackedFloat32Array = PackedFloat32Array() # 飢餓度
var agent_age_days: PackedInt32Array = PackedInt32Array()   # 存活天數
var agent_lifespan_days: PackedInt32Array = PackedInt32Array() # 壽命天數
var agent_carry_type: PackedInt32Array = PackedInt32Array() # 攜帶的資源類別 (-1 = 無)
var agent_carry_amount: PackedInt32Array = PackedInt32Array() # 攜帶數量
var agent_timers: PackedFloat32Array = PackedFloat32Array() # 採集或其他活動的倒數計時器

# 儲存可用空位 (Free List) 以便在 O(1) 回收與重複利用 Index
var _free_indices: Array[int] = []

## 全局唯一渲染實體
var _multi_mesh_instance: MultiMeshInstance2D = null

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

## 常量：Agent 跑動速度
const MOVE_SPEED: float = 300.0


func _ready() -> void:
	add_to_group("agent_manager")
	
	# 連接時間系統
	var world = get_node_or_null("/root/World")
	if world != null:
		var time_sys = world.get_node_or_null("TimeSystem")
		if time_sys != null:
			time_sys.tick_passed.connect(_on_tick_passed)
			time_sys.day_passed.connect(_on_day_passed)
	
	# 初始化 MultiMeshInstance2D 以負責繪製所有 Agent
	_multi_mesh_instance = MultiMeshInstance2D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	# 使用簡單的正方形 Mesh 替代原本的 _draw_circle
	var m = QuadMesh.new()
	m.size = Vector2(10, 10) # 寬高設定為大約 AGENT_RADIUS*2
	mm.mesh = m
	# 預先分配 10000 人的空間（並非全部繪製）
	mm.instance_count = 10000 
	mm.visible_instance_count = 0
	_multi_mesh_instance.multimesh = mm
	# 置頂繪製
	_multi_mesh_instance.z_index = 10
	add_child(_multi_mesh_instance)
	
	print("AgentManager (ECS-lite): 族群管理器初始化完成，基础最大人口: %d" % max_agents)
	
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
		var diff = new_max_hp - _current_global_max_hp
		_current_global_max_hp = new_max_hp
		for i in range(agent_active.size()):
			if agent_active[i] == 1:
				agent_max_hp[i] = new_max_hp
				if diff > 0:
					agent_hp[i] = min(agent_hp[i] + diff, agent_max_hp[i])
				else:
					if agent_hp[i] > agent_max_hp[i]:
						agent_hp[i] = agent_max_hp[i]


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

## 配置：最大 Agent 数量限制 (我們預設將 MultiMesh 的 instance_count 分配為 10000)
var _current_population: int = 0

func add_agent(position: Vector2, _ignored_min: int = 10, _ignored_max: int = 20) -> int:
	if _current_population >= get_max_population() or _current_population >= 10000:
		return -1
	
	var idx: int = -1
	# 從回收池找可用 index
	if _free_indices.size() > 0:
		idx = _free_indices.pop_back()
	else:
		# 沒有可用的回收 ID，需要擴充 Array
		idx = agent_active.size()
		agent_active.append(1)
		agent_positions.append(position)
		agent_targets.append(position)
		agent_states.append(0) # 0 = IDLE (AgentState)
		agent_hp.append(_current_global_max_hp)
		agent_max_hp.append(_current_global_max_hp)
		agent_hunger.append(100.0)
		agent_age_days.append(0)
		agent_lifespan_days.append(0)
		agent_carry_type.append(-1)
		agent_carry_amount.append(0)
		agent_timers.append(0.0)
	
	# 初始化該 index 資料
	agent_active[idx] = 1
	agent_positions[idx] = position
	agent_targets[idx] = position
	agent_states[idx] = 0
	agent_hp[idx] = _current_global_max_hp
	agent_max_hp[idx] = _current_global_max_hp
	agent_hunger[idx] = 100.0
	agent_age_days[idx] = 0
	agent_carry_type[idx] = -1
	agent_carry_amount[idx] = 0
	agent_timers[idx] = 0.0
	
	var lifespan_range = _get_global_lifespan_range()
	agent_lifespan_days[idx] = randi_range(int(lifespan_range.x), int(lifespan_range.y)) * 365
	
	_current_population += 1
	
	# 【暫不觸發 node 相關訊號以防崩潰】
	# agent_added.emit(agent_node_mock)
	
	var lf_years = int(agent_lifespan_days[idx] / 365.0)
	get_tree().call_group("event_log", "add_log", "第 %d 名居民誕生了 (壽命約 %d年)" % [_current_population, lf_years], "#88ff88")
	
	return idx


func _die_agent_at(idx: int, cause: String) -> void:
	if idx < 0 or idx >= agent_active.size() or agent_active[idx] == 0:
		return
		
	var age_years = int(agent_age_days[idx] / 365.0)
	var cause_text: String = "餓死" if cause == "starvation" else "壽終正寢"
	
	var log_color: String = "#ff4444" if cause == "starvation" else "#888888"
	get_tree().call_group("event_log", "add_log", "一名居民 (%d歲) %s" % [age_years, cause_text], log_color)
	print("☠️ ECS Agent [%d]: %s (%s)" % [idx, cause_text, cause])
	
	# 爆裝備
	if agent_carry_amount[idx] > 0 and agent_carry_type[idx] != -1:
		_on_agent_dropped_items(agent_positions[idx], agent_carry_type[idx], agent_carry_amount[idx])
		
	remove_agent_at(idx)


func remove_agent_at(idx: int) -> void:
	if idx < 0 or idx >= agent_active.size() or agent_active[idx] == 0:
		return
		
	agent_active[idx] = 0
	_free_indices.append(idx)
	_current_population -= 1


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


# 廢棄使用 Node2D 的舊方法
# func remove_agent(agent: Node2D) -> void:
# func get_all_agents() -> Array[Node2D]:

## ECS-lite: 取得特定 Index 的只讀快照 (供舊有 UI 檢視資料用)
func get_agent_data_at(idx: int) -> Dictionary:
	if idx < 0 or idx >= agent_active.size() or agent_active[idx] == 0:
		return {}
	return {
		"id": idx,
		"position": agent_positions[idx],
		"state": agent_states[idx],
		"hp": agent_hp[idx],
		"max_hp": agent_max_hp[idx],
		"hunger": agent_hunger[idx],
		"age_days": agent_age_days[idx],
		"age_years": int(agent_age_days[idx] / 365.0),
		"lifespan_days": agent_lifespan_days[idx],
		"carried_type": agent_carry_type[idx],
		"carried_amount": agent_carry_amount[idx]
	}



## 获取全局 Agent 的统计数据，供 UI 面板展示
func get_agents_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_count": _current_population,
		"critical_hunger_count": 0,
		"average_hunger": 0.0,
		"average_age_years": 0.0,
		"state_counts": {}
	}
	
	if _current_population == 0:
		return stats
		
	var total_hunger: float = 0.0
	var total_age: float = 0.0
	
	for i in range(agent_active.size()):
		if agent_active[i] == 0: continue
		
		var h = agent_hunger[i]
		total_hunger += h
		if h <= 25.0: # HUNGER_THRESHOLD_CRITICAL
			stats["critical_hunger_count"] += 1
			
		var age = int(agent_age_days[i] / 365.0)
		total_age += age
		
		var state_str = str(agent_states[i])
		# 如果需要對應字串可以在此處實作 AgentState 的轉換字典
		match agent_states[i]:
			0: state_str = "IDLE"
			1: state_str = "SEEK_RES"
			2: state_str = "MOVE_RES"
			3: state_str = "COLLECT"
			4: state_str = "RETURN"
			5: state_str = "DEPOSIT"
			6: state_str = "BUILD"
			
		if not stats["state_counts"].has(state_str):
			stats["state_counts"][state_str] = 1
		else:
			stats["state_counts"][state_str] += 1
				
	if stats["total_count"] > 0:
		stats["average_hunger"] = total_hunger / stats["total_count"]
		stats["average_age_years"] = total_age / stats["total_count"]
		
	return stats


func _process(delta: float) -> void:
	if _multi_mesh_instance == null or _multi_mesh_instance.multimesh == null:
		return
		
	var mm = _multi_mesh_instance.multimesh
	mm.visible_instance_count = _current_population
	
	if _current_population == 0:
		return
		
	var render_idx = 0
	for i in range(agent_active.size()):
		if agent_active[i] == 0:
			continue
			
		# [位移邏輯]
		if agent_states[i] == 2 or agent_states[i] == 4:
			var direction = (agent_targets[i] - agent_positions[i]).normalized()
			var current_speed = MOVE_SPEED
			if agent_carry_amount[i] > 0:
				current_speed = MOVE_SPEED * 0.7
			
			var movement = direction * current_speed * delta
			if agent_positions[i].distance_to(agent_targets[i]) <= movement.length():
				agent_positions[i] = agent_targets[i]
			else:
				agent_positions[i] += movement
			
		# 設定座標
		var pos = agent_positions[i]
		var xform = Transform2D(0.0, pos)
		mm.set_instance_transform_2d(render_idx, xform)
		
		# 設定顏色 (依照原本 _draw 的邏輯轉置)
		var display_color = Color.WHITE
		match agent_states[i]:
			1, 2: # SEEK_RES, MOVE_RES
				display_color = Color(1.0, 0.8, 0.2)
			3: # COLLECT
				display_color = Color(0.2, 0.8, 0.2)
			4, 5: # RETURN, DEPOSIT
				display_color = Color(0.2, 0.4, 1.0)
				
		if agent_hunger[i] <= 25.0: # CRITICAL HUNGER
			display_color = Color(1.0, 0.2, 0.2)
			
		mm.set_instance_color(render_idx, display_color)
		
		render_idx += 1
		if render_idx >= _current_population:
			break


## ==========================================
## ECS-lite: 集中式生命週期更新 (Life Cycle)
## ==========================================

const HUNGER_DECAY_PER_TICK: float = 0.5

func _on_tick_passed(_current_tick: int) -> void:
	if _current_population == 0: return
	
	# 快取全局食物與基準，避免 O(N) 內部再跑 O(M)
	var world = get_node_or_null("/root/World")
	var storages: Array[Node] = []
	var total_food: int = 0
	var has_space_for: Dictionary = {}
	var bm = world.get_node_or_null("BuildingManager") if world else null
	var resource_weights: Dictionary = {}
	var res_manager = world.get_node_or_null("ResourceManager") if world else null
	
	if world != null:
		var cave = world.get_node_or_null("Cave")
		if cave != null: storages.append(cave)
		if bm != null and bm.has_method("get_all_buildings"):
			storages.append_array(bm.get_all_buildings())
			
		for s in storages:
			var is_bp = s.is_blueprint if "is_blueprint" in s else false
			if is_bp: continue
			if "storage" in s and s.storage.has(ResourceTypes.Type.FOOD):
				total_food += s.storage[ResourceTypes.Type.FOOD]
			if s.has_method("get_remaining_space"):
				for t in ResourceTypes.get_all_types():
					if not has_space_for.has(t) and s.get_remaining_space(t) > 0:
						has_space_for[t] = true
						
		if res_manager != null and res_manager.has_method("get_resource_priority_weights"):
			resource_weights = res_manager.get_resource_priority_weights()
			
	var safe_food_line: int = _current_population * 15
	var resource_candidates = get_tree().get_nodes_in_group("inspectable")
	var blueprint_candidates = []
	if bm != null and bm.has_method("get_all_blueprints"):
		blueprint_candidates = bm.get_all_blueprints()
	
	for i in range(agent_active.size()):
		if agent_active[i] == 0: continue
		
		# 飢餓度扣減
		agent_hunger[i] = max(0.0, agent_hunger[i] - HUNGER_DECAY_PER_TICK)
		
		# 執行該 Agent 的 FSM 狀態機
		_update_agent_state_machine(i, world, storages, total_food, has_space_for, safe_food_line, resource_candidates, blueprint_candidates, resource_weights)


func _update_agent_state_machine(idx: int, world: Node, storages: Array, total_food: int, has_space: Dictionary, safe_food: int, candidates: Array, blueprints: Array, weights: Dictionary) -> void:
	match agent_states[idx]:
		0: # IDLE
			_decide_next_action_for_agent(idx, world, storages, blueprints, safe_food)
			
		1: # SEEK_RES (WANDERING)
			_find_nearest_resource_for_agent(idx, world, candidates, has_space, safe_food, total_food, weights)
			
		2: # MOVE_RES
			# 移動在 _process 處理，這裡只判斷到達
			if agent_positions[idx].distance_to(agent_targets[idx]) < 10.0:
				agent_states[idx] = 3 # COLLECT
				agent_timers[idx] = 0.0 # reset collection timer
				
		3: # COLLECT
			agent_timers[idx] += 0.5
			if agent_timers[idx] >= 1.0: # COLLECTION_TIME
				var all_targets = candidates.duplicate()
				all_targets.append_array(blueprints)
				_collect_resource_for_agent(idx, all_targets)
				
		4: # RETURN (TO CAVE)
			if agent_positions[idx].distance_to(agent_targets[idx]) < 10.0:
				agent_states[idx] = 5 # DEPOSIT
				
		5: # DEPOSIT
			_deposit_resource_for_agent(idx, storages)


func _on_day_passed(_current_day: int) -> void:
	if _current_population == 0: return
	
	for i in range(agent_active.size()):
		if agent_active[i] == 0: continue
		
		agent_age_days[i] += 1
		
		# 老死判定
		if agent_age_days[i] >= agent_lifespan_days[i]:
			_die_agent_at(i, "old_age")
			continue
			
		# 飢餓判定與扣血
		if agent_hunger[i] <= 0.0:
			agent_hp[i] -= 5.0
			var age_years = int(agent_age_days[i] / 365.0)
			print("ECS Agent [%d岁]: 遭受严重饥饿 (-5 HP)，剩余 HP: %d/%d" % [age_years, int(agent_hp[i]), int(agent_max_hp[i])])
			
			if agent_hp[i] == agent_max_hp[i] - 5.0:
				get_tree().call_group("event_log", "add_log", "【警告】有居民由於飢餓開始流失生命", "#ffaa00")
				
			if agent_hp[i] <= 0:
				_die_agent_at(i, "starvation")
				continue
				
		# 每日嘗試進食 (吃倉庫裡的食物)
		_try_consume_food_for_agent(i)


func _try_consume_food_for_agent(idx: int) -> void:
	var hunger_needed: float = 100.0 - agent_hunger[idx]
	var food_needed: int = ceil(hunger_needed / 10.0)

	if food_needed <= 0: return

	var world: Node = get_node_or_null("/root/World")
	if world == null: return
	
	var storages: Array[Node] = []
	var cave = world.get_node_or_null("Cave")
	if cave != null: storages.append(cave)
	
	var bm = world.get_node_or_null("BuildingManager")
	if bm != null and bm.has_method("get_all_buildings"):
		storages.append_array(bm.get_all_buildings())
		
	var total_consumed: int = 0
	for s in storages:
		if is_instance_valid(s) and s.has_method("consume_resource"):
			var has_store = 0
			if "storage" in s and s.storage.has(ResourceTypes.Type.FOOD):
				has_store = s.storage[ResourceTypes.Type.FOOD]
				
			if has_store > 0:
				var attempt = min(food_needed - total_consumed, has_store)
				var consumed = s.consume_resource(ResourceTypes.Type.FOOD, attempt)
				total_consumed += consumed
				
		if total_consumed >= food_needed:
			break
			
	if total_consumed > 0:
		agent_hunger[idx] = min(100.0, agent_hunger[idx] + total_consumed * 10.0)


## ==========================================
## ECS-lite: 具體行為邏輯轉譯
## ==========================================

func _decide_next_action_for_agent(idx: int, world: Node, storages: Array, blueprints: Array, safe_food: int) -> void:
	if agent_carry_amount[idx] > 0:
		var target = _find_nearest_valid_storage(agent_positions[idx], agent_carry_type[idx], storages)
		if target != null:
			agent_states[idx] = 4 # RETURN
			agent_targets[idx] = target.global_position
			return
		else:
			agent_carry_amount[idx] = 0
			agent_carry_type[idx] = -1
			
	if agent_hunger[idx] <= 60.0: # SEEK THRESHOLD
		agent_states[idx] = 1 # SEEK
		return
		
	# 尋找藍圖
	for target_bp in blueprints:
		if is_instance_valid(target_bp):
			var current_reservations = target_bp.get_meta("reserved_count", 0)
			if current_reservations < 3: # BLUEPRINT MAX
				target_bp.set_meta("reserved_count", current_reservations + 1)
				agent_targets[idx] = target_bp.global_position
				agent_states[idx] = 2 # MOVE
				return
				
	if randf() < 0.3:
		agent_states[idx] = 1 # SEEK


func _find_nearest_resource_for_agent(idx: int, world: Node, candidates: Array, has_space: Dictionary, safe_food: int, total_food: int, weights: Dictionary) -> void:
	var highest_score: float = -INF
	var nearest_target: Node2D = null
	var pos = agent_positions[idx]
	var can_collect_non_food = (agent_hunger[idx] >= 80.0) and (total_food >= safe_food)
	
	# 合併資源與藍圖兩種可能目標
	var all_targets = candidates.duplicate()
	var bm = world.get_node_or_null("BuildingManager")
	if bm != null and bm.has_method("get_all_blueprints"):
		all_targets.append_array(bm.get_all_blueprints())
	
	for child in all_targets:
		if not is_instance_valid(child): continue
		
		var is_bp = child.is_blueprint if "is_blueprint" in child else false
		var can_collect = not is_bp and child.has_method("collect")
		var can_build = is_bp and child.has_method("add_progress")
		
		# 必須是可採集或可建造
		if not can_collect and not can_build: continue
		if child.has_method("is_depleted") and child.is_depleted(): continue
		
		var res_type = child.resource_type if "resource_type" in child else 0
		var current_reservations = child.get_meta("reserved_count", 0)
		var max_allowed = 1
		if child.is_in_group("building"): max_allowed = 2
		if is_bp: max_allowed = 3
		if current_reservations >= max_allowed: continue
		
		# ===== 致命的過濾 Bug 發生在這裡 =====
		if not is_bp:
			if not has_space.get(res_type, false): continue
			if res_type != ResourceTypes.Type.FOOD and not can_collect_non_food: continue
			
		var score: float = 0.0
		if not is_bp: score += weights.get(res_type, 0.0)
		else: score += 150.0
		
		if child.has_method("get_attraction_weight"):
			score += child.get_attraction_weight()
			
		var dist = pos.distance_to(child.global_position)
		score -= dist * 0.2
		
		if score > highest_score:
			highest_score = score
			nearest_target = child
			
	if nearest_target != null:
		agent_targets[idx] = nearest_target.global_position
		nearest_target.set_meta("reserved_count", nearest_target.get_meta("reserved_count", 0) + 1)
		agent_states[idx] = 2 # MOVE
	else:
		var generator = world.get_node_or_null("WorldGenerator")
		if generator != null and generator.has_method("_get_random_position_in_world"):
			agent_targets[idx] = generator._get_random_position_in_world(100.0)
			agent_states[idx] = 2


func _collect_resource_for_agent(idx: int, candidates: Array) -> void:
	# 用距離來找出最近的資源（取代直接持有 Node Reference，避免 Node 死掉的 Crash）
	var pos = agent_positions[idx]
	var target_node = null
	for child in candidates:
		if is_instance_valid(child):
			var reach = 15.0
			var is_bp = child.is_blueprint if "is_blueprint" in child else false
			# 建築體積龐大，不能用 15.0 這種原點距離，否則永遠摸不到
			if is_bp or child.is_in_group("building") or child.name == "Cave":
				reach = 60.0
				
			if child.global_position.distance_to(pos) < reach:
				# ====== 修復：當升級時，新藍圖與舊建築重疊，必須優先敲擊藍圖 ======
				if target_node == null:
					target_node = child
				elif is_bp and not (target_node.is_blueprint if "is_blueprint" in target_node else false):
					target_node = child
					
	if target_node == null:
		agent_states[idx] = 0 # IDLE
		return
		
	if "is_blueprint" in target_node and target_node.is_blueprint:
		if target_node.has_method("add_progress"):
			target_node.add_progress(10.0)
		# 釋放佔位
		target_node.set_meta("reserved_count", max(0, target_node.get_meta("reserved_count", 0) - 1))
		agent_states[idx] = 0
		return
		
	var res_type = target_node.resource_type if "resource_type" in target_node else ResourceTypes.Type.FOOD
	var collected = 0
	if target_node.has_method("collect"):
		var req = 99999 if target_node.is_in_group("building") else 10 # CARRY_CAPACITY
		collected = target_node.collect(req, self)
		
	if collected > 0:
		agent_carry_type[idx] = res_type
		agent_carry_amount[idx] = collected
		target_node.set_meta("reserved_count", max(0, target_node.get_meta("reserved_count", 0) - 1))
		agent_states[idx] = 0 # 讓他在下一個 tick 跑 decide 去倉庫
	else:
		target_node.set_meta("reserved_count", max(0, target_node.get_meta("reserved_count", 0) - 1))
		agent_states[idx] = 1 # SEEK 繼續找


func _deposit_resource_for_agent(idx: int, storages: Array) -> void:
	var pos = agent_positions[idx]
	var target_node = null
	for s in storages:
		if is_instance_valid(s) and s.global_position.distance_to(pos) < 15.0:
			target_node = s
			break
			
	if target_node == null or agent_carry_amount[idx] <= 0:
		agent_states[idx] = 0
		return
		
	var deposited = 0
	if target_node.has_method("add_resource"):
		deposited = target_node.add_resource(agent_carry_type[idx], agent_carry_amount[idx])
		
	agent_carry_amount[idx] -= deposited
	
	if agent_carry_amount[idx] <= 0:
		agent_carry_type[idx] = -1
		agent_states[idx] = 0
	else:
		# 找下一個倉庫
		var next_target = _find_nearest_valid_storage(pos, agent_carry_type[idx], storages)
		if next_target != null:
			agent_targets[idx] = next_target.global_position
			agent_states[idx] = 4 # RETURN
		else:
			_on_agent_dropped_items(pos, agent_carry_type[idx], agent_carry_amount[idx])
			get_tree().call_group("event_log", "add_log", "滿倉！居民將 %d 單位物資棄置於地" % agent_carry_amount[idx], "#ffaa44")
			agent_carry_amount[idx] = 0
			agent_carry_type[idx] = -1
			agent_states[idx] = 0


func _find_nearest_valid_storage(pos: Vector2, type: int, storages: Array) -> Node2D:
	var best_target: Node2D = null
	var min_dist: float = INF
	
	for s in storages:
		if is_instance_valid(s) and s.has_method("get_remaining_space"):
			if s.get_remaining_space(type) > 0:
				var dist = pos.distance_to(s.global_position)
				if dist < min_dist:
					min_dist = dist
					best_target = s
					
	return best_target
