package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:intrinsics"
import "core:os"
import "core:slice"
import "core:time"
import "core:mem"

import sdl "vendor:sdl2"

DEBUG :: #config(DEBUG, false)
PRINT_SIGS :: #config(PRINT_SIGS, false)

/// SLICES, DYNAMICS
append_slice_to_dynamic :: proc(dyn: ^[dynamic]$T, slice: []T) {
	for item in slice {
		append(dyn, item)
	}
}

append_ptr_bytes_to_dynamic_byte_buffer :: proc(dyn: ^[dynamic]u8, thing: ^$T) {
	transmuted := transmute([^]u8) thing
	for k in 0..<size_of(T) {
		append(dyn, transmuted[k])
	}
}

append_ptr_bytes_to_dynamic_byte_buffer_with_len :: proc(dyn: ^[dynamic]u8, thing: ^$T, how_many: int) {
	transmuted := transmute([^]u8) thing
	for k in 0..<how_many {
		append(dyn, transmuted[k])
	}
}

// Appends raw bytes of a slice to a [dynamic]u8
// E.g. arguments (&buf, []<SomeStruct>{ ... }) would append raw bytes of the structs
append_slice_bytes_to_dynamic_byte_buffer :: proc(dyn: ^[dynamic]u8, sl: []$T)
{
	mem.copy(slice.first_ptr(dyn^[:]), slice.first_ptr(sl), size_of(T) * len(sl))
}

copy_data_from_byte_slice_to_struct :: #force_inline proc(s: ^$T, bs: []u8)
	where intrinsics.type_is_struct(T) {
	mem.copy(s, slice.first_ptr(bs), size_of(T))
}

talloc_slice :: #force_inline proc($T: typeid, els: uint, talloc := context.temp_allocator) -> ([]T) {
	return make([]T, els, talloc)
}

/// LOGGING
Logger :: struct {
	lfile: IOHandle,
}

// @private
// g_log: Logger

/*log_init :: proc() {
	io_ensure_file_static(LOG_FILE)
	f, worked := io_open_static(LOG_FILE)
	assert(worked, "Could not open log file!")
}*/

/// MATH
lerp :: proc(s, e, val: f32) -> (f32) {
	return ((val * (f32)(e - s)) + (f32)(s))
}

square :: #force_inline proc(val: f32) -> (f32) {
	return val * val
}

@private
perc_flip :: proc(val: f32) -> (f32) {
	return 1.0 - val
}

tween_ease_in :: proc(s, e, val: f32) -> (f32) {
	return lerp(s, e, val * val)
}

tween_ease_out :: proc(s, e, val: f32) -> (f32) {
	return lerp(s, e, perc_flip(square(perc_flip(val))))
}

tween_ease_in_out :: proc(s, e, val: f32) -> (f32) {
	return lerp(tween_ease_in(s, e, val), tween_ease_out(s, e, val), val)
}

FLOAT_NEAR_RANGE :: 0.0001
float_is_near :: proc(f, val: $T, range := FLOAT_NEAR_RANGE) -> (bool)
	where intrinsics.type_is_float(T) {
	return (f >= (val - T(FLOAT_NEAR_RANGE))) && (f <= (val + T(FLOAT_NEAR_RANGE)))
}

/// VECTORS
I32Vector2 :: struct { x, y: i32 }
F32Vector2 :: struct { x, y: f32 }
F64Vector2 :: struct { x, y: f64 }
IntVector2 :: struct { x, y: int }

I32Vector3 :: struct { x, y, z: i32 }
F32Vector3 :: struct { x, y, z: f32 }

I32Vector4 :: struct { x, y, z, w: i32 }
F32Vector4 :: struct { x, y, z, w: f32 }

I32Rect :: struct { x, y, w, h: i32 }
F32Rect :: struct { x, y, w, h: f32 }
L32Rect :: struct { x, y, w, h: f64 }
IntRect :: struct { x, y, w, h: int }
UVRect :: struct { x, y, x2, y2: f32 }

v2_add :: #force_inline proc(v1: ^$T, v2: T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	v1^ = {
		v1.x + v2.x,
		v1.y + v2.y,
	}
}

v2_add_im :: #force_inline proc(v1, v2: $T) -> (T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	return {
		v1.x + v2.x,
		v1.y + v2.y,
	}
}

v2_sub :: #force_inline proc(v1: ^$T, v2: T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	v1^ = {
		v1.x - v2.x,
		v1.y - v2.y,
	}
}

v2_sub_im :: #force_inline proc(v1, v2: $T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	return {
		v1.x - v2.x,
		v1.y - v2.y,
	}
}

v2_mul :: #force_inline proc(v1: ^$T, v2: T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	v1^ = {
		v1.x * v2.x,
		v1.y * v2.y,
	}
}

v2_mul_im :: #force_inline proc(v1, v2: $T) -> (T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	return {
		v1.x * v2.x,
		v1.y * v2.y,
	}
}

v2_equal :: #force_inline proc(v1, v2: $T) -> (bool)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	return (v1.x == v2.x && v1.y == v2.y)
}

v2_value_in_rangei :: proc(v: $T, val: $T2)
	where (T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2) &&
		type_of(v.x) == T2 {
	return (val >= v.x && val <= v.y)
}

v2_value_in_rangex :: #force_inline proc(v: $T, val: $T2)
	where (T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2) &&
		type_of(v.x) == T2 {
	return (val > v.x && val < v.y)
}

v2_percentage_in_range :: proc(v: $T, val: $T2) -> (T2)
	where (T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2) &&
		type_of(v.x) == T2 {
	range := v.y - v.x
	val2 := val - v.x
	return (val2 / range)
}

v2_lerp :: proc(v, v2: $T, val: f32) -> (T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	return {
		lerp(v.x, v2.x, val),
		lerp(v.y, v2.y, val),
	}
}

v2_ease_in :: proc(v, v2: $T, val: f32) -> (T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	return {
		tween_ease_in(v.x, v2.x, val),
		tween_ease_in(v.y, v2.y, val),
	}
}

v2_ease_out :: proc(v, v2: $T, val: f32) -> (T)
	where T == I32Vector2 || T == F32Vector2 || T == F64Vector2 || T == IntVector2 {
	return {
		tween_ease_out(v.x, v2.x, val),
		tween_ease_out(v.y, v2.y, val),
	}
}

v2_cast :: #force_inline proc(v1: $T, $to: typeid) -> (to)
	where intrinsics.type_is_struct(to) {
	return to{ (type_of(to.x))( v1.x ), (type_of(to.y))( v2.y ) }
}

/// RECT
rect_add :: #force_inline proc(r1: $T, r2: T) -> (T)
	where T == I32Rect || T == F32Rect || T == F64Rect || T == IntRect {
	return T{
		r1.x + r2.x,
		r1.y + r2.y,
		r1.w + r2.w,
		r1.h + r2.h,
	}
}

rect_mul :: #force_inline proc(r1: $T, r2: $T2) -> (T)
	where T == I32Rect || T == F32Rect || T == F64Rect || T == IntRect {
	return T{
		r1.x * type_of(r1.x)(r2.x),
		r1.y * type_of(r1.x)(r2.y),
		r1.w * type_of(r1.x)(r2.w),
		r1.h * type_of(r1.x)(r2.h),
	}
}

rect_mul_num :: #force_inline proc(r1: $T, val: $T2) -> (T) {
	return T{
		r1.x * type_of(r1.x)(val),
		r1.y * type_of(r1.y)(val),
		r1.w * type_of(r1.w)(val),
		r1.h * type_of(r1.h)(val),
	}
}

rect_apply_margin_rect :: #force_inline proc(r1: $T, r2: $T2) -> (T) {
	return T{
		r1.x + type_of(r1.x)(r2.x),
		r1.y + type_of(r1.y)(r2.y),
		r1.w + type_of(r1.w)(r2.w * -2),
		r1.h + type_of(r1.h)(r2.h * -2),
	}
}

rect_apply_centeropts :: #force_inline proc(r: $T, opts: CenterOpts) -> (T) {
	out := r
	if (.HCenter in opts) {
		out.x -= out.w / 2
	}

	if (.VCenter in opts) {
		out.y -= out.h / 2
	}
	
	return out
}

rect_f32toi32 :: proc(rect: F32Rect) -> (I32Rect) {
	return {
		i32(rect.x),
		i32(rect.y),
		i32(rect.w),
		i32(rect.h),
	}
}

rect_i32tof32 :: proc(rect: I32Rect) -> (F32Rect) {
	return {
		f32(rect.x),
		f32(rect.y),
		f32(rect.w),
		f32(rect.h),
	}
}

rect_grow :: proc(rect: $T, n: $T2) -> (T) {
	return {
		rect.x - type_of(rect.x)(n),
		rect.y - type_of(rect.y)(n),
		rect.w + type_of(rect.w)(n*2),
		rect.h + type_of(rect.h)(n*2),
	}
}

rect_grow_rect :: proc(rect: $T, n: $T2) -> (T) {
	return {
		rect.x - type_of(rect.x)(n.x),
		rect.y - type_of(rect.y)(n.y),
		rect.w + type_of(rect.w)(n.w*2),
		rect.h + type_of(rect.h)(n.h*2),
	}
}

rect_to_uv :: proc(viewport: IntRect, rect: IntRect) -> (UVRect) {
	return {
		x = (f32(rect.x) / f32(viewport.w)) * 2.0 - 1.0,
		y = (f32(rect.y) / f32(viewport.h)) * -2.0 + 1.0,
		x2 = (f32(rect.x + rect.w) / f32(viewport.w)) * 2.0 - 1.0,
		y2 = (f32(rect.y + rect.h) / f32(viewport.h)) * -2.0 + 1.0,
	}
}

v2_rect_collide :: proc(v2: $T, r: $T2) -> (bool) {
	return (f32(v2.x) >= f32(r.x) && f32(v2.x) <= (f32(r.x) + f32(r.w))) && (f32(v2.y) >= f32(r.y) && f32(v2.y) <= (f32(r.y) + f32(r.h)))
}

/// COLOR
Color :: sdl.Color
color_lerp :: proc(c1, c2: Color, f: f32) -> (Color) {
	return {
		cast(u8) lerp(f32(c1.r), f32(c2.r), f),
		cast(u8) lerp(f32(c1.g), f32(c2.g), f),
		cast(u8) lerp(f32(c1.b), f32(c2.b), f),
		cast(u8) lerp(f32(c1.a), f32(c2.a), f),
	}
}

/// MISC
// log
LogLevel :: enum { Note, Warn, Debug, Fatal, }
LOG_FILE :: "log.txt"
g_log_file_hnd: IOHandle
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

duration_to_f32 :: #force_inline proc(d: time.Duration) -> (f32) {
	return f32(time.duration_seconds(d))
}

// str checksum
gen_string_checksum :: proc(s: string) -> (uint) {
	if len(s) == 0 { return 0 }

	// Setup seeded RNG with first char of s as seed
	whrng: WHRngState
	#no_bounds_check { char_uint := uint(s[0]); whrng = { char_uint, char_uint, char_uint } }

	as_u8_sl := transmute([]u8) s
	out: uint = 0
	for char, i in as_u8_sl {
		out += uint(char) + uint(i) + uint(whrng_random(&whrng) * 100.0)
	}
	return out
}