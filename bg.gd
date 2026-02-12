extends ParallaxBackground


var speed = 40
var speedG = 55
var speedC = 20

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	
	
	var layer = get_node("ParallaxLayer2")
	layer.motion_offset.x -= speedG * delta
	
	var layer2 = get_node("ParallaxLayer3")
	layer2.motion_offset.x -= speedC * delta
	
	var layer3 = get_node("ParallaxLayer4")
	layer3.motion_offset.x -= speed * delta
