package SongOfTheEarth
import "core:fmt"
import "core:intrinsics"
import "core:math"
// import "core:time"
import "core:os"

import sdl "vendor:sdl2"

AnimationCallbackProc :: #type proc(sys: ^AnimationSystem, id: uint)
AnimationState :: enum
{
	Inactive = 0,
	Active = 1,
}

ANIM_USER_ARG_COUNT :: 14
Animation :: struct
{
	// Header
	state: AnimationState, // 0 = inactive, 1 = active, 2+ = user-defined
	runs: uint,
	total_deltas: f32,
	count_direction: int, // -1 || 0 || 1

	// User custom args
	i32s: [ANIM_USER_ARG_COUNT]i32,
	u32s: [ANIM_USER_ARG_COUNT]u32,
	f32s: [ANIM_USER_ARG_COUNT]f32,
	ptrs: [ANIM_USER_ARG_COUNT]rawptr,

	callback: AnimationCallbackProc,
}

MAX_ANIMS :: 256
ALLOCATED_PANIMS :: 32 // First 32 ANIM IDs are allocated to persistent anims
AnimationSystem :: struct
{
	anim_store: [MAX_ANIMS]Animation,
}

/// ACALC
AcalcTimingFunction :: enum
{
	None,
	Linear,
	EaseIn,
	EaseOut,
	EaseInOut,
}

AcalcDef :: struct
{
	timing_function: AcalcTimingFunction,
	origin, target: []FVector2,
	out: []FVector2, // @ExpectedValidMemory
}

AcalcTimeSetup :: struct
{
	phase: FVector2,
	which: []int,
}

anim_phase_check :: proc(aptr: ^Animation, phase: FVector2) -> (bool, f32)
{
	perc := v2_percentage_in_range(phase, aptr.total_deltas)
	if perc >= (f32)(1) || perc < (f32)(0)
	{
		return false, perc
	}

	return true, perc
}

anim_calc :: proc(aptr: ^Animation, defs: []^AcalcDef, time_setup: []AcalcTimeSetup) -> (perc: f32, which_phase: int)
{
	in_phase, passed: bool
	passed = false

	for t, j in time_setup
	{
		in_phase, perc = anim_phase_check(aptr, t.phase)
		if in_phase
		{
			passed = true
			which_phase = j
			break
		}
	}

	if !passed { return 0.0, -1 }

	for _, i in defs
	{
		found := false
		for val in time_setup[which_phase].which
		{
			found ||= (val == i)
		}
		if !found { continue }

		thisptr := defs[i]
		if thisptr.origin == nil || thisptr.target == nil || thisptr.out == nil
		{
			return perc, which_phase
		}

		assert(len(thisptr.origin) == len(thisptr.target))
		assert(len(thisptr.out) == len(thisptr.origin)) // transitive logic means all 3 are the same length here

		for _, k in thisptr.origin
		{
			// Interpolate each value into []out from []origin and []target
			#partial switch thisptr.timing_function {
			case .None:
			case .Linear:
				thisptr.out[k] = v2_lerp(thisptr.origin[k], thisptr.target[k], perc)
			case .EaseIn:
				thisptr.out[k] = v2_ease_in(thisptr.origin[k], thisptr.target[k], perc)
			case .EaseOut:
				thisptr.out[k] = v2_ease_out(thisptr.origin[k], thisptr.target[k], perc)
			}
		}
	}

	return perc, which_phase
}

/// PERSISTENT ANIMS
PANIMID_ITEM_GET :: 0

ITEM_GET_LINE_W :: 0.5
ITEM_GET_LINE_H :: 6
ITEM_GET_LINE_OFFSET :: 64
ITEM_GET_SEG_LENGTH :: 0.700
ITEM_GET_BUF :: 32

ITEM_GET_POS_TOPLINE := []FVector2{{}}
ITEM_GET_POS_BOTTOMLINE := []FVector2{{}}

// @Unused
PANIMPROC_ITEM_GET :: proc(sys: ^AnimationSystem, id: uint)
{
	aptr := anim_get_by_id(sys, id)

	P1 :: FVector2{ ITEM_GET_SEG_LENGTH * 0, ITEM_GET_SEG_LENGTH * 1 }
	P2 :: FVector2{ ITEM_GET_SEG_LENGTH * 1, ITEM_GET_SEG_LENGTH * 2.5 }
	P3 :: FVector2{ ITEM_GET_SEG_LENGTH * 4, ITEM_GET_SEG_LENGTH * 5 }

	perc1, phase1 := anim_calc(aptr, {
		&AcalcDef{
			// Top line forwards (#0)
			timing_function = .EaseIn,
			origin = {{
				fctx.sw_f32 + 20.0,
				fctx.half_sh_f32 - ITEM_GET_LINE_OFFSET
			}},
			target = {{
				(fctx.half_sw_f32 + ITEM_GET_BUF) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 - ITEM_GET_LINE_OFFSET
			}},

			out = ITEM_GET_POS_TOPLINE,
		},
		&AcalcDef{
			// Bottom line forwards (#1)
			timing_function = .EaseIn,
			origin = {{
				- 20.0,
				fctx.half_sh_f32 + ITEM_GET_LINE_OFFSET
			}},
			target = {{
				(fctx.half_sw_f32 - ITEM_GET_BUF) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 + ITEM_GET_LINE_OFFSET
			}},

			out = ITEM_GET_POS_BOTTOMLINE,
		},
		&AcalcDef{
			// Text fade in (#2)
		},
		&AcalcDef{
			// Top line middle (#3)
			timing_function = .Linear,
			origin = {{
				(fctx.half_sw_f32 + ITEM_GET_BUF) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 - ITEM_GET_LINE_OFFSET
			}},
			target = {{
				(fctx.half_sw_f32 - 0) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 - ITEM_GET_LINE_OFFSET
			}},

			out = ITEM_GET_POS_TOPLINE,
		},
		&AcalcDef{
			// Bottom line middle (#4)
			timing_function = .Linear,
			origin = {{
				(fctx.half_sw_f32 - ITEM_GET_BUF) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 + ITEM_GET_LINE_OFFSET
			}},
			target = {{
				(fctx.half_sw_f32 + 0) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 + ITEM_GET_LINE_OFFSET
			}},

			out = ITEM_GET_POS_BOTTOMLINE,
		},
		&AcalcDef{
			// Text middle (#5)
		},
		&AcalcDef{
			// Top line ending (#6)
			timing_function = .EaseOut,
			origin = {{
				(fctx.half_sw_f32 - 0) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 - ITEM_GET_LINE_OFFSET
			}},
			target = {{
				-10 - fctx.half_sw_f32,
				fctx.half_sh_f32 - ITEM_GET_LINE_OFFSET
			}},

			out = ITEM_GET_POS_TOPLINE,
		},
		&AcalcDef{
			// Bottom line ending (#7)
			timing_function = .EaseOut,
			origin = {{
				(fctx.half_sw_f32 - 0) - (0.5 * ITEM_GET_LINE_W * fctx.sw_f32),
				fctx.half_sh_f32 + ITEM_GET_LINE_OFFSET
			}},
			target = {{
				10 + fctx.sw_f32,
				fctx.half_sh_f32 + ITEM_GET_LINE_OFFSET
			}},

			out = ITEM_GET_POS_BOTTOMLINE,
		},
		&AcalcDef{
			// Text ending (#8)
		},
	}, {
		{
			phase = P1,
			which = { 0, 1 },
		},
		{
			phase = P2,
			which = { 3, 4 },
		},
		{
			phase = P3,
			which = { 6, 7 },
		},
	})

	// Draw segments
	alpha: u8
	if phase1 == 0 || phase1 == 2
	{
		alpha = (u8)(perc1 * 255.0)
		if phase1 == 2 { alpha = 255 - alpha }
	} else
	{
		alpha = 255
	}

	// alph_white := rl.WHITE
	// alph_white.a = alpha

	// rl.DrawRectangleV(ITEM_GET_POS_TOPLINE[0], { ITEM_GET_LINE_W * fctx.sw_f32, ITEM_GET_LINE_H }, alph_white)
	// rl.DrawRectangleV(ITEM_GET_POS_BOTTOMLINE[0], { ITEM_GET_LINE_W * fctx.sw_f32, ITEM_GET_LINE_H }, alph_white)
}

PANIMID_WALK :: 1
PANIMPROC_WALK :: proc(sys: ^AnimationSystem, id: uint)
{
	aptr := anim_get_by_id(sys, id)
}

PANIMID_BOX :: 2
PANIMPROC_BOX :: proc(sys: ^AnimationSystem, id: uint)
{
	aptr := anim_get_by_id(sys, id)
}

// Actives when <MENU> is pressed
PANIMID_MENU :: 3

MENU_ITEM_POS := []FVector2{{}}
MENU_BUTTON_W :: 256
MENU_BUTTON_H :: 32
MENU_BUTTON_VMARGIN :: 2
PANIMPROC_MENU :: proc(sys: ^AnimationSystem, id: uint)
{
	aptr := anim_get_by_id(sys, id)

	// Slide items in
	perc, phase := anim_calc(aptr, {
		&AcalcDef{
			// Main item slide (offset this for other items)
			timing_function = .EaseIn,
			origin = {{
				0.0,
				0.0,
			}},
			target = {{
				1.0,
				1.0,
			}},

			out = MENU_ITEM_POS,
		},
		&AcalcDef{
			// Party member slide
			timing_function = .EaseIn,
			origin = {{

			}},
			target = {{

			}},
			
			out = MENU_ITEM_POS,
		},
		&AcalcDef{
			// Bottom info box slide
			timing_function = .EaseIn,
			origin = {{

			}},
			target = {{

			}},
			
			out = MENU_ITEM_POS,
		},
	}, {
		{
			phase = { 0.0, 5.00 },
			which = { 0, 1, 2 },
		},
	})

	assert(phase > -1, "Phase is -1. <anim.odin> line 345. PANIMPROC_MENU")

	menu_positions := [16]FVector2{}
	if phase == 0
	{
		cur_perc := min(perc + 0.5, 1.0)
		i := 0
		for // render menu items loop
		{
			this_rect := FRect{
				(cur_perc * 200) - 200,
				(i * MENU_BUTTON_H) + MENU_BUTTON_VMARGIN,
				MENU_BUTTON_W,
				MENU_BUTTON_H,
			}
			hl_draw_rect(&g.renderer, this_rect, { 255, 0, 0, 255 })

			i += 1
		}
	}
}

// Battle transition anim
ACALC_LINEAR_NIL := AcalcDef{
	timing_function = .Linear,
	origin = {{}},
	target = {{}},
	out = {{}},
}
PANIMID_BATTLE_TRANS :: 4

BTRANS_PX_GRAIN :: 7
BTRANS_PX_GRAIN_SQ :: (BTRANS_PX_GRAIN * BTRANS_PX_GRAIN)
BTRANS_START_FADE_PERC : f32 : 0.83

// BTRANS_OUT :: []FVector2{{}}
btrans_pixels: []struct { col: Color, pos, accel, accel2: FVector2 }
// btrans_img: rl.Image
btrans_tex: ^sdl.Texture
PANIMPROC_BATTLE_TRANS :: proc(sys: ^AnimationSystem, id: uint)
{
	aptr := anim_get_by_id(sys, id)

	perc, which_ph := anim_calc(aptr, {
		&ACALC_LINEAR_NIL,
	}, {
		{
			phase = { 0.0, 1.6 },
			which = { 0 },
		},
		{
			phase = { 1.6, 99 },
			which = { 0 },
		},
	})

	if which_ph > 0
	{
		GLOBAL_set_scene(.MainMenu)
		GLOBAL_set_clear_alpha(255)
		delete(btrans_pixels)
		btrans_pixels = nil

		anim_inactive_and_reset(sys, id)
		return
	}

	div_sw := (uint)(fctx.sw / BTRANS_PX_GRAIN)
	div_sh := (uint)(fctx.sh / BTRANS_PX_GRAIN)
	div_screen_px := div_sw * div_sh

	if btrans_pixels == nil
	{
		GLOBAL_set_scene(.Blank)
		GLOBAL_set_clear_alpha(90)
		whrng_random(&g.throwaway_rng)

		btrans_pixels = make(type_of(btrans_pixels), div_screen_px, context.allocator)
		btrans_tex = sdl.CreateTextureFromSurface(g.renderer, g.screen_buffer)

		for _, i in btrans_pixels
		{
			accel: FVector2
			accel2: FVector2
			
			xpos := cast(f32) ((i32)(i) % cast(i32) div_sw) * BTRANS_PX_GRAIN
			ypos := (f32)(math.floor_f32((f32)(i) / (f32)(div_sw))) * BTRANS_PX_GRAIN

			xdist := (f32)(xpos) - (f32)(fctx.global_bounds.w / 2)
			ydist := (f32)(ypos) - (f32)(fctx.global_bounds.h / 2)

			accel.x = whrng_randfloat(&g.throwaway_rng, 3 * xdist, xdist) / 50
			accel.y = whrng_randfloat(&g.throwaway_rng, 3 * ydist, ydist) / 30

			accel2.x = -1 * whrng_randfloat(&g.throwaway_rng, -0.9, 0.9)
			accel2.y = 0.26

			btrans_pixels[i] = {
				col = { 255, 0, 0, 255 },
				pos = { xpos, ypos },
				accel = accel,
				accel2 = accel2,
			}
		}
	}

	alph: f32 = 1.0
	if perc >= BTRANS_START_FADE_PERC
	{
		alph = (1.0 - perc) * (1 / (1.0 - BTRANS_START_FADE_PERC))
	}

	for _, i in btrans_pixels
	{
		f_pos := FVector2{
			(f32)((i32)(i) % cast(i32) div_sw) * BTRANS_PX_GRAIN,
			(f32)(math.floor_f32((f32)((i32)(i) / cast(i32) div_sw)) * BTRANS_PX_GRAIN),
		}

		sdl.RenderCopyEx(g.renderer,
			btrans_tex,
			&sdl.Rect{ (i32)(f_pos.x), (i32)(f_pos.y), BTRANS_PX_GRAIN, BTRANS_PX_GRAIN },
			&sdl.Rect{ (i32)(btrans_pixels[i].pos.x), (i32)(btrans_pixels[i].pos.y), BTRANS_PX_GRAIN, BTRANS_PX_GRAIN },
			0.0,
			nil,
			sdl.RendererFlip.NONE)

		v2_add(&btrans_pixels[i].pos, v2_mul_im(btrans_pixels[i].accel, fctx.norm_delta_v2))
		v2_add(&btrans_pixels[i].accel, v2_mul_im(btrans_pixels[i].accel2, fctx.norm_delta_v2))
	}
}








// SEPARATION








/// ANIM
anim_init :: proc(sys: ^AnimationSystem)
{
	anim_register_persistent(sys, PANIMID_ITEM_GET,			PANIMPROC_ITEM_GET) // @Unused
	anim_register_persistent(sys, PANIMID_WALK,				PANIMPROC_WALK)
	anim_register_persistent(sys, PANIMID_BOX,				PANIMPROC_BOX)
	anim_register_persistent(sys, PANIMID_MENU,				PANIMPROC_MENU)
	anim_register_persistent(sys, PANIMID_BATTLE_TRANS,		PANIMPROC_BATTLE_TRANS)
}

anim_get_by_id :: #force_inline proc(sys: ^AnimationSystem, id: uint) -> (^Animation)
{
	return &sys.anim_store[id]
}

@private
anim_find_next_avail_spot :: proc(sys: ^AnimationSystem) -> (spot: uint, worked: bool)
{
	for i := (uint)(ALLOCATED_PANIMS); i < len(sys.anim_store); i += 1
	{
		if sys.anim_store[i].callback != nil
		{
			return i, true
		}
	}

	return 0, false
}

anim_register_persistent :: proc(sys: ^AnimationSystem, id: uint, cb: AnimationCallbackProc,
	i32s: []i32 = nil, u32s: []u32 = nil, f32s: []f32 = nil, ptrs: []rawptr = nil)
{
	assert(id < ALLOCATED_PANIMS)
	sys.anim_store[id] = Animation{
		callback = cb,
		state = .Inactive,
	}

	anim_set_direction_forwards(sys, id)
	if i32s != nil || u32s != nil || f32s != nil || ptrs != nil
	{
		anim_set_arguments(sys, id, i32s, u32s, f32s, ptrs)
	}
}

anim_register_new :: proc(sys: ^AnimationSystem, cb: AnimationCallbackProc,
	i32s: []i32 = nil, u32s: []u32 = nil, f32s: []f32 = nil, ptrs: []rawptr = nil) -> (uint)
{
	location, worked := anim_find_next_avail_spot(sys)
	assert(worked, "Could not find space for new animation! Increase MAX_ANIMS")
	assert(location >= ALLOCATED_PANIMS && location < MAX_ANIMS)

	sys.anim_store[location] = Animation{
		callback = cb,
		state = .Inactive,
	}

	anim_set_direction_forwards(sys, location)
	if i32s != nil || u32s != nil || f32s != nil || ptrs != nil
	{
		anim_set_arguments(sys, location, i32s, u32s, f32s, ptrs)
	}

	return location
}

anim_set_arguments :: proc(sys: ^AnimationSystem, id: uint, i32s: []i32, u32s: []u32, f32s: []f32, ptrs: []rawptr)
{
	write_argset :: proc(anim_list: ^[ANIM_USER_ARG_COUNT]$T, user: []T)
		where intrinsics.type_is_numeric(T) || T == rawptr
	{
		if user == nil { return }
		for i := 0; i < len(user) && i < ANIM_USER_ARG_COUNT; i += 1
		{
			anim_list^[i] = user[i]
		}
	}

	a := anim_get_by_id(sys, id)
	write_argset(&a.i32s, i32s)
	write_argset(&a.u32s, u32s)
	write_argset(&a.f32s, f32s)
	write_argset(&a.ptrs, ptrs)
}

anim_tick_all :: proc(sys: ^AnimationSystem)
{
	anim_tick_single :: #force_inline proc(sys: ^AnimationSystem, id: uint)
	{
		aptr := anim_get_by_id(sys, id)
		if aptr.state != .Inactive
		{
			aptr.callback(sys, id)
		}

		aptr.runs = (uint)( max((int)(aptr.runs) + (1 * aptr.count_direction), 0) )
		aptr.total_deltas = max(aptr.total_deltas + ((f32)(fctx.delta) * (f32)(aptr.count_direction)), 0)
	}

	for i := 0; i < MAX_ANIMS; i += 1
	{
		if sys.anim_store[i].state != .Inactive
		{
			anim_tick_single(sys, (uint)(i))
		}
	}
}

anim_clear_header :: proc(sys: ^AnimationSystem, id: uint)
{
	a := &sys.anim_store[id]
	a.total_deltas = 0
	a.runs = 0
	// a.user_phase = 0
}

anim_remove :: proc(sys: ^AnimationSystem, id: uint)
{
	sys.anim_store[id].callback = nil
}

anim_activate :: proc(sys: ^AnimationSystem, id: uint)
{
	// anim_clear_header(sys, id)
	sys.anim_store[id].state = .Active
}

anim_activate_and_reset :: proc(sys: ^AnimationSystem, id: uint)
{
	anim_clear_header(sys, id)
	anim_activate(sys, id)
}

anim_inactivate :: proc(sys: ^AnimationSystem, id: uint)
{
	// anim_clear_header(sys, id)
	sys.anim_store[id].state = .Inactive
}

anim_inactive_and_reset :: #force_inline proc(sys: ^AnimationSystem, id: uint)
{
	anim_inactivate(sys, id)
	anim_clear_header(sys, id)
}

// Stops counting runs/deltas
anim_freeze :: #force_inline proc(sys: ^AnimationSystem, id: uint)
{
	sys.anim_store[id].count_direction = 0
}

anim_set_direction_forwards :: #force_inline proc(sys: ^AnimationSystem, id: uint)
{
	sys.anim_store[id].count_direction = 1
}

anim_set_direction_backwards :: #force_inline proc(sys: ^AnimationSystem, id: uint)
{
	sys.anim_store[id].count_direction = -1
}

anim_is_first_run :: #force_inline proc(sys: ^AnimationSystem, id: uint) -> (bool)
{
	return sys.anim_store[id].runs == 0
}