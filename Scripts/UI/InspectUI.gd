## InspectUI - 物件检视界面
##
## 职责：当鼠标悬停在游戏物件上时显示详细信息
## 包括人类状态、资源储量、山洞食物、建筑状态等
##
## AI Context: 这是游戏的检查系统，帮助玩家了解世界状态

extends Control


## 配置：检查延迟（秒）
@export var inspect_delay: float = 0.3

## 配置：信息面板偏移
@export var panel_offset: Vector2 = Vector2(15, 15)

## 面板固定尺寸
const PANEL_SIZE: Vector2 = Vector2(250, 180)

## 建筑升级路线图: [旧BuildingType] -> [新BuildingType]
## 4(CAVE)->1(WOODEN_HUT)->2(STONE_HOUSE)->3(RESIDENCE)
const UPGRADE_MAP: Dictionary = {
	4: 1,
	1: 2,
	2: 3
}

## UI 节点引用
var _info_panel: Panel = null
var _title_label: Label = null
var _content_label: Label = null

## 内部状态
var _hovered_object: Node2D = null
var _hover_timer: float = 0.0
var _is_hovering: bool = false
var _camera: Camera2D = null
var _init_logged: bool = false


func _ready() -> void:
	print(">>> InspectUI: 真实挂载的脚本 _ready() 被调用 <<<")
	# WHY: 不使用 @onready，改为手动查找节点以打印调试信息
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_info_panel = get_node_or_null("InfoPanel") as Panel
	if _info_panel == null:
		# WHY: 如果场景中没有 InfoPanel，就动态创建一个
		print("InspectUI: ⚠️ 未找到 InfoPanel 子节点，动态创建中...")
		_create_panel()
	else:
		_title_label = _info_panel.get_node_or_null("TitleLabel") as Label
		_content_label = _info_panel.get_node_or_null("ContentLabel") as Label
	
	# 确保初始化
	if _title_label == null:
		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		_info_panel.add_child(_title_label)
	if _content_label == null:
		_content_label = Label.new()
		_content_label.name = "ContentLabel"
		_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_info_panel.add_child(_content_label)
	
	# 强制设置面板属性
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	_info_panel.z_index = 100
	_info_panel.size = PANEL_SIZE
	
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("InspectUI: ✅ 面板初始化完成")
	
	# WHY: 延迟以确保世界和相机已创建完毕
	call_deferred("_deferred_init")


func _create_panel() -> void:
	_info_panel = Panel.new()
	_info_panel.name = "InfoPanel"
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.size = PANEL_SIZE
	add_child(_info_panel)
	
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.position = Vector2(8, 8)
	_title_label.size = Vector2(PANEL_SIZE.x - 16, 24)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(_title_label)
	
	_content_label = Label.new()
	_content_label.name = "ContentLabel"
	_content_label.position = Vector2(8, 36)
	_content_label.size = Vector2(PANEL_SIZE.x - 16, PANEL_SIZE.y - 44)
	_content_label.add_theme_font_size_override("font_size", 12)
	_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(_content_label)


func _deferred_init() -> void:
	_camera = get_node_or_null("/root/World/WorldCamera") as Camera2D


func _process(delta: float) -> void:
	# 确保相机引用有效
	if _camera == null or not is_instance_valid(_camera):
		var world = get_node_or_null("/root/World")
		if world != null:
			_camera = world.get_viewport().get_camera_2d()
		if _camera == null:
			return

	# WHY: 一次性诊断输出，确认系统正常运行
	if not _init_logged:
		_init_logged = true
		var group = get_tree().get_nodes_in_group("inspectable")
		print("InspectUI: camera=OK | inspectable组=%d个 | panel=%s" % [
			group.size(), "OK" if _info_panel != null else "NULL"
		])

	_check_hover()

	# 处理悬停计时
	if _is_hovering and _hovered_object != null and is_instance_valid(_hovered_object):
		_hover_timer += delta
		if _hover_timer >= inspect_delay:
			_show_inspect_info()
	else:
		_hover_timer = 0.0
		if _info_panel.visible:
			_info_panel.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			_try_upgrade_hovered_building()
			

func _try_upgrade_hovered_building() -> void:
	if _hovered_object == null or not is_instance_valid(_hovered_object): return
	
	if not _is_hovering or not _info_panel.visible: return
	
	# 只处理特定包含 building_type 的对象 (且非施工状态)
	var current_type: int = -1
	var is_blueprint: bool = false
	if "building_type" in _hovered_object:
		current_type = _hovered_object.building_type
	if "is_blueprint" in _hovered_object:
		is_blueprint = _hovered_object.is_blueprint
		
	if is_blueprint or current_type == -1: return
	
	if not UPGRADE_MAP.has(current_type):
		return # 不可升级
		
	var next_type: int = UPGRADE_MAP[current_type]
	
	# 调用 Controller 实现升级
	var controller = get_node_or_null("/root/World/PlayerController")
	if controller != null and controller.has_method("upgrade_building"):
		controller.upgrade_building(_hovered_object, next_type)


## 检查鼠标悬停
func _check_hover() -> void:
	var world_pos: Vector2 = _camera.get_global_mouse_position()
	var zoom_factor: float = 1.0 / max(_camera.zoom.x, 0.01)
	var inspectables: Array[Node] = get_tree().get_nodes_in_group("inspectable")

	var found_object: Node2D = null
	var closest_dist: float = INF

	for child in inspectables:
		if not child is Node2D:
			continue
		if not is_instance_valid(child):
			continue
		if not child.has_method("get_status"):
			continue

		# WHY: 山洞和建筑使用更大的检测半径
		var base_radius: float = 30.0
		if child.name == "Cave" or child.is_in_group("building"):
			base_radius = 50.0

		var check_radius: float = base_radius * zoom_factor

		var dist: float = child.global_position.distance_to(world_pos)
		if dist < check_radius and dist < closest_dist:
			closest_dist = dist
			found_object = child

	# 更新悬停状态
	# WHY: 只有当检测到的对象发生变化时才更新，避免每帧都重置 timer
	if found_object != _hovered_object:
		_hovered_object = found_object
		_hover_timer = 0.0
		_is_hovering = found_object != null

		if _hovered_object != null:
			_update_inspect_content()
		else:
			_info_panel.visible = false


## 更新检视内容
func _update_inspect_content() -> void:
	if _hovered_object == null or not is_instance_valid(_hovered_object):
		return
	
	var title: String = "未知"
	var content: String = ""
	
	# 根据物件类型获取信息
	if _hovered_object.has_method("get_status"):
		var status: Dictionary = _hovered_object.get_status()
		
		if "lifespan" in status:
			# 人类
			title = "👤 " + tr("HUMAN_TITLE")
			content = _format_human_info(status)
		elif "max_storage" in status and "storage" in status:
			# 山洞
			title = "🏠 " + tr("CAVE_TITLE")
			content = _format_cave_info(status)
		elif "bonus_pop" in status or "bonus_storage" in status or "growth" in status:
			# 新增的建筑 (Farm / Residence)
			title = "🏗️ " + tr(status.get("name", "BUILDING_TITLE"))
			content = _format_building_info(status)
		elif "type" in status:
			# 资源
			title = "🍎 " + tr(status.get("type", "RESOURCE_TITLE"))
			content = _format_resource_info(status)
		else:
			title = _hovered_object.name
			content = "位置: (%d, %d)" % [int(_hovered_object.global_position.x), int(_hovered_object.global_position.y)]
	else:
		# 通用信息
		title = _hovered_object.name
		content = "位置: (%d, %d)" % [int(_hovered_object.global_position.x), int(_hovered_object.global_position.y)]
	
	_title_label.text = title
	_content_label.text = content


## 格式化人类信息
func _format_human_info(status: Dictionary) -> String:
	var text: String = ""
	
	var age_years: int = status.get("age_years", 0)
	var age_days: int = status.get("age_days", 0)
	var lifespan: int = status.get("lifespan_years", 0)
	
	text += (tr("UI_AGE") + "\n") % [age_years, age_days]
	text += (tr("UI_LIFESPAN") + "\n") % lifespan
	text += (tr("UI_HUNGER") + "\n") % status.get("hunger", 0)
	text += (tr("UI_STATE") + "\n") % tr(status.get("state", "STATE_UNKNOWN"))
	
	# WHY: 显示携带的资源类型与数量
	var carried: int = status.get("carried", 0)
	if carried > 0:
		var carried_type: int = status.get("carried_type", 0)
		var type_name: String = tr(ResourceTypes.get_type_name(carried_type))
		text += tr("UI_CARRIED_RESOURCE") % [carried, type_name]
	
	return text


## 格式化山洞信息
## WHY: 展示每种资源的独立库存
func _format_cave_info(status: Dictionary) -> String:
	var text: String = ""
	
	var cave_storage: Dictionary = status.get("storage", {})
	var max_storage: int = status.get("max_storage", 100)
	
	# 逐类型显示库存
	for type in ResourceTypes.get_all_types():
		var amount: int = cave_storage.get(type, 0)
		var icon: String = ResourceTypes.get_type_icon(type)
		var type_name: String = tr(ResourceTypes.get_type_name(type))
		text += "%s %s: %d/%d\n" % [icon, type_name, amount, max_storage]
	
	if status.get("can_spawn_human", false):
		text += tr("UI_CAN_REPRODUCE") + "\n"
	else:
		text += tr("UI_CANNOT_REPRODUCE") + "\n"
		
	# WHY: 追加升级提示
	text += _get_upgrade_hint(status.get("building_type", 4))
	
	return text


## 格式化资源信息
func _format_resource_info(status: Dictionary) -> String:
	var text: String = ""
	
	var amount: int = status.get("amount", 0)
	var max_amount: int = status.get("max_amount", 100)
	
	text += (tr("UI_AMOUNT") + "\n") % [amount, max_amount]
	text += tr("UI_REMAINING") % (amount * 100 / max(max_amount, 1))
	
	if status.get("depleted", false):
		text += tr("UI_DEPLETED")
	
	return text


## 格式化建筑 (Farm / Residence) 信息
func _format_building_info(status: Dictionary) -> String:
	var text: String = ""
	
	if status.get("is_blueprint", true):
		text += "🚧 [施工中]\n"
		var progress: float = status.get("progress", 0.0)
		var req: float = status.get("work_required", 1.0)
		text += "进度: %d%%\n" % int((progress / req) * 100)
		return text
		
	# 建成状态
	if "growth" in status:
		# 农田
		text += "🌱 农田\n"
		text += "熟练度: %d 级\n" % (status.get("proficiency", 0) / 10)
		if status.get("is_ready", false):
			text += "▶ 状态: 可收割 (预计产出: %d)\n" % status.get("current_yield", 0)
		else:
			text += "▶ 状态: 生长中 (%.1f%%)\n" % status.get("growth", 0)
			
	elif "bonus_pop" in status:
		# 住所
		text += "🏠 住所营地\n"
		var p: int = status.get("bonus_pop", 0)
		var s: int = status.get("bonus_storage", 0)
		if p > 0:
			text += "👥 提供人口上限: +%d\n" % p
		if s > 0:
			text += "📦 提供储物上限: +%d\n" % s
			
		text += _get_upgrade_hint(status.get("building_type", 0))
			
	return text


func _get_upgrade_hint(current_type: int) -> String:
	if not UPGRADE_MAP.has(current_type):
		return ""
		
	var next_type = UPGRADE_MAP[current_type]
	var bm = get_node_or_null("/root/World/BuildingManager")
	if bm == null or not bm.has_method("get_building_data"): return ""
	
	var data = bm.get_building_data(next_type)
	if data.is_empty(): return ""
	
	var cost_hint = ""
	var cost_dict = data.get("cost", {})
	for rc in cost_dict:
		var rc_name = tr(ResourceTypes.get_type_name(rc))
		cost_hint += "%sx%d " % [rc_name, cost_dict[rc]]
		
	var next_name = tr(data.get("name", "Unknown"))
	return "\n⭐ 按 [U] 升级为 [%s]*\n   花费: %s" % [next_name, cost_hint.strip_edges()]


## 显示检视信息
func _show_inspect_info() -> void:
	if _hovered_object == null or not is_instance_valid(_hovered_object):
		return
	
	# WHY: 每次显示时更新内容（数值可能已变化）
	_update_inspect_content()
	
	# WHY: 从 root viewport 取鼠标位置，确保在 CanvasLayer 下坐标正确
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	
	# WHY: 直接用 offset 控制位置，比 position 更可靠（不受 layout 系统影响）
	var target_x: float = mouse_pos.x + panel_offset.x
	var target_y: float = mouse_pos.y + panel_offset.y
	
	# 确保面板不超出屏幕
	var screen_size: Vector2 = get_viewport_rect().size
	
	if target_x + PANEL_SIZE.x > screen_size.x:
		target_x = mouse_pos.x - PANEL_SIZE.x - panel_offset.x
	if target_y + PANEL_SIZE.y > screen_size.y:
		target_y = mouse_pos.y - PANEL_SIZE.y - panel_offset.y
	
	# WHY: 使用 global_position 而非 position，避免父级 Control 的偏移干扰
	_info_panel.global_position = Vector2(target_x, target_y)
	_info_panel.size = PANEL_SIZE
	_info_panel.visible = true


# [For Future AI]
# =========================
# 关键假设:
# 1. 所有可检视物件都有 get_status() 方法
# 2. 使用 Camera2D 进行坐标转换
# 3. 面板通过 global_position 直接定位，避免 layout 系统干扰
# 4. mouse_filter = IGNORE 确保面板不拦截鼠标事件
#
# 依赖模块:
# - HumanAgent.get_status()
# - Cave.get_status()
# - Resource.get_status()
# - Building.get_status()
