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
		
	# 移除快捷键，全由 UI 按钮触发
			
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


signal building_selected(target: Node2D)
signal building_hovered(target: Node2D)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if current_build_type == -1:
			# 非建造模式下：鼠标划过侦测
			_try_hover_object()
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_build_type == -1:
			# 非建造模式下：点选物品
			_try_select_object()
		else:
			# 处于建造模式下：放置蓝图
			get_viewport().set_input_as_handled()
			_try_place_building()
			
	# FIXME: 这里仅在按下时处理，释放时如有拖拽相机逻辑应由相机自己处理
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if current_build_type != -1:
			get_viewport().set_input_as_handled()


func _try_select_object() -> void:
	if _camera == null: return
	
	var world_pos = _camera.get_global_mouse_position()
	var zoom_factor = 1.0 / max(_camera.zoom.x, 0.01)
	var inspectables = get_tree().get_nodes_in_group("inspectable")
	
	var found_object: Node2D = null
	var closest_dist: float = INF
	
	for child in inspectables:
		if not child is Node2D or not is_instance_valid(child): continue
		
		# 点击弹窗，只认建筑和山洞
		var is_building = child.name == "Cave" or child.is_in_group("building")
		if not is_building: continue
		
		var base_radius = 50.0
		var check_radius = base_radius * zoom_factor
		var dist = child.global_position.distance_to(world_pos)
		
		if dist < check_radius and dist < closest_dist:
			closest_dist = dist
			found_object = child
			
	# 如果沒有點到建築，嘗試點擊 ECS Agent
	if found_object == null:
		var am = get_node_or_null("/root/World/AgentManager")
		if am != null and am.has_method("get_agent_data_at"):
			var base_radius = 20.0 # Agent 半徑較小
			var check_radius = base_radius * zoom_factor
			var nearest_idx = -1
			
			for i in range(am.agent_active.size()):
				if am.agent_active[i] == 0: continue
				var dist = am.agent_positions[i].distance_to(world_pos)
				if dist < check_radius and dist < closest_dist:
					closest_dist = dist
					nearest_idx = i
					
			if nearest_idx != -1:
				var data = am.get_agent_data_at(nearest_idx)
				found_object = _create_mock_agent_node(data)
			
	building_selected.emit(found_object)
	if found_object:
		print("PlayerController: 选中了物件 -> ", found_object.name)
	else:
		print("PlayerController: 点击了空地，取消选中")

func _create_mock_agent_node(data: Dictionary) -> Node2D:
	var mock = Node2D.new()
	var lf_years = int(data.get("lifespan_days", 0) / 365.0)
	var age_years = int(data.get("age_days", 0) / 365.0)
	var hp = int(data.get("hp", 0))
	var max_hp = int(data.get("max_hp", 0))
	var id = data.get("id", 0)
	mock.name = "居民 #%d" % id
	# 直接塞一個 get_status 方法給它
	mock.set_script(preload("res://Scripts/Core/MockAgent.gd"))
	if mock.has_method("setup"):
		mock.setup(data)
	return mock

var _last_hovered: Node2D = null

func _try_hover_object() -> void:
	if _camera == null: return
	
	var world_pos = _camera.get_global_mouse_position()
	var zoom_factor = 1.0 / max(_camera.zoom.x, 0.01)
	var inspectables = get_tree().get_nodes_in_group("inspectable")
	
	var found_object: Node2D = null
	var closest_dist: float = INF
	
	for child in inspectables:
		if not child is Node2D or not is_instance_valid(child): continue
		
		# 悬停弹窗，只认野生资源
		var is_building = child.name == "Cave" or child.is_in_group("building")
		if is_building: continue
		
		var base_radius = 50.0
		var check_radius = base_radius * zoom_factor
		var dist = child.global_position.distance_to(world_pos)
		
		if dist < check_radius and dist < closest_dist:
			closest_dist = dist
			found_object = child
			
	if found_object == null:
		var am = get_node_or_null("/root/World/AgentManager")
		if am != null and am.has_method("get_agent_data_at"):
			var base_radius = 20.0
			var check_radius = base_radius * zoom_factor
			var nearest_idx = -1
			
			for i in range(am.agent_active.size()):
				if am.agent_active[i] == 0: continue
				var dist = am.agent_positions[i].distance_to(world_pos)
				if dist < check_radius and dist < closest_dist:
					closest_dist = dist
					nearest_idx = i
					
			if nearest_idx != -1:
				var data = am.get_agent_data_at(nearest_idx)
				found_object = _create_mock_agent_node(data)
			
	if found_object != _last_hovered:
		# 不要一直 delete 上一個 Mock Node，交回給 GC 處理即可
		_last_hovered = found_object
		building_hovered.emit(found_object)


func _try_place_building() -> void:
	if not _is_preview_valid:
		print("PlayerController: 建造位置无效（发生碰撞或在边界外）")
		return
		
	if _building_manager == null or _camera == null:
		return
		
	var data = _building_manager.get_building_data(current_build_type)
	var cost_dict: Dictionary = data.get("cost", {})
	
	var storages = _get_all_storages()
	if not _check_global_resources(cost_dict, storages):
		print("PlayerController: 资源不足！无法放置蓝图")
		return
	
	var mouse_pos = _camera.get_global_mouse_position()
	
	var blueprint = _building_manager.place_building(current_build_type, mouse_pos, false)
	
	if blueprint != null:
		_consume_global_resources(cost_dict, storages)
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
	print("PlayerController: 准备进入升级消耗判定，花费配置：", cost_dict)
	
	var storages = _get_all_storages()
	# 升級判定時，把目前舊建築提供的返還建材也算入財產中核查
	if not _check_global_resources(cost_dict, storages, old_building):
		print("PlayerController: 升级拦截 -> 资源不足！无法升级建筑")
		return
		
	var target_pos = old_building.global_position
	
	# 原址生成升阶蓝图，强制绕开碰撞检查，并关联旧建筑
	var new_bp = _building_manager.place_building(next_type, target_pos, false, old_building)
	if new_bp != null:
		# 修改扣款邏輯：先將舊建築的退還物資從花費清單中折抵掉
		var actual_cost: Dictionary = cost_dict.duplicate()
		if old_building.has_method("get_refund_resources"):
			var refunds = old_building.get_refund_resources()
			for r_type in refunds:
				if actual_cost.has(r_type):
					actual_cost[r_type] = max(0, actual_cost[r_type] - refunds[r_type])
					if actual_cost[r_type] == 0:
						actual_cost.erase(r_type)
						
		# 只有在蓝图实际成功放置时，才真实扣除折扣後的花费
		_consume_global_resources(actual_cost, storages)
		print("PlayerController: 成功放置升级蓝图并扣除了资源")
	else:
		push_warning("PlayerController: 蓝图放置发生碰撞等阻碍失败，幸好资源尚未扣除！")


func _get_all_storages() -> Array[Node2D]:
	var bm = get_node_or_null("/root/World/BuildingManager")
	var cave = get_node_or_null("/root/World/Cave")
	var storages: Array[Node2D] = []
	if cave != null: storages.append(cave)
	if bm != null and bm.has_method("get_all_buildings"):
		storages.append_array(bm.get_all_buildings())
	return storages


func _check_global_resources(cost_dict: Dictionary, storages: Array[Node2D], refund_building: Node2D = null) -> bool:
	if cost_dict.is_empty(): return true
	
	# 如果有升級或替換等原址拆除建築，要將它的退還物資算作本次的「預借津貼」
	var refunds: Dictionary = {}
	if refund_building != null and refund_building.has_method("get_refund_resources"):
		refunds = refund_building.get_refund_resources()
		
	for type in cost_dict:
		var req = cost_dict[type]
		var total_owned = 0
		
		# 加上預借津貼
		if refunds.has(type):
			total_owned += refunds[type]
			
		# 加上國庫現有
		for s in storages:
			if "storage" in s and s.storage.has(type):
				total_owned += s.storage[type]
				
		if total_owned < req:
			print("PlayerController: 缺乏 %s, 需 %d 实有 %d (含折抵)" % [ResourceTypes.get_type_name(type), req, total_owned])
			return false
	return true


func _consume_global_resources(cost_dict: Dictionary, storages: Array[Node2D]) -> void:
	if cost_dict.is_empty(): return
	
	# 真实扣除
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
					

func exit_build_mode() -> void:
	current_build_type = -1
	_is_preview_valid = false
	print("PlayerController: 退出建造模式")
	queue_redraw()


func demolish_building(building: Node2D) -> void:
	if _building_manager == null or not is_instance_valid(building): return
	
	# 双重保险，防止拆除野生资源或其他不该拆除的物件
	var is_building = building.name == "Cave" or building.is_in_group("building")
	if not is_building:
		print("PlayerController: 拦截拆除 -> 目标不是合法建筑 %s" % building.name)
		return
		
	# 交由 BuildingManager 处理带返还包裹的拆除逻辑
	print("PlayerController: 玩家发起建筑拆除指令 -> %s" % building.name)
	if _building_manager.has_method("remove_building_with_refund"):
		_building_manager.remove_building_with_refund(building)
	else:
		_building_manager.remove_building(building)


func _draw() -> void:
	if current_build_type != -1:
		var color = Color(0.2, 0.8, 0.2, 0.4) if _is_preview_valid else Color(0.8, 0.2, 0.2, 0.4)
		var outline_color = Color(0.2, 0.8, 0.2, 0.8) if _is_preview_valid else Color(0.8, 0.2, 0.2, 0.8)
		
		draw_rect(_preview_rect, color, true)
		draw_rect(_preview_rect, outline_color, false, 2.0)
