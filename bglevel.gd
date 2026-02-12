extends ParallaxBackground


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


var speedG = 20
func _process(delta):
	
	
	
	var layer = get_node("ParallaxLayer2")
	layer.motion_offset.x -= speedG * delta
