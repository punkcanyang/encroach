## WorldCamera - 世界相机控制器
##
## 职责：管理游戏相机，支持玩家移动视角查看大地图
## 实现平滑移动和边界限制

extends Camera2D


## 相机移动速度（像素/秒）
@export var move_speed: float = 500.0

## 相机缩放速度
@export var zoom_speed: float = 0.1

## 最小缩放级别（将在此后动态计算）
@export var min_zoom: float = 0.05

## 最大缩放级别
@export var max_zoom: float = 3.0

## 平滑移动系数（0-1，越小越平滑）
@export var smoothness: float = 0.15


## 目标位置（用于平滑移动）
var _target_position: Vector2

## 目标缩放级别（用于平滑缩放）
var _target_zoom: float = 0.25

## 是否启用边界限制
var _use_limits: bool = false

## 鼠标拖拽相关
var _is_dragging: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO

## 边界限制值
var _limit_left: float = 0
var _limit_top: float = 0
var _limit_right: float = 2400
var _limit_bottom: float = 1800


func _ready() -> void:
	# 读取边界限制（从 meta 数据）
	if has_meta("limit_left"):
		_limit_left = get_meta("limit_left")
		_use_limits = true
	if has_meta("limit_top"):
		_limit_top = get_meta("limit_top")
	if has_meta("limit_right"):
		_limit_right = get_meta("limit_right")
	if has_meta("limit_bottom"):
		_limit_bottom = get_meta("limit_bottom")
	
	# 启用边界限制
	if _use_limits:
		limit_left = int(_limit_left)
		limit_top = int(_limit_top)
		limit_right = int(_limit_right)
		limit_bottom = int(_limit_bottom)
		limit_smoothed = true
		position_smoothing_enabled = false # 关闭引擎自带的平滑，防止在 time_scale 很大时计算爆炸导致画面消失
		position_smoothing_speed = 10.0
	
	# 监听窗口尺寸改变以更新动态最小缩放
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_calculate_dynamic_min_zoom()
	
	# 初始化目标位置和缩放
	_target_zoom = clamp(1.0, min_zoom, max_zoom)
	_target_position = position
	
	# 设置为当前相机
	make_current()
	
	print("WorldCamera: 相机已激活，位置: %s" % str(position))
	print("WorldCamera: 边界限制 [%d, %d, %d, %d]" % [limit_left, limit_top, limit_right, limit_bottom])
	print("WorldCamera: 控制方式 - 中键拖拽移动, 滚轮缩放, 数字键1/2/3快速缩放")


func _process(delta: float) -> void:
	# 处理输入
	_handle_input(delta)
	
	# 平滑移动到目标位置
	if position != _target_position:
		position = position.lerp(_target_position, smoothness)
	
	# 平滑缩放到目标缩放级别
	var current_zoom: float = zoom.x
	if abs(current_zoom - _target_zoom) > 0.001:
		var new_zoom: float = lerp(current_zoom, _target_zoom, smoothness)
		zoom = Vector2(new_zoom, new_zoom)
		_apply_limits_to_target() # 缩放后重新应用边界限制


## 处理输入
func _handle_input(delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	# WASD 或方向键移动
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_vector.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_vector.x += 1
	
	# 归一化输入向量（避免对角线移动过快）
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		
		# 计算移动量
		var move_amount: Vector2 = input_vector * move_speed * delta / zoom.x
		_target_position += move_amount
	
	# 鼠标滚轮缩放
	if Input.is_action_just_released("ui_page_up"):
		_zoom_camera(-zoom_speed)
	if Input.is_action_just_released("ui_page_down"):
		_zoom_camera(zoom_speed)
	
	# 数字键快速缩放
	if Input.is_key_pressed(KEY_1):
		_set_target_zoom_level(1.0)
	if Input.is_key_pressed(KEY_2):
		_set_target_zoom_level(0.75)
	if Input.is_key_pressed(KEY_3):
		_set_target_zoom_level(0.5)
	
	# 应用边界限制到目标位置
	_apply_limits_to_target()


## 处理鼠标输入事件（拖拽与滚轮与触控板）
## 改用 _unhandled_input 防止被 UI 拦截
func _unhandled_input(event: InputEvent) -> void:
	# 处理鼠标按钮按下/释放以及滚轮缩放
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	
	# 处理鼠标移动拖拽
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		
	# 处理 Mac 触控板的双指滑动缩放事件
	if event is InputEventPanGesture:
		# delta.y 为正表示向下/向内（缩小），为负表示向上/向外（放大）
		# Mac 触控板滑动灵敏，通常给一个小倍率系数
		_zoom_camera(-event.delta.y * zoom_speed * 0.5)


## 处理鼠标按钮事件
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# 左键或中键按下 - 开始拖拽
	if (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE) and event.pressed:
		_is_dragging = true
		_last_mouse_position = event.position
	
	# 左键或中键释放 - 停止拖拽
	elif (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE) and not event.pressed:
		_is_dragging = false
	
	# 鼠标滚轮缩放（平滑）
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_zoom -= zoom_speed
		_target_zoom = clamp(_target_zoom, min_zoom, max_zoom)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_zoom += zoom_speed
		_target_zoom = clamp(_target_zoom, min_zoom, max_zoom)


## 处理鼠标移动事件
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _is_dragging:
		return
	
	# 计算鼠标移动的增量
	var mouse_delta: Vector2 = event.position - _last_mouse_position
	
	# 将屏幕坐标的移动转换为世界坐标的移动（考虑缩放）
	var world_delta: Vector2 = - mouse_delta / zoom.x
	
	# 更新目标位置
	_target_position += world_delta
	_apply_limits_to_target()
	
	# 更新最后的鼠标位置
	_last_mouse_position = event.position


## 应用边界限制
func _apply_limits_to_target() -> void:
	if not _use_limits:
		return
	
	# 获取视窗大小，并根据目标缩放级别(_target_zoom)计算实际可见范围
	# 注意：Camera2D 的 zoom 越大，看到的范围越小；所以视口计算正好相反（Godot默认缩放是放大倍数）
	var viewport_size: Vector2 = get_viewport_rect().size / _target_zoom
	
	# 计算边界对应相机的中心点限制偏移
	var half_width: float = viewport_size.x / 2.0
	var half_height: float = viewport_size.y / 2.0
	
	_target_position.x = clamp(
		_target_position.x,
		_limit_left + half_width,
		_limit_right - half_width
	)
	_target_position.y = clamp(
		_target_position.y,
		_limit_top + half_height,
		_limit_bottom - half_height
	)


## 缩放相机（修改目标缩放，用于平滑过渡）
func _zoom_camera(zoom_delta: float) -> void:
	_target_zoom += zoom_delta
	_target_zoom = clamp(_target_zoom, min_zoom, max_zoom)


## 设置目标缩放级别（立即设置，用于数字键）
func _set_target_zoom_level(level: float) -> void:
	_target_zoom = clamp(level, min_zoom, max_zoom)


## 响应视窗大小变化
func _on_viewport_size_changed() -> void:
	_calculate_dynamic_min_zoom()
	_target_zoom = clamp(_target_zoom, min_zoom, max_zoom)
	_apply_limits_to_target()


## 动态计算最小缩放限制（缩小最多到全览地图）
func _calculate_dynamic_min_zoom() -> void:
	if not _use_limits:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var map_width: float = _limit_right - _limit_left
	var map_height: float = _limit_bottom - _limit_top
	
	if map_width > 0 and map_height > 0:
		var min_zoom_x: float = viewport_size.x / map_width
		var min_zoom_y: float = viewport_size.y / map_height
		# 取较大值，保证宽和高都不会让视角比地图还大（即看不到黑边）
		# 极小防呆，防止除以 0 导致相机 NaN
		min_zoom = max(0.01, max(min_zoom_x, min_zoom_y))
		if min_zoom > max_zoom:
			max_zoom = min_zoom


## 瞬间移动相机到指定位置（不经过平滑）
func snap_to_position(new_position: Vector2) -> void:
	_target_position = new_position
	position = new_position


## 设置边界限制
func set_limits(left: float, top: float, right: float, bottom: float) -> void:
	_limit_left = left
	_limit_top = top
	_limit_right = right
	_limit_bottom = bottom
	
	limit_left = int(left)
	limit_top = int(top)
	limit_right = int(right)
	limit_bottom = int(bottom)
	_use_limits = true


## 聚焦到特定位置（平滑移动）
func focus_on(target_pos: Vector2) -> void:
	_target_position = target_pos


# [For Future AI]
# =========================
# 关键假设:
# 1. 相机使用 Godot 内置的 Camera2D 节点
# 2. 输入使用 Godot 内置的 ui_ 动作和键盘扫描码
# 3. 边界限制通过 limit_* 属性和手动 clamp 实现
# 4. 平滑移动使用 lerp 插值
#
# 潜在边界情况:
# 1. 如果视窗大小大于世界大小，边界限制可能导致相机无法移动
# 2. 缩放时边界计算基于当前 zoom，快速缩放可能导致瞬间越界
# 3. 如果 smoothness 为 0，相机会瞬间移动；如果为 1，永远不会到达目标
# 4. 多触摸/鼠标拖拽未实现（MVP 简化）
#
# 依赖模块:
# - 由 WorldGenerator 实例化并设置参数
# - 依赖 Godot 内置的 Camera2D 功能
#
# 控制说明:
# - WASD 或方向键: 移动相机
# - 鼠标拖拽 (左键或中键): 移动相机
# - MacOS 触控板双指滑动: 平滑缩放
# - 鼠标滚轮: 平滑缩放（推荐）
# - PageUp/PageDown: 缩放
# - 数字键 1/2/3: 快速缩放到 100%/75%/50%
#
# 缩放特性:
# - 滚轮缩放带有平滑过渡效果
# - 缩放范围: 0.5x - 2.0x
# - 缩放时会自动调整边界限制
#
# 扩展建议:
# 1. 添加鼠标拖拽移动（右键或中键）
# 2. 添加鼠标滚轮缩放
# 3. 添加聚焦到特定 Agent 的功能
# 4. 添加小地图显示相机位置
