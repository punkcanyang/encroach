## PlayerController - 玩家交互控制器
##
## 职责：处理鼠标点击放置建筑的逻辑、预览建筑轮廓
##
## AI Context: 支持进入建造模式，鼠标跟随显示轮廓，点击后调用 BuildingManager。

extends Node2D

## 当前选中的建筑类型 (-1 表示未选中/非建造模式)
var current_build_type: int = -1

var _building_manager: Node = null
var _camera: Camera2D = null

## 预览用的轮廓矩形（不会添加到世界层级产生碰撞影响）
var _preview_rect: Rect2 = Rect2()
var _is_preview_valid: bool = false


func _ready() -> void:
	name = "PlayerController"
	# 确保它的处理层级比相机高（后处理），这样可以吃掉未处理的输入
	process_priority = -1
	
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	_building_manager = get_node_or_null("/root/World/BuildingManager")
	_camera = get_node_or_null("/root/World/WorldCamera") as Camera2D
	
	print("PlayerController: 玩家控制器已初始化。按 'B' 键切换建造农田模式。")


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_node_or_null("/root/World/WorldCamera") as Camera2D
		
	# 按 B 键快捷切换选中农田 (后期将被 UI 按钮替代)
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_B):
		if current_build_type == -1:
			enter_build_mode(0) # 0 = BuildingType.FARM
		else:
			exit_build_mode()
			
	# 如果在建造模式，更新预览位置和验证状态
	if current_build_type != -1 and _camera != null and _building_manager != null:
		var mouse_pos = _camera.get_global_mouse_position()
		var data = _building_manager.get_building_data(current_build_type)
		var size = data.get("size", Vector2(40, 40))
		
		_preview_rect = Rect2(mouse_pos - size / 2.0, size)
		# 如果 collision 为 true，则 valid 为 false
		_is_preview_valid = not _building_manager.check_collision(_preview_rect)
		
		# 请求重绘预览
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if current_build_type == -1:
		return
		
	# 处于建造模式下，监听鼠标左键点击
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 吃掉点击事件，防止相机拖拽
			get_viewport().set_input_as_handled()
			_try_place_building()
		else:
			# 释放鼠标也吃掉，防止相机取消拖拽状态错误
			get_viewport().set_input_as_handled()


func _try_place_building() -> void:
	if not _is_preview_valid:
		print("PlayerController: 建造位置无效（发生碰撞或在边界外）")
		return
		
	if _building_manager == null or _camera == null:
		return
		
	var cave = get_node_or_null("/root/World/Cave")
	if cave == null:
		push_error("PlayerController: 未找到山洞引用，无法执行资源扣除。")
		return
		
	var data = _building_manager.get_building_data(current_build_type)
	var cost_dict: Dictionary = data.get("cost", {})
	
	# 检查资源是否充足
	for type in cost_dict:
		var required = cost_dict[type]
		var owned = cave.storage.get(type, 0)
		if owned < required:
			print("PlayerController: 资源不足！需要 %s x%d，当前只有 %d" % [ResourceTypes.get_type_name(type), required, owned])
			# TODO: 添加游戏内 UI 悬浮提示框供未来的进一步打磨
			return
			
	# 执行真实扣除
	for type in cost_dict:
		cave.consume_resource(type, cost_dict[type])
	
	var mouse_pos = _camera.get_global_mouse_position()
	
	var blueprint = _building_manager.place_building(current_build_type, mouse_pos, false)
	
	if blueprint != null:
		print("PlayerController: 成功放置类为 %d 的蓝图并扣除对应资源" % current_build_type)
		queue_redraw()
		# 放置后是否退出建造模式取决于设计，这里暂时允许连续放置
		# exit_build_mode()


func enter_build_mode(type: int) -> void:
	current_build_type = type
	print("PlayerController: 进入建造模式，类型 %d" % type)
	
	# 修改鼠标指针或通知 UI（未来实现）


func exit_build_mode() -> void:
	current_build_type = -1
	_is_preview_valid = false
	print("PlayerController: 退出建造模式")
	queue_redraw()


func _draw() -> void:
	if current_build_type != -1:
		var color = Color(0.2, 0.8, 0.2, 0.4) if _is_preview_valid else Color(0.8, 0.2, 0.2, 0.4)
		var outline_color = Color(0.2, 0.8, 0.2, 0.8) if _is_preview_valid else Color(0.8, 0.2, 0.2, 0.8)
		
		draw_rect(_preview_rect, color, true)
		draw_rect(_preview_rect, outline_color, false, 2.0)
