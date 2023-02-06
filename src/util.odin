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

/// SLICES, DYNAMICS
append_slice_to_dynamic :: proc(dyn: ^[dynamic]$T, slice: []T)
{
	for item in slice
	{
		append(dyn, item)
	}
}

append_ptr_bytes_to_dynamic_byte_buffer :: proc(dyn: ^[dynamic]u8, thing: ^$T)
{
	transmuted := transmute([^]u8) thing
	for k in 0..<size_of(T)
	{
		append(dyn, transmuted[k])
	}
}

append_ptr_bytes_to_dynamic_byte_buffer_with_len :: proc(dyn: ^[dynamic]u8, thing: ^$T, how_many: int)
{
	transmuted := transmute([^]u8) thing
	for k in 0..<how_many
	{
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
	where intrinsics.type_is_struct(T)
{
	mem.copy(s, slice.first_ptr(bs), size_of(T))
}

talloc_slice :: #force_inline proc($T: typeid, els: uint, talloc := context.temp_allocator) -> ([]T)
{
	return make([]T, els, talloc)
}

/// LOGGING
LogLevel :: enum
{
	Note,
	Warn,
	Debug,
	Fatal,
}

Logger :: struct
{
	lfile: IOHandle,
}

@private
g_log: Logger

LOG_FILE :: "log.txt"
log_init :: proc()
{
	io_ensure_file_static(LOG_FILE)
	f, worked := io_open_static(LOG_FILE)
	assert(worked, "Could not open log file!")
}

log :: proc(level: LogLevel, _fmt: ..any)
{
	finalstr := fmt.tprintln(_fmt)

	switch level {
	case .Debug:
		when !DEBUG {
			return
		}
		fallthrough
	case .Note, .Warn:
		// Matches here if .Debug level when DEBUG is false
		fmt.print(finalstr)
		io_write_string(g_log.lfile, finalstr)
	case .Fatal:
		fmt.print(finalstr)
		io_write_string(g_log.lfile, finalstr)
		panic("")
	}
}

log_shutdown :: proc()
{
	io_close(g_log.lfile)
}

/// MATH
lerp :: proc(s, e: $T, val: f32) -> (T)
	where intrinsics.type_is_numeric(T)
{
	return (T)((val * (f32)(e - s)) + (f32)(s))
}

square :: #force_inline proc(val: f32) -> (f32)
{
	return val * val
}

@private
perc_flip :: proc(val: f32) -> (f32)
{
	return 1.0 - val
}

tween_ease_in :: proc(s, e: $T, val: f32) -> (T)
{
	return lerp(s, e, val * val)
}

tween_ease_out :: proc(s, e: $T, val: f32) -> (T)
{
	return lerp(s, e, perc_flip(square(perc_flip(val))))
}

tween_ease_in_out :: proc(s, e: $T, val: f32) -> (T)
{
	return lerp(tween_ease_in(val), tween_ease_out(val), val)
}

/// VECTORS
IVector2 :: struct { x, y: i32 }
FVector2 :: struct { x, y: f32 }
LVector2 :: struct { x, y: f64 }

IRect :: struct { x, y, w, h: i32 }
FRect :: sdl.FRect
LRect :: struct { x, y, w, h: f64 }

v2_add :: #force_inline proc(v1: ^$T, v2: T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	v1^ = {
		v1.x + v2.x,
		v1.y + v2.y,
	}
}

v2_add_im :: #force_inline proc(v1, v2: $T) -> (T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	return {
		v1.x + v2.x,
		v1.y + v2.y,
	}
}

v2_sub :: #force_inline proc(v1: ^$T, v2: T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	v1^ = {
		v1.x - v2.x,
		v1.y - v2.y,
	}
}

v2_sub_im :: #force_inline proc(v1, v2: $T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	return {
		v1.x - v2.x,
		v1.y - v2.y,
	}
}

v2_mul :: #force_inline proc(v1: ^$T, v2: T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	v1^ = {
		v1.x * v2.x,
		v1.y * v2.y,
	}
}

v2_mul_im :: #force_inline proc(v1, v2: $T) -> (T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	return {
		v1.x * v2.x,
		v1.y * v2.y,
	}
}

v2_equal :: #force_inline proc(v1, v2: $T) -> (bool)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	return (v1.x == v2.x && v1.y == v2.y)
}

v2_value_in_rangei :: proc(v: $T, val: $T2)
	where (T == IVector2 || T == FVector2 || T == LVector2) &&
		type_of(v.x) == T2
{
	return (val >= v.x && val <= v.y)
}

v2_value_in_rangex :: #force_inline proc(v: $T, val: $T2)
	where (T == IVector2 || T == FVector2 || T == LVector2) &&
		type_of(v.x) == T2
{
	return (val > v.x && val < v.y)
}

v2_percentage_in_range :: proc(v: $T, val: $T2) -> (T2)
	where (T == IVector2 || T == FVector2 || T == LVector2) &&
		type_of(v.x) == T2
{
	range := v.y - v.x
	val2 := val - v.x
	return (val2 / range)
}

v2_lerp :: proc(v, v2: $T, val: f32) -> (T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	return {
		lerp(v.x, v2.x, val),
		lerp(v.y, v2.y, val),
	}
}

v2_ease_in :: proc(v, v2: $T, val: f32) -> (T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	return {
		tween_ease_in(v.x, v2.x, val),
		tween_ease_in(v.y, v2.y, val),
	}
}

v2_ease_out :: proc(v, v2: $T, val: f32) -> (T)
	where T == IVector2 || T == FVector2 || T == LVector2
{
	return {
		tween_ease_out(v.x, v2.x, val),
		tween_ease_out(v.y, v2.y, val),
	}
}

v2_cast :: #force_inline proc(v1: $T, $to: typeid) -> (to)
	where intrinsics.type_is_struct(to)
{
	return to{ (type_of(to.x))( v1.x ), (type_of(to.y))( v2.y ) }
}

/// RECT
rect_add :: #force_inline proc(r1: ^$T, r2: T)
	where T == IRect || T == FRect || T == LRect
{
	r1^ = {
		r1.x + r2.x,
		r1.y + r2.y,
		r1.w + r2.w,
		r1.h + r2.h,
	}
}

rect_mul :: #force_inline proc(r1: ^$T, r2: T)
	where T == IRect || T == FRect || T == LRect
{
	r1^ = {
		r1.x * r2.x,
		r1.y * r2.y,
		r1.w * r2.w,
		r1.h * r2.h,
	}
}

rect_cast :: proc(irect: IRect, $to: typeid) -> (to)
	where intrinsics.type_is_struct(to)
{
	_to := to{}
	return {
		(type_of(_to.x))(irect.x),
		(type_of(_to.y))(irect.y),
		(type_of(_to.w))(irect.w),
		(type_of(_to.h))(irect.h),
	}
}

/// COLOR
Color :: sdl.Color

color_lerp_im :: proc(c1, c2: Color, f: f32) -> (Color)
{
	return {
		lerp(c1.r, c2.r, f),
		lerp(c1.g, c2.g, f),
		lerp(c1.b, c2.b, f),
		lerp(c1.a, c2.a, f),
	}
}

/// MISC
duration_to_f32 :: #force_inline proc(d: time.Duration) -> (f32)
{
	return (f32)(time.duration_seconds(d))
}