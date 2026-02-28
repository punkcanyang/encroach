extends SceneTree

func _init():
    var timer = Timer.new()
    timer.wait_time = 3.0
    timer.one_shot = true
    timer.timeout.connect(self._check_ui)
    root.add_child(timer)
    
    var world = load("res://Scenes/World.tscn").instantiate()
    root.add_child(world)
    
    timer.start() # Move start after add_child
    print("Test: Timer started")

func _check_ui():
    var world = root.get_node("World")
    var ui = world.get_node("UIManager/InspectUI")
    if ui:
        print("======== InspectUI State ========")
        print("InspectUI Node: ", ui)
        print("Visible: ", ui.visible)
        print("Modulate: ", ui.modulate)
        print("Self Modulate: ", ui.self_modulate)
        print("Z Index: ", ui.z_index)
        
        # Test fake click
        var pc = world.get_node("PlayerController")
        var cave = world.get_node("Cave")
        print("Faking click to emit signal...")
        pc.building_selected.emit(cave)
        
    else:
        print("InspectUI not found!")
        
    var timer2 = Timer.new()
    timer2.wait_time = 1.0
    timer2.one_shot = true
    timer2.timeout.connect(self._check_ui2)
    root.add_child(timer2)
    timer2.start()

func _check_ui2():
    var world = root.get_node("World")
    var ui = world.get_node("UIManager/InspectUI")
    if ui:
        print("======== After Click State ========")
        print("InspectUI Node: ", ui)
        print("Visible: ", ui.visible)
        if ui._info_panel:
            print("InfoPanel Visible: ", ui._info_panel.visible)
            print("InfoPanel Size: ", ui._info_panel.size)
            print("InfoPanel Pos: ", ui._info_panel.position)
        else:
            print("InfoPanel is null! Scripts didn't run?")
    quit()
