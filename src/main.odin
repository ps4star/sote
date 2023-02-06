package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:mem"
import "core:time"
import "core:os"

import sdl "vendor:sdl2"

GameScene :: enum
{
	Blank, // For transitions
	MainMenu,
	World,
	Battle,
}

Game :: struct
{
	// Graphics/main
	// screen_buffer: rl.RenderTexture,
	window: ^sdl.Window,
	renderer: ^sdl.Renderer,
	screen_buffer: ^sdl.Surface,

	// Control values
	scene: GameScene,
	party_menu_layers: []PartyMenuLayer,

	// Misc values
	clear_alpha: u8, // @Default(255) - used for blend effects
	g_alts: [dynamic]AlterationDegreePair,
	throwaway_rng: WHRngState,

	// Systems
	asset_sys: AssetSystem,
	tilemap_sys: TileMapSystem,
	anim_sys: AnimationSystem,
	tr_sys: TrSystem,
	uprefs: Uprefs,

	diag_scroll: TextScrollSystem, // dialog scroller
}

FrameContext :: struct
{
	// Event/looping
	evt: sdl.Event,
	evt_analysis: EventAnalysis,
	target_fps: int,
	
	// Timing
	ftime_start, ftime_end: time.Time,
	time_delta: time.Duration,
	delta: f32,

	// Delta analysis stuff
	norm_delta: f32,
	norm_delta_v2: FVector2,
	frame_count: uint,

	// Dimensions
	global_bounds: IRect,
	global_bounds_frect: FRect,

	sw_i32, sh_i32: i32,
	sw, sh, half_sw, half_sh: int,
	sw_f32, sh_f32, half_sw_f32, half_sh_f32: f32,
}

g: ^Game = nil
fctx: FrameContext

debugx, debugy: i32

main :: proc()
{
	/// ODIN INIT
	init_global_temporary_allocator(2 * mem.Megabyte)

	/// GAME INIT
	g = new(Game)
	GLOBAL_set_clear_alpha(255)
	GLOBAL_set_scene(.MainMenu)

	g.party_menu_layers = make(type_of(g.party_menu_layers), 32)

	/// INIT STAGE 1
	{
		final_base_path := io_peel_back(os.args[0], context.allocator)
		io_init(final_base_path)
		log_init()
		tr_init(&g.tr_sys)
		uprefs_init(&g.uprefs)
		fctx.target_fps = (int)(g.uprefs.target_fps)

		anim_init(&g.anim_sys)
		whrng_initialize_from_clock(&g.throwaway_rng)
	}

	sdl.Init({ .VIDEO, .EVENTS, .JOYSTICK })
	g.window = sdl.CreateWindow("Song of The Earth", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, 0, 0,
		{ .RESIZABLE, .MAXIMIZED, .HIDDEN })
	g.renderer = sdl.CreateRenderer(g.window, -1,
		{ .PRESENTVSYNC, .ACCELERATED })

	/// INIT STAGE 2 - AFTER SDL INIT
	asset_init(&g.asset_sys)

	// Init event analysis
	/// NOTE: ensure that event_init occurs after uprefs_init always
	event_init(&fctx.evt_analysis)

	sdl.ShowWindow(g.window)
	mainloop: for
	{
		fctx.ftime_start = time.now()

		defer
		{
			fctx.time_delta = time.since(fctx.ftime_start)

			ideal_duration := (time.Duration)( ((f32)(1_000) / (f32)(g.uprefs.target_fps)) ) * time.Millisecond
			diff := ideal_duration - fctx.time_delta
			if diff >= (1 * time.Nanosecond) { time.sleep(diff) }
		}

		sdl.GetWindowSize(g.window, &fctx.sw_i32, &fctx.sh_i32)
		if (int)(fctx.sw_i32) != fctx.sw || fctx.sw_i32 == 0 || fctx.sh_i32 == 0
		{
			g.screen_buffer = sdl.GetWindowSurface(g.window)
		}

		fctx.sw = (int)(fctx.sw_i32)
		fctx.sh = (int)(fctx.sh_i32)
		fctx.half_sw = (int)(fctx.sw_i32 / 2)
		fctx.half_sh = (int)(fctx.sh_i32 / 2)
		fctx.sw_f32 = (f32)(fctx.sw)
		fctx.sh_f32 = (f32)(fctx.sh)
		fctx.half_sw_f32 = (f32)(fctx.half_sw)
		fctx.half_sh_f32 = (f32)(fctx.half_sh)

		fctx.global_bounds = { 0, 0, fctx.sw_i32, fctx.sh_i32 }
		fctx.global_bounds_frect = FRect{ 0, 0, (f32)(fctx.sw_i32), (f32)(fctx.sh_i32) }



		event_begin(&fctx.evt_analysis)
		for sdl.PollEvent(&fctx.evt)
		{
			#partial switch fctx.evt.type {
			case .QUIT:
				break mainloop
			case .KEYDOWN:
				event_push_key(&fctx.evt_analysis, fctx.evt.key.keysym.sym, .Down)
			case .KEYUP:
				event_push_key(&fctx.evt_analysis, fctx.evt.key.keysym.sym, .Up)
			case .MOUSEBUTTONDOWN:
			case .MOUSEBUTTONUP:
			case .CONTROLLERAXISMOTION:
			case .CONTROLLERBUTTONDOWN:
			case .CONTROLLERBUTTONUP:
			case .CONTROLLERDEVICEADDED:
			case .CONTROLLERDEVICEREMOVED:
			}
		}
		event_generate_signals_from_analysis(&fctx.evt_analysis, &g.uprefs.bindings)



		sdl.SetRenderDrawColor(g.renderer, 0, 0, 0, g.clear_alpha)
		sdl.RenderClear(g.renderer)

		#partial switch g.scene {
		case .MainMenu:
			// info, has := event_check_signal(&fctx.evt_analysis, .Confirm)
			// if has
			// {
			// 	fmt.println(info)
			// 	anim_activate_and_reset(&g.anim_sys, PANIMID_BATTLE_TRANS)
			// }
			GLOBAL_set_scene(.World)
		case .World:
			// tm_set_map(&g.tilemap_sys, TMID_DEBUG)

			// Menu open
			if event_has_signal(&fctx.evt_analysis, .Menu)
			{
				anim_activate_and_reset(&g.anim_sys, PANIMID_MENU)
			}

			// cmap := tmsys_get_current_ptr(&g.tilemap_sys)
			// tm_draw(cmap)
		case .Battle:
			// GLOBAL_set_scene(.MainMenu)
		case .Blank:
		}

		anim_tick_all(&g.anim_sys)
		sdl.RenderPresent(g.renderer)
	}

	log_shutdown()
}