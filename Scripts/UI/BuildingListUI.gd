## BuildingListUI - 实时建筑清单面板
##
## 职责：列出当前所有的建筑、蓝图，支持双击相机平滑追踪
## 纯代码构建，无需 .tscn，由快捷键 B 触发展开与收齐

extends PanelContainer

var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _title_label: Label
var _empty_label: Label

var _building_manager: Node = null
var _player_controller: Node = null
var _world_camera: Camera2D = null

var _is_open: bool = false
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 1.0

func _ready() -> void:
	name = "BuildingListUI"
	visible = false
	
	# 面板背景布局
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.12, 0.15, 0.18, 0.85)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.4, 0.6, 0.8, 0.8)
	stylebox.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", stylebox)
	
	# 放置在屏幕左下方附近，避开可能的 InspectUI(左上)
	custom_minimum_size = Vector2(280, 400)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	position = Vector2(20, get_viewport_rect().size.y - 420)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)
	
	# 标题
	_title_label = Label.new()
	_title_label.text = "🏗️ " + tr("BUILDING_LIST_TITLE", "建筑清单总览")
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)
	
	main_vbox.add_child(HSeparator.new())
	
	_empty_label = Label.new()
	_empty_label.text = "暂无任何建筑或施工蓝图"
	_empty_label.add_theme_font_size_override("font_size", 14)
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.visible = false
	main_vbox.add_child(_empty_label)
	
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 5)
	_scroll.add_child(_vbox)
	
	# 缓存依赖引用
	_building_manager = get_node_or_null("/root/World/BuildingManager")
	_player_controller = get_node_or_null("/root/World/PlayerController")
	_world_camera = get_node_or_null("/root/World/WorldCamera")


func _process(delta: float) -> void:
	if not visible: return
	
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_refresh_list()


func toggle_panel() -> void:
	_is_open = not _is_open
	visible = _is_open
	if visible:
		_refresh_list()


func _refresh_list() -> void:
	if _building_manager == null:
		_building_manager = get_node_or_null("/root/World/BuildingManager")
		if _building_manager == null: return
		
	# 清理旧的条目
	for child in _vbox.get_children():
		child.queue_free()
		
	var all_nodes: Array[Node2D] = []
	
	# 加入蓝图
	if _building_manager.has_method("get_all_blueprints"):
		all_nodes.append_array(_building_manager.get_all_blueprints())
	
	# 加入建筑和特殊建筑(比如 Cave)
	if _building_manager.has_method("get_all_buildings"):
		all_nodes.append_array(_building_manager.get_all_buildings())
		
	var cave = get_node_or_null("/root/World/Cave")
	if cave != null and not cave in all_nodes:
		all_nodes.append(cave)
		
	if all_nodes.size() == 0:
		_empty_label.visible = true
	else:
		_empty_label.visible = false
		for b in all_nodes:
			_create_item_for_building(b)


func _create_item_for_building(building: Node2D) -> void:
	if not is_instance_valid(building): return
	
	# 动态创建单项面板
	var item_panel = PanelContainer.new()
	var item_sb = StyleBoxFlat.new()
	item_sb.bg_color = Color(0.2, 0.25, 0.3, 0.8)
	item_sb.set_corner_radius_all(4)
	item_panel.add_theme_stylebox_override("panel", item_sb)
	item_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	item_panel.add_child(margin)
	
	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(lbl)
	
	# 组装显示文字
	var title = building.name
	var status_text = ""
	
	if building.has_method("get_status"):
		var status = building.get_status()
		if "name" in status:
			title = tr(status["name"])
			
		var is_bp = status.get("is_blueprint", false)
		if is_bp:
			var p = status.get("progress", 0.0)
			var r = status.get("work_required", 1.0)
			status_text = "[color=#ffdd55]施工中 ( %d%% )[/color]" % int((p/r)*100)
		else:
			# 可选：显示它内部的库存，这里简单显示当前健康度或提供人口
			if "health" in status:
				status_text = "[color=#88ff88]HP: %d[/color]" % int(status["health"])
			elif "pop_cap" in status and status["pop_cap"] > 0:
				status_text = "[color=#aaddff]提供床位 (有效)[/color]"
			elif building.name == "Cave":
				status_text = "[color=#dddddd]中心营地[/color]"
			else:
				status_text = "[color=#88ff88]运作中[/color]"
				
	lbl.text = "[b]%s[/b]\n%s" % [title, status_text]
	
	# 挂载双击事件处理
	item_panel.gui_input.connect(_on_item_gui_input.bind(building))
	
	# 当鼠标移入移出提供高亮反馈
	item_panel.mouse_entered.connect(func(): item_sb.bg_color = Color(0.3, 0.35, 0.4, 0.9))
	item_panel.mouse_exited.connect(func(): item_sb.bg_color = Color(0.2, 0.25, 0.3, 0.8))
	
	_vbox.add_child(item_panel)


func _on_item_gui_input(event: InputEvent, building: Node2D) -> void:
	if not is_instance_valid(building): return
	
	# 拦截所有双击事件
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		# 1. 取消面板展开(可不关，通常列表保持开启比较方便，因此保留)
		
		# 2. 镜头追踪
		if _world_camera == null:
			_world_camera = get_node_or_null("/root/World/WorldCamera")
			
		if _world_camera != null and _world_camera.has_method("focus_on"):
			_world_camera.focus_on(building.global_position)
			print("BuildingListUI: 已双击并平滑相焦到 %s" % building.name)
		else:
			print("BuildingListUI: 找不到 /root/World/WorldCamera 或无 focus_on() 函式")
			
		# 3. 强迫选中它(等价于直接点在世界地图该建筑上)
		if _player_controller == null:
			_player_controller = get_node_or_null("/root/World/PlayerController")
			
		if _player_controller != null and _player_controller.has_method("select_building"):
			_player_controller.select_building(building)
		
		get_viewport().set_input_as_handled()
