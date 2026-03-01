## ResourceDrop.gd - 遗物包裹/掉落物资
##
## 职责：代表 Agent 死亡后在原地留下的资源包裹
## 拥有和小矿脉一样的接口，允许存活的 Agent 将其作为最高优先级的采集目标来拾荒。
##

extends Node2D

## 包裹内含物资种类
var resource_type: int = 0
## 包裹内含物资数量
var amount: int = 0
## 是否已被吸干
var _is_depleted: bool = false

func _ready() -> void:
	# 加入 inspectable 组允许弹窗悬停
	# 加入 resource 组诱骗其他 Agent 将其当做野生矿脉
	add_to_group("inspectable")
	add_to_group("resource")
	z_index = 0 # 落在地上

func _draw() -> void:
	if _is_depleted: return
	
	# 画一个像小包包或者盒子的矩形
	var size = Vector2(10, 8)
	var rect = Rect2(-size / 2.0, size)
	
	var base_color: Color = Color.WHITE
	# 根据类型上色
	match resource_type:
		0: base_color = Color(0.2, 0.8, 0.2) # FOOD
		1: base_color = Color(0.55, 0.55, 0.55) # DIRT
		2: base_color = Color(0.6, 0.6, 0.8) # IND_METAL
		3: base_color = Color(0.95, 0.8, 0.2) # PREC_METAL
		
	draw_rect(rect, base_color, true)
	draw_rect(rect, Color(0.3, 0.2, 0.1), false, 1.0) # 皮质描边
	
	# 画一条束带
	draw_line(Vector2(0, -size.y / 2), Vector2(0, size.y / 2), Color.DARK_ORANGE, 1.5)

## Interface: 鸭子类型伪装野生矿脉
func is_depleted() -> bool:
	return _is_depleted

## Interface: 鸭子类型伪装野生矿脉
func collect(requested_amount: int, _collector: Node2D = null) -> int:
	if _is_depleted: return 0
	
	# 吸干机制：能拿多少拿多少
	var actual: int = min(requested_amount, amount)
	amount -= actual
	
	# 如果包裹被搬空，光速自毁
	if amount <= 0:
		_is_depleted = true
		call_deferred("queue_free")
	else:
		# 更新一下 UI 可能有挂载的信息
		queue_redraw()
		
	return actual

## 暴露给 InspectUI 的查看接口
func get_status() -> Dictionary:
	return {
		"type": ResourceTypes.get_type_name(resource_type), # 回传名字用于拼接
		"amount": amount,
		"max_amount": amount, # 把 max 当代当前值以便 ui 计算
		"depleted": _is_depleted
	}
