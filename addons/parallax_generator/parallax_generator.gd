@tool
extends EditorPlugin

const PARALLAX_PANEL := preload("res://addons/parallax_generator/parallax_panel.tscn")
var panel: Control

func _enter_tree() -> void:
	panel = PARALLAX_PANEL.instantiate()
	# Dock it
	add_control_to_dock(DOCK_SLOT_LEFT_BR, panel)

func _exit_tree() -> void:
	# Clean up on plugin disable
	remove_control_from_docks(panel)
	panel.queue_free()
