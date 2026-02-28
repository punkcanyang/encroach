extends SceneTree

func _init():
    var timer = Timer.new()
    timer.wait_time = 3.0
    timer.one_shot = true
    timer.timeout.connect(self._fake_click)
    root.add_child(timer)
    
    var world = load("res://Scenes/World.tscn").instantiate()
    root.add_child(world)
    
    timer.start()

func _fake_click():
    var world = root.get_node("World")
    var cave = world.get_node("Cave")
    print("Test: Cave global_position = ", cave.global_position)
    
    var event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.position = Vector2(100, 100) # Screen pos
    event.global_position = event.position
    
    var cam = world.get_node("WorldCamera")
    # Actually we just send it via Input
    cam.position = cave.global_position # Move cam to cave directly
    
    await root.get_tree().create_timer(1.0).timeout
    
    event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    # Just mock center of screen where camera is
    event.position = cam.get_viewport_rect().size / 2.0
    Input.parse_input_event(event)
    
    await root.get_tree().create_timer(1.0).timeout
    
    var ui = world.get_node("UIManager/InspectUI")
    if ui:
        print("Test: InspectUI visible: ", ui._info_panel.visible)
        if ui._info_panel.visible:
            print("Test: InspectUI title: ", ui._title_label.text)
    else:
        print("Test: InspectUI not found at UIManager/InspectUI")
        
    quit()
