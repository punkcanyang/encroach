## BoundaryVisualizer - 世界边界可视化
##
## 职责：在世界边缘绘制边界线，让玩家知道地图范围
## 使用 _draw() 函数绘制，不依赖任何美术资源

extends Node2D


## 边界线颜色
const BOUNDARY_COLOR: Color = Color(0.3, 0.3, 0.3, 0.5)

## 边界线宽度
const BOUNDARY_WIDTH: float = 2.0

## 网格线颜色
const GRID_COLOR: Color = Color(0.2, 0.2, 0.2, 0.2)

## 网格线间隔
const GRID_SIZE: float = 100.0


var _width: float = 24000.0
var _height: float = 18000.0

## 绘制背景基础色
const BACKGROUND_COLOR: Color = Color(0.5, 0.4, 0.2) # 深土黄色
func _ready() -> void:
	# 从 meta 数据读取世界大小
	if has_meta("width"):
		_width = get_meta("width")
	if has_meta("height"):
		_height = get_meta("height")
		
	# 标记需要重绘（仅仅为了边界线）
	# 设置节点不随 process 更新
	set_process(false)
	set_physics_process(false)
	
	queue_redraw()
	
	print("BoundaryVisualizer: 边界可视化已创建 (%dx%d)" % [_width, _height])


func _draw() -> void:
	# 1. 绘制草地地形
	_draw_ground()
	
	# 2. 绘制世界边界（矩形）
	_draw_boundary()
	
	# 3. 绘制参考网格
	_draw_grid()


## 绘制草地背景 (已取消，改为使用 ProjectSettings 直接填充 clear_color 节省性能)
func _draw_ground() -> void:
	pass


## 绘制世界边界矩形
func _draw_boundary() -> void:
	# 绘制矩形边框
	draw_rect(
		Rect2(0, 0, _width, _height),
		BOUNDARY_COLOR,
		false,
		BOUNDARY_WIDTH
	)
	
	# 在四个角绘制标记
	var corner_size: float = 20.0
	
	# 左上角
	draw_line(Vector2(0, corner_size), Vector2(0, 0), BOUNDARY_COLOR, BOUNDARY_WIDTH)
	draw_line(Vector2(corner_size, 0), Vector2(0, 0), BOUNDARY_COLOR, BOUNDARY_WIDTH)
	
	# 右上角
	draw_line(Vector2(_width - corner_size, 0), Vector2(_width, 0), BOUNDARY_COLOR, BOUNDARY_WIDTH)
	draw_line(Vector2(_width, corner_size), Vector2(_width, 0), BOUNDARY_COLOR, BOUNDARY_WIDTH)
	
	# 左下角
	draw_line(Vector2(0, _height - corner_size), Vector2(0, _height), BOUNDARY_COLOR, BOUNDARY_WIDTH)
	draw_line(Vector2(corner_size, _height), Vector2(0, _height), BOUNDARY_COLOR, BOUNDARY_WIDTH)
	
	# 右下角
	draw_line(Vector2(_width - corner_size, _height), Vector2(_width, _height), BOUNDARY_COLOR, BOUNDARY_WIDTH)
	draw_line(Vector2(_width, _height - corner_size), Vector2(_width, _height), BOUNDARY_COLOR, BOUNDARY_WIDTH)


## 绘制参考网格
func _draw_grid() -> void:
	# 绘制垂直线
	var x: float = GRID_SIZE
	while x < _width:
		draw_line(
			Vector2(x, 0),
			Vector2(x, _height),
			GRID_COLOR,
			1.0
		)
		x += GRID_SIZE
	
	# 绘制水平线
	var y: float = GRID_SIZE
	while y < _height:
		draw_line(
			Vector2(0, y),
			Vector2(_width, y),
			GRID_COLOR,
			1.0
		)
		y += GRID_SIZE


# [For Future AI]
# =========================
# 关键假设:
# 1. 世界坐标系原点在左上角 (0,0)
# 2. 此节点作为 World 的子节点，使用世界坐标
# 3. _width 和 _height 通过 meta 数据传入
#
# 潜在边界情况:
# 1. 如果世界大小为 0，不会绘制任何内容
# 2. 如果网格间隔大于世界大小，不会绘制网格线
# 3. 边界线在世界边缘，可能被相机裁切
#
# 依赖模块:
# - 由 WorldGenerator 实例化并设置参数
