extends Node


signal rule_triggered(rule_name: String, data: Dictionary)


@export var rules: Array[Dictionary] = []

var active_rules: Dictionary = {}


func _ready() -> void:
	load_default_rules()


func _process(_delta: float) -> void:
	evaluate_rules()


func load_default_rules() -> void:
	rules = []


func evaluate_rules() -> void:
	for rule in rules:
		if should_trigger_rule(rule):
			trigger_rule(rule)


func should_trigger_rule(rule: Dictionary) -> bool:
	if not rule.has("condition"):
		return false
	return rule["condition"].call()


func trigger_rule(rule: Dictionary) -> void:
	var rule_name = rule.get("name", "unnamed_rule")
	if active_rules.get(rule_name, false):
		return
	
	active_rules[rule_name] = true
	var data = rule.get("data", {})
	rule_triggered.emit(rule_name, data)
	
	if rule.has("action"):
		rule["action"].call(data)


func reset_rule(rule_name: String) -> void:
	active_rules[rule_name] = false


func add_rule(rule: Dictionary) -> void:
	rules.append(rule)


func remove_rule(rule_name: String) -> void:
	rules = rules.filter(func(r): return r.get("name") != rule_name)
