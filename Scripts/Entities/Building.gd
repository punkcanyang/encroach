## Building - 建筑实体基类
##
## 职责：提供建筑的基础属性、施工进度管理，以及被检视接口
##
## AI Context: 所有可放置的建筑都应继承此类。支持蓝图态和建成态。

extends Node2D
class_name Building


signal storage_changed(building: Node2D, resource_type: int, new_amount: int)

## 建筑类型 (由 BuildingManager.BuildingType 定义)
@export var building_type: int = 0

## 是否为蓝图状态
var is_blueprint: bool = true

## 施工进度 (0.0 - 100.0)
var construction_progress: float = 0.0

## 需要的工作总量
var work_required: float = 100.0

## 资源库存字典（Type -> int）
var storage: Dictionary = {}


func _ready() -> void:
	add_to_group("inspectable")
	add_to_group("building")
	queue_redraw()
	set_process(true)


func _draw() -> void:
	# 基类绘制逻辑（通常由子类重写）
	var size = get_size()
	var rect = Rect2(-size / 2.0, size)
	
	if is_blueprint:
		# 蓝图绘制：半透明轮廓和进度条
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.3), true)
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.8), false, 2.0)
		
		# 进度条背景
		draw_rect(Rect2(-size.x / 2, size.y / 2 + 5, size.x, 6), Color(0.2, 0.2, 0.2))
		# 进度条前景
		var progress_width = size.x * (construction_progress / max(work_required, 1.0))
		draw_rect(Rect2(-size.x / 2, size.y / 2 + 5, progress_width, 6), Color(0.2, 0.8, 0.2))
	else:
		# 默认建筑绘制
		draw_rect(rect, Color(0.5, 0.3, 0.1), true)
		draw_rect(rect, Color.WHITE, false, 2.0)


## 获取建筑尺寸
func get_size() -> Vector2:
	# 尝试从 Manager 获取
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		if data.has("size"):
			return data["size"]
	return Vector2(40, 40)


## 开始施工（作为蓝图放置）
func start_construction(required: float) -> void:
	is_blueprint = true
	construction_progress = 0.0
	work_required = required
	queue_redraw()
	
	# 推送日志
	var b_name: String = "建筑"
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		b_name = tr(data.get("name", "建筑"))
	get_tree().call_group("event_log", "add_log", "开始修筑 %s 蓝图..." % b_name, "#5588aa")


## 增加施工进度（被 Agent 交互时调用）
func add_progress(amount: float) -> void:
	if not is_blueprint:
		return
		
	construction_progress += amount
	
	if construction_progress >= work_required:
		finish_construction()
	
	queue_redraw()


## 完成施工
func finish_construction() -> void:
	if is_blueprint:
		is_blueprint = false
		construction_progress = work_required
		
		# 推送日志
		var b_name: String = "建筑"
		var manager = get_node_or_null("/root/World/BuildingManager")
		if manager != null and manager.has_method("get_building_data"):
			b_name = tr(manager.get_building_data(building_type).get("name", "建筑"))
			manager.finalize_blueprint(self )
		
		get_tree().call_group("event_log", "add_log", "🎉 %s 建造完成！" % b_name, "#00ccff")
			
		_on_construction_finished()
		queue_redraw()

## 蓝图鸭子类型接口：被 Agent 敲打时调用
func collect(requested_amount: int, _collector: Node) -> int:
	if is_blueprint:
		add_progress(10.0)
		return 0 # 返回 0 意味着没有资源可以抱走，但施工进度已经增加了
	return 0

## 蓝图鸭子类型接口：供 Agent 雷达验证状态
func is_depleted() -> bool:
	if is_blueprint:
		return false # 施工中的蓝图不能被视为无效点
	return true # 竣工的建筑本体不提供资源采集


## 子类可重写的回调
func _on_construction_finished() -> void:
	# 初始化独立的资源储存
	storage = {}


## 获取本建筑对应某类型的仓库上限
func get_max_storage_for_type(type: int) -> int:
	if is_blueprint: return 0
	
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		var allowed: Array = data.get("allowed_storage", [])
		if type in allowed:
			return data.get("storage_cap", 0)
	return 0


## 获取可用空间
func get_remaining_space(type: int) -> int:
	if is_blueprint: return 0
	return get_max_storage_for_type(type) - storage.get(type, 0)


## 存入资源
func add_resource(type: int, amount: int) -> int:
	if is_blueprint or amount <= 0: return 0
	var max_cap: int = get_max_storage_for_type(type)
	if max_cap <= 0: return 0
	
	var current: int = storage.get(type, 0)
	var space: int = max_cap - current
	if space <= 0: return 0
	
	var actual: int = min(amount, space)
	storage[type] = current + actual
	storage_changed.emit(self , type, storage[type])
	return actual


## 提取资源
func consume_resource(type: int, amount: int) -> int:
	if is_blueprint or amount <= 0: return 0
	var current: int = storage.get(type, 0)
	if current <= 0: return 0
	
	var actual: int = min(amount, current)
	storage[type] = current - actual
	storage_changed.emit(self , type, storage[type])
	return actual


## 获取节点状态 (InspectUI 调用)
func get_status() -> Dictionary:
	var status: Dictionary = {}
	status["is_blueprint"] = is_blueprint
	status["progress"] = construction_progress
	status["work_required"] = work_required
	
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		status["name"] = data.get("name", "BUILDING_UNKNOWN")
		
		if not is_blueprint:
			var max_caps = {}
			for t in data.get("allowed_storage", []):
				max_caps[t] = get_max_storage_for_type(t)
			status["max_storage"] = max_caps
			status["storage"] = storage.duplicate()
	else:
		status["name"] = "BUILDING_UNKNOWN"
		
	return status


## 取得拆除 / 升級原址取代時，可返還與折抵的總資源
func get_refund_resources() -> Dictionary:
	var refunds = {}
	
	# 返還內部倉庫的所有材料
	for type in storage:
		if storage[type] > 0:
			refunds[type] = storage[type]
			
	# 返還造價的 50% 作為建材津貼
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		var cost_dict = data.get("cost", {})
		for type in cost_dict:
			var half_cost = int(floor(cost_dict[type] * 0.5))
			if half_cost > 0:
				if refunds.has(type):
					refunds[type] += half_cost
				else:
					refunds[type] = half_cost
					
	return refunds


# [For Future AI]
# =========================
# 关键假设:
# 1. 蓝图绘制默认提供进度条展示
# 2. 建成后由 _on_construction_finished 触发特定逻辑
# 3. 依赖 BuildingManager 获取名称和尺寸
