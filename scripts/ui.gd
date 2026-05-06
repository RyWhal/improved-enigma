class_name DungeonUI
extends CanvasLayer

signal tool_selected(tool: String)
signal overlay_selected(overlay: String)
signal undo_requested
signal start_requested
signal restart_requested
signal night_pause_toggled(paused: bool)

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
var night_countdown_label: Label
var night_pause_button: Button
var tool_rail: PanelContainer
var info_panel: PanelContainer
var warnings_button: Button
var log_button: Button
var warnings_popup: PanelContainer
var warnings_popup_label: RichTextLabel
var log_popup: PanelContainer
var log_popup_label: RichTextLabel
var tool_buttons: Dictionary = {}
var overlay_buttons: Dictionary = {}
var resource_labels: Dictionary = {}
var current_tool: String = "inspect"
var current_overlay: String = "normal"
var warning_lines: Array[String] = []
var log_lines: Array[String] = ["Log initialized."]

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
	"expand_influence",
]
const OVERLAYS := ["normal", "heat", "moisture", "magic", "biomass"]
const RESOURCE_ICONS := {
	"essence": "E",
	"biomass": "Bio",
	"magic": "M",
	"bone": "B",
	"fear": "F",
	"knowledge": "K",
}
const TOOL_ICONS := {
	"inspect": "?",
	"dig": "D",
	"fill": "F",
	"place_heart": "H",
	"place_treasure": "Tr",
	"place_trap": "^",
	"place_door": "Dr",
	"place_monster_den": "Den",
	"move_heart": "Mv",
	"moisture_source": "Mo",
	"heat_vent": "Ht",
	"magic_seep": "Mg",
	"seed_spore_root": "Sp",
	"seed_carrion_mite": "Sk",
	"respawn_boss": "Bo",
	"explode_spores": "Ex",
	"expand_influence": "+",
}
const OVERLAY_ICONS := {
	"normal": "N",
	"heat": "Ht",
	"moisture": "Mo",
	"magic": "Mg",
	"biomass": "Bio",
}
const TOOL_GROUPS := [
	{"label": "Core", "node": "CoreTools", "tools": ["inspect", "dig", "fill", "expand_influence"]},
	{"label": "Buildings", "node": "BuildingsTools", "tools": ["place_heart", "move_heart", "place_treasure", "place_trap", "place_door", "place_monster_den", "moisture_source", "heat_vent", "magic_seep"]},
	{"label": "Monsters", "node": "MonstersTools", "tools": ["seed_spore_root", "seed_carrion_mite", "respawn_boss"]},
	{"label": "Special", "node": "SpecialTools", "tools": ["explode_spores"]},
]

func _ready() -> void:
	_build()

func _build() -> void:
	tool_buttons.clear()
	overlay_buttons.clear()
	resource_labels.clear()
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
	top_bar.offset_left = 112
	top_bar.offset_top = 10
	top_bar.offset_right = 1050
	top_bar.offset_bottom = 42
	root.add_child(top_bar)
	top_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.026, 0.030, 0.84), Color(0.24, 0.34, 0.28, 0.65)))
	var resource_row := HBoxContainer.new()
	resource_row.name = "ResourceRow"
	resource_row.add_theme_constant_override("separation", 8)
	top_bar.add_child(resource_row)

	phase_label = Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = "Planning Phase"
	phase_label.tooltip_text = "Current dungeon phase"
	phase_label.custom_minimum_size = Vector2(104, 0)
	phase_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	resource_row.add_child(phase_label)

	for resource_name in ["essence", "biomass", "magic", "bone", "fear", "knowledge"]:
		var label := Label.new()
		label.name = "%sResource" % resource_name.capitalize()
		label.tooltip_text = resource_name.capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(54, 0)
		resource_row.add_child(label)
		resource_labels[resource_name] = label
	night_countdown_label = Label.new()
	night_countdown_label.name = "NightCountdown"
	night_countdown_label.tooltip_text = "Time until the next crawler incursion."
	night_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	night_countdown_label.custom_minimum_size = Vector2(104, 0)
	resource_row.add_child(night_countdown_label)
	night_pause_button = Button.new()
	night_pause_button.name = "NightPauseButton"
	night_pause_button.text = "Pause"
	night_pause_button.tooltip_text = "Pause or resume the next crawler incursion countdown."
	night_pause_button.custom_minimum_size = Vector2(64, 0)
	night_pause_button.focus_mode = Control.FOCUS_NONE
	night_pause_button.toggle_mode = true
	night_pause_button.pressed.connect(func() -> void: night_pause_toggled.emit(night_pause_button.button_pressed))
	resource_row.add_child(night_pause_button)

	undo_button = _small_text_button("UndoButton", "U", "Undo planning action")
	undo_button.pressed.connect(func() -> void: undo_requested.emit())
	resource_row.add_child(undo_button)
	start_button = _small_text_button("StartButton", "Go", "Start dungeon")
	start_button.pressed.connect(func() -> void: start_requested.emit())
	resource_row.add_child(start_button)
	restart_button = _small_text_button("RestartButton", "R", "Restart after game over")
	restart_button.disabled = true
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	resource_row.add_child(restart_button)

	tool_rail = PanelContainer.new()
	tool_rail.name = "ToolRail"
	tool_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	tool_rail.offset_left = 10
	tool_rail.offset_top = 54
	tool_rail.offset_right = 102
	tool_rail.anchor_bottom = 1.0
	tool_rail.offset_bottom = -12
	tool_rail.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.026, 0.030, 0.88), Color(0.24, 0.34, 0.28, 0.72)))
	root.add_child(tool_rail)
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	tool_rail.add_child(margin)

	var rail := VBoxContainer.new()
	rail.name = "Rail"
	rail.add_theme_constant_override("separation", 5)
	margin.add_child(rail)

	for group in TOOL_GROUPS:
		rail.add_child(_rail_label(group["label"]))
		var tool_grid := GridContainer.new()
		tool_grid.name = group["node"]
		tool_grid.columns = 2
		tool_grid.add_theme_constant_override("h_separation", 4)
		tool_grid.add_theme_constant_override("v_separation", 4)
		rail.add_child(tool_grid)
		for tool in group["tools"]:
			tool_grid.add_child(_tool_button(tool))

	rail.add_child(_rail_label("Overlay"))
	var overlay_grid := GridContainer.new()
	overlay_grid.name = "OverlayTools"
	overlay_grid.columns = 2
	overlay_grid.add_theme_constant_override("h_separation", 4)
	overlay_grid.add_theme_constant_override("v_separation", 4)
	rail.add_child(overlay_grid)
	for overlay in OVERLAYS:
		overlay_grid.add_child(_overlay_button(overlay))

	warnings_button = _small_text_button("WarningsButton", "!", "Show warnings")
	warnings_button.pressed.connect(func() -> void: _toggle_popup(warnings_popup))
	rail.add_child(warnings_button)
	log_button = _small_text_button("LogButton", "Log", "Show game log")
	log_button.pressed.connect(func() -> void: _toggle_popup(log_popup))
	rail.add_child(log_button)

	info_panel = PanelContainer.new()
	info_panel.name = "InfoPanel"
	info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	info_panel.offset_left = 112
	info_panel.offset_top = 52
	info_panel.offset_right = 392
	info_panel.offset_bottom = 186
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.026, 0.030, 0.82), Color(0.24, 0.34, 0.28, 0.56)))
	root.add_child(info_panel)
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 10)
	info_margin.add_theme_constant_override("margin_top", 8)
	info_margin.add_theme_constant_override("margin_right", 10)
	info_margin.add_theme_constant_override("margin_bottom", 8)
	info_panel.add_child(info_margin)
	info_label = RichTextLabel.new()
	info_label.name = "InspectText"
	info_label.custom_minimum_size = Vector2(260, 112)
	info_label.fit_content = false
	info_label.bbcode_enabled = true
	info_label.text = "Select inspect, then click a tile or creature."
	info_margin.add_child(info_label)

	warnings_popup = _floating_popup("WarningsPopup", Vector2(112, 196), Vector2(360, 190))
	root.add_child(warnings_popup)
	warnings_popup_label = _popup_text("WarningsPopupText")
	warnings_label = warnings_popup_label
	warnings_popup.get_node("PopupMargin").add_child(warnings_popup_label)
	set_warnings(["Place the dungeon Heart before starting."])

	log_popup = _floating_popup("LogPopup", Vector2(112, 396), Vector2(420, 260))
	root.add_child(log_popup)
	log_popup_label = _popup_text("LogPopupText")
	log_label = log_popup_label
	log_popup.get_node("PopupMargin").add_child(log_popup_label)
	_update_log_popup()

	_select_tool("inspect")
	_select_overlay("normal")

func _panel_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _rail_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.62, 0.96, 0.68))
	label.add_theme_font_size_override("font_size", 10)
	return label

func _small_text_button(node_name: String, text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(34, 30)
	return button

func _tool_button(tool: String) -> Button:
	var button := _small_text_button(_node_name_from_id(tool, "Tool"), TOOL_ICONS.get(tool, "?"), _pretty_name(tool))
	button.toggle_mode = true
	button.pressed.connect(func() -> void: _select_tool(tool))
	tool_buttons[tool] = button
	return button

func _overlay_button(overlay: String) -> Button:
	var button := _small_text_button(_node_name_from_id(overlay, "Overlay"), OVERLAY_ICONS.get(overlay, "O"), "%s overlay" % _pretty_name(overlay))
	button.toggle_mode = true
	button.pressed.connect(func() -> void: _select_overlay(overlay))
	overlay_buttons[overlay] = button
	return button

func _floating_popup(node_name: String, position: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel.offset_left = position.x
	panel.offset_top = position.y
	panel.offset_right = position.x + size.x
	panel.offset_bottom = position.y + size.y
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.026, 0.030, 0.94), Color(0.38, 0.50, 0.42, 0.88)))
	var margin := MarginContainer.new()
	margin.name = "PopupMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	return panel

func _popup_text(node_name: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = node_name
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = true
	label.custom_minimum_size = Vector2(320, 160)
	return label

func _node_name_from_id(value: String, suffix: String) -> String:
	var parts := value.split("_", false)
	var result := ""
	for part in parts:
		result += part.capitalize()
	return "%s%s" % [result, suffix]

func _toggle_popup(panel: Control) -> void:
	if panel == null:
		return
	panel.visible = not panel.visible

func _select_tool(tool: String) -> void:
	current_tool = tool
	for key in tool_buttons.keys():
		tool_buttons[key].set_pressed_no_signal(key == tool)
	if build_menu_button != null:
		build_menu_button.text = "Build: %s" % _pretty_name(tool)
	tool_selected.emit(tool)

func _select_overlay(overlay: String) -> void:
	current_overlay = overlay
	for key in overlay_buttons.keys():
		overlay_buttons[key].set_pressed_no_signal(key == overlay)
	if overlay_menu_button != null:
		overlay_menu_button.text = "Overlay: %s" % _pretty_name(overlay)
	overlay_selected.emit(overlay)

func bind_resources(resources: DungeonResources) -> void:
	resources.changed.connect(update_resources)
	update_resources(resources.snapshot())

func update_resources(values: Dictionary) -> void:
	for resource_name in resource_labels.keys():
		resource_labels[resource_name].text = "%s %s" % [RESOURCE_ICONS[resource_name], values.get(resource_name, 0)]

func set_night_countdown(seconds: float, paused: bool, planning_phase: bool = false, dungeon_inert: bool = false) -> void:
	if night_countdown_label == null or night_pause_button == null:
		return
	if dungeon_inert:
		night_countdown_label.text = "Night: inert"
		night_pause_button.disabled = true
		night_pause_button.set_pressed_no_signal(false)
		night_pause_button.text = "Pause"
		return
	if planning_phase:
		night_countdown_label.text = "Night: dormant"
		night_pause_button.disabled = true
		night_pause_button.set_pressed_no_signal(false)
		night_pause_button.text = "Pause"
		return
	night_pause_button.disabled = false
	night_pause_button.set_pressed_no_signal(paused)
	night_pause_button.text = "Resume" if paused else "Pause"
	var prefix := "Paused" if paused else "Night in"
	night_countdown_label.text = "%s %ss" % [prefix, max(0, ceili(seconds))]

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
	log_lines.push_front(message)
	while log_lines.size() > 30:
		log_lines.pop_back()
	_update_log_popup()

func set_phase(phase_name: String) -> void:
	phase_label.text = phase_name
	undo_button.disabled = phase_name != "Planning Phase"
	start_button.disabled = phase_name != "Planning Phase"
	restart_button.disabled = phase_name != "Game Over"

func set_warnings(warnings: Array[String]) -> void:
	warning_lines = warnings.duplicate()
	_update_warning_popup()

func is_world_input_blocked() -> bool:
	return should_block_world_input(get_viewport().gui_get_hovered_control())

func should_block_world_input(control: Control) -> bool:
	var cursor := control
	while cursor != null:
		if cursor.name in ["TopResourceBar", "ToolRail", "InfoPanel", "WarningsPopup", "LogPopup"]:
			return true
		cursor = cursor.get_parent() as Control
	return false

func _update_warning_popup() -> void:
	if warnings_label == null:
		return
	if warning_lines.is_empty():
		warnings_label.text = "[color=light_green]Layout warnings clear.[/color]"
		if warnings_button != null:
			warnings_button.text = "OK"
			warnings_button.tooltip_text = "Warnings: clear"
	else:
		warnings_label.text = "\n".join(warning_lines)
		if warnings_button != null:
			warnings_button.text = "! %s" % warning_lines.size()
			warnings_button.tooltip_text = "Warnings: %s" % warning_lines[0]

func _update_log_popup() -> void:
	if log_label == null:
		return
	log_label.text = "\n".join(log_lines)
	if log_button != null and not log_lines.is_empty():
		log_button.tooltip_text = "Game log: %s" % log_lines[0]

func _pretty_name(value: String) -> String:
	return value.replace("_", " ").capitalize()
