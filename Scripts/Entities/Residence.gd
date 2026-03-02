## Residence - 住所建筑实体
##
## 职责：一种提供基础人口上限和仓储上限的建筑。
## 根据 building_type 的不同，渲染为木屋、石屋或现代大楼。
##
## AI Context: 继承自 Building。使用 Duck Typing 提供扩展上限的信息。

extends "res://Scripts/Entities/Building.gd"


signal human_spawned(agent: Node2D)
signal spawn_failed(reason: String)

var _time_system: Node = null
var _agent_manager: Node = null

const FOOD_COST_PER_HUMAN: int = 50

var _days_active: int = 0

func _ready() -> void:
	# 确保加入通用建筑组
	super._ready()
	
	if not is_blueprint:
		_connect_to_systems()

func _connect_to_systems() -> void:
	var world: Node = get_node_or_null("/root/World")
	if world == null: return

	_time_system = world.get_node_or_null("TimeSystem")
	if _time_system != null:
		_time_system.day_passed.connect(_on_day_passed)

	_agent_manager = world.get_node_or_null("AgentManager")


func _draw() -> void:
	var size = get_size()
	var rect = Rect2(-size / 2.0, size)
	
	if is_blueprint:
		super._draw()
		return
		
	# 根据类型分发绘制逻辑
	match building_type:
		1: # WOODEN_HUT
			_draw_wooden_hut(rect, size)
		2: # STONE_HOUSE
			_draw_stone_house(rect, size)
		3: # RESIDENCE_BUILDING
			_draw_residence_building(rect, size)
		_:
			# Fallback
			draw_rect(rect, Color.GRAY, true)
			draw_rect(rect, Color.WHITE, false, 2.0)


func _draw_wooden_hut(rect: Rect2, size: Vector2) -> void:
	var wood_color = Color(0.5, 0.35, 0.2)
	var roof_color = Color(0.4, 0.25, 0.1)
	
	# 主体
	draw_rect(rect, wood_color, true)
	
	# 木板条纹
	for i in range(1, 5):
		var y = rect.position.y + size.y * i / 5.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + size.x, y), roof_color, 2.0)
		
	# 屋顶(人字形)
	var roof_points = PackedVector2Array([
		Vector2(-size.x / 2 - 5, -size.y / 2),
		Vector2(0, -size.y / 2 - size.y * 0.4),
		Vector2(size.x / 2 + 5, -size.y / 2)
	])
	draw_polygon(roof_points, PackedColorArray([roof_color]))
	
	# 门
	draw_rect(Rect2(-size.x * 0.15, size.y / 2 - size.y * 0.35, size.x * 0.3, size.y * 0.35), Color(0.2, 0.1, 0.05), true)


func _draw_stone_house(rect: Rect2, size: Vector2) -> void:
	var stone_color = Color(0.55, 0.55, 0.55)
	var mortar_color = Color(0.4, 0.4, 0.4)
	
	# 主体
	draw_rect(rect, stone_color, true)
	
	# 石砖缝隙网格
	for i in range(1, 4):
		var y = rect.position.y + size.y * i / 4.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + size.x, y), mortar_color, 2.0)
	for i in range(1, 4):
		var x = rect.position.x + size.x * i / 4.0
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + size.y), mortar_color, 2.0)
		
	# 平顶带雉堞
	for i in range(5):
		var w = size.x / 5.0
		if i % 2 == 0:
			draw_rect(Rect2(rect.position.x + w * i, -size.y / 2 - 10, w, 10), stone_color, true)


func _draw_residence_building(rect: Rect2, size: Vector2) -> void:
	var base_color = Color(0.8, 0.85, 0.9) # 现代大楼浅灰白
	var window_color = Color(0.2, 0.6, 0.9, 0.8) # 蓝色玻璃
	
	# 主体
	draw_rect(rect, base_color, true)
	draw_rect(rect, Color(0.4, 0.4, 0.5), false, 2.0)
	
	# 网格玻璃窗
	var rows = 4
	var cols = 3
	var w_width = size.x * 0.2
	var w_height = size.y * 0.15
	
	for r in range(rows):
		for c in range(cols):
			var wx = rect.position.x + size.x * 0.15 + c * (size.x * 0.27)
			var wy = rect.position.y + size.y * 0.1 + r * (size.y * 0.2)
			draw_rect(Rect2(wx, wy, w_width, w_height), window_color, true)


## 扩展状态获取，显示给 UI
func get_status() -> Dictionary:
	var status = super.get_status()
	
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		status["bonus_pop"] = data.get("pop_cap", 0)
		status["bonus_storage"] = data.get("storage_cap", 0)
		
	return status


## WHY: 蓝图竣工后 _ready 不会再执行，必须在此处手动绑定时间系统信号
func _on_construction_finished() -> void:
	super._on_construction_finished()
	_connect_to_systems()
	print("🏠 %s: 竣工！已连接时间系统，开始计算繁衍周期" % name)


func _on_day_passed(_current_day: int) -> void:
	if is_blueprint:
		return
		
	_days_active += 1
		
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		var spawn_interval = data.get("spawn_interval_days", 0)
		
		# 只有当此建筑被配有独立的小周期时才激活繁衍机制
		if spawn_interval > 0 and _days_active > 0 and _days_active % spawn_interval == 0:
			_try_spawn_human()


## 尝试由此建筑生成新人类
func _try_spawn_human() -> void:
	if _agent_manager != null and _agent_manager._current_population >= _agent_manager.get_max_population():
		spawn_failed.emit("人口已达全局上限")
		return

	# 住宅繁衍消耗其自储备的对应食物
	var has_food: int = 0
	if "storage" in self and typeof(storage) == TYPE_DICTIONARY:
		has_food = storage.get(0, 0) # 0 = ResourceTypes.Type.FOOD
	
	if has_food < FOOD_COST_PER_HUMAN:
		spawn_failed.emit("本住所食粮不足，无法生成新生儿")
		return

	if _agent_manager == null:
		spawn_failed.emit("AgentManager 不可用")
		return

	# 扣除食物
	storage[0] -= FOOD_COST_PER_HUMAN
	if has_signal("storage_changed"):
		emit_signal("storage_changed", self , 0, storage[0])

	# 随机出生在房子周围
	var spawn_offset: Vector2 = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	var spawn_position: Vector2 = global_position + spawn_offset

	var new_idx: int = _agent_manager.add_agent(spawn_position, 20, 30)
	if new_idx != -1:
		# 修改了訊號傳遞，原本是要傳 Node2D，現在傳 Index，或者這裡的訊號只有印 log 沒有其他人聽
		var b_name = get_node("/root/World/BuildingManager").get_building_data(building_type).get("name", "住所")
		print("🏠 %s: 居民新生儿降生！消耗库存食物 %d" % [tr(b_name), FOOD_COST_PER_HUMAN])
		get_tree().call_group("event_log", "add_log", "🏠 [%s] 迎接了一名新生命！" % tr(b_name), "#88ffaa")
		queue_redraw()
	else:
		# 生成失败则回退食物
		storage[0] += FOOD_COST_PER_HUMAN
		spawn_failed.emit("Agent生成失败")
