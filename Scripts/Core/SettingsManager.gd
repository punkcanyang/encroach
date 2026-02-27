## SettingsManager - 游戏设置管理器
##
## 职责：管理游戏的所有可配置选项，包括显示设置、游戏速度等
## 提供运行时修改设置的能力，并持久化到配置文件
##
## AI Context: 此模块是游戏的配置中心，所有可调参数都应通过此处管理
## 设置会在游戏启动时自动加载，修改后自动保存

extends Node


## 信号：当任何设置发生变化时发射
signal settings_changed(setting_name: String, new_value: Variant)

## 信号：当窗口模式改变时发射
signal window_mode_changed(mode: DisplayServer.WindowMode)

## 信号：当分辨率改变时发射
signal resolution_changed(new_size: Vector2i)


## 配置常量：配置文件路径
const SETTINGS_FILE_PATH: String = "user://settings.cfg"

## 配置常量：默认窗口大小（1280x720，即 720p）
const DEFAULT_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)

## 配置常量：最小窗口大小
const MIN_WINDOW_SIZE: Vector2i = Vector2i(800, 600)

## 配置常量：可用的分辨率列表
const AVAILABLE_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),   # 720p (HD)
	Vector2i(1920, 1080),  # 1080p (Full HD)
	Vector2i(2560, 1440),  # 1440p (2K)
	Vector2i(3840, 2160),  # 4K
]


## 当前设置数据（使用 Dictionary 存储所有设置）
var _settings: Dictionary = {}

## 配置对象，用于读写文件
var _config: ConfigFile = ConfigFile.new()

## 标记：设置是否已加载
var _is_loaded: bool = false


func _ready() -> void:
	# 加载设置，如果不存在则使用默认值
	_load_settings()
	
	# 应用显示设置
	_apply_display_settings()
	
	print("SettingsManager: 设置管理器初始化完成")


## 加载设置文件，如果不存在则创建默认设置
func _load_settings() -> void:
	var error: Error = _config.load(SETTINGS_FILE_PATH)
	
	if error != OK:
		print("SettingsManager: 未找到设置文件，使用默认设置")
		_create_default_settings()
	else:
		print("SettingsManager: 成功加载设置文件")
		_parse_settings_from_config()
	
	_is_loaded = true


## 创建默认设置
func _create_default_settings() -> void:
	# 显示设置
	_set_default_value("display", "window_mode", "windowed")  # windowed, fullscreen, borderless
	_set_default_value("display", "resolution", DEFAULT_WINDOW_SIZE)
	_set_default_value("display", "vsync", true)
	_set_default_value("display", "target_fps", 60)
	
	# 游戏设置
	_set_default_value("game", "time_scale", 1.0)  # 时间流逝速度倍率
	_set_default_value("game", "tick_rate", 0.5)   # 每个 Tick 的秒数
	_set_default_value("game", "ticks_per_day", 10)
	
	# 音频设置（占位，MVP 暂不实现音频）
	_set_default_value("audio", "master_volume", 100)
	_set_default_value("audio", "sfx_volume", 100)
	_set_default_value("audio", "music_volume", 100)
	
	# 保存到文件
	_save_settings()


## 从 ConfigFile 解析设置到内存
func _parse_settings_from_config() -> void:
	# 遍历所有 section
	for section in _config.get_sections():
		_settings[section] = {}
		# 遍历 section 下的所有 key
		for key in _config.get_section_keys(section):
			_settings[section][key] = _config.get_value(section, key)


## 设置默认值（内部使用）
func _set_default_value(section: String, key: String, value: Variant) -> void:
	if not _settings.has(section):
		_settings[section] = {}
	_settings[section][key] = value
	_config.set_value(section, key, value)


## 保存当前设置到文件
func _save_settings() -> void:
	var error: Error = _config.save(SETTINGS_FILE_PATH)
	if error == OK:
		print("SettingsManager: 设置已保存")
	else:
		push_warning("SettingsManager: 保存设置失败，错误码: %d" % error)


## 应用显示设置到引擎
func _apply_display_settings() -> void:
	# 应用窗口模式
	_apply_window_mode()
	
	# 应用分辨率
	_apply_resolution()
	
	# 应用 VSync
	var vsync: bool = get_setting("display", "vsync", true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	
	# 应用目标帧率
	var target_fps: int = get_setting("display", "target_fps", 60)
	Engine.max_fps = target_fps


## 应用窗口模式
func _apply_window_mode() -> void:
	var mode_string: String = get_setting("display", "window_mode", "windowed")
	var mode: DisplayServer.WindowMode
	
	match mode_string:
		"fullscreen":
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		"borderless":
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		"windowed", _:
			mode = DisplayServer.WINDOW_MODE_WINDOWED
	
	DisplayServer.window_set_mode(mode)
	window_mode_changed.emit(mode)


## 应用分辨率
func _apply_resolution() -> void:
	var resolution: Vector2i = get_setting("display", "resolution", DEFAULT_WINDOW_SIZE)
	
	# 确保分辨率不小于最小值
	resolution.x = max(resolution.x, MIN_WINDOW_SIZE.x)
	resolution.y = max(resolution.y, MIN_WINDOW_SIZE.y)
	
	# 只有在窗口模式下才改变大小（全屏模式使用显示器原生分辨率）
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)
		resolution_changed.emit(resolution)


## 获取设置值
## 参数：section - 设置分类（如 "display", "game", "audio"）
##       key - 设置项名称
##       default_value - 如果设置不存在，返回的默认值
## 返回：设置值，如果不存在则返回 default_value
func get_setting(section: String, key: String, default_value: Variant = null) -> Variant:
	if _settings.has(section) and _settings[section].has(key):
		return _settings[section][key]
	return default_value


## 设置配置值
## 参数：section - 设置分类
##       key - 设置项名称
##       value - 新的值
## 返回：是否成功设置
func set_setting(section: String, key: String, value: Variant) -> bool:
	if not _settings.has(section):
		_settings[section] = {}
	
	_settings[section][key] = value
	_config.set_value(section, key, value)
	
	# 保存到文件
	_save_settings()
	
	# 发射信号
	settings_changed.emit("%s.%s" % [section, key], value)
	
	# 如果是显示相关设置，实时应用
	if section == "display":
		_apply_display_settings()
	
	print("SettingsManager: 设置已更改 [%s.%s] = %s" % [section, key, str(value)])
	return true


## 切换窗口模式（窗口化 <-> 全屏）
func toggle_fullscreen() -> void:
	var current_mode: String = get_setting("display", "window_mode", "windowed")
	var new_mode: String
	
	if current_mode == "windowed":
		new_mode = "fullscreen"
	else:
		new_mode = "windowed"
	
	set_setting("display", "window_mode", new_mode)


## 设置窗口分辨率（仅在窗口模式下有效）
func set_resolution(width: int, height: int) -> void:
	var new_size: Vector2i = Vector2i(width, height)
	set_setting("display", "resolution", new_size)


## 设置游戏速度倍率
func set_time_scale(scale: float) -> void:
	scale = clamp(scale, 0.1, 3.0)  # 限制在 0.1x 到 3.0x 之间
	set_setting("game", "time_scale", scale)
	Engine.time_scale = scale


## 获取当前游戏速度倍率
func get_time_scale() -> float:
	return get_setting("game", "time_scale", 1.0)


## 重置所有设置为默认值
func reset_to_defaults() -> void:
	_settings.clear()
	_create_default_settings()
	_apply_display_settings()
	print("SettingsManager: 所有设置已重置为默认值")


## 打印当前所有设置（用于调试）
func print_all_settings() -> void:
	print("\n========== 当前游戏设置 ==========")
	for section in _settings.keys():
		print("[%s]" % section)
		for key in _settings[section].keys():
			print("  %s = %s" % [key, str(_settings[section][key])])
	print("================================\n")


## 获取可用的分辨率列表
func get_available_resolutions() -> Array[Vector2i]:
	return AVAILABLE_RESOLUTIONS.duplicate()


# [For Future AI]
# =========================
# 关键假设:
# 1. 配置文件存储在用户目录（user://settings.cfg），跨平台兼容
# 2. Godot 的 ConfigFile 使用 INI 格式，人类可读
# 3. DisplayServer 在 _ready() 时已经可用
# 4. 设置变更会立即生效并自动保存
#
# 潜在边界情况:
# 1. 如果设置文件损坏，会自动创建默认设置
# 2. 如果设置的值类型错误（如把 bool 当 int），ConfigFile 会尝试转换
# 3. 在全屏模式下修改分辨率，实际效果取决于操作系统
# 4. user:// 目录可能无写入权限（罕见），此时设置不会持久化
#
# 依赖模块:
# - 被 World 依赖：World 应持有此节点的引用
# - 依赖 Godot 内置：ConfigFile, DisplayServer, Engine
#
# 扩展建议:
# 1. 未来可添加图形质量设置（阴影、抗锯齿等）
# 2. 可添加键位绑定设置（InputMap 操作重映射）
# 3. 可添加语言/本地化设置
