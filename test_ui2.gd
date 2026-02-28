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
    
    var cam = world.get_node("WorldCamera")
    cam.position = cave.global_position
    
    await root.get_tree().create_timer(1.0).timeout
    
    # 派发点击事件给 PlayerController
    var pc = world.get_node("PlayerController")
    pc._try_select_object() # 强制调用选择代码看看信号有没有通
    
    await root.get_tree().create_timer(0.5).timeout
    
    var ui = world.get_node("UIManager/InspectUI")
    if ui:
        print("Test2: InspectUI visible: ", ui._info_panel.visible)
        if ui._info_panel.visible:
            print("Test2: InspectUI title: ", ui._title_label.text)
    else:
        print("Test2: InspectUI not found")
        
    quit()
