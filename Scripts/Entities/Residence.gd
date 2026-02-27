## Residence - 住所建筑实体
##
## 职责：一种提供基础人口上限和仓储上限的建筑。
## 根据 building_type 的不同，渲染为木屋、石屋或现代大楼。
##
## AI Context: 继承自 Building。使用 Duck Typing 提供扩展上限的信息。

extends "res://Scripts/Entities/Building.gd"


func _ready() -> void:
	# 确保加入通用建筑组
	super._ready()


func _draw() -> void:
	var size = get_size()
	var rect = Rect2(-size / 2.0, size)
	
	if is_blueprint:
		super._draw()
		return
		
	# 根据类型分发绘制逻辑
	match building_type:
		1: # WOODEN_HUT
			_draw_wooden_hut(rect, size)
		2: # STONE_HOUSE
			_draw_stone_house(rect, size)
		3: # RESIDENCE_BUILDING
			_draw_residence_building(rect, size)
		_:
			# Fallback
			draw_rect(rect, Color.GRAY, true)
			draw_rect(rect, Color.WHITE, false, 2.0)


func _draw_wooden_hut(rect: Rect2, size: Vector2) -> void:
	var wood_color = Color(0.5, 0.35, 0.2)
	var roof_color = Color(0.4, 0.25, 0.1)
	
	# 主体
	draw_rect(rect, wood_color, true)
	
	# 木板条纹
	for i in range(1, 5):
		var y = rect.position.y + size.y * i / 5.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + size.x, y), roof_color, 2.0)
		
	# 屋顶(人字形)
	var roof_points = PackedVector2Array([
		Vector2(-size.x / 2 - 5, -size.y / 2),
		Vector2(0, -size.y / 2 - size.y * 0.4),
		Vector2(size.x / 2 + 5, -size.y / 2)
	])
	draw_polygon(roof_points, PackedColorArray([roof_color]))
	
	# 门
	draw_rect(Rect2(-size.x * 0.15, size.y / 2 - size.y * 0.35, size.x * 0.3, size.y * 0.35), Color(0.2, 0.1, 0.05), true)


func _draw_stone_house(rect: Rect2, size: Vector2) -> void:
	var stone_color = Color(0.55, 0.55, 0.55)
	var mortar_color = Color(0.4, 0.4, 0.4)
	
	# 主体
	draw_rect(rect, stone_color, true)
	
	# 石砖缝隙网格
	for i in range(1, 4):
		var y = rect.position.y + size.y * i / 4.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + size.x, y), mortar_color, 2.0)
	for i in range(1, 4):
		var x = rect.position.x + size.x * i / 4.0
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + size.y), mortar_color, 2.0)
		
	# 平顶带雉堞
	for i in range(5):
		var w = size.x / 5.0
		if i % 2 == 0:
			draw_rect(Rect2(rect.position.x + w * i, -size.y / 2 - 10, w, 10), stone_color, true)


func _draw_residence_building(rect: Rect2, size: Vector2) -> void:
	var base_color = Color(0.8, 0.85, 0.9) # 现代大楼浅灰白
	var window_color = Color(0.2, 0.6, 0.9, 0.8) # 蓝色玻璃
	
	# 主体
	draw_rect(rect, base_color, true)
	draw_rect(rect, Color(0.4, 0.4, 0.5), false, 2.0)
	
	# 网格玻璃窗
	var rows = 4
	var cols = 3
	var w_width = size.x * 0.2
	var w_height = size.y * 0.15
	
	for r in range(rows):
		for c in range(cols):
			var wx = rect.position.x + size.x * 0.15 + c * (size.x * 0.27)
			var wy = rect.position.y + size.y * 0.1 + r * (size.y * 0.2)
			draw_rect(Rect2(wx, wy, w_width, w_height), window_color, true)


## 扩展状态获取，显示给 UI
func get_status() -> Dictionary:
	var status = super.get_status()
	
	var manager = get_node_or_null("/root/World/BuildingManager")
	if manager != null and manager.has_method("get_building_data"):
		var data = manager.get_building_data(building_type)
		status["bonus_pop"] = data.get("pop_cap", 0)
		status["bonus_storage"] = data.get("storage_cap", 0)
		
	return status
