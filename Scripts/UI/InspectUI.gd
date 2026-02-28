## InspectUI - 物件检视界面
##
## 职责：当鼠标悬停在游戏物件上时显示详细信息
## 包括人类状态、资源储量、山洞食物、建筑状态等
##
## AI Context: 这是游戏的检查系统，帮助玩家了解世界状态

extends Control


## 固定弹窗配置
const PANEL_SIZE: Vector2 = Vector2(280, 220)
const PANEL_POS: Vector2 = Vector2(20, 100) # 左上角偏下固定位置

## 建筑升级路线图: [旧BuildingType] -> [新BuildingType]
const UPGRADE_MAP: Dictionary = {
	4: 1, # CAVE -> WOODEN_HUT
	1: 2, # WOODEN_HUT -> STONE_HOUSE
	2: 3 # STONE_HOUSE -> RESIDENCE
}

## UI 节点引用
var _info_panel: Panel = null
var _title_label: Label = null
var _content_label: Label = null
var _upgrade_btn: Button = null
var _close_btn: Button = null

## 内部状态
var _selected_object: Node2D = null
var _player_controller: Node = null


var _init_print_done = false

func _ready() -> void:
	print("InspectUI: _ready is called")
	# 设置自身能接收输入，但平时不阻挡
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_create_ui_nodes()
	_info_panel.visible = false


func _create_ui_nodes() -> void:
	if _info_panel == null:
		_info_panel = Panel.new()
		_info_panel.name = "InfoPanel"
		_info_panel.size = PANEL_SIZE
		# WHY: 使用 STOP 让这块区域能吃掉点击（点在面板上不会关掉自己）
		_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_info_panel.position = PANEL_POS
		add_child(_info_panel)
		
	# 标题
	_title_label = Label.new()
	_title_label.position = Vector2(10, 10)
	_title_label.size = Vector2(PANEL_SIZE.x - 40, 30)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.add_theme_font_size_override("font_size", 16)
	_info_panel.add_child(_title_label)
	
	# 关闭按钮
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.position = Vector2(PANEL_SIZE.x - 35, 5)
	_close_btn.size = Vector2(30, 30)
	_close_btn.pressed.connect(_on_close_pressed)
	_info_panel.add_child(_close_btn)
	
	# 内容区
	_content_label = Label.new()
	_content_label.position = Vector2(10, 45)
	_content_label.size = Vector2(PANEL_SIZE.x - 20, PANEL_SIZE.y - 100)
	_content_label.add_theme_font_size_override("font_size", 14)
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_panel.add_child(_content_label)
	
	# 升级按钮
	_upgrade_btn = Button.new()
	_upgrade_btn.position = Vector2(10, PANEL_SIZE.y - 50)
	_upgrade_btn.size = Vector2(PANEL_SIZE.x - 20, 40)
	_upgrade_btn.add_theme_font_size_override("font_size", 14)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_upgrade_btn.visible = false # 默认隐藏
	_info_panel.add_child(_upgrade_btn)


func _on_building_selected(target: Node2D) -> void:
	print("InspectUI: 接到显示命令，目标 -> ", target)
	if target == null:
		_info_panel.visible = false
		_selected_object = null
		return
		
	_selected_object = target
	_update_inspect_content()
	_info_panel.visible = true


func _on_close_pressed() -> void:
	_info_panel.visible = false
	_selected_object = null


func _process(_delta: float) -> void:
	if not _init_print_done:
		print("InspectUI: _process is running")
		_init_print_done = true
		
	# 延迟初始化连接（防止 _ready 时 World 尚未入树导致找不到）
	if _player_controller == null:
		_player_controller = get_node_or_null("/root/World/PlayerController")
		if _player_controller != null and _player_controller.has_signal("building_selected"):
			_player_controller.building_selected.connect(_on_building_selected)
			print("InspectUI: 成功绑定 PlayerController 信号！")
			
	# 定期刷新数据（当面板开着的时候）
	if _info_panel.visible and is_instance_valid(_selected_object):
		_update_inspect_content()
	elif _info_panel.visible and not is_instance_valid(_selected_object):
		# 对象被销毁销毁了
		_on_close_pressed()


func _update_inspect_content() -> void:
	if _selected_object == null or not is_instance_valid(_selected_object): return
	
	var title: String = ""
	var content: String = ""
	
	var current_type: int = -1
	if "building_type" in _selected_object:
		current_type = _selected_object.building_type
		
	if _selected_object.has_method("get_status"):
		var status = _selected_object.get_status()
		
		# 强制赋予建筑名 (翻译文本已自带Emoji，去除代码前缀)
		if "name" in status:
			title = tr(status["name"])
		else:
			title = _selected_object.name
			
		# 根据真实类型套用专属排版
		if current_type == 4: # BuildingType.CAVE
			title = tr("CAVE_TITLE")
			content = _format_cave_info(status)
		elif current_type in [1, 2, 3]: # WOODEN_HUT, STONE_HOUSE, RESIDENCE_BUILDING
			content = _format_residence_info(status)
		elif current_type == 0: # FARM
			content = _format_farm_info(status)
		else:
			content = "状态不可用"
	else:
		title = _selected_object.name
		content = "状态不可用"
		
	_title_label.text = title
	_content_label.text = content
	
	_update_upgrade_button()


func _update_upgrade_button() -> void:
	# 只处理特定包含 building_type 的对象 (且非施工状态)
	var current_type: int = -1
	var is_blueprint: bool = false
	if "building_type" in _selected_object:
		current_type = _selected_object.building_type
	if "is_blueprint" in _selected_object:
		is_blueprint = _selected_object.is_blueprint
		
	if is_blueprint or current_type == -1 or not UPGRADE_MAP.has(current_type):
		_upgrade_btn.visible = false
		return
		
	var next_type = UPGRADE_MAP[current_type]
	var bm = get_node_or_null("/root/World/BuildingManager")
	if bm == null or not bm.has_method("get_building_data"):
		_upgrade_btn.visible = false
		return
		
	var data = bm.get_building_data(next_type)
	if data.is_empty():
		_upgrade_btn.visible = false
		return
		
	var cost_dict = data.get("cost", {})
	var cost_hint = ""
	for rc in cost_dict:
		cost_hint += "%s:%d  " % [tr(ResourceTypes.get_type_name(rc)), cost_dict[rc]]
		
	var next_name = tr(data.get("name", "Unknown"))
	_upgrade_btn.text = "升级至 %s\n(%s)" % [next_name, cost_hint.strip_edges()]
	_upgrade_btn.visible = true


func _on_upgrade_pressed() -> void:
	if _selected_object == null or not is_instance_valid(_selected_object): return
	if not "building_type" in _selected_object: return
	
	var current_type = _selected_object.building_type
	if UPGRADE_MAP.has(current_type):
		var next_type = UPGRADE_MAP[current_type]
		if _player_controller != null and _player_controller.has_method("upgrade_building"):
			# 发起升级
			_player_controller.upgrade_building(_selected_object, next_type)
			# 升级后它变成蓝图了（由于原址翻修），我们最好关掉面板
			_on_close_pressed()


## 格式化山洞信息
func _format_cave_info(status: Dictionary) -> String:
	var text: String = ""
	var cave_storage: Dictionary = status.get("storage", {})
	var max_storage_dict = status.get("max_storage", {})
	for type in ResourceTypes.get_all_types():
		var amount: int = cave_storage.get(type, 0)
		var cap: int = 100
		if typeof(max_storage_dict) == TYPE_DICTIONARY:
			cap = max_storage_dict.get(type, 100)
		elif typeof(max_storage_dict) == TYPE_INT:
			cap = max_storage_dict # 向后兼容
			
		var icon: String = ResourceTypes.get_type_icon(type)
		text += "%s %s:  %d / %d\n" % [icon, tr(ResourceTypes.get_type_name(type)), amount, cap]
	return text


## 格式化营地大楼 (WOODEN_HUT, STONE_HOUSE, RESIDENCE_BUILDING) 信息
func _format_residence_info(status: Dictionary) -> String:
	var text: String = ""
	if status.get("is_blueprint", true):
		text += "🚧 [正在施工中]\n"
		var progress: float = status.get("progress", 0.0)
		var req: float = status.get("work_required", 1.0)
		text += "当前进度: %d%%\n等待小人敲打完成" % int((progress / req) * 100)
		return text
		
	var p: int = status.get("bonus_pop", 0)
	var s: int = status.get("bonus_storage", 0)
	if p > 0: text += "👥 提供人口上限: +%d\n" % p
	if s > 0: text += "📦 提供单矿物上限: +%d\n" % s
	
	# 打印目前储存的东西
	if "storage" in status and status.storage is Dictionary:
		var storage = status.storage
		var has_any = false
		for t in storage:
			if storage[t] > 0:
				if not has_any:
					text += "--------------\n"
					has_any = true
				text += "%s: %d\n" % [tr(ResourceTypes.get_type_name(t)), storage[t]]
		
	return text

## 格式化农田 (FARM) 信息
func _format_farm_info(status: Dictionary) -> String:
	var text: String = ""
	if status.get("is_blueprint", true):
		text += "🚧 [正在施工中]\n"
		var progress: float = status.get("progress", 0.0)
		var req: float = status.get("work_required", 1.0)
		text += "当前进度: %d%%\n等待小人开垦完" % int((progress / req) * 100)
		return text
		
	text += "🌱 农田\n熟练度: %d 级\n" % (status.get("proficiency", 0) / 10)
	if status.get("is_ready", false):
		text += "▶ 状态: 可收割 (预计产出: %d)\n" % status.get("current_yield", 0)
	else:
		text += "▶ 状态: 生长中 (%.1f%%)\n" % status.get("growth", 0)
		
	return text
