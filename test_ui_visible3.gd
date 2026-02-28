extends SceneTree

func _init():
    var world = load("res://Scenes/World.tscn").instantiate()
    root.add_child(world)
    
    var uim = world.get_node("UIManager")
    print("UIManager Node: ", uim)
    if uim:
        print("UIManager children: ")
        for child in uim.get_children():
            print("- ", child.name)
            
    quit()
