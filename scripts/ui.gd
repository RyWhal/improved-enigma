class_name DungeonUI
extends CanvasLayer

signal tool_selected(tool: String)
signal overlay_selected(overlay: String)
signal undo_requested
signal start_requested
signal restart_requested
signal night_pause_toggled(paused: bool)
signal den_order_requested(den_id: int, order: String)
signal research_upgrade_requested(upgrade_id: String)
signal mode_selected(mode: String)

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
var top_resource_bar: PanelContainer
var tool_rail: PanelContainer
var info_panel: PanelContainer
var start_menu: Control
var warnings_button: Button
var log_button: Button
var research_button: Button
var warnings_popup: PanelContainer
var warnings_popup_label: RichTextLabel
var log_popup: PanelContainer
var log_popup_label: RichTextLabel
var research_popup: PanelContainer
var research_popup_label: RichTextLabel
var research_upgrade_buttons: Dictionary = {}
var den_order_actions: HBoxContainer
var tool_buttons: Dictionary = {}
var overlay_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var resource_labels: Dictionary = {}
var submenu_container: HBoxContainer
var action_icon_atlas: Texture2D
var current_tool: String = "inspect"
var current_overlay: String = "normal"
var active_menu_category: String = ""
var inspected_den_id: int = -1
var warning_lines: Array[String] = []
var log_lines: Array[String] = ["Log initialized."]

const ACTION_ICON_ATLAS := "res://assets/ui/action_icons.png"
const TOOLS := [
	"inspect",
	"dig",
	"fill",
	"place_heart",
	"place_treasure",
	"place_trap",
	"place_poison_trap",
	"place_door",
	"place_locked_door",
	"place_secret_tunnel",
	"place_monster_den",
	"place_carrion_den",
	"move_heart",
	"moisture_source",
	"heat_vent",
	"magic_seep",
	"seed_spore_root",
	"seed_carrion_mite",
	"spawn_carrion_mite",
	"poison_cloud",
	"magic_field",
	"heal",
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
	"place_poison_trap": "Pz",
	"place_door": "Dr",
	"place_locked_door": "Lk",
	"place_secret_tunnel": "Sc",
	"place_monster_den": "Gb",
	"place_carrion_den": "Ca",
	"move_heart": "Mv",
	"moisture_source": "Mo",
	"heat_vent": "Ht",
	"magic_seep": "Mg",
	"seed_spore_root": "Sp",
	"seed_carrion_mite": "Sk",
	"spawn_carrion_mite": "Sk",
	"poison_cloud": "Pc",
	"magic_field": "Mf",
	"heal": "+",
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
const DISPLAY_NAMES := {
	"place_monster_den": "Goblin Den",
	"place_carrion_den": "Carrion Den",
	"spawn_carrion_mite": "Spawn Carrion Mite",
	"poison_cloud": "Poison Cloud",
	"magic_field": "Magic Field",
	"heal": "Heal",
}
const TOOL_GROUPS := [
	{"label": "Buildings", "node": "BuildingsTools", "tools": ["dig", "fill", "expand_influence", "place_treasure", "place_trap", "place_poison_trap", "place_door", "place_locked_door", "place_secret_tunnel", "moisture_source", "heat_vent", "magic_seep"]},
	{"label": "Monsters", "node": "MonstersTools", "tools": ["place_heart", "move_heart", "place_monster_den", "place_carrion_den", "seed_spore_root", "respawn_boss"]},
	{"label": "Special", "node": "SpecialTools", "tools": ["spawn_carrion_mite", "explode_spores", "poison_cloud", "magic_field", "heal"]},
]
const PRIMARY_MENU_ACTIONS := [
	{"id": "inspect", "kind": "tool", "node": "InspectPrimaryButton", "tooltip": "Inspect tiles, creatures, crawlers, and dens."},
	{"id": "buildings", "kind": "category", "node": "BuildingsMenuButton", "tooltip": "Show dungeon building and shaping tools.", "icon": "place_monster_den"},
	{"id": "monsters", "kind": "category", "node": "MonstersMenuButton", "tooltip": "Show monster and boss tools.", "icon": "seed_carrion_mite"},
	{"id": "special", "kind": "category", "node": "SpecialMenuButton", "tooltip": "Show special attacks.", "icon": "explode_spores"},
	{"id": "overlay", "kind": "category", "node": "OverlayMenuButton", "tooltip": "Show visual overlays.", "icon": "magic_seep"},
]
const ACTION_ICON_INDEX := {
	"inspect": 0,
	"dig": 1,
	"fill": 2,
	"expand_influence": 3,
	"place_heart": 4,
	"move_heart": 5,
	"place_treasure": 6,
	"place_trap": 7,
	"place_poison_trap": 8,
	"place_door": 9,
	"place_locked_door": 10,
	"place_secret_tunnel": 11,
	"place_monster_den": 12,
	"place_carrion_den": 17,
	"moisture_source": 13,
	"heat_vent": 14,
	"magic_seep": 15,
	"seed_spore_root": 16,
	"seed_carrion_mite": 17,
	"spawn_carrion_mite": 17,
	"respawn_boss": 18,
	"explode_spores": 19,
	"poison_cloud": 8,
	"magic_field": 15,
	"heal": 4,
	"guard_heart": 20,
	"guard_room": 21,
	"patrol": 22,
	"ambush_door": 23,
	"research": 24,
	"normal": 0,
	"heat": 14,
	"moisture": 13,
	"magic": 15,
	"biomass": 16,
}
const DEN_ORDER_ACTIONS := [
	{"order": "guard_heart", "label": "Heart", "node": "GuardHeartDenOrderButton", "tooltip": "Send den-born monsters to defend the dungeon Heart."},
	{"order": "guard_room", "label": "Room", "node": "GuardRoomDenOrderButton", "tooltip": "Keep den-born monsters near this room."},
	{"order": "patrol", "label": "Patrol", "node": "PatrolDenOrderButton", "tooltip": "Have den-born monsters patrol from this den."},
	{"order": "ambush_door", "label": "Door", "node": "AmbushDoorDenOrderButton", "tooltip": "Post den-born monsters near the closest room door."},
	{"order": "research", "label": "Study", "node": "ResearchDenOrderButton", "tooltip": "Turn this qualified magical room into a research den."},
]
const RESEARCH_ACTIONS := [
	{"id": "dungeon_praxis", "label": "Dungeon Praxis", "node": "DungeonPraxisResearchButton", "branch": "root", "tooltip": "Improves research and opens deeper research branches."},
	{"id": "stonecraft", "label": "Stonecraft", "node": "StonecraftResearchButton", "branch": "root", "tooltip": "Reduces tunnel digging cost."},
	{"id": "goblin_warrens", "label": "Goblin Warrens", "node": "GoblinWarrensResearchButton", "branch": "monsters", "tooltip": "Formalizes goblin den breeding and unlocks brood research."},
	{"id": "hardened_brood", "label": "Hardened Brood", "node": "HardenedBroodResearchButton", "branch": "monsters", "tooltip": "Den-born monsters gain more HP."},
	{"id": "quickened_brood", "label": "Quickened Brood", "node": "QuickenedBroodResearchButton", "branch": "monsters", "tooltip": "Den-born monsters act faster."},
	{"id": "feral_vitality", "label": "Feral Vitality", "node": "FeralVitalityResearchButton", "branch": "monsters", "tooltip": "Monsters can steal life when they hit crawlers."},
	{"id": "den_fertility", "label": "Den Fertility", "node": "DenFertilityResearchButton", "branch": "monsters", "tooltip": "Monster dens produce creatures faster."},
	{"id": "skeleton_servitors", "label": "Skeleton Servitors", "node": "SkeletonServitorsResearchButton", "branch": "monsters", "tooltip": "Unlocks skeleton-like den servants."},
	{"id": "hexbound_kin", "label": "Hexbound Kin", "node": "HexboundKinResearchButton", "branch": "spawning", "tooltip": "Unlocks arcane goblins in magic dens."},
	{"id": "ember_pact", "label": "Ember Pact", "node": "EmberPactResearchButton", "branch": "spawning", "tooltip": "Unlocks fiery den creatures."},
	{"id": "bog_brood", "label": "Bog Brood", "node": "BogBroodResearchButton", "branch": "spawning", "tooltip": "Unlocks damp biomass creatures."},
	{"id": "arcane_spawning", "label": "Arcane Spawning", "node": "ArcaneSpawningResearchButton", "branch": "spawning", "tooltip": "Magic dens unlock stronger arcane spawns."},
	{"id": "heart_pupation", "label": "Heart Pupation", "node": "HeartPupationResearchButton", "branch": "heart", "tooltip": "Allows the Heart boss larva to evolve."},
	{"id": "heart_bulk", "label": "Heart Bulk", "node": "HeartBulkResearchButton", "branch": "heart", "tooltip": "The Heart boss gains more HP."},
	{"id": "heart_violence", "label": "Heart Violence", "node": "HeartViolenceResearchButton", "branch": "heart", "tooltip": "The Heart boss hits harder."},
	{"id": "heart_dominion", "label": "Heart Dominion", "node": "HeartDominionResearchButton", "branch": "heart", "tooltip": "Deep boss evolution hook for future stages."},
	{"id": "reinforced_doors", "label": "Reinforced Doors", "node": "ReinforcedDoorsResearchButton", "branch": "defense", "tooltip": "Unlocks locked doors, then makes them tougher."},
	{"id": "poison_craft", "label": "Poison Craft", "node": "PoisonCraftResearchButton", "branch": "defense", "tooltip": "Unlocks poison traps and improves their venom."},
	{"id": "hidden_ways", "label": "Hidden Ways", "node": "HiddenWaysResearchButton", "branch": "defense", "tooltip": "Unlocks secret tunnels for monsters."},
	{"id": "claimed_spoils", "label": "Claimed Spoils", "node": "ClaimedSpoilsResearchButton", "branch": "economy", "tooltip": "Recover loot from dead crawlers."},
	{"id": "fearful_reclamation", "label": "Fearful Reclamation", "node": "FearfulReclamationResearchButton", "branch": "economy", "tooltip": "Improves crawler kill recovery."},
]
const RESEARCH_BRANCHES := [
	{"id": "root", "node": "ResearchBranchRoot", "label": "Root"},
	{"id": "monsters", "node": "ResearchBranchMonsters", "label": "Monsters"},
	{"id": "spawning", "node": "ResearchBranchSpawning", "label": "Spawn Types"},
	{"id": "heart", "node": "ResearchBranchHeart", "label": "Heart"},
	{"id": "defense", "node": "ResearchBranchDefense", "label": "Defense"},
	{"id": "economy", "node": "ResearchBranchEconomy", "label": "Economy"},
]

func _ready() -> void:
	_build()

func _build() -> void:
	tool_buttons.clear()
	overlay_buttons.clear()
	category_buttons.clear()
	resource_labels.clear()
	action_icon_atlas = _load_png_texture(ACTION_ICON_ATLAS)
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

	top_resource_bar = PanelContainer.new()
	top_resource_bar.name = "TopResourceBar"
	top_resource_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	top_resource_bar.offset_left = 112
	top_resource_bar.offset_top = 10
	top_resource_bar.offset_right = 1050
	top_resource_bar.offset_bottom = 42
	root.add_child(top_resource_bar)
	top_resource_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.026, 0.030, 0.84), Color(0.24, 0.34, 0.28, 0.65)))
	var resource_row := HBoxContainer.new()
	resource_row.name = "ResourceRow"
	resource_row.add_theme_constant_override("separation", 8)
	top_resource_bar.add_child(resource_row)

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
	tool_rail.anchor_left = 0.5
	tool_rail.anchor_top = 1.0
	tool_rail.anchor_right = 0.5
	tool_rail.anchor_bottom = 1.0
	tool_rail.offset_left = -258
	tool_rail.offset_right = 258
	tool_rail.offset_top = -104
	tool_rail.offset_bottom = -12
	tool_rail.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.026, 0.030, 0.88), Color(0.24, 0.34, 0.28, 0.72)))
	root.add_child(tool_rail)
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	tool_rail.add_child(margin)

	var rail := VBoxContainer.new()
	rail.name = "Rail"
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	rail.add_theme_constant_override("separation", 6)
	margin.add_child(rail)

	var primary_menu := HBoxContainer.new()
	primary_menu.name = "PrimaryMenu"
	primary_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	primary_menu.add_theme_constant_override("separation", 6)
	rail.add_child(primary_menu)
	for action in PRIMARY_MENU_ACTIONS:
		primary_menu.add_child(_primary_menu_button(action))

	research_button = _small_text_button("ResearchButton", "Rs", "Show research tree")
	research_button.custom_minimum_size = Vector2(42, 38)
	research_button.pressed.connect(func() -> void: _toggle_popup(research_popup))
	primary_menu.add_child(research_button)
	warnings_button = _small_text_button("WarningsButton", "!", "Show warnings")
	warnings_button.custom_minimum_size = Vector2(42, 38)
	warnings_button.pressed.connect(func() -> void: _toggle_popup(warnings_popup))
	primary_menu.add_child(warnings_button)
	log_button = _small_text_button("LogButton", "Log", "Show game log")
	log_button.custom_minimum_size = Vector2(48, 38)
	log_button.pressed.connect(func() -> void: _toggle_popup(log_popup))
	primary_menu.add_child(log_button)

	submenu_container = HBoxContainer.new()
	submenu_container.name = "ActionSubmenu"
	submenu_container.visible = false
	submenu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	submenu_container.add_theme_constant_override("separation", 5)
	rail.add_child(submenu_container)

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
	info_margin.name = "InfoMargin"
	info_margin.add_theme_constant_override("margin_left", 10)
	info_margin.add_theme_constant_override("margin_top", 8)
	info_margin.add_theme_constant_override("margin_right", 10)
	info_margin.add_theme_constant_override("margin_bottom", 8)
	info_panel.add_child(info_margin)
	var info_content := VBoxContainer.new()
	info_content.name = "InfoContent"
	info_content.add_theme_constant_override("separation", 6)
	info_margin.add_child(info_content)
	info_label = RichTextLabel.new()
	info_label.name = "InspectText"
	info_label.custom_minimum_size = Vector2(260, 112)
	info_label.fit_content = false
	info_label.bbcode_enabled = true
	info_label.text = "Select inspect, then click a tile or creature."
	info_content.add_child(info_label)
	den_order_actions = HBoxContainer.new()
	den_order_actions.name = "DenOrderActions"
	den_order_actions.visible = false
	den_order_actions.add_theme_constant_override("separation", 4)
	info_content.add_child(den_order_actions)
	for action in DEN_ORDER_ACTIONS:
		den_order_actions.add_child(_den_order_button(action))

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

	research_popup = _floating_popup("ResearchPopup", Vector2(112, 196), Vector2(620, 440))
	root.add_child(research_popup)
	var research_scroll := ScrollContainer.new()
	research_scroll.name = "ResearchScroll"
	research_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	research_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	research_scroll.custom_minimum_size = Vector2(590, 410)
	research_popup.get_node("PopupMargin").add_child(research_scroll)
	var research_content := VBoxContainer.new()
	research_content.name = "ResearchContent"
	research_content.add_theme_constant_override("separation", 6)
	research_scroll.add_child(research_content)
	research_popup_label = _popup_text("ResearchPopupText")
	research_popup_label.custom_minimum_size = Vector2(560, 70)
	research_content.add_child(research_popup_label)
	var branch_lookup := {}
	for branch in RESEARCH_BRANCHES:
		var branch_box := VBoxContainer.new()
		branch_box.name = branch["node"]
		branch_box.add_theme_constant_override("separation", 3)
		var branch_label := Label.new()
		branch_label.name = "%sLabel" % branch["node"]
		branch_label.text = String(branch["label"]).to_upper()
		branch_label.add_theme_color_override("font_color", Color(0.64, 0.95, 0.62, 0.95))
		branch_box.add_child(branch_label)
		research_content.add_child(branch_box)
		branch_lookup[branch["id"]] = branch_box
	for action in RESEARCH_ACTIONS:
		var button := _research_upgrade_button(action)
		var branch_box: VBoxContainer = branch_lookup.get(action.get("branch", "root"), research_content) as VBoxContainer
		branch_box.add_child(button)
		research_upgrade_buttons[action["id"]] = button

	_build_start_menu(root)
	set_research_state({}, 0)

	_select_tool("inspect")
	_select_overlay("normal")
	_hide_action_submenu()

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

func _build_start_menu(root: Control) -> void:
	start_menu = Control.new()
	start_menu.name = "StartMenu"
	start_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	start_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_menu.visible = false
	root.add_child(start_menu)

	var shade := ColorRect.new()
	shade.name = "Backdrop"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.68)
	start_menu.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -160
	panel.offset_right = 210
	panel.offset_bottom = 160
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.028, 0.023, 0.020, 0.96), Color(0.45, 0.66, 0.45, 0.9)))
	start_menu.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "MenuMargin"
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "MenuContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Heartwarren"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "Choose how the dungeon wakes."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.88, 0.74))
	content.add_child(subtitle)

	var standard_button := _menu_mode_button("StandardRunButton", "Standard Run", "Start the current Heartwarren mode.")
	standard_button.pressed.connect(func() -> void: mode_selected.emit("standard"))
	content.add_child(standard_button)

	var tutorial_button := _menu_mode_button("TutorialButton", "Tutorial", "Guided mode placeholder.")
	tutorial_button.pressed.connect(func() -> void: show_tutorial_placeholder())
	content.add_child(tutorial_button)

	var unlimited_button := _menu_mode_button("UnlimitedBuildButton", "Unlimited Build", "Testing mode with unlimited resources and unlocked tools.")
	unlimited_button.pressed.connect(func() -> void: mode_selected.emit("unlimited_build"))
	content.add_child(unlimited_button)

func _menu_mode_button(node_name: String, text: String, tooltip: String) -> Button:
	var button := _small_text_button(node_name, text, tooltip)
	button.custom_minimum_size = Vector2(270, 42)
	return button

func show_start_menu() -> void:
	if start_menu != null:
		start_menu.visible = true
	_set_game_controls_visible(false)

func hide_start_menu() -> void:
	if start_menu != null:
		start_menu.visible = false
	_set_game_controls_visible(true)

func show_tutorial_placeholder() -> void:
	show_message("Tutorial coming soon. For now, try Standard Run or Unlimited Build.")

func _set_game_controls_visible(visible: bool) -> void:
	for control in [top_resource_bar, tool_rail, info_panel]:
		if control != null:
			control.visible = visible
	for popup in [warnings_popup, log_popup, research_popup]:
		if popup != null:
			popup.visible = false

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

func _load_png_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _icon_texture(action_id: String) -> Texture2D:
	if action_icon_atlas == null or not ACTION_ICON_INDEX.has(action_id):
		return null
	var icon_index := int(ACTION_ICON_INDEX[action_id])
	var atlas := AtlasTexture.new()
	atlas.atlas = action_icon_atlas
	atlas.region = Rect2(Vector2((icon_index % 5) * 64, int(icon_index / 5) * 64), Vector2(64, 64))
	return atlas

func _icon_button(node_name: String, action_id: String, tooltip: String, fallback_text: String = "") -> Button:
	var button := _small_text_button(node_name, fallback_text, tooltip)
	button.custom_minimum_size = Vector2(42, 38)
	button.icon = _icon_texture(action_id)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if button.icon != null:
		button.text = ""
	return button

func _primary_menu_button(action: Dictionary) -> Button:
	var icon_id: String = String(action.get("icon", action["id"]))
	var button := _icon_button(action["node"], icon_id, action["tooltip"], _pretty_name(String(action["id"])).substr(0, 2))
	button.toggle_mode = true
	if action["kind"] == "tool":
		var tool: String = action["id"]
		button.pressed.connect(func() -> void:
			_select_tool(tool)
			_hide_action_submenu()
		)
		tool_buttons[tool] = button
	else:
		var category: String = action["id"]
		button.pressed.connect(func() -> void: _toggle_action_submenu(category))
		category_buttons[category] = button
	return button

func _tool_button(tool: String) -> Button:
	var button := _icon_button(_node_name_from_id(tool, "Tool"), tool, _pretty_name(tool), TOOL_ICONS.get(tool, "?"))
	button.toggle_mode = true
	button.pressed.connect(func() -> void: _select_tool(tool))
	tool_buttons[tool] = button
	return button

func _overlay_button(overlay: String) -> Button:
	var button := _icon_button(_node_name_from_id(overlay, "Overlay"), overlay, "%s overlay" % _pretty_name(overlay), OVERLAY_ICONS.get(overlay, "O"))
	button.toggle_mode = true
	button.pressed.connect(func() -> void: _select_overlay(overlay))
	overlay_buttons[overlay] = button
	return button

func _den_order_button(action: Dictionary) -> Button:
	var button := _small_text_button(action["node"], action["label"], action["tooltip"])
	button.custom_minimum_size = Vector2(58, 28)
	var order: String = action["order"]
	button.pressed.connect(func() -> void:
		if inspected_den_id != -1:
			den_order_requested.emit(inspected_den_id, order)
	)
	return button

func _research_upgrade_button(action: Dictionary) -> Button:
	var button := _small_text_button(action["node"], action["label"], action["tooltip"])
	button.custom_minimum_size = Vector2(170, 28)
	var upgrade_id: String = action["id"]
	button.pressed.connect(func() -> void: research_upgrade_requested.emit(upgrade_id))
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

func _toggle_action_submenu(category: String) -> void:
	if active_menu_category == category and submenu_container != null and submenu_container.visible:
		_hide_action_submenu()
		return
	_show_action_submenu(category)

func _show_action_submenu(category: String) -> void:
	if submenu_container == null:
		return
	for child in submenu_container.get_children():
		submenu_container.remove_child(child)
		child.queue_free()
	active_menu_category = category
	submenu_container.visible = true
	if tool_rail != null:
		tool_rail.offset_top = -104
	for key in category_buttons.keys():
		category_buttons[key].set_pressed_no_signal(key == category)
	var group_container := HBoxContainer.new()
	group_container.name = _submenu_node_for_category(category)
	group_container.alignment = BoxContainer.ALIGNMENT_CENTER
	group_container.add_theme_constant_override("separation", 5)
	submenu_container.add_child(group_container)
	if category == "overlay":
		for overlay in OVERLAYS:
			group_container.add_child(_overlay_button(overlay))
		return
	for group in TOOL_GROUPS:
		if String(group["label"]).to_lower() == category:
			for tool in group["tools"]:
				group_container.add_child(_tool_button(tool))
			return

func _hide_action_submenu() -> void:
	active_menu_category = ""
	if submenu_container != null:
		submenu_container.visible = false
		for child in submenu_container.get_children():
			submenu_container.remove_child(child)
			child.queue_free()
	if tool_rail != null:
		tool_rail.offset_top = -58
	for key in category_buttons.keys():
		category_buttons[key].set_pressed_no_signal(false)

func _submenu_node_for_category(category: String) -> String:
	match category:
		"buildings":
			return "BuildingsTools"
		"monsters":
			return "MonstersTools"
		"special":
			return "SpecialTools"
		"overlay":
			return "OverlayTools"
	return "ActionTools"

func _select_tool(tool: String) -> void:
	current_tool = tool
	var stale_keys: Array[String] = []
	for key in tool_buttons.keys():
		var button_value = tool_buttons[key]
		if not is_instance_valid(button_value):
			stale_keys.append(key)
			continue
		var button := button_value as Button
		if button == null:
			stale_keys.append(key)
			continue
		button.set_pressed_no_signal(key == tool)
	for key in stale_keys:
		tool_buttons.erase(key)
	if build_menu_button != null:
		build_menu_button.text = "Build: %s" % _pretty_name(tool)
	tool_selected.emit(tool)

func _select_overlay(overlay: String) -> void:
	current_overlay = overlay
	var stale_keys: Array[String] = []
	for key in overlay_buttons.keys():
		var button_value = overlay_buttons[key]
		if not is_instance_valid(button_value):
			stale_keys.append(key)
			continue
		var button := button_value as Button
		if button == null:
			stale_keys.append(key)
			continue
		button.set_pressed_no_signal(key == overlay)
	for key in stale_keys:
		overlay_buttons.erase(key)
	if overlay_menu_button != null:
		overlay_menu_button.text = "Overlay: %s" % _pretty_name(overlay)
	overlay_selected.emit(overlay)

func bind_resources(resources: DungeonResources) -> void:
	resources.changed.connect(update_resources)
	update_resources(resources.snapshot())

func update_resources(values: Dictionary) -> void:
	for resource_name in resource_labels.keys():
		resource_labels[resource_name].text = "%s %s" % [RESOURCE_ICONS[resource_name], values.get(resource_name, 0)]

func set_research_state(upgrades: Dictionary, knowledge: int, definitions: Dictionary = {}) -> void:
	if research_popup_label != null:
		research_popup_label.text = "[b]Research Tree[/b]\nAssign a qualified magical den to Study. Scholar goblins convert time into knowledge.\nKnowledge: %s" % knowledge
	for action in RESEARCH_ACTIONS:
		var upgrade_id: String = action["id"]
		var button := research_upgrade_buttons.get(upgrade_id, null) as Button
		if button == null:
			continue
		var rank := int(upgrades.get(upgrade_id, 0))
		var max_rank := 1
		var next_cost := 0
		var prereqs := {}
		if definitions.has(upgrade_id):
			var definition: Dictionary = definitions[upgrade_id]
			var costs: Array = definition.get("costs", [])
			max_rank = costs.size()
			if rank < costs.size():
				next_cost = int(costs[rank])
			prereqs = definition.get("prereqs", {})
		var locked := not _research_prereqs_met_for_ui(upgrades, prereqs)
		var complete := rank >= max_rank
		button.disabled = locked or complete
		var prefix := ""
		if complete:
			prefix = "Done "
		elif locked:
			prefix = "Locked "
		var cost_text := "" if complete or locked else " %sK" % next_cost
		button.text = "%s%s %s/%s%s" % [prefix, action["label"], rank, max_rank, cost_text]
		var prereq_text := _research_prereq_text(prereqs)
		var status_text := "Complete" if complete else ("Locked" if locked else ("Available with %s knowledge" % knowledge))
		button.tooltip_text = "%s\nStatus: %s\n%sEffect: %s" % [action["label"], status_text, prereq_text, action["tooltip"]]

func _research_prereqs_met_for_ui(upgrades: Dictionary, prereqs: Dictionary) -> bool:
	for upgrade_id in prereqs.keys():
		if int(upgrades.get(upgrade_id, 0)) < int(prereqs[upgrade_id]):
			return false
	return true

func _research_prereq_text(prereqs: Dictionary) -> String:
	if prereqs.is_empty():
		return "Requires: none\n"
	var parts: Array[String] = []
	for upgrade_id in prereqs.keys():
		parts.append("%s %s" % [_research_label_for_id(String(upgrade_id)), int(prereqs[upgrade_id])])
	return "Requires: %s\n" % ", ".join(parts)

func _research_label_for_id(upgrade_id: String) -> String:
	for action in RESEARCH_ACTIONS:
		if action["id"] == upgrade_id:
			return action["label"]
	return upgrade_id.replace("_", " ").capitalize()

func set_night_countdown(seconds: float, paused: bool, planning_phase: bool = false, dungeon_inert: bool = false, next_wave: int = 1, pressure: int = 1) -> void:
	if night_countdown_label == null or night_pause_button == null:
		return
	if dungeon_inert:
		night_countdown_label.text = "Night: inert"
		night_countdown_label.tooltip_text = "The Heart is dead and the dungeon is inert."
		night_pause_button.disabled = true
		night_pause_button.set_pressed_no_signal(false)
		night_pause_button.text = "Pause"
		return
	if planning_phase:
		night_countdown_label.text = "Night: dormant"
		night_countdown_label.tooltip_text = "Crawler waves begin after the dungeon wakes."
		night_pause_button.disabled = true
		night_pause_button.set_pressed_no_signal(false)
		night_pause_button.text = "Pause"
		return
	night_pause_button.disabled = false
	night_pause_button.set_pressed_no_signal(paused)
	night_pause_button.text = "Resume" if paused else "Pause"
	var prefix := "Paused" if paused else "in"
	night_countdown_label.text = "Wave %s %s %ss" % [next_wave, prefix, max(0, ceili(seconds))]
	night_countdown_label.tooltip_text = "Pressure %s. Higher pressure means larger, tougher crawler waves." % pressure

func show_tile_info(coord: Vector2i, tile: DungeonTileData, nearby_mutations: String, room_profile: Dictionary = {}) -> void:
	_hide_den_order_actions()
	var structure_text := "none"
	if tile.structure != "":
		structure_text = tile.structure
		if tile.structure == "heart":
			structure_text += " HP %s" % tile.heart_hp
		elif tile.structure == "monster_den":
			structure_text += " Order %s" % tile.den_order.replace("_", " ")
			_show_den_order_actions(tile.den_id, tile.den_order)
	var room_text := "Unknown"
	if not room_profile.is_empty():
		room_text = "%s (%s tiles, %s doors)" % [String(room_profile.get("label", "Chamber")), int(room_profile.get("size", 0)), int(room_profile.get("door_count", 0))]
	info_label.text = "[b]Tile %s,%s[/b]\nType: %s\nStructure: %s\nRoom: %s\nTemperature: %.0f\nMoisture: %.0f\nMagic: %.0f\nDarkness: %.0f\nBiomass: %.0f\n\nLikely mutations nearby:\n%s" % [
		coord.x,
		coord.y,
		tile.tile_name(),
		structure_text,
		room_text,
		tile.temperature,
		tile.moisture,
		tile.magic,
		tile.darkness,
		tile.biomass,
		nearby_mutations,
	]

func show_creature_info(creature: DungeonCreature) -> void:
	_hide_den_order_actions()
	var order_text := "none"
	if creature.den_order != "":
		order_text = "%s -> %s,%s" % [creature.den_order.replace("_", " "), creature.command_target.x, creature.command_target.y]
	var target_text := "none"
	if creature.command_target != Vector2i(-1, -1):
		target_text = "%s,%s" % [creature.command_target.x, creature.command_target.y]
	info_label.text = "[b]%s[/b]\nHP: %.0f\nAttack: %.1f\nStatus: %s\nTraits: %s\nOrder: %s\nTarget: %s\nMutation pressure: %s" % [
		_pretty_name(creature.species),
		creature.hp,
		creature.attack_damage(),
		creature.status_summary(),
		", ".join(creature.traits),
		order_text,
		target_text,
		creature.mutation_summary(),
	]

func show_adventurer_info(adventurer: DungeonAdventurer) -> void:
	_hide_den_order_actions()
	info_label.text = "[b]%s[/b]\nHP: %.0f\nAttack: %.1f\nHeart Damage: %.0f\nNerve: %.0f\nRole: %s\nIntent: %s\nStatus: %s\nTarget: %s,%s" % [
		_pretty_name(adventurer.role),
		adventurer.hp,
		adventurer.attack_damage(),
		adventurer.heart_damage(),
		adventurer.nerve,
		_pretty_name(adventurer.role),
		adventurer.intent_summary(),
		adventurer.status_summary(),
		adventurer.target.x,
		adventurer.target.y,
	]

func show_message(message: String) -> void:
	_hide_den_order_actions()
	info_label.text = message

func _show_den_order_actions(den_id: int, current_order: String) -> void:
	inspected_den_id = den_id
	if den_order_actions == null:
		return
	den_order_actions.visible = true
	for child in den_order_actions.get_children():
		var button := child as Button
		if button == null:
			continue
		button.disabled = false
		for action in DEN_ORDER_ACTIONS:
			if action["node"] == button.name:
				button.disabled = action["order"] == current_order
				break

func _hide_den_order_actions() -> void:
	inspected_den_id = -1
	if den_order_actions != null:
		den_order_actions.visible = false

func add_log(message: String) -> void:
	log_lines.push_front(message)
	while log_lines.size() > 30:
		log_lines.pop_back()
	_update_log_popup()

func set_phase(phase_name: String) -> void:
	phase_label.text = phase_name
	var can_plan := phase_name in ["Planning Phase", "Unlimited Build"]
	undo_button.disabled = not can_plan
	start_button.disabled = not can_plan
	restart_button.disabled = phase_name != "Game Over"

func set_warnings(warnings: Array[String]) -> void:
	warning_lines = warnings.duplicate()
	_update_warning_popup()

func is_world_input_blocked() -> bool:
	return should_block_world_input(get_viewport().gui_get_hovered_control())

func should_block_world_input(control: Control) -> bool:
	var cursor := control
	while cursor != null:
		if cursor.name in ["TopResourceBar", "ToolRail", "InfoPanel", "WarningsPopup", "LogPopup", "StartMenu"]:
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
	if DISPLAY_NAMES.has(value):
		return DISPLAY_NAMES[value]
	return value.replace("_", " ").capitalize()
