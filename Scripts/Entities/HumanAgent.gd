## HumanAgent - 人类实体（多资源版本）
##
## 职责：代表一个会移动、采集不同类型资源并带回山洞的个体
## 饱腹度 >= 80 时可采集非食物资源，否则优先采集食物
##
## AI Context: 搬运系统按 ResourceTypes.Type 分类，每次只携带一种资源

extends Node2D


## 信号：当 Agent 死亡时发射
signal agent_died(agent: Node2D, cause: String, age: int)

## 信号：当 Agent 死前身上带了东西时抛出这个遗产
signal agent_dropped_items(pos: Vector2, type: int, amount: int)

## 信号：当 Agent 采集到资源时发射
signal resource_collected(resource_type: int, amount: int)

## 信号：当 Agent 返回山洞时发射
signal returned_to_cave(resource_type: int, amount: int)


## 枚举：Agent 的行为状态
enum AgentState {IDLE, SEEKING_RESOURCE, MOVING_TO_RESOURCE, COLLECTING, RETURNING_TO_CAVE, DEPOSITING, CONSTRUCTING}

## 常量配置
const AGENT_RADIUS: float = 5.0
const AGENT_COLOR: Color = Color.WHITE
const HUNGER_DECAY_PER_TICK: float = 0.5
const HUNGER_THRESHOLD_SEEK: float = 60.0
const HUNGER_THRESHOLD_CRITICAL: float = 25.0
## WHY: 饱腹度 >= 此值才允许采集非食物资源（规则集2）
const HUNGER_THRESHOLD_NON_FOOD: float = 80.0
const MIN_LIFESPAN_YEARS: int = 20
const MAX_LIFESPAN_YEARS: int = 30
const DAYS_PER_YEAR: int = 365
const MOVE_SPEED: float = 300.0
const CARRY_CAPACITY: int = 10
const COLLECTION_TIME: float = 1.0
const CAVE_INTERACTION_DISTANCE: float = 50.0


## 生命属性
var hunger: float = 100.0:
	set(value):
		hunger = clamp(value, 0.0, 100.0)

var max_hp: float = 20.0
var hp: float = 20.0

var age_days: int = 0
var age_years: int = 0
var lifespan_days: int = 0
var alive: bool = true

## 搬运状态：当前携带的资源类型与数量
var carried_type: int = -1 ## -1 表示未携带
var carried_amount: int = 0

## 行为状态
var current_state: AgentState = AgentState.IDLE
var target_position: Vector2 = Vector2.ZERO
var _collection_timer: float = 0.0

## 内部引用
var _time_system: Node = null
var _cave: Node2D = null
var _nearest_resource: Node2D = null
var _target_building: Node2D = null # WHY: 当前正要去存资源的建筑

# ---------------------------------------------
# 黑板占位机制 (Blackboard Reservation)
# 防止大量 Agent 扎堆涌向同一个资源或蓝图
# ---------------------------------------------
const MAX_RESERVERS_WILD: int = 1 # 野生矿点最多1人开采
const MAX_RESERVERS_FARM: int = 2 # 农田最多2人同时收割
const MAX_RESERVERS_BLUEPRINT: int = 3 # 蓝图最多3人同时敲打

## 当前个人独自锁定的占位目标
var _reserved_target: Node = null

## 内部计时器
var _days_since_last_meal: int = 0


func _ready() -> void:
	add_to_group("inspectable")
	# 初始化寿命与参数
	# 由 AgentManager 创建它时赋值了 lifespan_days，这里由于 _ready 后于实例化执行，避免覆盖
	if lifespan_days == 0:
		lifespan_days = randi_range(10, 20) * DAYS_PER_YEAR
	age_days = 0
	age_years = 0
	hunger = 100.0
	alive = true
	current_state = AgentState.IDLE
	carried_type = -1
	carried_amount = 0
	_target_building = null
	
	hp = 20.0
	max_hp = 20.0

	_connect_to_systems()
	queue_redraw()

	var display_years = lifespan_days / float(DAYS_PER_YEAR)
	print("HumanAgent: 出生在位置 %s，预计寿命 %d 岁（%d 天）" % [str(global_position), int(display_years), lifespan_days])


## 被 AgentManager 调用的全局血量同步
func update_max_hp(new_max: float) -> void:
	if new_max > max_hp:
		# 享受涨幅补贴
		var diff = new_max - max_hp
		max_hp = new_max
		hp = min(hp + diff, max_hp)
		print("HumanAgent [%d岁]: 受到时代建筑光环影响，生命值提升 %d，当前: %d/%d" % [age_years, int(diff), int(hp), int(max_hp)])
	elif new_max < max_hp:
		# 有高级建筑被拆除了
		max_hp = max_hp
		if hp > max_hp: hp = max_hp
		print("HumanAgent [%d岁]: 时代衰退，生命值上限降至 %d" % [age_years, int(max_hp)])


func _connect_to_systems() -> void:
	var world: Node = get_node("/root/World")
	if world == null:
		return

	_time_system = world.get_node("TimeSystem")
	if _time_system != null:
		_time_system.tick_passed.connect(_on_tick_passed)
		_time_system.day_passed.connect(_on_day_passed)

	# 寻找山洞
	_cave = world.get_node_or_null("Cave")
	if _cave == null:
		for child in world.get_children():
			if child is Node2D and child.name == "Cave":
				_cave = child
				break


func _draw() -> void:
	var display_color: Color = AGENT_COLOR

	match current_state:
		AgentState.SEEKING_RESOURCE, AgentState.MOVING_TO_RESOURCE:
			display_color = Color(1.0, 0.8, 0.2)
		AgentState.COLLECTING:
			display_color = Color(0.2, 0.8, 0.2)
		AgentState.RETURNING_TO_CAVE, AgentState.DEPOSITING:
			display_color = Color(0.2, 0.4, 1.0)

	if hunger <= HUNGER_THRESHOLD_CRITICAL:
		display_color = Color(1.0, 0.2, 0.2)

	draw_circle(Vector2.ZERO, AGENT_RADIUS, display_color)
	draw_circle(Vector2.ZERO, AGENT_RADIUS, Color.WHITE, false, 1.0)

	# WHY: 携带资源时头顶绘制对应颜色的小点以及重量数字
	if carried_amount > 0:
		var carry_color: Color = _get_carry_indicator_color()
		# 绘制小点
		draw_circle(Vector2(0, -AGENT_RADIUS - 6), 3.0, carry_color)
		# 绘制数字
		var font = ThemeDB.fallback_font
		if font != null:
			var text_str = "+%d" % carried_amount
			draw_string(font, Vector2(5, -AGENT_RADIUS - 2), text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, carry_color)


## 根据携带的资源类型返回指示器颜色
func _get_carry_indicator_color() -> Color:
	match carried_type:
		ResourceTypes.Type.FOOD: return Color(0.2, 0.8, 0.2)
		ResourceTypes.Type.DIRT: return Color(0.55, 0.55, 0.55)
		ResourceTypes.Type.IND_METAL: return Color(0.9, 0.92, 0.95)
		ResourceTypes.Type.PREC_METAL: return Color(0.95, 0.8, 0.2)
		_: return Color.WHITE


func _process(delta: float) -> void:
	if not alive:
		return
	_handle_movement(delta)


func _on_tick_passed(_current_tick: int) -> void:
	if not alive:
		return
	_apply_hunger_decay()
	_update_state_machine()
	_check_death()
	queue_redraw()


func _on_day_passed(_current_day: int) -> void:
	if not alive:
		return
	age_days += 1
	_days_since_last_meal += 1

	if hunger <= 0.0:
		hp -= 5.0
		var display_cause: String = "严重饥饿 (-5 HP)"
		print("HumanAgent [%d岁%d天]: 遭受 %s，剩余 HP: %d/%d" % [age_years, age_days % DAYS_PER_YEAR, display_cause, int(hp), int(max_hp)])
		if hp == max_hp - 5.0:
			# 只在第一次因饥饿扣血时显示警告，避免洗版
			get_tree().call_group("event_log", "add_log", "【警告】一名居民由于饥饿开始流失生命", "#ffaa00")

	# 每天尝试进食
	if _days_since_last_meal >= 1:
		_try_consume_food_from_any_storage()


func _apply_hunger_decay() -> void:
	hunger -= HUNGER_DECAY_PER_TICK


func _try_consume_food_from_any_storage() -> void:
	var hunger_needed: float = 100.0 - hunger
	var food_needed: int = ceil(hunger_needed / 10.0)

	if food_needed <= 0: return

	var world: Node = get_node_or_null("/root/World")
	if world == null: return
	
	var storages: Array[Node] = []
	if _cave != null: storages.append(_cave)
	
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
		hunger = min(hunger + (total_consumed * 10.0), 100.0)
		_days_since_last_meal = 0
		print("HumanAgent [%d岁%d天]: 从营地进食，消耗 %d 食物，饥饿 %.1f" % [
			age_years, age_days % DAYS_PER_YEAR, total_consumed, hunger
		])


func _update_state_machine() -> void:
	# 安全兜底：如果脱离了前往资源/采集资源的状态，释放当前的目标占位
	if current_state != AgentState.MOVING_TO_RESOURCE and current_state != AgentState.COLLECTING:
		_set_reserved_target(null)

	match current_state:
		AgentState.IDLE:
			_decide_next_action()

		AgentState.SEEKING_RESOURCE:
			_find_and_move_to_nearest_resource()

		AgentState.MOVING_TO_RESOURCE:
			if _reached_target():
				current_state = AgentState.COLLECTING
				_collection_timer = 0.0

		AgentState.COLLECTING:
			_collection_timer += 0.5
			if _collection_timer >= COLLECTION_TIME:
				_collect_resource()

		AgentState.RETURNING_TO_CAVE:
			if _target_building != null and is_instance_valid(_target_building):
				target_position = _target_building.global_position
				if _reached_target():
					current_state = AgentState.DEPOSITING
			else:
				# 目标丢了，重新决定
				current_state = AgentState.IDLE

		AgentState.DEPOSITING:
			_deposit_to_cave()


## 更改个人的专属目标并原子化切换黑板上的占位人数
func _set_reserved_target(new_target: Node) -> void:
	if _reserved_target == new_target:
		return
		
	# 释放旧目标
	if is_instance_valid(_reserved_target):
		var old_count = _reserved_target.get_meta("reserved_count", 0)
		_reserved_target.set_meta("reserved_count", max(0, old_count - 1))
		
	_reserved_target = new_target
	
	# 占有新目标
	if is_instance_valid(_reserved_target):
		var new_count = _reserved_target.get_meta("reserved_count", 0)
		_reserved_target.set_meta("reserved_count", new_count + 1)


func _decide_next_action() -> void:
	# 如果携带资源，寻找最近的合格仓库返回
	if carried_amount > 0:
		_target_building = _find_nearest_valid_storage(carried_type)
		if _target_building != null:
			current_state = AgentState.RETURNING_TO_CAVE
			target_position = _target_building.global_position
			return
		else:
			# 此资源全图已满或无容身之所，直接把资源扔掉
			print("HumanAgent [%d岁]: %s 无处安放，丢弃处理" % [age_years, ResourceTypes.get_type_name(carried_type)])
			carried_amount = 0
			carried_type = -1
			# 继续往下执行寻找新的事情做

	# 如果饥饿，寻找食物资源
	if hunger <= HUNGER_THRESHOLD_SEEK:
		current_state = AgentState.SEEKING_RESOURCE
		return

	# 优先去建造蓝图
	var world: Node = get_node_or_null("/root/World")
	if world != null:
		var bm = world.get_node_or_null("BuildingManager")
		if bm != null and bm.has_method("get_all_blueprints"):
			var bps = bm.get_all_blueprints()
			for target_bp in bps:
				if is_instance_valid(target_bp):
					var current_reservations = target_bp.get_meta("reserved_count", 0)
					if current_reservations < MAX_RESERVERS_BLUEPRINT:
						_nearest_resource = target_bp
						target_position = target_bp.global_position
						_set_reserved_target(target_bp)
						current_state = AgentState.MOVING_TO_RESOURCE
						return

	# 随机游走或寻找资源
	if randf() < 0.3:
		current_state = AgentState.SEEKING_RESOURCE


## 预计算并寻找最近的可采集资源（性能优化与新策略）
func _find_and_move_to_nearest_resource() -> void:
	var nearest_dist: float = INF
	_nearest_resource = null

	var world: Node = get_node_or_null("/root/World")
	if world == null: return

	# --- 1. 预计算全局空间与全局食物储备 ---
	var total_food: int = 0
	var pop: int = 0
	
	var bm = world.get_node_or_null("BuildingManager")
	var am = world.get_node_or_null("AgentManager")
	if am != null: pop = am.agents.size()
	
	var storages: Array[Node] = []
	if _cave != null: storages.append(_cave)
	if bm != null and bm.has_method("get_all_buildings"):
		storages.append_array(bm.get_all_buildings())
		
	# 记录哪些资源类型目前还有存储空间
	var has_space_for: Dictionary = {}
	
	for s in storages:
		# 跳过蓝图
		var is_bp = s.is_blueprint if "is_blueprint" in s else false
		if is_bp: continue
		
		# 累加总食物
		if "storage" in s and s.storage.has(ResourceTypes.Type.FOOD):
			total_food += s.storage[ResourceTypes.Type.FOOD]
			
		# 检查可用空间
		if s.has_method("get_remaining_space"):
			for t in ResourceTypes.get_all_types():
				if not has_space_for.has(t) and s.get_remaining_space(t) > 0:
					has_space_for[t] = true

	var safe_food_line: int = pop * 15
	var can_collect_non_food: bool = (hunger >= HUNGER_THRESHOLD_NON_FOOD) and (total_food >= safe_food_line)

	# --- 新增：取得全局資源短缺權重 ---
	var resource_weights: Dictionary = {}
	var _resource_manager = get_node_or_null("/root/World/ResourceManager")
	if _resource_manager != null and _resource_manager.has_method("get_resource_priority_weights"):
		resource_weights = _resource_manager.get_resource_priority_weights()

	# --- 2. 遍历资源节点寻找最高分目标 ---
	var highest_score: float = -INF
	var candidates: Array[Node] = get_tree().get_nodes_in_group("inspectable")
	
	for child in candidates:
		# 目標分為兩類：可以採集的資源，或是需要施工的藍圖
		var is_bp = child.is_blueprint if "is_blueprint" in child else false
		var can_collect = not is_bp and child.has_method("collect")
		var can_build = is_bp and child.has_method("add_progress")
		
		if not can_collect and not can_build:
			continue
			
		# 是否為採集枯竭確認
		if child.has_method("is_depleted") and child.is_depleted(): continue

		var res_type: int = child.resource_type if "resource_type" in child else 0
		
		# ---- 【新增：黑板目标过滤体系】 ----
		var current_reservations = child.get_meta("reserved_count", 0)
		var max_allowed = MAX_RESERVERS_WILD
		if child.is_in_group("building"):
			max_allowed = MAX_RESERVERS_FARM # 后续如果加入其他生产建筑这里可以动态取值
		if "is_blueprint" in child and child.is_blueprint:
			max_allowed = MAX_RESERVERS_BLUEPRINT
		
		# 强制分流：如果发现该资源点的排队人数已满，直接视而不见（跳过）
		if current_reservations >= max_allowed:
			continue
		# ------------------------------
		
		# 蓝图不需要存放空间，但采矿需要
		if not is_bp:
			# 全图无空间存放此资源，跳过
			if not has_space_for.get(res_type, false):
				continue
				
			# 非食物需满足食物安全线和饱腹度，否则跳过
			if res_type != ResourceTypes.Type.FOOD:
				if not can_collect_non_food:
					continue

		# --- 3. 評分計算 (Scoring) ---
		var score: float = 0.0
		
		# 3a. 基礎物質極缺權重
		if not is_bp:
			score += resource_weights.get(res_type, 0.0)
		else:
			score += 150.0 # 藍圖自帶高基礎優先級

		# 3b. 建築特殊引力 (Attraction)
		if child.has_method("get_attraction_weight"):
			score += child.get_attraction_weight()
			
		# 3c. 距離衰減懲罰 (Distance Penalty)
		var dist: float = global_position.distance_to(child.global_position)
		score -= dist * 0.2  # 每 1 像素距離扣 0.2 分
		
		if score > highest_score:
			highest_score = score
			_nearest_resource = child

	# --- 3. 指派移动目标 ---
	if _nearest_resource != null:
		target_position = _nearest_resource.global_position
		_set_reserved_target(_nearest_resource)
		current_state = AgentState.MOVING_TO_RESOURCE
	else:
		# 没有可用资源，随机移动
		var generator = world.get_node_or_null("WorldGenerator")
		if generator != null and generator.has_method("_get_random_position_in_world"):
			target_position = generator._get_random_position_in_world(100.0)
			_set_reserved_target(null) # 游走不占位
			current_state = AgentState.MOVING_TO_RESOURCE


func _handle_movement(delta: float) -> void:
	if current_state != AgentState.MOVING_TO_RESOURCE and \
	   current_state != AgentState.RETURNING_TO_CAVE:
		return

	var direction: Vector2 = (target_position - global_position).normalized()
	
	# 硬核物流：如果身上带了东西，走路变慢 30% 来表现负重感
	var current_speed = MOVE_SPEED
	if carried_amount > 0:
		current_speed = MOVE_SPEED * 0.7
		
	var movement: Vector2 = direction * current_speed * delta

	if global_position.distance_to(target_position) <= movement.length():
		global_position = target_position
	else:
		global_position += movement


func _reached_target() -> bool:
	return global_position.distance_to(target_position) < 10.0


func _collect_resource() -> void:
	if _nearest_resource == null or not is_instance_valid(_nearest_resource):
		current_state = AgentState.IDLE
		return

	# WHY: 检查是否为蓝图施工
	if "is_blueprint" in _nearest_resource and _nearest_resource.is_blueprint:
		if _nearest_resource.has_method("add_progress"):
			_nearest_resource.add_progress(10.0)
			print("HumanAgent [%d岁]: 敲击蓝图，增加进度 10.0" % age_years)
		current_state = AgentState.IDLE
		return

	# WHY: 记录采集的资源类型，而非写死为 FOOD
	var res_type: int = _nearest_resource.resource_type if "resource_type" in _nearest_resource else ResourceTypes.Type.FOOD

	var collected: int = 0
	if _nearest_resource.has_method("collect"):
		# 特权设定：如果是具有成长熟练度的建筑（如农田），允许一次性清空其所有存量。
		# WHY: 防止由于拾取上限卡住建筑的下一次倒计时生成。
		var request_amount = 99999 if _nearest_resource.is_in_group("building") else CARRY_CAPACITY
		collected = _nearest_resource.collect(request_amount, self )

	if collected > 0:
		carried_type = res_type
		carried_amount = collected
		resource_collected.emit(carried_type, collected)
		
		# WHY: 采完立刻寻找最近仓库
		_target_building = _find_nearest_valid_storage(carried_type)
		if _target_building != null:
			current_state = AgentState.RETURNING_TO_CAVE
			target_position = _target_building.global_position
			var type_name: String = ResourceTypes.get_type_name(carried_type)
			print("HumanAgent [%d岁]: 采集到 %d %s，正在前往最近仓库" % [age_years, collected, tr(type_name)])
		else:
			carried_amount = 0
			carried_type = -1
			current_state = AgentState.IDLE
	else:
		current_state = AgentState.SEEKING_RESOURCE


func _deposit_to_cave() -> void:
	if _target_building == null or not is_instance_valid(_target_building) or carried_amount <= 0:
		current_state = AgentState.IDLE
		return

	# WHY: 使用通用 add_resource 接口，向其存入
	var deposited: int = 0
	if _target_building.has_method("add_resource"):
		deposited = _target_building.add_resource(carried_type, carried_amount)
		if deposited > 0:
			returned_to_cave.emit(carried_type, deposited)
			var type_name: String = ResourceTypes.get_type_name(carried_type)
			print("HumanAgent [%d岁]: 向储藏室存入 %d %s" % [age_years, deposited, tr(type_name)])
		
	# 扣除已存入的数量
	carried_amount -= deposited
	
	if carried_amount <= 0:
		# 全部存完了，清空状态
		carried_amount = 0
		carried_type = -1
		_target_building = null
		current_state = AgentState.IDLE
	else:
		# 还有没存完的，找下一个仓库
		_target_building = _find_nearest_valid_storage(carried_type)
		if _target_building != null:
			current_state = AgentState.RETURNING_TO_CAVE
			target_position = _target_building.global_position
			print("HumanAgent [%d岁]: 此仓库已满，携带剩余 %d 转往下一个仓库" % [age_years, carried_amount])
		else:
			# 全世界由于各种原因都没有存储空间了，只好丢在地上成为资源包
			agent_dropped_items.emit(global_position, carried_type, carried_amount)
			get_tree().call_group("event_log", "add_log", "滿倉！居民將 %d 單位物資棄置於地" % carried_amount, "#ffaa44")
			print("HumanAgent [%d岁]: 仓库全满，将剩余 %d 资源丢弃于地" % [age_years, carried_amount])
			carried_amount = 0
			carried_type = -1
			current_state = AgentState.IDLE


func _check_death() -> void:
	if hp <= 0.0:
		_die("starvation_hp_depleted")
		return

	if age_days >= lifespan_days:
		_die("old_age")
		return


func _die(cause: String) -> void:
	alive = false
	var cause_text: String = "餓死" if cause == "starvation_hp_depleted" else "壽終正寢"
	var display_years = lifespan_days / float(DAYS_PER_YEAR)
	print("☠️  HumanAgent [%d岁/%d天寿命]: %s" % [age_years, int(display_years), cause_text])

	var log_color: String = "#ff4444" if cause == "starvation_hp_depleted" else "#888888"
	get_tree().call_group("event_log", "add_log", "一名居民 (%d歲) %s" % [age_years, cause_text], log_color)

	agent_died.emit(self , cause, age_years)
	
	# 如果肚子里或手上带着没放回去的资源，就爆出来
	if carried_amount > 0 and carried_type != -1:
		agent_dropped_items.emit(global_position, carried_type, carried_amount)
		print("📦 遗物包裹已生成！内含 %s * %d" % [tr(ResourceTypes.get_type_name(carried_type)), carried_amount])

	if _time_system != null:
		if _time_system.tick_passed.is_connected(_on_tick_passed):
			_time_system.tick_passed.disconnect(_on_tick_passed)
		if _time_system.day_passed.is_connected(_on_day_passed):
			_time_system.day_passed.disconnect(_on_day_passed)

	call_deferred("queue_free")


## 获取带有本地化键值的状态名称
func _get_state_string(state: AgentState) -> String:
	match state:
		AgentState.IDLE: return "STATE_IDLE"
		AgentState.SEEKING_RESOURCE: return "STATE_WANDERING"
		AgentState.MOVING_TO_RESOURCE: return "STATE_MOVING_TO_RESOURCE"
		AgentState.COLLECTING: return "STATE_COLLECTING"
		AgentState.RETURNING_TO_CAVE: return "STATE_MOVING_TO_CAVE"
		AgentState.DEPOSITING: return "STATE_DEPOSITING"
		AgentState.CONSTRUCTING: return "STATE_CONSTRUCTING"
		_: return "STATE_UNKNOWN"


## 获取状态
func get_status() -> Dictionary:
	var status: Dictionary = {}
	status["hunger"] = hunger
	status["hp"] = hp
	status["max_hp"] = max_hp
	status["age_years"] = age_years
	status["age_days"] = age_days
	status["lifespan_years"] = int(float(lifespan_days) / float(DAYS_PER_YEAR))
	status["lifespan_days"] = lifespan_days
	status["alive"] = alive
	status["state"] = _get_state_string(current_state)
	status["carried"] = carried_amount
	status["carried_type"] = carried_type
	status["position"] = global_position
	return status


## WHY: 新增：寻找最近允许存储目标类型且未满的居所（原山洞及新造好的房子）
func _find_nearest_valid_storage(type: int) -> Node2D:
	var best_target: Node2D = null
	var min_dist: float = INF
	
	var world = get_node_or_null("/root/World")
	if world == null: return null
	
	var candidates: Array[Node2D] = []
	if _cave != null and is_instance_valid(_cave):
		candidates.append(_cave)
		
	var bm = world.get_node_or_null("BuildingManager")
	if bm != null and bm.has_method("get_all_buildings"):
		var bds = bm.get_all_buildings()
		for b in bds:
			if is_instance_valid(b) and b != _cave and b.has_method("get_remaining_space"):
				candidates.append(b)
				
	for child in candidates:
		if child.has_method("get_remaining_space"):
			var free_space = child.get_remaining_space(type)
			if free_space > 0:
				var dist = global_position.distance_to(child.global_position)
				if dist < min_dist:
					min_dist = dist
					best_target = child
					
	return best_target


# [For Future AI]
# =========================
# 关键假设:
# 1. 每次只能携带一种资源，上限 CARRY_CAPACITY
# 2. 饱腹 >= 80 才采集非食物（规则集2）
# 3. resource_type 属性从 Resource 节点读取
# 4. 使用 Cave.add_resource() 通用接口存入
#
# 潜在边界情况:
# 1. 所有食物耗尽时会去采矿吗？不会，饱腹不够
# 2. 矿物满了还会采吗？会，但存不进去
#
# 依赖模块:
# - ResourceTypes: 类型枚举
# - Cave: add_resource / consume_food
# - Resource: collect / is_depleted / resource_type
# - TimeSystem: tick/day 事件
