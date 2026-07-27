class_name FadeOverlay
extends CanvasLayer
## Full-screen fade used by RoomManager during room transitions.

@onready var color_rect: ColorRect = $ColorRect


func fade_out(duration: float = 0.4) -> void:
	color_rect.visible = true
	color_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	await tween.finished
	color_rect.visible = false
