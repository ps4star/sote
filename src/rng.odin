package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:mem"
import "core:math/linalg"
import "core:os"
import "core:time"

/// SIMPLE RNG
// Wichmann-hill PRNG
WHRngState :: struct
{
	a, b, c: uint,
}

ACAP :: 30_269
BCAP :: 30_307
CCAP :: 30_323

whrng_initialize_from_clock :: proc(s: ^WHRngState)
{
	now_t := (time.read_cycle_counter() / 2) + (u64)(time.now()._nsec / 2)

	s.a = (uint)(now_t & (0xFFF << 0)) % ACAP
	s.b = (uint)(now_t & (0xFFF << 5)) % BCAP
	s.c = (uint)(now_t & (0xFFF << 13)) % CCAP
}

whrng_call :: proc(s: ^WHRngState)
{
	s.a = (171 * s.a) % ACAP
	s.b = (172 * s.b) % BCAP
	s.c = (170 * s.c) % CCAP
}

whrng_random :: proc(s: ^WHRngState, call := true) -> (f32)
{
	if call { whrng_call(s) } // Advance RNG prior to usage
	temp := f32(s.a)/f32(ACAP) + f32(s.b)/f32(BCAP) + f32(s.c)/f32(CCAP)
	return temp - (f32)(linalg.floor(temp))
}

whrng_randint :: proc(s: ^WHRngState, start, end: int, call := true) -> (int)
{
	return (int)(linalg.floor(whrng_random(s, call) * (f32)(end - start + 1))) + start
}

whrng_randfloat :: proc(s: ^WHRngState, start, end: f32, call := true) -> (f32)
{
	return ((whrng_random(s, call) * (f32)(end - start))) + start
}

/// SEEDS
translate_string_seed_to_numeric :: proc(str_seed: string, loc := #caller_location) -> (int)
{
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	as_u8_sl := transmute([]u8) str_seed

	for ch in as_u8_sl
	{
		if ch >= u8('0') && ch <= u8('9')
		{
			strings.write_int(&sb, (int)(ch - '0'))
		} else
		{
			strings.write_int(&sb, (int)(ch))
		}
	}

	builder_as_str := strings.to_string(sb)
	// fmt.println(builder_as_str)
	out, succ := strconv.parse_int(builder_as_str)
	if !succ { fmt.println("Error in translate_string_to_numeric!", loc); panic("") }
	return out
}