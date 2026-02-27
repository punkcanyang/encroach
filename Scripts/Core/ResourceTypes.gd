## ResourceTypes - 全局共享资源类型定义
##
## 职责：统一定义所有资源类型枚举与工具函数
## 所有涉及资源类型的模块（Cave, HumanAgent, Resource 等）都应引用此定义
##
## AI Context: 中央资源类型注册表，避免各模块重复定义枚举

class_name ResourceTypes


## 资源类型枚举
## FOOD=0, DIRT=1, IND_METAL=2, PREC_METAL=3
## WHY: 与 Resource.gd 中的 ResourceType 枚举序号保持一致
enum Type {
	FOOD, ## 食物
	DIRT, ## 土矿
	IND_METAL, ## 工业金属矿
	PREC_METAL ## 贵金属矿
}


## 所有资源类型的列表
## WHY: 方便遍历初始化 Dictionary、循环统计等场景
static func get_all_types() -> Array:
	return [Type.FOOD, Type.DIRT, Type.IND_METAL, Type.PREC_METAL]


## 获取资源类型的翻译键名
## WHY: 统一翻译键格式，UI 层直接用 tr(get_type_name(type)) 即可
static func get_type_name(type: int) -> String:
	match type:
		Type.FOOD: return "RESOURCE_FOOD"
		Type.DIRT: return "RESOURCE_DIRT"
		Type.IND_METAL: return "RESOURCE_IND_METAL"
		Type.PREC_METAL: return "RESOURCE_PREC_METAL"
		_: return "RESOURCE_UNKNOWN"


## 获取资源类型的 Emoji 图标
## WHY: 用于 InspectUI 和日志中快速识别资源
static func get_type_icon(type: int) -> String:
	match type:
		Type.FOOD: return "🍎"
		Type.DIRT: return "🪨"
		Type.IND_METAL: return "⚙️"
		Type.PREC_METAL: return "💎"
		_: return "❓"


## 创建一个所有类型都初始化为 0 的空字典
## WHY: 标准化存储结构，避免遗漏某种类型
static func create_empty_storage() -> Dictionary:
	var storage: Dictionary = {}
	for type in get_all_types():
		storage[type] = 0
	return storage


# [For Future AI]
# =========================
# 关键假设:
# 1. 枚举值必须与 Resource.gd 中的 ResourceType 一一对应
# 2. class_name 注册后全局可用，无需 preload
# 3. 所有资源相关模块应使用此定义而非各自重复
#
# 潜在边界情况:
# 1. 新增资源类型时需同步更新 get_all_types / get_type_name / get_type_icon
#
# 依赖模块:
# - 被 Cave, HumanAgent, ResourceManager, StatsPanel, InspectUI 引用
