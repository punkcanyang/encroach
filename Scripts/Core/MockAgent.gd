## MockAgent - ECS 虛擬檢視節點
## 
## 職責：當玩家點擊畫面上的 ECS 小人時，由 PlayerController 動態生成的暫時性 Node2D。
## 裡面裝載了從 AgentManager 抽出的該小人的當下資料快照。
##
## AI Context: 這只是為了相容舊的 InspectUI (預期要接到一個有 get_status 的 Node) 所做的 Adapter。

extends Node2D

var _data: Dictionary = {}

func setup(data: Dictionary) -> void:
	_data = data
	global_position = data.get("position", Vector2.ZERO)

func get_status() -> Dictionary:
	var status: Dictionary = {}
	status["name"] = name
	status["hunger"] = _data.get("hunger", 100.0)
	status["hp"] = _data.get("hp", 0)
	status["max_hp"] = _data.get("max_hp", 0)
	status["age_years"] = _data.get("age_years", 0)
	status["age_days"] = _data.get("age_days", 0)
	
	var lf_days = _data.get("lifespan_days", 0)
	status["lifespan_years"] = int(float(lf_days) / 365.0)
	status["lifespan_days"] = lf_days
	status["alive"] = true
	status["carried"] = _data.get("carried_amount", 0)
	status["carried_type"] = _data.get("carried_type", -1)
	status["position"] = _data.get("position", Vector2.ZERO)
	
	var state_id = _data.get("state", 0)
	status["state"] = _get_state_string(state_id)
	
	return status

func _get_state_string(state: int) -> String:
	match state:
		0: return "STATE_IDLE"
		1: return "STATE_WANDERING"
		2: return "STATE_MOVING_TO_RESOURCE"
		3: return "STATE_COLLECTING"
		4: return "STATE_MOVING_TO_CAVE"
		5: return "STATE_DEPOSITING"
		6: return "STATE_CONSTRUCTING"
		_: return "STATE_UNKNOWN"

# [For Future AI]
# =========================
# 關鍵假設:
# 1. 這只是一個唯讀的 Data Container，不會被加入 SceneTree (或加了也會隨機被清理)
# 2. inspect_ui 會固定頻率 _process 呼叫這個 Node 的 get_status
# 3. 如果需要狀態實時更新，需要實作一個向 AgentManager 重新拉資料的 reference，但目前僅作為一次性快照展示
