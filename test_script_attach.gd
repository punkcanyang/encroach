extends SceneTree

func _init():
    var ui_scene = load("res://Scenes/InspectUI.tscn")
    var ui = ui_scene.instantiate()
    print("Does InspectUI have a script? ", ui.get_script())
    quit()
