## UIManager - UI 管理器
##
## 职责：管理所有游戏 UI，处理快捷键打开设置等功能
## 作为 CanvasLayer 存在，确保 UI 始终显示在最上层
##
## AI Context: 此节点作为 UI 的根节点，集中管理所有界面
## 未来可扩展为包含更多 UI 面板（资源统计、Agent 列表等）

extends CanvasLayer


## 引用：设置界面
@onready var _settings_ui: Control = $SettingsUI

## 统计面板引用
var _stats_panel: PanelContainer


func _ready() -> void:
	print("UIManager: UI 管理器初始化完成")
	print("UIManager: 按 ESC 键打开设置")
	
	# 创建顶部的数据统计面板
	_stats_panel = PanelContainer.new()
	_stats_panel.name = "StatsPanel"
	var stats_script = load("res://Scripts/UI/StatsPanel.gd")
	if stats_script:
		_stats_panel.set_script(stats_script)
		add_child(_stats_panel)
	else:
		push_error("UIManager: 无法加载 StatsPanel 脚本")
		
	# 创建物件检视面板 InspectUI
	var inspect_ui = Control.new()
	inspect_ui.name = "InspectUI"
	var inspect_script = load("res://Scripts/UI/InspectUI.gd")
	if inspect_script:
		inspect_ui.set_script(inspect_script)
		add_child(inspect_ui)
		print("UIManager: 成功通过代码动态挂载 InspectUI")
	else:
		push_error("UIManager: 无法加载 InspectUI 脚本")
		
	# 创建 Agent 统计面板 AgentStatsUI
	var agent_stats_ui = PanelContainer.new()
	agent_stats_ui.name = "AgentStatsUI"
	var agent_stats_script = load("res://Scripts/UI/AgentStatsUI.gd")
	if agent_stats_script:
		agent_stats_ui.set_script(agent_stats_script)
		add_child(agent_stats_ui)
		print("UIManager: 成功通过代码动态挂载 AgentStatsUI")
	else:
		push_error("UIManager: 无法加载 AgentStatsUI 脚本")
		
	# 创建 建筑清单总览 BuildingListUI
	var b_list_ui = PanelContainer.new()
	b_list_ui.name = "BuildingListUI"
	var b_list_script = load("res://Scripts/UI/BuildingListUI.gd")
	if b_list_script:
		b_list_ui.set_script(b_list_script)
		add_child(b_list_ui)
		print("UIManager: 成功通过代码动态挂载 BuildingListUI")
	else:
		push_error("UIManager: 无法加载 BuildingListUI 脚本")

	# 创建 滚动事件日志 EventLogUI
	var evt_log_ui = MarginContainer.new()
	evt_log_ui.name = "EventLogUI"
	var evt_log_script = load("res://Scripts/UI/EventLogUI.gd")
	if evt_log_script:
		evt_log_ui.set_script(evt_log_script)
		add_child(evt_log_ui)
		print("UIManager: 成功通过代码动态挂载 EventLogUI")
	else:
		push_error("UIManager: 无法加载 EventLogUI 脚本")


## 处理全局输入
func _input(event: InputEvent) -> void:
	# 按 ESC 键打开/关闭设置
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_settings()
		get_viewport().set_input_as_handled()
		
	# 按 C 键打开/关闭 Agent 状态统计面板
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		var agent_stats = get_node_or_null("AgentStatsUI")
		if agent_stats and agent_stats.has_method("toggle_panel"):
			agent_stats.toggle_panel()
			get_viewport().set_input_as_handled()
			
	# 按 B 键打开/关闭 建筑清单面板
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		var block = get_node_or_null("BuildingListUI")
		if block and block.has_method("toggle_panel"):
			block.toggle_panel()
			get_viewport().set_input_as_handled()


## 切换设置界面
func _toggle_settings() -> void:
	if _settings_ui == null:
		push_warning("UIManager: 设置界面未找到")
		return
	
	if _settings_ui.visible:
		_settings_ui.close_settings()
	else:
		_settings_ui.open_settings()


## 打开设置界面（外部调用）
func open_settings() -> void:
	if _settings_ui != null and not _settings_ui.visible:
		_settings_ui.open_settings()


## 关闭设置界面（外部调用）
func close_settings() -> void:
	if _settings_ui != null and _settings_ui.visible:
		_settings_ui.close_settings()


# [For Future AI]
# =========================
# 关键假设:
# 1. 此节点是 CanvasLayer 类型，确保 UI 渲染在世界之上
# 2. SettingsUI 是此节点的直接子节点，路径为 $SettingsUI
# 3. _input 会捕获 ESC 键，阻止其传播到其他节点
#
# 潜在边界情况:
# 1. 如果 SettingsUI 未添加到场景树，按 ESC 会报错
# 2. 多个 UI 同时打开时，ESC 行为可能需要调整
# 3. 游戏暂停时（get_tree().paused = true），_input 仍会被调用
#
# 依赖模块:
# - SettingsUI: 设置界面场景
# - 被 World 依赖：World 应添加此节点为子节点
#
# 扩展建议:
# 1. 添加资源统计面板（显示食物、人口、天数）
# 2. 添加 Agent 列表面板（点击查看详情）
# 3. 添加建筑选择面板
# 4. 添加日志/事件显示区域
