@tool
extends EditorPlugin

const PARALLAX_PANEL := preload("res://addons/parallax_generator/parallax_panel.tscn")
# It's good practice to use a unique prefix for your project settings
const SETTING_STYLE_PATH = "plugins/parallax_generator/active_style_path"

var panel: Control

func _enter_tree() -> void:
	panel = PARALLAX_PANEL.instantiate()
	
	# --- CORRECTED: Use the ProjectSettings global singleton ---
	if ProjectSettings.has_setting(SETTING_STYLE_PATH):
		var path = ProjectSettings.get_setting(SETTING_STYLE_PATH, "")
		if not path.is_empty() and ResourceLoader.exists(path):
			var loaded_style = load(path)
			panel.set_style_picker_resource(loaded_style)

	# Wait for the panel's UI to be created before connecting to it.
	panel.ready.connect(_on_panel_ready)

	add_control_to_dock(DOCK_SLOT_LEFT_BR, panel)

func _exit_tree() -> void:
	if is_instance_valid(panel):
		remove_control_from_docks(panel)
		panel.queue_free()

func _on_panel_ready() -> void:
	# This part remains the same
	var style_picker = panel.get("style_picker")
	if style_picker:
		style_picker.resource_changed.connect(_on_panel_style_changed)

func _on_panel_style_changed(resource: Resource) -> void:
	# --- CORRECTED: Use set_setting with a null value to "erase" ---
	if resource and resource.resource_path:
		ProjectSettings.set_setting(SETTING_STYLE_PATH, resource.resource_path)
	else:
		# Setting the value to null is the correct way to remove it.
		ProjectSettings.set_setting(SETTING_STYLE_PATH, null)

	# --- CRITICAL STEP: Save the project settings file ---
	# Changes are not written to disk until you call save()
	ProjectSettings.save()
