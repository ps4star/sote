package SongOfTheEarth

import "core:fmt"
import "core:strings"
import "core:slice"
import "core:mem"
import "core:intrinsics"
import "core:simd"

import stbtt "vendor:stb/truetype"

// Some graphics primitives
TTF_Glyph_Info :: struct {
	stb_index: int,
}

MAX_NUM_GLYPHS_PER_LANG :: 512
TTF_Font :: struct {
	stb_font: stbtt.fontinfo,

	glyphs_head: int, // head of chars array
	glyphs: #soa[MAX_NUM_GLYPHS_PER_LANG]TTF_Glyph_Info,
}

// Software blitting functions
blit_rect :: proc(rgba: []u32, x, y, w, h, src_w: int, color: Color) {
    assert(x >= 0 && y >= 0 && x < w && y < h && src_w > -1)

    rgba_as_ptr := transmute([^]u32) slice.first_ptr(rgba) // This shouldn't be any faster than a slice set, but just to be safe

    color_u32 := transmute(u32) color
    i, j: int
    offset: int = x + (y * src_w)
    for j = 0; j < h; j += 1 {
        for i = 0; i < w; i += 1 {
            #no_bounds_check rgba_as_ptr[offset] = color_u32
            offset += 1
        }

        offset += src_w // Advance to next line at same X
        offset -= w // Now push X back to start
    }
}

blit_text :: proc(rgba: []u32, font: TTF_Font, text: string, x, y: int, src_w: int, color: Color) {
    
}