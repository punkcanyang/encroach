extends SceneTree
func _init():
    var timer = Timer.new()
    timer.wait_time = 2.0
    timer.one_shot = true
    timer.timeout.connect(self._fake_click)
    root.add_child(timer)
    timer.start()

func _fake_click():
    var event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.global_position = Vector2(100, 100) # Whatever
    Input.parse_input_event(event)

    await root.get_tree().create_timer(1.0).timeout
    quit()
