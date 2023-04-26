package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:mem"
import "core:time"
import "core:os"
import "core:slice"
import "core:intrinsics"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"
import stbtt "vendor:stb/truetype"

GameScene :: enum {
	Blank, // For transitions
	MainMenu,
	World,
	Battle,

	WorldSelect,
	Settings,
}

Game :: struct {
	window: ^sdl.Window,
	gl_context: sdl.GLContext,

	// GL screen stuff
	screen_pixels: [dynamic]u32, // RGBX8888
	screen_framebuffer: u32,
	screen_rendertex: u32,
	screen_depthbuffer: u32,

	using_sdl_fallback: bool,

	should_paint: bool,

	scene: GameScene,

	event_state: EventState,

	// TR
	tr: TranslationRecord,

	// UI
	ui: UIContext,
	
	ftime_start, ftime_end, ftime_debug: time.Time,
	time_delta: time.Duration,
	delta: f32,
	frame_count: int,

	win_w, win_h: i32,
	old_win_w, old_win_h: i32,

	mouse_x, mouse_y, anim_mouse_x, anim_mouse_y: i32,
	mouse_delta_v2: IntVector2,
	mouse_cursor, mouse_cursor_last: sdl.SystemCursor,

	party_menu_layers: [dynamic]PartyMenuLayer,

	// world select screen state
	world_saves_loaded: bool,
	world_save_files: [dynamic]struct{ hnd: IOHandle, path: string },

	// Battle
	inventory: [MAX_NUM_INV_ITEMS]ItemSlot,
	bstate: BattleState,

	wh_rngs: [enum { Throwaway, Battle }]WHRngState,

	// Fonts
	font_std32: TTF_Font,

	// Saved (uprefs) data
	using uprefs: Uprefs,
}
g: Game

// Internal screen buffer size
IBUF_W :: 320
IBUF_H :: 240

main :: proc() {
	init_global_temporary_allocator(3 * mem.Megabyte)

	g.party_menu_layers = make([dynamic]PartyMenuLayer, 0, 12)
	g.world_save_files = make(type_of(g.world_save_files), 0, 100, context.allocator)

	// IO, TR, Uprefs...
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

			g.tr = make(type_of(g.tr))
			for i := 1; i < len(header_list); i += 1 {
				// Write empty map to each lang section
				g.tr[header_list[i]] = make(map[string]string)
			}

			for j := 1; j < len(split_lines); j += 1 {
				delimed := strings.split(split_lines[j], TR_STRINGS_DELIM, context.allocator) // delimed[0] -> KEY
				log_assert((len(delimed) == len(header_list)) || (len(split_lines[j]) == 0),
					fmt.tprintln("Num. values provided for a >0-length row != num. defined fields.", delimed))

				for k := 1; k < len(delimed); k += 1 {
					// Write each string into the map under the right lang section, using first column for key
					m := &g.tr[header_list[k]]
					m^[delimed[0]] = delimed[k]
				}
			}
		}

		free_all(context.temp_allocator)

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
					loaded_uprefs := transmute(^Uprefs) slice.first_ptr(f_data)
					g.uprefs = loaded_uprefs^
				}
			}
		}

		g.target_fps = i32(g.uprefs.target_fps)
		for _, i in g.wh_rngs {
			whrng_initialize_from_clock(&g.wh_rngs[i])
		}
	}

	if sdl_init_res := sdl.Init({ .VIDEO, .EVENTS }); sdl_init_res != 0 {
		assert(false, fmt.tprintln("SDL_Init failed, code:", sdl_init_res))
	}

	g.window = sdl.CreateWindow(tr_get_cstring(g.tr, g.canon_lang_key, "MM_TITLE"),
		sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
		IBUF_W / 2, IBUF_H / 2,
		{ .HIDDEN, .RESIZABLE, .OPENGL })
	assert(g.window != nil, "Could not init SDL!")

	sdl.SetWindowMinimumSize(g.window, 640, 480)

	{ // Init GL
		gl.load_up_to(3, 0, proc(p: rawptr, name: cstring) { (^rawptr)(p)^ = sdl.GL_GetProcAddress(name) })
		g.gl_context = sdl.GL_CreateContext(g.window)

		// Create the framebuffer and render tex
		pixbuf_size := IBUF_W * IBUF_H
		g.screen_pixels = make([dynamic]u32, pixbuf_size, context.allocator) // screen buffer

		gl.GenTextures(1, &g.screen_rendertex)
		gl.BindTexture(gl.TEXTURE_2D, g.screen_rendertex)
		gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.GENERATE_MIPMAP, transmute(i32) b32(gl.TRUE))
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, IBUF_W, IBUF_H, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
		gl.BindTexture(gl.TEXTURE_2D, 0)

		gl.GenRenderbuffers(1, &g.screen_depthbuffer)
		gl.BindRenderbuffer(gl.RENDERBUFFER, g.screen_depthbuffer)
		gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, IBUF_W, IBUF_H)
		gl.BindRenderbuffer(gl.RENDERBUFFER, 0)

		gl.GenFramebuffers(1, &g.screen_framebuffer)
		gl.BindFramebuffer(gl.FRAMEBUFFER, g.screen_framebuffer)
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, g.screen_rendertex, 0)
		draw_buffers := [?]u32{ gl.COLOR_ATTACHMENT0 }
		gl.DrawBuffers(1, slice.first_ptr(draw_buffers[:]))
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, g.screen_depthbuffer)
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	}

	apply_uprefs :: proc() {
		if g.uprefs.window_maximized {
			sdl.MaximizeWindow(g.window)
		}
	
		if g.uprefs.window_fullscreen {
			sdl.SetWindowFullscreen(g.window, { .FULLSCREEN })
		}

		sdl.GL_SetSwapInterval(1 if g.uprefs.vsync else 0)
	}
	apply_uprefs()

	{ // Load fonts
		eurostile_raw_data, succ := io_read_entire_file_from_name_static("assets/font/eurostile.ttf", context.allocator)
		defer free(slice.first_ptr(eurostile_raw_data), context.allocator)
		assert(succ)

		stbtt.InitFont(&g.font_std32.stb_font, slice.first_ptr(eurostile_raw_data), 0)
	}

	{ // Initial game state
		g.bstate.party = {
			gen_default_party_member(id=TERRY, recruited=true),
			gen_default_party_member(id=VIOLA, recruited=false),
			gen_default_party_member(id=DEX, recruited=false),
		}

		g.scene = .MainMenu
		g.should_paint = true
	}

	when DEBUG { // Setup debug save file
		party_member_unlock_ability(&g.bstate.party, TERRY, .ACC_Strike)
		party_member_unlock_ability(&g.bstate.party, TERRY, .ACC_Blitzkrieg)

		g.scene = .Battle

		g.uprefs.vsync = true
		g.uprefs.window_fullscreen = true
	}

	sdl.ShowWindow(g.window)
	sdl.InitSubSystem({ .JOYSTICK })
	mainloop: for {
		g.ftime_start = time.now()
		g.ftime_debug = g.ftime_start

		e := &g.event_state
		{ // Parse events
			// Initial state
			e.was_window_resized = false
			e.gained_focus = false
			e.lost_focus = false

			e.was_mouse_moved = false

			e.was_gamepad_connected = false

			// Add next
			evt: sdl.Event
			for sdl.PollEvent(&evt) {
				#partial switch evt.type {
				case .WINDOWEVENT:
					win_evt: sdl.WindowEventID = evt.window.event
					if win_evt == .RESIZED || win_evt == .SIZE_CHANGED {
						e.was_window_resized = true
					} else if win_evt == .EXPOSED || win_evt == .SHOWN {
						e.gained_focus = true
					} else if win_evt == .HIDDEN {
						e.lost_focus = true
					}
				case .MOUSEMOTION:
					e.was_mouse_moved = true
					e.mouse_x = int(evt.motion.x)
					e.mouse_y = int(evt.motion.y)
				case .QUIT:
					sdl.Quit()
					os.exit(0)
				}
			}
		}

		{ // Handle parsed events
			if e.was_window_resized {
				g.old_win_w = g.win_w
				g.old_win_h = g.win_h
				sdl.GetWindowSize(g.window, &g.win_w, &g.win_h)
			}
	
			if e.gained_focus {
				g.should_paint = true
			} else if e.lost_focus {
				g.should_paint = false
			}
		}

		if g.should_paint { // Graphics entry point
			gl.BindFramebuffer(gl.FRAMEBUFFER, g.screen_framebuffer)
			gl.Viewport(0, 0, g.win_w, g.win_h)
			gl.ClearColor(1.0, 0.0, 0.0, 1.0)
			gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)
		}

		#partial switch g.scene {
		case .Battle:
			// Battle UI
			ui := &g.ui
			{ ui_begin(ui)
				ui_push_origin(ui, 20, 20)

				ui.color = { 255, 0, 0, 255 }
				ui_rect(ui, 0, 0, 200, 200)

				ui.text_center = { .HCenter }
				ui.color = { 255, 255, 255, 255 }
				ui_text(ui, tr_get(g.tr, g.canon_lang_key, "NIL"), 20, 20)

				ui.rect_center = { .HCenter }
				ui.color = { 0, 0, 255, 255 }
				ui.font = g.font_std32
				ui_rect(ui, 0, 0, 20, 20)
			ui_end(ui) }
		}

		{ // Render UI
			for this_ui := 0; this_ui < g.ui.cmd_head; this_ui += 1 {
				this_cmd := g.ui.cmd_stack[this_ui]
				switch cmd in this_cmd {
				case UIDrawCommandRect:
					blit_rect(g.screen_pixels[:], cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, int(IBUF_W), cmd.color)

				case UIDrawCommandText:
					blit_text(g.screen_pixels[:], cmd.font, cmd.text, cmd.begin.x, cmd.begin.y, int(IBUF_W), cmd.color)
				}
			}
		}

		if g.should_paint { // Frame/drawing clean-up
			gl.BindTexture(gl.TEXTURE_2D, g.screen_rendertex)
			gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, IBUF_W, IBUF_H, gl.RGBA, gl.UNSIGNED_BYTE, transmute(rawptr) slice.first_ptr(g.screen_pixels[:]))
			gl.BindTexture(gl.TEXTURE_2D, 0)

			gl.BindFramebuffer(gl.READ_FRAMEBUFFER, g.screen_framebuffer)
			gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
			gl.BlitFramebuffer(0, 0, IBUF_W, IBUF_H, 0, 0, g.win_w, g.win_h, gl.COLOR_BUFFER_BIT, gl.NEAREST)

			gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
			gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)
			gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)

			gl.Finish()
			sdl.GL_SwapWindow(g.window)
			free_all(context.temp_allocator)
		}

		defer if !g.should_paint { // Suspend CPU unti next event
			// Since WaitEvent pops from queue, we have to manually push it back into the queue and then continue
			wait_evt: sdl.Event
			if sdl.WaitEvent(&wait_evt) {
				sdl.PushEvent(&wait_evt)
			}
		}

		{ // Enforce FPS timing for non-vsync
			g.time_delta = time.since(g.ftime_start)
			g.delta = f32(i64(g.time_delta / time.Microsecond)) / f32(1_000 * 1_000)

			if !g.uprefs.vsync { // manual frame clocking
				ideal_duration := time.Duration( (f32(1_000) / f32(g.uprefs.target_fps)) ) * time.Millisecond
				diff := ideal_duration - g.time_delta
				if diff >= (1 * time.Nanosecond) { time.sleep(diff) }
			}

			g.frame_count += 1
		}
	}

	log_shutdown()
}
