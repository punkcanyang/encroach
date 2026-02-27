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
		
	var data = _building_manager.get_building_data(current_build_type)
	var cost_dict: Dictionary = data.get("cost", {})
	
	if not _try_consume_global_resources(cost_dict):
		print("PlayerController: 资源不足！无法放置蓝图")
		return
	
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


func upgrade_building(old_building: Node2D, next_type: int) -> void:
	if _building_manager == null or not is_instance_valid(old_building): return
	
	var data = _building_manager.get_building_data(next_type)
	if data.is_empty(): return
	
	var cost_dict: Dictionary = data.get("cost", {})
	if not _try_consume_global_resources(cost_dict):
		print("PlayerController: 资源不足！无法升级建筑")
		return
		
	var target_pos = old_building.global_position
	
	# 开始接管原内部储存
	var old_storage: Dictionary = {}
	if "storage" in old_building and old_building.storage is Dictionary:
		old_storage = old_building.storage.duplicate()
		
	# 移除旧实体
	_building_manager.remove_building(old_building)
	
	# 原理生成升阶蓝图
	var new_bp = _building_manager.place_building(next_type, target_pos, false)
	if new_bp != null:
		# 强制把旧储物塞入新蓝图底层肚子，等竣工后即可直接取用（或在蓝图期也能查阅）
		if "storage" in new_bp:
			new_bp.storage = old_storage
		print("PlayerController: 发起原址建筑升级至 %d" % next_type)


func _try_consume_global_resources(cost_dict: Dictionary) -> bool:
	if cost_dict.is_empty(): return true
	
	var bm = get_node_or_null("/root/World/BuildingManager")
	var cave = get_node_or_null("/root/World/Cave")
	var storages: Array[Node2D] = []
	if cave != null: storages.append(cave)
	if bm != null and bm.has_method("get_all_buildings"):
		var all_b = bm.get_all_buildings()
		storages.append_array(all_b)
		
	# 1. 预检查全图余量
	for type in cost_dict:
		var req = cost_dict[type]
		var total_owned = 0
		for s in storages:
			if "storage" in s and s.storage.has(type):
				total_owned += s.storage[type]
		if total_owned < req:
			print("PlayerController: 缺乏 %s, 需 %d 实有 %d" % [ResourceTypes.get_type_name(type), req, total_owned])
			return false
			
	# 2. 真实扣除
	for type in cost_dict:
		var remain: int = cost_dict[type]
		for s in storages:
			if remain <= 0: break
			if not s.has_method("consume_resource"): continue
			
			var has_store = 0
			if "storage" in s and s.storage.has(type):
				has_store = s.storage[type]
				
			if has_store > 0:
				var actual_consumed = s.consume_resource(type, min(remain, has_store))
				remain -= actual_consumed
				# 强制刷新：由于 `StatsPanel` 订阅了所有 building_placed 及 storage_changed
				if s.has_user_signal("storage_changed") or s.has_signal("storage_changed"):
					# Building/Cave 的 consume_resource 已内部 emit，不过如果有些还没完全连上，我们保底调用一次
					pass
			
	return true


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
