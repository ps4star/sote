package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:mem"
import "core:time"
import "core:os"
import "core:slice"

import rl "vendor:raylib"

GameScene :: enum {
	Blank, // For transitions
	MainMenu,
	World,
	Battle,

	WorldSelect,
	Settings,
}

PartyMenuLayer :: enum {
	Base,
		Create,
			Craft,
			Dismantle,
		SkillTree,
			SkillTreeTerry,
			SkillTreeViola,
			SkillTreeDex,
		Equip,
		Items,
			Battle,
			Components,
			Chemicals,
			KeyItems,
}
PartyMenuLayerStringNames := [PartyMenuLayer]string{
	.Base = "",
	.Create = "UI_PARTYMENU_CREATE",
		.Craft = "UI_PARTYMENU_CRAFT",
		.Dismantle = "UI_PARTYMENU_DISMANTLE",
	.SkillTree = "UI_PARTYMENU_SKILLTREE",
		.SkillTreeTerry = "UI_TERRY",
		.SkillTreeViola = "UI_VIOLA",
		.SkillTreeDex = "UI_DEX",
	.Equip = "UI_PARTYMENU_EQUIP",
	.Items = "UI_PARTYMENU_ITEMS",
		.Battle = "UI_PARTYMENU_BATTLE",
		.Components = "UI_PARTYMENU_COMPONENTS",
		.Chemicals = "UI_PARTYMENU_CHEMICALS",
		.KeyItems = "UI_PARTYMENU_KEYITEMS",
}

Animation :: struct {
	active: bool,
	deltas: f32,
	direction: f32,
	user: rawptr,
}

SerializableUprefsData :: struct { // @FullyImmediateData
	lang: [2]u8,

	target_fps: i32,
	window_maximized: bool,
	window_fullscreen: bool,

	bindings: KeyBindings,

	vsync: bool,
}
UPREFS_FILE :: "uprefs"

KEYBIND_INPUT_NIL :: KeybindInput{{key = -1}, {key = -1}, {key = -1}, {key = -1}}
DEFAULT_UPREFS := SerializableUprefsData{
	lang = { 'e', 'n' },

	target_fps = 60,
	window_maximized = true,
	window_fullscreen = false,
	vsync = true,

	bindings = #partial KeyBindings{
		.PtrMove = {
			{{.MouseMovement, 1, .Down}, {key = -1}, {key = -1}, {key = -1}},
			{{.ControllerQuad, controller_quad_to_int(.LeftStickMotion), .InQuad}, {key = -1}, {key = -1}, {key = -1}},
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,

			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
		},
		.Confirm = {
			{{.Key, key_to_int(.C), .Down}, {key = -1}, {key = -1}, {key = -1}},
			{{.Key, key_to_int(.ENTER), .Down}, {key = -1}, {key = -1}, {key = -1}},
			{{.MouseButton, mouse_button_to_int(.LEFT), .Down}, {key = -1}, {key = -1}, {key = -1}},
			{{.ControllerButton, controller_button_to_int(.RIGHT_FACE_DOWN), .Down}, {key = -1}, {key = -1}, {key = -1}},

			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
		},
		.MoveDown = {
			{{.Key, key_to_int(.A), .Down}, {key = -1}, {key = -1}, {key = -1}},
			{{.ControllerButton, controller_button_to_int(.LEFT_FACE_DOWN), .Down}, {key = -1}, {key = -1}, {key = -1}},
			{{.ControllerQuad, controller_quad_to_int(.LeftStickDown), .InQuad}, {key = -1}, {key = -1}, {key = -1}},
			KEYBIND_INPUT_NIL,

			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
		},
		.Menu = {
			{{.Key, key_to_int(.E), .Down}, {key = -1}, {key = -1}, {key = -1}},
			{{.ControllerButton, controller_button_to_int(.RIGHT_FACE_UP), .Down}, {key = -1}, {key = -1}, {key = -1}},
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,

			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
			KEYBIND_INPUT_NIL,
		},
	},
}

SerializableSaveFileData :: struct { // @FullyImmediateData
	party: [3]PartyMember,
	menu_unlocks: [PartyMenuLayer]b8,
}
PARTY_INDEX_TERRY :: 0
PARTY_INDEX_VIOLA :: 1
PARTY_INDEX_DEX :: 2

FontWrapper :: struct { font: rl.Font, size, spacing: f32 }

Asset :: struct {
	rl_tex: rl.Texture2D,
}
Game :: struct {
	assets: [enum {
		CursorAtlas,
	}]Asset,

	scene: GameScene,
	clear_alpha: u8, // @Default(255) - used for blend effects

	controllers: [dynamic]Controller,
	
	ftime_start, ftime_end: time.Time,
	time_delta: time.Duration,
	delta: f32,

	sw_i32, sh_i32: i32,
	sw, sh, half_sw, half_sh: int,
	sw_f32, sh_f32, half_sw_f32, half_sh_f32: f32,

	mouse_x, mouse_y: f32,
	mouse_v2, mouse_delta_v2: FVector2,
	mouse_cursor, mouse_cursor_last: rl.MouseCursor,

	party_menu_layers: [dynamic]PartyMenuLayer,
	animation_system: map[string]Animation,

	wh_rngs: [enum { Throwaway }]WHRngState,

	// Fonts
	font_std16, font_std24, font_std32: FontWrapper,

	// Saved (uprefs) data
	using uprefs: SerializableUprefsData,

	// Saved (per-game) data
	using save: SerializableSaveFileData,
}

@private g: ^Game = nil

// Log
LogLevel :: enum { Note, Warn, Debug, Fatal, }
LOG_FILE :: "log.txt"
@private g_log_file_hnd: IOHandle
log :: proc(level: LogLevel, str: string) {
	switch level {
	case .Debug:
		when !DEBUG {
			return
		}
		fmt.println(str)
		io_write_string(g_log_file_hnd, str)
	case .Note, .Warn:
		// Matches here if .Debug level when DEBUG is false
		io_write_string(g_log_file_hnd, str)
	case .Fatal:
		fmt.println(str)
		io_write_string(g_log_file_hnd, str)
		log_shutdown()
		panic("")
	}
}
log_assert :: #force_inline proc(cond: $T, str: string) {
	if !bool(cond) {
		log(.Fatal, str)
	}
}
log_shutdown :: proc() { io_close(g_log_file_hnd) }

// TR
TR_STRINGS_PATH :: "strings.csv"
TR_STRINGS_DELIM :: ";;"

@private g_strings: map[string]map[string]string

tr_get :: #force_inline proc(input: string) -> (string) {
	got, worked := g_strings[cast(string) g.uprefs.lang[:]][input]
	if !worked { return "MISSINGSTR" }
	return got
}

// ANIMATION
anim_spawn :: #force_inline proc(sys: ^map[string]Animation, name: string) {
	sys^[name] = Animation{ active = true, direction = 1.0 }
}
anim_get :: #force_inline proc(sys: ^map[string]Animation, name: string) -> (^Animation) {
	return (name in sys^) ? &sys^[name] : nil
}
anim_despawn :: proc(sys: ^map[string]Animation, name: string) {
	if (name in sys^) {
		delete_key(sys, name)
	}
}

ANIM_MM_BUTTONS :: "mm_buttons"
ANIM_UI_PTR :: "ui_ptr"

// GFX/UI
CenterOpt :: enum { HCenter, VCenter }
CenterOpts :: bit_set[CenterOpt]

TextBoxInfo :: struct {
	rect: FRect,
	font: FontWrapper,
	text: cstring,
	// pos: IVector2,
	opts: CenterOpts,
}
get_text_box :: proc(font: FontWrapper, text: string, pos: IVector2, opts: CenterOpts) -> (TextBoxInfo) {
	pos := pos
	text_cstr := strings.clone_to_cstring(tr_get(text), context.temp_allocator)
	text_measure: FVector2

	text_measure = rl.MeasureTextEx(font.font, text_cstr, font.size, font.spacing)

	if (.HCenter in opts) {
		pos.x -= i32(text_measure.x / 2)
	}

	if (.VCenter in opts) {
		pos.y -= i32(text_measure.y / 2)
	}
	return {
		rect = { f32(pos.x), f32(pos.y), (text_measure.x), (text_measure.y) },
		font = font,
		text = text_cstr,
		// pos = pos,
		opts = opts,
	}
}
draw_text :: proc(info: TextBoxInfo, color: Color) {
	// text_cstr := strings.clone_to_cstring(tr_get(text), context.temp_allocator)
	rl.DrawTextEx(info.font.font, info.text, { f32(info.rect.x), f32(info.rect.y) }, info.font.size, info.font.spacing, color)
}

UIState :: struct {
	width: int,
	layout: []FRect,
	current: int, // @Default(-1)
}

@private anim_ui_vecs := [2]FVector2{ {0.0, 0.0}, {0.0, 0.0} }
ui_update :: proc(siglist: ^map[KeybindName]SignalTriggerInfo, state: ^UIState) {
	max_x := state.width - 1
	max_y := (len(state.layout) / state.width) - 1

	c_x := state.current % state.width
	c_y := state.current / state.width

	moved := false
	if (.MoveDown in siglist^) {
		c_y = min(c_y, max_y)
		moved = true
	}

	animptr := anim_get(&g.animation_system, ANIM_UI_PTR)
	assert(animptr != nil)
	if (.PtrMove in siglist^) { // user cursor movement overrides this
		animptr.active = false
		animptr.deltas = 0.0
		return
	}

	if moved {
		animptr.active = true
		animptr.deltas = 0.0
		anim_ui_vecs[0] = {  } // target
		anim_ui_vecs[1] = g.mouse_v2 // current mouse
	}

	animptr.deltas = clamp(0.0, 1.0, animptr.deltas)
}

main :: proc() {
	init_global_temporary_allocator(3 * mem.Megabyte)

	g = new(Game)
	g.clear_alpha = 255
	g.scene = .MainMenu

	// g.events = make([dynamic]Event, 0, 20)
	g.controllers = make([dynamic]Controller, 0, 12)

	g.party_menu_layers = make([dynamic]PartyMenuLayer, 0, 12)

	{
		// IO init
		final_base_path := io_peel_back(os.args[0], context.allocator)
		io_set_base_path(final_base_path)

		// Log init
		io_ensure_file_static(LOG_FILE)
		log_file, worked := io_open_static(LOG_FILE, os.O_RDWR)
		if worked {
			g_log_file_hnd = log_file
		} else {
			panic("Could not open log file.")
		}

		{ // @Inlined tr_init() - Init string translations from strings.csv
			full_path := io_resolve_static(TR_STRINGS_PATH, context.temp_allocator)
			f, worked := io_open_raw(full_path)
			log_assert(worked, "Could not open TR file.")

			fcont, worked2 := io_read_entire_file(f)
			log_assert(worked2, "Got TR file HND but could not read it as str.")
			log_assert(fcont != nil && len(fcont) > 0, "Have read TR file, but string is empty.")

			split_lines := strings.split(cast(string) fcont, "\n", context.allocator)
			header_list := strings.split(split_lines[0], TR_STRINGS_DELIM, context.allocator)

			g_strings = make(type_of(g_strings))
			for i := 1; i < len(header_list); i += 1 {
				// Write empty map to each lang section
				g_strings[header_list[i]] = make(map[string]string)
			}

			for j := 1; j < len(split_lines); j += 1 {
				delimed := strings.split(split_lines[j], TR_STRINGS_DELIM, context.allocator) // delimed[0] -> KEY
				log_assert((len(delimed) == len(header_list)) || (len(split_lines[j]) == 0),
					fmt.tprintln("Num. values provided for a >0-length row != num. defined fields.", delimed))

				for k := 1; k < len(delimed); k += 1 {
					// Write each string into the map under the right lang section, using first column for key
					m := &g_strings[header_list[k]]
					m^[delimed[0]] = delimed[k]
				}
			}
		}

		{ // @Inlined uprefs_init() - Read uprefs or write default ones
			f_existed := true
			if !io_exists_static(UPREFS_FILE) || DEBUG {
				io_ensure_file_static(UPREFS_FILE)
				up_file, worked := io_open_static(UPREFS_FILE, IO_OPEN_READ_WRITE)
				log_assert(worked, "Could not open Uprefs file for default write even after io_ensure() call (?)")

				g.uprefs = DEFAULT_UPREFS
				io_write_ptr_len(up_file, &g.uprefs, size_of(g.uprefs))

				io_close(up_file)
				f_existed = false
			}

			if f_existed {
				// Load uprefs
				f_data, worked := io_read_entire_file_from_name_static(UPREFS_FILE)
				log_assert(worked, "f_existed check passed; io_read_entire_file... did not.")

				{ // @Inlined: uprefs_load(&g.uprefs, f_data)
					loaded_uprefs := transmute(^SerializableUprefsData) slice.first_ptr(f_data)
					g.uprefs = loaded_uprefs^
				}
			}
		}

		g.target_fps = i32(g.uprefs.target_fps)
		for _, i in g.wh_rngs {
			whrng_initialize_from_clock(&g.wh_rngs[i])
		}
	}

	rl.SetConfigFlags({ .WINDOW_MAXIMIZED, .WINDOW_RESIZABLE, .WINDOW_HIDDEN, .VSYNC_HINT })
	rl.SetTargetFPS(g.uprefs.target_fps)
	rl.InitWindow(0, 0, "Song of The Earth")
	rl.SetWindowMinSize(640, 480)

	if g.uprefs.window_maximized {
		rl.MaximizeWindow()
	}

	if g.uprefs.window_fullscreen {
		rl.SetWindowState({ .FULLSCREEN_MODE })
	}

	load_asset :: proc(path: string) -> (Asset) {
		cstr_path := strings.clone_to_cstring(io_resolve_static(path, context.temp_allocator), context.temp_allocator)
		rl_tex := rl.LoadTexture(cstr_path)
		return {
			rl_tex = rl_tex,
		}
	}
	{ // Load assets
		g.assets[.CursorAtlas] = load_asset("assets/cursor_atlas.png")
	}

	{ // Load fonts
		load_font :: proc(path: string, size, spacing: f32) -> (FontWrapper) {
			cstr := strings.clone_to_cstring(io_resolve_static(path, context.temp_allocator), context.temp_allocator)
			return {
				font = rl.LoadFontEx(cstr, i32(size), nil, 0),
				size = size,
				spacing = spacing,
			}
		}

		FONTPATH_EUROSTILE :: "assets/font/eurostile.ttf"
		g.font_std16 = load_font(FONTPATH_EUROSTILE, 16, 1.0)
		g.font_std24 = load_font(FONTPATH_EUROSTILE, 24, 1.0)
		g.font_std32 = load_font(FONTPATH_EUROSTILE, 32, 1.0)
	}

	/// INIT STAGE 2 - AFTER SDL INIT
	// Init assets (@TODO)

	// Persistent animations
	anim_spawn(&g.animation_system, ANIM_MM_BUTTONS)
	anim_spawn(&g.animation_system, ANIM_UI_PTR)

	rl.ClearWindowState({ .WINDOW_HIDDEN })
	mainloop: for !rl.WindowShouldClose() {
		g.ftime_start = time.now()

		defer {
			g.time_delta = time.since(g.ftime_start)
			g.delta = f32(i64(g.time_delta / time.Microsecond)) / f32(1_000 * 1_000)

			if !g.uprefs.vsync { // manual frame clocking
				ideal_duration := time.Duration( (f32(1_000) / f32(g.uprefs.target_fps)) ) * time.Millisecond
				diff := ideal_duration - g.time_delta
				if diff >= (1 * time.Nanosecond) { time.sleep(diff) }
			}
		}

		g.sw_i32 = rl.GetScreenWidth()
		g.sh_i32 = rl.GetScreenHeight()

		if (int(g.sw_i32) != g.sw) || (int(g.sh_i32) != g.sh) || g.sw_i32 == 0 || g.sh_i32 == 0 { // update soft layers
			
		}

		g.sw = int(g.sw_i32)
		g.sh = int(g.sh_i32)
		g.half_sw = int(g.sw_i32 / 2)
		g.half_sh = int(g.sh_i32 / 2)
		g.sw_f32 = f32(g.sw)
		g.sh_f32 = f32(g.sh)
		g.half_sw_f32 = f32(g.half_sw)
		g.half_sh_f32 = f32(g.half_sh)

		global_bounds := IRect{ 0, 0, g.sw_i32, g.sh_i32 }

		update_mouse :: proc(x, y: f32) {
			g.mouse_x = x
			g.mouse_y = y
			g.mouse_v2 = { x, y }
		}
		update_mouse(f32(rl.GetMouseX()), f32(rl.GetMouseY()))

		mdelta := rl.GetMouseDelta()
		g.mouse_delta_v2 = { f32(mdelta.x), f32(mdelta.y) }
		siglist := event_get_signal_analysis_from_events(&g.bindings, g.mouse_delta_v2, context.temp_allocator)

		// Move mouse via gamepad or other pointer devices other than mouse
		/*if (.PtrMove in siglist) && !trigger_includes_method(&siglist[.PtrMove], .MouseMovement) {
			// Simulate mouse movement from controller etc
			for info, j in siglist[.PtrMove].triggered_bindings {
				for bind in info {
					if bind.key == -1 || bind.method == .None { continue }
					if bind.method == .ControllerQuad {
						movement, union_cast_worked := siglist[.PtrMove].extra.(SignalExtraControllerQuad)
						assert(union_cast_worked, "<main.odin> Could not cast to (SignalExtraControllerQuad)")

						new_mx := g.mouse_x
						new_my := g.mouse_y
						for pad in movement {
							new_mx += pad[.LEFT_X] * 8
							new_my += pad[.LEFT_Y] * 8
						}
						update_mouse(new_mx, new_my)
						rl.SetMousePosition(i32(new_mx), i32(new_my))
					}
				}
			}
		}*/

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		#partial switch g.scene {
		case .MainMenu:
			{ // Handle/draw main menu title and buttons
				mm_title_render := get_text_box(g.font_std32, "MM_TITLE", { g.sw_i32 / 2, 60 }, { .HCenter })

				INDEX_PLAY :: 0
				INDEX_SETTINGS :: 1
				boxes := [2]TextBoxInfo{}
				boxes[INDEX_PLAY] = get_text_box(g.font_std24, "MM_PLAY", { g.sw_i32 / 2, (g.sh_i32 / 2) - 20 }, { .HCenter })
				boxes[INDEX_SETTINGS] = get_text_box(g.font_std24, "MM_SETTINGS", { g.sw_i32 / 2, (g.sh_i32 / 2) + 20 }, { .HCenter })

				handle_mm_button_press :: proc(button_index: int) {
					if button_index == INDEX_PLAY {
						g.scene = .WorldSelect
					} else if button_index == INDEX_SETTINGS {
						g.scene = .Settings
					}
				}

				MM_ANIM_SPEED :: 1.0 / 8.0
				@static anim_dt_mm_buttons := [3][3]f32{ {0.0, 0.0, 1.0}, {0.0, 0.0, 1.0}, {0.0, 0.0, 1.0} }

				// UI layout mapping for controller usage
				@static mm_ui_state := UIState{
					width = 1,
					layout = {
						{},
						{},
					},
					current = -1,
				}

				mm_ui_state.layout[INDEX_PLAY] = rect_add(boxes[INDEX_PLAY].rect, FRect{ boxes[INDEX_PLAY].rect.w / 2, boxes[INDEX_PLAY].rect.h / 2, 0, 0 })
				mm_ui_state.layout[INDEX_SETTINGS] = rect_add(boxes[INDEX_SETTINGS].rect, FRect{ boxes[INDEX_SETTINGS].rect.w / 2, boxes[INDEX_SETTINGS].rect.h / 2, 0, 0 })
				ui_update(&siglist, &mm_ui_state)

				collided_index := -1
				for _, i in boxes {
					pixels_wide := i32(anim_dt_mm_buttons[i][1] * f32(boxes[i].rect.w))
					if v2_rect_collide(g.mouse_v2, boxes[i].rect) {
						anim_dt_mm_buttons[i][2] = 1.0
						collided_index = i

						if (.Confirm in siglist) /*&& trigger_includes_method(&siglist[.Confirm], .MouseButton)*/ {
							handle_mm_button_press(collided_index)
							collided_index = -1
							break
						}
					} else {
						anim_dt_mm_buttons[i][2] = -1.0
					}

					anim_dt_mm_buttons[i][0] = clamp(anim_dt_mm_buttons[i][0] + (MM_ANIM_SPEED * anim_dt_mm_buttons[i][2]), 0.0, 1.0)
					anim_dt_mm_buttons[i][1] = tween_ease_in_out(f32(0.0), f32(1.0), anim_dt_mm_buttons[i][0])

					rl.DrawRectangleRec({ f32(boxes[i].rect.x - f32(pixels_wide/2)) + (boxes[i].rect.w/2),
						f32(boxes[i].rect.y + boxes[i].rect.h),
						f32(pixels_wide),
						1.0
					}, rl.WHITE)
				}
				if collided_index > -1 {
					g.mouse_cursor = .POINTING_HAND
				} else {
					g.mouse_cursor = .DEFAULT
				}

				draw_text(mm_title_render, rl.WHITE)
				draw_text(boxes[0], rl.WHITE)
				draw_text(boxes[1], rl.WHITE)
			}
		case .World:
			// Menu open
			when DEBUG {
				g.scene = .Battle
				continue mainloop
			}

			if (.Menu in siglist) {
				anim_spawn(&g.animation_system, "party_menu")
			}

			menu_anim := anim_get(&g.animation_system, "party_menu")
			if menu_anim != nil {
				// Draw menu items
				anim_perc := menu_anim.deltas / 0.5 // 0.5 seconds
				fmt.println(anim_perc, menu_anim.deltas)
			}
		case .Battle:
			topleft: int
			for i in 0..<len(g.party) { // Draw stat box backgrounds
				if g.party[i].recruited {
					topleft = i * (g.sw / len(g.party))
				}
			}
		case .WorldSelect:

		case .Settings:
		case .Blank:
		}

		{ // anim_tick_all()
			for k, v in &(g.animation_system) {
				if v.active {
					v.deltas += g.delta * v.direction
				}
			}
		}

		if g.mouse_cursor != g.mouse_cursor_last {
			g.mouse_cursor_last = g.mouse_cursor
			rl.SetMouseCursor(g.mouse_cursor)
		}
		rl.EndDrawing()
	}

	log_shutdown()
}
