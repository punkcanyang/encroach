## EventLogUI - 系统事件日志组件
##
## 职责：在屏幕指定位置（右下角）滚动显示系统核心事件
## （如居民饿死、建筑建成、新生儿诞生等）
## AI Context: 纯代码构建 UI。提供全局接口供其他系统投递消息。

extends MarginContainer

## 内部配置
const MAX_LOG_LINES: int = 15
const LOG_FADE_OUT_TIME: float = 12.0 # 每条日志停留的时间，之后完全消失
const MAX_LOG_HISTORY: int = 30 # 保留多久的历史节点（即使透明也防爆存）

## UI 节点映射
var _vbox: VBoxContainer

## 历史日志管理 [{ node: RichTextLabel, timer: float }]
var _log_entries: Array[Dictionary] = []


func _ready() -> void:
	name = "EventLogUI"
	add_to_group("event_log")
	
	# 设置锚点为右下角向下对齐的盒子
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	
	# 偏移留点边距
	offset_left = -400.0
	offset_right = -20.0
	offset_top = -250.0
	offset_bottom = -70.0 # 避开最底部边缘
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 建立底层背景让字看得清楚 (半透明黑渐变或纯色块)
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.2)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# 建立承载文字的垂直堆栈
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_END # 从下往上长
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 上下左右留边
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_vbox)
	
	add_child(margin)
	
	print("EventLogUI: 日志面板已在右下角挂载准备就绪。")
	
	# 预存一条欢迎语
	add_log("世界开始流转...", "#aaddff")


func _process(delta: float) -> void:
	# 处理每条日志的淡出和消除机制
	for i in range(_log_entries.size() - 1, -1, -1):
		var entry = _log_entries[i]
		entry.timer += delta
		
		var node = entry.node as RichTextLabel
		if node != null and is_instance_valid(node):
			# 开始衰退
			if entry.timer > (LOG_FADE_OUT_TIME - 2.0):
				var alpha = clamp( (LOG_FADE_OUT_TIME - entry.timer) / 2.0, 0.0, 1.0 )
				node.modulate.a = alpha
			
			if entry.timer >= LOG_FADE_OUT_TIME:
				node.queue_free()
				_log_entries.remove_at(i)
		else:
			# 节点已死，清理引用
			_log_entries.remove_at(i)


## 外部调用的唯一接口
## @param message: 要显示的文本
## @param color_hex: 颜色色值，如 "#ffeedd"
func add_log(message: String, color_hex: String = "#ffffff") -> void:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 描边让文字在复杂背景下不丢失
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	var timestamp: String = _get_current_game_time_string()
	label.text = "[color=#888888][%s] [/color][color=%s]%s[/color]" % [timestamp, color_hex, message]
	
	_vbox.add_child(label)
	_log_entries.append({ "node": label, "timer": 0.0 })
	
	# 防卡顿爆栈清理
	if _vbox.get_child_count() > MAX_LOG_LINES:
		var oldest = _vbox.get_child(0)
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()
			# 同步移除内部记录以免 _process 报错
			for i in range(_log_entries.size()):
				if _log_entries[i].node == oldest:
					_log_entries.remove_at(i)
					break


## 从 TimeSystem 获取当前游戏日历字串（无依赖静默获取）
func _get_current_game_time_string() -> String:
	var ts = get_node_or_null("/root/World/TimeSystem")
	if ts != null and "current_day" in ts:
		var d = ts.current_day
		# 转换成年/日
		var y = d / 10 + 1 # DAYS_PER_YEAR 是 10
		var dd = d % 10 + 1
		return "第%d年/天%d" % [y, dd]
	return "???"


# [For Future AI]
# =========================
# 关键假设:
# 1. 这个类使用 add_to_group("event_log")，供任意节点通过 get_tree().call_group 调用
# 2. 会根据真实的时间自动淡出 `RichTextLabel`
# 3. 提供了一层黑色半透明垫底避免纯白地形看不清字
