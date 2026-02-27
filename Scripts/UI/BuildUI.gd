## BuildUI - 建造选单界面
##
## 职责：提供底部操作栏，让玩家选择要建造的建筑（农田、山洞以外的新住所）
## 选单交互将通过绝对路径调用 PlayerController 进入建造模式。
##
## AI Context: 作为 UIManager 的子级模块，控制底部的建造按钮。

extends Control


var _hbox: HBoxContainer = null
var _initialized: bool = false


func _ready() -> void:
	name = "BuildUI"
	
	# WHY: 让鼠标能穿透 BuildUI 的空白区域，只有按钮本身可点击
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置布局：底部横条
	set_anchors_preset(PRESET_BOTTOM_WIDE)
	offset_top = -50
	offset_bottom = 0
	
	_hbox = HBoxContainer.new()
	_hbox.name = "ButtonRow"
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	# WHY: HBoxContainer 本身也不应拦截鼠标（只有子按钮拦截）
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_hbox)
	
	print("BuildUI: 建造选单已创建，等待 BuildingManager 初始化...")


func _process(_delta: float) -> void:
	# WHY: 用轮询替代 call_deferred，确保 BuildingManager 确实已经准备好
	if _initialized:
		return
		
	var bm = get_node_or_null("/root/World/BuildingManager")
	if bm == null:
		return
	
	# 到这里说明 BuildingManager 已存在，可以生成按钮了
	_initialized = true
	_generate_buttons(bm)


func _generate_buttons(bm: Node) -> void:
	var all_types = [4, 0, 1, 2, 3] # CAVE, FARM, WOODEN_HUT, STONE_HOUSE, RESIDENCE_BUILDING
	
	var label = Label.new()
	label.text = tr("UI_BUILD_LABEL")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.add_child(label)
	
	for type in all_types:
		var data = bm.get_building_data(type)
		if data.is_empty():
			continue
			
		var btn = Button.new()
		# WHY: 使用 tr() 翻译建筑名称
		btn.text = tr(data.get("name", str(type)))
		
		# 构造 tooltip 悬停耗费
		var tooltip_str = ""
		var cost_dict = data.get("cost", {})
		for rc in cost_dict:
			tooltip_str += tr("UI_BUILD_COST") % [tr(ResourceTypes.get_type_name(rc)), cost_dict[rc]] + "\n"
			
		var pop_cap = data.get("pop_cap", 0)
		var sto_cap = data.get("storage_cap", 0)
		if pop_cap > 0:
			tooltip_str += tr("UI_BUILD_POP") % pop_cap + "\n"
		if sto_cap > 0:
			tooltip_str += tr("UI_BUILD_STORAGE") % sto_cap + "\n"
			
		btn.tooltip_text = tooltip_str.strip_edges()
		btn.custom_minimum_size = Vector2(100, 36)
		
		# 连接点击事件
		btn.pressed.connect(_on_build_button_pressed.bind(type))
		_hbox.add_child(btn)
		
	# 取消按钮
	var cancel_btn = Button.new()
	cancel_btn.text = tr("UI_BUILD_CANCEL")
	cancel_btn.custom_minimum_size = Vector2(80, 36)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	_hbox.add_child(cancel_btn)
	
	print("BuildUI: 建造选单已生成 %d 个建筑按钮" % all_types.size())


func _on_build_button_pressed(type: int) -> void:
	var controller = get_node_or_null("/root/World/PlayerController")
	if controller != null and controller.has_method("enter_build_mode"):
		controller.enter_build_mode(type)
		print("BuildUI: 选中建筑类型 %d" % type)


func _on_cancel_pressed() -> void:
	var controller = get_node_or_null("/root/World/PlayerController")
	if controller != null and controller.has_method("exit_build_mode"):
		controller.exit_build_mode()
		print("BuildUI: 取消建造模式")


# [For Future AI]
# =========================
# 关键假设:
# 1. 挂载于 UIManager (CanvasLayer)
# 2. 使用 _process 轮询等待 BuildingManager 初始化
# 3. mouse_filter = IGNORE 确保中间空白区域不拦截世界交互
