## AgentStatsUI - 进阶 Agent 统计面板
##
## 职责：在屏幕一侧显示实时的所有 Agent 统计信息
## AI Context: 该面板由纯代码构建，默认隐藏，由快捷键 (如 'C') 触发展开与收齐

extends PanelContainer

var _container: VBoxContainer
var _title_label: Label
var _population_label: RichTextLabel
var _health_label: RichTextLabel
var _states_label: RichTextLabel

var _agent_manager: Node = null
var _is_open: bool = false
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 1.0

func _ready() -> void:
	name = "AgentStatsUI"
	visible = false
	
	# 面板背景与尺寸
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.15, 0.2, 0.85)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.3, 0.4, 0.5, 1.0)
	stylebox.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", stylebox)
	
	# 面板放置于屏幕右侧中间偏上
	custom_minimum_size = Vector2(250, 300)
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	position = Vector2(get_viewport_rect().size.x - 270, 80)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)
	
	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 10)
	margin.add_child(_container)
	
	# 标题
	_title_label = Label.new()
	_title_label.text = "👥 " + tr("AGENT_STATS_TITLE", "居民状态统计")
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_title_label)
	
	_container.add_child(HSeparator.new())
	
	# 人口与年龄
	_population_label = RichTextLabel.new()
	_population_label.bbcode_enabled = true
	_population_label.fit_content = true
	_container.add_child(_population_label)
	
	# 健康与饥饿
	_health_label = RichTextLabel.new()
	_health_label.bbcode_enabled = true
	_health_label.fit_content = true
	_container.add_child(_health_label)
	
	_container.add_child(HSeparator.new())
	
	# 状态分布
	var state_title = Label.new()
	state_title.text = "🏃 行为分布："
	state_title.add_theme_font_size_override("font_size", 14)
	_container.add_child(state_title)
	
	_states_label = RichTextLabel.new()
	_states_label.bbcode_enabled = true
	_states_label.fit_content = true
	_container.add_child(_states_label)
	
	# 初始化缓存
	_agent_manager = get_node_or_null("/root/World/AgentManager")


func _process(delta: float) -> void:
	if not visible: return
	
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_refresh_stats()


func toggle_panel() -> void:
	_is_open = not _is_open
	visible = _is_open
	if visible:
		_refresh_stats()


func _refresh_stats() -> void:
	if _agent_manager == null:
		_agent_manager = get_node_or_null("/root/World/AgentManager")
		if _agent_manager == null: return
		
	if not _agent_manager.has_method("get_agents_statistics"): return
	
	var stats: Dictionary = _agent_manager.get_agents_statistics()
	var total = stats.get("total_count", 0)
	
	if total == 0:
		_population_label.text = "暂无存活的居民"
		_health_label.text = ""
		_states_label.text = ""
		return
		
	var avg_age = stats.get("average_age_years", 0.0)
	_population_label.text = "[color=#dddddd]当前存活:[/color] [b]%d[/b] 人\n[color=#dddddd]平均年龄:[/color] %.1f 岁" % [total, avg_age]
	
	var avg_hunger = stats.get("average_hunger", 0.0)
	var critical = stats.get("critical_hunger_count", 0)
	var health_text = "[color=#dddddd]平均饱腹度:[/color] %.1f%%\n" % avg_hunger
	if critical > 0:
		health_text += "[color=#ff4444]⚠️ 极度饥饿警告: %d 人[/color]" % critical
	else:
		health_text += "[color=#88ff88]☑️ 族群健康状况良好[/color]"
	_health_label.text = health_text
	
	var states_text = ""
	var state_counts: Dictionary = stats.get("state_counts", {})
	for state_key in state_counts.keys():
		var count = state_counts[state_key]
		# 尝试本地化状态文本
		var translated_state = tr(state_key)
		states_text += "  • %s : [b]%d[/b] 人\n" % [translated_state, count]
		
	if states_text == "":
		states_text = "  (无)"
	_states_label.text = states_text
