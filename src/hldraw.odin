package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:time"
import "core:os"
import "core:mem"
import "core:math"

import sdl "vendor:sdl2"

AlignSetting :: enum
{
	HCenter,
	VCenter,
}
AlignSet :: bit_set[AlignSetting]

/// HIGH-LEVEL DRAWING
TextDrawSettings :: struct
{
	align: AlignSet,
	scroll_mult: f32, // <0.0 -> error
}

TextScrollSystem :: struct
{
	enabled: bool,
	chars_revealed: uint,
	reveal_every: f32, // delta interval to reveal each char
	delta_count: f32,
}

/// TEXT FUNCTIONS
// @Note(text_scroll may be a nil ptr if scrolling is disabled anyway)
hl_draw_text :: proc(text_ds: TextDrawSettings, text_scroll: ^TextScrollSystem, text: string, pos: IVector2)
{
	defer
	{
		if text_scroll.enabled && text_scroll.chars_revealed < len(text)
		{
			text_scroll.delta_count += fctx.delta
			for text_scroll.delta_count >= text_scroll.reveal_every
			{
				text_scroll.delta_count -= text_scroll.reveal_every
				text_scroll.chars_revealed += 1
			}
		}
	}


}

// /// MENU BUTTON
// MenuButtonDrawSettings :: struct
// {
// 	inner_text_align: AlignSet,
	
// }

// hl_draw_menu_button :: proc(mbutton_ds: MenuButtonDrawSettings, text: string, pos: IVector2)
// {

// }