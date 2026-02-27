## SettingsUI - 设置界面
##
## 职责：提供图形界面让玩家调整游戏设置
## 包括窗口模式、分辨率、游戏速度等
##
## AI Context: 这是一个简单的设置面板，使用 Godot 内置 UI 节点
## 通过 SettingsManager 实际应用设置变更

extends Control


## 信号：当设置界面关闭时发射
signal settings_closed()


## 内部引用
@onready var _settings_manager: Node = null

## UI 节点引用
@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/TitleLabel
@onready var _window_mode_button: Button = $Panel/WindowModeButton
@onready var _resolution_option: OptionButton = $Panel/ResolutionOption
@onready var _speed_slider: HSlider = $Panel/SpeedSlider
@onready var _speed_value_label: Label = $Panel/SpeedValueLabel
@onready var _close_button: Button = $Panel/CloseButton

## 当前设置缓存
var _current_window_mode: String = "windowed"
var _current_resolution: Vector2i = Vector2i(1280, 720)
var _current_speed: float = 1.0


func _ready() -> void:
	# 获取 SettingsManager
	var world = get_node("/root/World")
	if world:
		_settings_manager = world.get_node("SettingsManager")
	
	# 初始化 UI
	_initialize_ui()
	
	# 默认隐藏
	hide()


## 初始化 UI 状态和值
func _initialize_ui() -> void:
	if _settings_manager == null:
		push_warning("SettingsUI: 无法找到 SettingsManager")
		return
	
	# 获取当前设置
	_current_window_mode = _settings_manager.get_setting("display", "window_mode", "windowed")
	_current_resolution = _settings_manager.get_setting("display", "resolution", Vector2i(1280, 720))
	_current_speed = _settings_manager.get_setting("game", "time_scale", 1.0)
	
	# 更新窗口模式按钮
	_update_window_mode_button()
	
	# 填充分辨率选项
	_fill_resolution_options()
	
	# 设置速度滑块
	_speed_slider.value = _current_speed
	_speed_slider.min_value = 0.1
	_speed_slider.max_value = 3.0
	_speed_slider.step = 0.1
	_update_speed_label()


## 更新窗口模式按钮文本
func _update_window_mode_button() -> void:
	var button_text: String = tr("UI_WINDOWED")
	match _current_window_mode:
		"fullscreen":
			button_text = tr("UI_FULLSCREEN")
		"borderless":
			button_text = tr("UI_WINDOWED")
	_window_mode_button.text = tr("UI_DISPLAY_MODE") % button_text


## 填充分辨率下拉选项
func _fill_resolution_options() -> void:
	_resolution_option.clear()
	
	var resolutions: Array[Vector2i] = _settings_manager.get_available_resolutions()
	var current_index: int = 0
	
	for i in range(resolutions.size()):
		var res: Vector2i = resolutions[i]
		var res_text: String = "%dx%d" % [res.x, res.y]
		
		# 添加选项，存储分辨率值
		_resolution_option.add_item(res_text, i)
		_resolution_option.set_item_metadata(i, res)
		
		# 检查是否为当前分辨率
		if res == _current_resolution:
			current_index = i
	
	# 选择当前分辨率
	_resolution_option.selected = current_index


## 更新速度标签
func _update_speed_label() -> void:
	_speed_value_label.text = tr("UI_SPEED_MULTI") % _speed_slider.value


## 显示设置界面
func open_settings() -> void:
	# 刷新当前值
	_initialize_ui()
	
	# 显示并暂停游戏（可选）
	show()
	get_tree().paused = true
	
	print("SettingsUI: 设置界面已打开")


## 关闭设置界面
func close_settings() -> void:
	hide()
	get_tree().paused = false
	settings_closed.emit()
	
	print("SettingsUI: 设置界面已关闭")


## 切换窗口模式
func _on_window_mode_button_pressed() -> void:
	if _settings_manager == null:
		return
	
	# 循环切换：窗口化 -> 全荧幕 -> 无边框 -> 窗口化
	match _current_window_mode:
		"windowed":
			_current_window_mode = "fullscreen"
		"fullscreen":
			_current_window_mode = "borderless"
		"borderless", _:
			_current_window_mode = "windowed"
	
	# 应用设置
	_settings_manager.set_setting("display", "window_mode", _current_window_mode)
	
	# 更新按钮文本
	_update_window_mode_button()
	
	print("SettingsUI: 窗口模式切换为 %s" % _current_window_mode)


## 分辨率改变
func _on_resolution_option_item_selected(index: int) -> void:
	if _settings_manager == null:
		return
	
	# 获取选择的分辨率
	var selected_res: Vector2i = _resolution_option.get_item_metadata(index)
	_current_resolution = selected_res
	
	# 应用设置
	_settings_manager.set_resolution(selected_res.x, selected_res.y)
	
	print("SettingsUI: 分辨率设置为 %dx%d" % [selected_res.x, selected_res.y])


## 速度滑块值改变
func _on_speed_slider_value_changed(value: float) -> void:
	if _settings_manager == null:
		return
	
	_current_speed = value
	_update_speed_label()


## 速度滑块拖动结束
func _on_speed_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed or _settings_manager == null:
		return
	
	# 应用游戏速度
	_settings_manager.set_time_scale(_current_speed)
	
	print("SettingsUI: 游戏速度设置为 %.1fx" % _current_speed)


## 关闭按钮
func _on_close_button_pressed() -> void:
	close_settings()


## 处理输入（按 ESC 关闭）
func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			close_settings()
			get_viewport().set_input_as_handled()


# [For Future AI]
# =========================
# 关键假设:
# 1. SettingsManager 存在且路径为 /root/World/SettingsManager
# 2. UI 节点在场景树中的名称和层级正确
# 3. 使用 get_tree().paused = true/false 暂停/恢复游戏
#
# 潜在边界情况:
# 1. 如果 SettingsManager 不存在，设置变更不会生效
# 2. 在设置界面打开时按 ESC 会关闭界面（已处理）
# 3. 分辨率变更可能需要重启才能完全生效（取决于 Godot 行为）
#
# 依赖模块:
# - SettingsManager: 用于实际应用设置变更
# - 需要被添加到 World 场景或作为 CanvasLayer 的子节点
#
# 使用方式:
# 1. 将 SettingsUI.tscn 添加到 World 场景
# 2. 按 ESC 键打开设置界面
# 3. 调整设置后点击关闭或再按 ESC
