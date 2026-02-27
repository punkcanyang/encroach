## StatsPanel - 全局统计数据横幅（多资源版本）
##
## 职责：在屏幕顶部显示总人口、天数、各类资源库存等关键生存指标
## AI Context: 纯代码构建的 UI，通过 Group/信号实时更新，按资源类型分别显示

extends PanelContainer

const DAYS_PER_YEAR: int = 365

# UI 核心组件
var _time_label: Label
var _population_label: Label
var _food_label: Label
var _dirt_label: Label
var _ind_metal_label: Label
var _prec_metal_label: Label
var _wild_resource_label: Label

# 数据源缓存
var _time_system: Node = null
var _agent_manager: Node = null
var _resource_manager: Node = null
var _cave: Node2D = null

# 内部计数缓存
var _current_population: int = 0
var _cave_max_population: int = 6
var _current_days: int = 0
## WHY: 按类型存储山洞库存与类型上限
var _cave_storage: Dictionary = {}
var _max_storage_caps: Dictionary = {}
var _wild_resources_count: int = 0
var _total_collected: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0.6)
	stylebox.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", stylebox)

	custom_minimum_size = Vector2(0, 40)
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_right", 30)
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin_container)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 25)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.add_child(hbox)

	var left_spacer = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(left_spacer)

	# 1. 存活时间
	_time_label = _create_label()
	hbox.add_child(_time_label)

	# 2. 人口
	_population_label = _create_label()
	hbox.add_child(_population_label)

	# 3. 食物库存
	_food_label = _create_label()
	hbox.add_child(_food_label)

	# 4. 土矿库存
	_dirt_label = _create_label()
	hbox.add_child(_dirt_label)

	# 5. 工业金属库存
	_ind_metal_label = _create_label()
	hbox.add_child(_ind_metal_label)

	# 6. 贵金属库存
	_prec_metal_label = _create_label()
	hbox.add_child(_prec_metal_label)

	# 7. 野外资源
	_wild_resource_label = _create_label()
	hbox.add_child(_wild_resource_label)

	var right_spacer = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right_spacer)

	# WHY: 追加右上角倍速控制区
	_setup_time_controls(hbox)

	call_deferred("_setup_connections")
	_update_displays()


func _create_label() -> Label:
	var lbl = Label.new()
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _setup_time_controls(parent: Control) -> void:
	var time_box = HBoxContainer.new()
	time_box.add_theme_constant_override("separation", 10)
	time_box.alignment = BoxContainer.ALIGNMENT_END
	time_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(time_box)
	
	var btn_pause = _create_speed_button("⏸", "暂停", 0.0)
	var btn_slow = _create_speed_button("▶", "慢速", 0.5)
	var btn_normal = _create_speed_button("▶▶", "正常", 1.0)
	var btn_fast = _create_speed_button("▶▶▶", "加速", 2.0)
	
	time_box.add_child(btn_pause)
	time_box.add_child(btn_slow)
	time_box.add_child(btn_normal)
	time_box.add_child(btn_fast)


func _create_speed_button(text: String, tooltip: String, speed_scale: float) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(35, 25)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(func(): _on_speed_button_pressed(speed_scale))
	return btn


func _on_speed_button_pressed(speed_scale: float) -> void:
	var target = get_node_or_null("/root/SettingsManager")
	if target != null and target.has_method("set_time_scale"):
		# SettingsManager 里 clamp 了 0.1 ，如果希望支持暂停需要特调或手动调 Engine
		if speed_scale <= 0.0:
			Engine.time_scale = 0.0
			print("StatsPanel: 游戏已暂停")
		else:
			target.set_time_scale(speed_scale)
			print("StatsPanel: 游戏速度调整为 %.1fx" % speed_scale)
	else:
		Engine.time_scale = speed_scale


func _setup_connections() -> void:
	# TimeSystem
	if get_tree().has_group("time_system"):
		var nodes = get_tree().get_nodes_in_group("time_system")
		if nodes.size() > 0:
			_time_system = nodes[0]
			if _time_system.has_signal("day_passed"):
				_time_system.day_passed.connect(_on_day_passed)

	# AgentManager
	if get_tree().has_group("agent_manager"):
		var nodes = get_tree().get_nodes_in_group("agent_manager")
		if nodes.size() > 0:
			_agent_manager = nodes[0]
			if _agent_manager.has_signal("agent_added"):
				_agent_manager.agent_added.connect(_on_agent_changed)
			if _agent_manager.has_signal("agent_removed"):
				_agent_manager.agent_removed.connect(_on_agent_changed)
			_current_population = _agent_manager.agents.size()

	# ResourceManager & Cave
	var world_node = get_tree().root.get_node_or_null("World")
	if world_node != null:
		_resource_manager = world_node.get_node_or_null("ResourceManager")

		_cave = world_node.get_node_or_null("Cave")
		if _cave != null:
			# WHY: 监听通用 storage_changed 信号
			if _cave.has_signal("storage_changed"):
				_cave.storage_changed.connect(_on_storage_changed)
				
		var bm = world_node.get_node_or_null("BuildingManager")
		if bm != null:
			if bm.has_signal("building_placed"):
				bm.building_placed.connect(_on_building_placed)
			if bm.has_method("get_all_buildings"):
				for b in bm.get_all_buildings():
					_on_building_placed(b)
					
			_refresh_resource_stats() # WHY: 使用统一方法更新最新上限

	_refresh_resource_stats()
	_update_displays()


func _on_day_passed(day: int) -> void:
	_current_days = day
	_refresh_resource_stats()
	_update_displays()


func _on_agent_changed(_agent: Node2D = null) -> void:
	if _agent_manager:
		_current_population = _agent_manager.agents.size()
	_update_displays()


func _on_building_placed(building: Node2D) -> void:
	if building.has_signal("storage_changed") and not building.storage_changed.is_connected(_on_building_storage_changed):
		building.storage_changed.connect(_on_building_storage_changed)
	_refresh_resource_stats()
	_update_displays()


func _on_building_storage_changed(_building: Node2D, _type: int, _new_amount: int) -> void:
	_refresh_resource_stats()
	_update_displays()


func _on_storage_changed(_type: int, _new_amount: int) -> void:
	_refresh_resource_stats()
	_update_displays()


func _refresh_resource_stats() -> void:
	if _resource_manager != null:
		var stats: Dictionary = _resource_manager.get_stats()
		_wild_resources_count = stats.get("resources_in_world", 0)
		_total_collected = stats.get("total_collected_ever", 0)
		
	# 同步 cave 数据和动态上限
	_cave_storage.clear()
	
	if _cave != null:
		if _cave.has_method("get_max_population"):
			_cave_max_population = _cave.get_max_population()
		if _cave.has_method("get_max_storage_per_type"):
			for t in ResourceTypes.get_all_types():
				_max_storage_caps[t] = _cave.get_max_storage_per_type(t)
				_cave_storage[t] = _cave.storage.get(t, 0)
				
	# 叠加建筑内的资源库
	var world_node = get_tree().root.get_node_or_null("World")
	if world_node != null:
		var bm = world_node.get_node_or_null("BuildingManager")
		if bm != null and bm.has_method("get_all_buildings"):
			for b in bm.get_all_buildings():
				if "storage" in b and b.storage is Dictionary:
					for t in b.storage.keys():
						_cave_storage[t] = _cave_storage.get(t, 0) + b.storage[t]


func _update_displays() -> void:
	if _time_label == null:
		return

	@warning_ignore("integer_division")
	var years: int = _current_days / DAYS_PER_YEAR

	_time_label.text = tr("UI_STATS_TIME") % [_current_days, years]
	_population_label.text = tr("UI_STATS_POPULATION") % [_current_population, _cave_max_population]

	# WHY: 按类型分别显示库存
	var food: int = _cave_storage.get(ResourceTypes.Type.FOOD, 0)
	var dirt: int = _cave_storage.get(ResourceTypes.Type.DIRT, 0)
	var ind_metal: int = _cave_storage.get(ResourceTypes.Type.IND_METAL, 0)
	var prec_metal: int = _cave_storage.get(ResourceTypes.Type.PREC_METAL, 0)

	_food_label.text = tr("UI_STATS_CAVE_FOOD") % [food, _max_storage_caps.get(ResourceTypes.Type.FOOD, 0)]
	_dirt_label.text = tr("UI_STATS_CAVE_DIRT") % [dirt, _max_storage_caps.get(ResourceTypes.Type.DIRT, 0)]
	_ind_metal_label.text = tr("UI_STATS_CAVE_IND_METAL") % [ind_metal, _max_storage_caps.get(ResourceTypes.Type.IND_METAL, 0)]
	_prec_metal_label.text = tr("UI_STATS_CAVE_PREC_METAL") % [prec_metal, _max_storage_caps.get(ResourceTypes.Type.PREC_METAL, 0)]

	_wild_resource_label.text = tr("UI_STATS_WILD_RESOURCES") % _wild_resources_count


# [For Future AI]
# =========================
# 关键假设:
# 1. StatsPanel 监听 Cave.storage_changed 信号
# 2. 按 ResourceTypes.Type 分别显示各资源库存
# 3. 字体大小调小到 14 以容纳更多资源信息
#
# 依赖模块:
# - ResourceTypes: 类型枚举
# - Cave: storage / storage_changed / MAX_STORAGE_PER_TYPE
# - ResourceManager: get_stats()
