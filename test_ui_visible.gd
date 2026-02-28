extends SceneTree

func _init():
    var timer = Timer.new()
    timer.wait_time = 3.0
    timer.one_shot = true
    timer.timeout.connect(self._check_ui)
    root.add_child(timer)
    
    var world = load("res://Scenes/World.tscn").instantiate()
    root.add_child(world)
    
    timer.start()

func _check_ui():
    var world = root.get_node("World")
    var ui = world.get_node("UIManager/InspectUI")
    if ui:
        print("InspectUI Node: ", ui)
        print("Visible: ", ui.visible)
        print("Modulate: ", ui.modulate)
        print("Self Modulate: ", ui.self_modulate)
        print("Z Index: ", ui.z_index)
        if ui._info_panel:
            print("InfoPanel Visible: ", ui._info_panel.visible)
            print("InfoPanel Size: ", ui._info_panel.size)
            print("InfoPanel Pos: ", ui._info_panel.position)
        else:
            print("InfoPanel is null! Scripts didn't run?")
    else:
        print("InspectUI not found!")
    quit()
