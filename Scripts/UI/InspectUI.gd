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

## 建筑升级路线图: [旧BuildingType] -> Array[新BuildingType]
const UPGRADE_MAP: Dictionary = {
	4: [1, 2, 3], # CAVE -> WOODEN_HUT, STONE_HOUSE, RESIDENCE
	1: [2, 3], # WOODEN_HUT -> STONE_HOUSE, RESIDENCE
	2: [3] # STONE_HOUSE -> RESIDENCE
}

## UI 节点引用
var _info_panel: Panel = null
var _title_label: Label = null
var _content_label: RichTextLabel = null
var _close_btn: Button = null

## 动态交互操作区
var _actions_container: VBoxContainer = null
var _demolish_btn: Button = null

## 内部状态
var _selected_object: Node2D = null
var _player_controller: Node = null
var _is_pinned: bool = false

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
	
	# 内容区 (更换为富文本以支持配色与粗体)
	_content_label = RichTextLabel.new()
	_content_label.position = Vector2(10, 45)
	_content_label.size = Vector2(PANEL_SIZE.x - 20, 90) # 缩小文本区域，留给下方滚动清单
	_content_label.add_theme_font_size_override("normal_font_size", 14)
	_content_label.add_theme_font_size_override("bold_font_size", 14)
	_content_label.bbcode_enabled = true
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_label.scroll_active = false
	_info_panel.add_child(_content_label)
	
	# 动态操作区 (ScrollContainer -> VBoxContainer)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 140)
	scroll.size = Vector2(PANEL_SIZE.x - 20, PANEL_SIZE.y - 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_panel.add_child(scroll)
	
	_actions_container = VBoxContainer.new()
	_actions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_actions_container)
	
	# 拆除按钮（常驻但由逻辑控制隐藏）
	_demolish_btn = Button.new()
	_demolish_btn.text = "拆除建筑 (返还50%资源)"
	_demolish_btn.add_theme_font_size_override("font_size", 14)
	_demolish_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_demolish_btn.pressed.connect(_on_demolish_pressed)
	_demolish_btn.visible = false
	_info_panel.add_child(_demolish_btn)
	# 把拆除按钮放在整个面板的最底部，盖在滚动条下面
	_demolish_btn.position = Vector2(10, PANEL_SIZE.y - 7) # 这个位置实际上跑到面版外面了一点，调整面版大小
	_info_panel.size.y = PANEL_SIZE.y + 35
	# 更正上面：我们将_info_panel 高度调大到 255，拆除按钮放在 220 处
	_demolish_btn.position = Vector2(10, PANEL_SIZE.y)
	_demolish_btn.size = Vector2(PANEL_SIZE.x - 20, 30)


func _on_building_selected(target: Node2D) -> void:
	print("InspectUI: 接到点击锁定，目标 -> ", target)
	if target == null:
		_info_panel.visible = false
		_selected_object = null
		_is_pinned = false
		return
		
	_selected_object = target
	_is_pinned = true
	_update_inspect_content()
	_info_panel.visible = true


func _on_building_hovered(target: Node2D) -> void:
	if _is_pinned: return
	
	if target == null:
		# 没有悬停到目标且面板没被固定时，自动隐藏面板
		if _info_panel.visible:
			_info_panel.visible = false
			_selected_object = null
		return
		
	_selected_object = target
	_update_inspect_content()
	if not _info_panel.visible:
		_info_panel.visible = true


func _on_close_pressed() -> void:
	_info_panel.visible = false
	_selected_object = null
	_is_pinned = false


func _process(_delta: float) -> void:
	if not _init_print_done:
		print("InspectUI: _process is running")
		_init_print_done = true
		
	# 延迟初始化连接（防止 _ready 时 World 尚未入树导致找不到）
	if _player_controller == null:
		_player_controller = get_node_or_null("/root/World/PlayerController")
		if _player_controller != null and _player_controller.has_signal("building_selected"):
			_player_controller.building_selected.connect(_on_building_selected)
			if _player_controller.has_signal("building_hovered"):
				_player_controller.building_hovered.connect(_on_building_hovered)
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
		elif "depleted" in status:
			# 野生资源点
			if "type" in status:
				title = "🌲 " + tr(status["type"])
			content = _format_resource_info(status)
		else:
			content = "状态不可用"
	else:
		title = _selected_object.name
		content = "状态不可用"
		
	_title_label.text = title
	_content_label.text = content # 先兜底清理文本
	_content_label.text = "" # 彻底清空普通纯文本，强制走 BBCode
	_content_label.parse_bbcode(content)
	
	_update_upgrade_button()


func _update_upgrade_button() -> void:
	# 控制拆除按钮显示 (山洞、木屋等属于建筑，可拆)
	var is_building = (_selected_object.name == "Cave" or _selected_object.is_in_group("building"))
	_demolish_btn.visible = is_building
		
	# 提取状态判断升级条件
	var current_type: int = -1
	var is_blueprint: bool = false
	if "building_type" in _selected_object:
		current_type = _selected_object.building_type
	if "is_blueprint" in _selected_object:
		is_blueprint = _selected_object.is_blueprint
		
	if is_blueprint or current_type == -1 or not UPGRADE_MAP.has(current_type):
		for child in _actions_container.get_children():
			child.queue_free()
		return
		
	var next_types = UPGRADE_MAP[current_type]
	var bm = get_node_or_null("/root/World/BuildingManager")
	if bm == null or not bm.has_method("get_building_data"):
		return
		
	# 检查是否需要重建按钮 (数量不符，或者类型不符)
	var child_count = _actions_container.get_child_count()
	var needs_rebuild = (child_count != next_types.size())
	if not needs_rebuild:
		for i in range(child_count):
			var btn = _actions_container.get_child(i) as Button
			if btn == null or btn.get_meta("upgrade_type", -1) != next_types[i]:
				needs_rebuild = true
				break
				
	if needs_rebuild:
		# 清空重建
		for child in _actions_container.get_children():
			child.queue_free()
		for next_type in next_types:
			var btn = Button.new()
			btn.set_meta("upgrade_type", next_type)
			btn.add_theme_font_size_override("font_size", 12)
			btn.custom_minimum_size = Vector2(0, 50)
			btn.pressed.connect(_on_upgrade_pressed.bind(btn))
			_actions_container.add_child(btn)

	# 更新按钮状态
	for i in range(next_types.size()):
		var next_type = next_types[i]
		var data = bm.get_building_data(next_type)
		if data.is_empty(): continue
			
		var cost_dict = data.get("cost", {})
		
		# ---- 【預檢資源庫存，決定防呆反灰】 ----
		var can_afford: bool = true
		if _player_controller != null and _player_controller.has_method("_get_all_storages"):
			var storages = _player_controller._get_all_storages()
			can_afford = _player_controller._check_global_resources(cost_dict, storages, _selected_object)
			
		var cost_hint = ""
		var count_i = 0
		for rc in cost_dict:
			cost_hint += "%s:%d " % [tr(ResourceTypes.get_type_name(rc)), cost_dict[rc]]
			count_i += 1
			if count_i % 2 == 0:
				cost_hint += "\n" # 两条换行
			
		var next_name = tr(data.get("name", "Unknown"))
		
		var btn = _actions_container.get_child(i) as Button
		if btn == null: continue
		
		if not can_afford:
			btn.text = "升级至 %s (资源不足)\n%s" % [next_name, cost_hint.strip_edges()]
			btn.disabled = true
			btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			btn.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
			btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.3, 0.3))
		else:
			btn.text = "升级至 %s\n%s" % [next_name, cost_hint.strip_edges()]
			btn.disabled = false
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			if btn.has_theme_color_override("font_disabled_color"):
				btn.remove_theme_color_override("font_disabled_color")


func _on_upgrade_pressed(btn: Button) -> void:
	if _selected_object == null or not is_instance_valid(_selected_object): return
	if not "building_type" in _selected_object: return
	
	btn.disabled = true # 立即禁用，防止雙擊連發造成重複扣款
	var next_type = btn.get_meta("upgrade_type")
	if _player_controller != null and _player_controller.has_method("upgrade_building"):
		_player_controller.upgrade_building(_selected_object, next_type)
		_on_close_pressed()


func _on_demolish_pressed() -> void:
	if _selected_object == null or not is_instance_valid(_selected_object): return
	
	if _player_controller != null and _player_controller.has_method("demolish_building"):
		_player_controller.demolish_building(_selected_object)
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
		text += "  %s [color=#dddddd]%s:[/color]  [b]%d[/b] / %d\n" % [icon, tr(ResourceTypes.get_type_name(type)), amount, cap]
	return text


## 格式化野生资源点信息
func _format_resource_info(status: Dictionary) -> String:
	var text: String = "\n"
	text += "[color=#dddddd]剩余储量:[/color] [b]%d[/b] / %d\n" % [status.get("amount", 0), status.get("max_amount", 0)]
	if status.get("depleted", false):
		text += "[color=#ff6666]▶ 状态: 已彻底枯竭[/color]"
	else:
		text += "[color=#88ff88]▶ 状态: 可开采[/color]"
	return text

## 格式化建筑 (Farm / Residence) 信息
func _format_residence_info(status: Dictionary) -> String:
	var text: String = ""
	if status.get("is_blueprint", true):
		text += "\n[color=#ffdd55]🚧 正在施工中[/color]\n"
		var progress: float = status.get("progress", 0.0)
		var req: float = status.get("work_required", 1.0)
		text += "[color=#999999]当前进度: %d%%\n等待居民敲打完成...[/color]" % int((progress / req) * 100)
		return text
		
	var p: int = status.get("bonus_pop", 0)
	var s: int = status.get("bonus_storage", 0)
	if p > 0: text += "👥 提供人口上限: [color=#aaddff][b]+%d[/b][/color]\n" % p
	if s > 0: text += "📦 提供单矿物上限: [color=#aaddff][b]+%d[/b][/color]\n" % s
	
	# 打印目前储存的东西
	if "storage" in status and status.storage is Dictionary:
		var storage = status.storage
		var has_any = false
		for t in storage:
			if storage[t] > 0:
				if not has_any:
					text += "\n[color=#888888]─────── 库存物资 ───────[/color]\n"
					has_any = true
				text += "  [color=#dddddd]%s:[/color] [b]%d[/b]\n" % [tr(ResourceTypes.get_type_name(t)), storage[t]]
		
	return text

## 格式化农田 (FARM) 信息
func _format_farm_info(status: Dictionary) -> String:
	var text: String = ""
	if status.get("is_blueprint", true):
		text += "\n[color=#ffdd55]🚧 农田开垦中[/color]\n"
		var progress: float = status.get("progress", 0.0)
		var req: float = status.get("work_required", 1.0)
		text += "[color=#999999]当前进度: %d%%\n等待居民翻土完成...[/color]" % int((progress / req) * 100)
		return text
		
	text += "🌱 [color=#dddddd]农田熟练度:[/color] [b]%d[/b] 级\n" % (status.get("proficiency", 0) / 10)
	if status.get("is_ready", false):
		text += "[color=#88ff88]▶ 状态: 可收割 (产出: [b]%d[/b])[/color]\n" % status.get("current_yield", 0)
	else:
		text += "[color=#aaddff]▶ 状态: 生长中 (%.1f%%)[/color]\n" % status.get("growth", 0)
		
	return text
