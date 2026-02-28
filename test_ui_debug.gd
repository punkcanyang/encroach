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
    
    var pc = world.get_node("PlayerController")
    pc.building_selected.emit(cave)
    
    print("Test3: Clicked cave emitted")
    await root.get_tree().create_timer(1.0).timeout
    quit()
