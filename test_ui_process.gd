extends SceneTree

func _init():
    var timer = Timer.new()
    timer.wait_time = 2.0
    timer.one_shot = true
    timer.timeout.connect(self._check_tree)
    root.add_child(timer)
    
    var world = load("res://Scenes/World.tscn").instantiate()
    root.add_child(world)
    timer.start()

func _check_tree():
    var ui = root.get_node("World/UIManager/InspectUI")
    if ui:
        print("Test: InspectUI process_mode = ", ui.process_mode)
        print("Test: Is processing? ", ui.is_processing())
        print("Test: Is visible in tree? ", ui.is_visible_in_tree())
        var p = ui.get_parent()
        print("Test: Parent (UIManager) process_mode = ", p.process_mode)
    quit()
