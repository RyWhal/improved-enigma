class_name DungeonUI
extends CanvasLayer

signal tool_selected(tool: String)
signal overlay_selected(overlay: String)
signal undo_requested
signal start_requested
signal restart_requested

var resource_label: Label
var info_label: RichTextLabel
var phase_label: Label
var warnings_label: RichTextLabel
var log_label: RichTextLabel
var undo_button: Button
var start_button: Button
var restart_button: Button
var build_menu_button: MenuButton
var overlay_menu_button: MenuButton
var tool_buttons: Dictionary = {}
var overlay_buttons: Dictionary = {}
var resource_labels: Dictionary = {}
var current_tool: String = "inspect"
var current_overlay: String = "normal"

const TOOLS := [
	"inspect",
	"dig",
	"fill",
	"place_heart",
	"place_treasure",
	"place_trap",
	"place_door",
	"place_monster_den",
	"move_heart",
	"moisture_source",
	"heat_vent",
	"magic_seep",
	"seed_spore_root",
	"seed_carrion_mite",
	"respawn_boss",
	"explode_spores",
]
const OVERLAYS := ["normal", "heat", "moisture", "magic", "biomass"]

func _ready() -> void:
	_build()

func _build() -> void:
	var root := Control.new()
	root.name = "HudRoot"
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var vignette := ColorRect.new()
	vignette.name = "FogVignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.0, 0.0, 0.0, 0.16)
	root.add_child(vignette)

	var top_bar := PanelContainer.new()
	top_bar.name = "TopResourceBar"
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	top_bar.offset_left = 360
	top_bar.offset_top = 12
	top_bar.offset_right = 1120
	top_bar.offset_bottom = 52
	root.add_child(top_bar)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.025, 0.026, 0.030, 0.84)
	top_style.border_color = Color(0.24, 0.34, 0.28, 0.65)
	top_style.border_width_left = 1
	top_style.border_width_top = 1
	top_style.border_width_right = 1
	top_style.border_width_bottom = 1
	top_style.corner_radius_top_left = 8
	top_style.corner_radius_top_right = 8
	top_style.corner_radius_bottom_left = 8
	top_style.corner_radius_bottom_right = 8
	top_bar.add_theme_stylebox_override("panel", top_style)
	var resource_row := HBoxContainer.new()
	resource_row.name = "ResourceRow"
	resource_row.add_theme_constant_override("separation", 18)
	top_bar.add_child(resource_row)
	for resource_name in ["essence", "biomass", "magic", "bone", "fear", "knowledge"]:
		var label := Label.new()
		label.name = "%sResource" % resource_name.capitalize()
		label.tooltip_text = resource_name.capitalize()
		label.custom_minimum_size = Vector2(76, 0)
		resource_row.add_child(label)
		resource_labels[resource_name] = label

	var panel := PanelContainer.new()
	panel.name = "CommandPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(320, 0)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = 340
	panel.offset_bottom = 780
	root.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.026, 0.030, 0.90)
	style.border_color = Color(0.24, 0.34, 0.28, 0.75)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Dungeon Tycoon"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	phase_label = Label.new()
	phase_label.text = "Planning Phase"
	phase_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	vbox.add_child(phase_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	vbox.add_child(action_row)
	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.focus_mode = Control.FOCUS_NONE
	undo_button.pressed.connect(func() -> void: undo_requested.emit())
	action_row.add_child(undo_button)
	start_button = Button.new()
	start_button.text = "Start Dungeon"
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(func() -> void: start_requested.emit())
	action_row.add_child(start_button)
	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.disabled = true
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	action_row.add_child(restart_button)

	build_menu_button = MenuButton.new()
	build_menu_button.name = "BuildMenuButton"
	build_menu_button.text = "Build: Inspect"
	build_menu_button.focus_mode = Control.FOCUS_NONE
	vbox.add_child(build_menu_button)
	var build_popup := build_menu_button.get_popup()
	for i in range(TOOLS.size()):
		build_popup.add_item(_pretty_name(TOOLS[i]), i)
	build_popup.id_pressed.connect(func(id: int) -> void: _select_tool(TOOLS[id]))

	overlay_menu_button = MenuButton.new()
	overlay_menu_button.name = "OverlayMenuButton"
	overlay_menu_button.text = "Overlay: Normal"
	overlay_menu_button.focus_mode = Control.FOCUS_NONE
	vbox.add_child(overlay_menu_button)
	var overlay_popup := overlay_menu_button.get_popup()
	for i in range(OVERLAYS.size()):
		overlay_popup.add_item(_pretty_name(OVERLAYS[i]), i)
	overlay_popup.id_pressed.connect(func(id: int) -> void: _select_overlay(OVERLAYS[id]))

	vbox.add_child(_section_label("Inspect"))
	info_label = RichTextLabel.new()
	info_label.custom_minimum_size = Vector2(280, 260)
	info_label.fit_content = false
	info_label.bbcode_enabled = true
	info_label.text = "Select inspect, then click a tile or creature."
	vbox.add_child(info_label)

	vbox.add_child(_section_label("Warnings"))
	warnings_label = RichTextLabel.new()
	warnings_label.custom_minimum_size = Vector2(280, 92)
	warnings_label.bbcode_enabled = true
	warnings_label.text = "Place the dungeon Heart before starting."
	vbox.add_child(warnings_label)

	vbox.add_child(_section_label("Game Log"))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(280, 120)
	log_label.bbcode_enabled = true
	log_label.text = "Log initialized."
	vbox.add_child(log_label)

	var hint := Label.new()
	hint.text = "WASD pans, mouse wheel zooms. Shape conditions, then watch life adapt."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.74, 0.83, 0.76)
	vbox.add_child(hint)
	_select_tool("inspect")
	_select_overlay("normal")

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.62, 0.96, 0.68))
	label.add_theme_font_size_override("font_size", 15)
	return label

func _select_tool(tool: String) -> void:
	current_tool = tool
	for key in tool_buttons.keys():
		tool_buttons[key].button_pressed = key == tool
	if build_menu_button != null:
		build_menu_button.text = "Build: %s" % _pretty_name(tool)
	tool_selected.emit(tool)

func _select_overlay(overlay: String) -> void:
	current_overlay = overlay
	for key in overlay_buttons.keys():
		overlay_buttons[key].button_pressed = key == overlay
	if overlay_menu_button != null:
		overlay_menu_button.text = "Overlay: %s" % _pretty_name(overlay)
	overlay_selected.emit(overlay)

func bind_resources(resources: DungeonResources) -> void:
	resources.changed.connect(update_resources)
	update_resources(resources.snapshot())

func update_resources(values: Dictionary) -> void:
	var icons := {
		"essence": "E",
		"biomass": "Bio",
		"magic": "M",
		"bone": "B",
		"fear": "F",
		"knowledge": "K",
	}
	for resource_name in resource_labels.keys():
		resource_labels[resource_name].text = "%s %s" % [icons[resource_name], values.get(resource_name, 0)]

func show_tile_info(coord: Vector2i, tile: DungeonTileData, nearby_mutations: String) -> void:
	var structure_text := "none"
	if tile.structure != "":
		structure_text = tile.structure
		if tile.structure == "heart":
			structure_text += " HP %s" % tile.heart_hp
	info_label.text = "[b]Tile %s,%s[/b]\nType: %s\nStructure: %s\nTemperature: %.0f\nMoisture: %.0f\nMagic: %.0f\nDarkness: %.0f\nBiomass: %.0f\n\nLikely mutations nearby:\n%s" % [
		coord.x,
		coord.y,
		tile.tile_name(),
		structure_text,
		tile.temperature,
		tile.moisture,
		tile.magic,
		tile.darkness,
		tile.biomass,
		nearby_mutations,
	]

func show_creature_info(creature: DungeonCreature) -> void:
	info_label.text = "[b]%s[/b]\nHP: %.0f\nHunger: %.0f\nTraits: %s\nMutation pressure: %s" % [
		_pretty_name(creature.species),
		creature.hp,
		creature.hunger,
		", ".join(creature.traits),
		creature.mutation_summary(),
	]

func show_adventurer_info(adventurer: DungeonAdventurer) -> void:
	info_label.text = "[b]%s[/b]\nHP: %.0f\nNerve: %.0f\nRole: %s" % [
		_pretty_name(adventurer.role),
		adventurer.hp,
		adventurer.nerve,
		_pretty_name(adventurer.role),
	]

func show_message(message: String) -> void:
	info_label.text = message

func add_log(message: String) -> void:
	var lines: Array[String] = []
	for line in log_label.text.split("\n", false):
		lines.append(line)
	lines.push_front(message)
	while lines.size() > 8:
		lines.pop_back()
	log_label.text = "\n".join(lines)

func set_phase(phase_name: String) -> void:
	phase_label.text = phase_name
	undo_button.disabled = phase_name != "Planning Phase"
	start_button.disabled = phase_name != "Planning Phase"
	restart_button.disabled = phase_name != "Game Over"

func set_warnings(warnings: Array[String]) -> void:
	if warnings.is_empty():
		warnings_label.text = "[color=light_green]Layout warnings clear.[/color]"
	else:
		warnings_label.text = "\n".join(warnings)

func is_world_input_blocked() -> bool:
	return should_block_world_input(get_viewport().gui_get_hovered_control())

func should_block_world_input(control: Control) -> bool:
	var cursor := control
	while cursor != null:
		if cursor.name == "CommandPanel" or cursor.name == "TopResourceBar":
			return true
		cursor = cursor.get_parent() as Control
	return false

func _pretty_name(value: String) -> String:
	return value.replace("_", " ").capitalize()
