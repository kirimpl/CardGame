extends Node

enum Starter { PLAYER, ENEMY }

@export var starter: Starter = Starter.PLAYER
@export_file("*.tscn") var return_scene: String = "res://level.tscn"
@export var spawn_pos: Vector2 = Vector2.ZERO
