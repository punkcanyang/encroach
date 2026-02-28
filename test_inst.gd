extends SceneTree

func _init():
    var ui = load("res://Scenes/InspectUI.tscn")
    if ui:
        print("Test: InspectUI loaded")
        var inst = ui.instantiate()
        if inst:
            print("Test: InspectUI instanced")
            root.add_child(inst)
            print("Test: InspectUI added to tree")
        else:
            print("Test: InspectUI instantiation failed")
    else:
        print("Test: InspectUI loading failed")
    
    var timer = Timer.new()
    timer.wait_time = 0.5
    timer.one_shot = true
    timer.timeout.connect(self.quit)
    root.add_child(timer)
    timer.start()
