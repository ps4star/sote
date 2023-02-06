package SongOfTheEarth
import "core:fmt"
import "core:os"
import "core:strings"
import "core:intrinsics"
import "core:mem"
import "core:reflect"
import "core:runtime"
import "core:slice"

import rl "vendor:raylib"

Uprefs :: struct // @IOStruct
{
	target_fps: i32,

	window_size: IRect,
	window_maximized: bool,
	render_pixel_scale: i32, // [1, 2, 4, 8] are valid values

	bindings: KeyBindings,
}
UPREFS_FILE :: "uprefs"

DEFAULT_UPREFS := Uprefs{
	target_fps = 60,

	window_size = { 0, 0, 0, 0 },
	window_maximized = true,
	render_pixel_scale = 1,

	// bindings = <SET MANUALLY>,
}

DEFAULT_KEY_BINDINGS := KeyBindings{
	.Cancel = {
		{ .Key,					key_to_int(.X),						ButtonState.Down },
		{ .ControllerButton,	controller_button_to_int(.B),		ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },

		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
	},
	.Confirm = {
		{ .Key,					key_to_int(.C),						ButtonState.Down },
		{ .ControllerButton,	controller_button_to_int(.A),		ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },

		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
	},
	.Menu = {
		{ .Key,					key_to_int(.E),						ButtonState.Down },
		{ .ControllerButton,	controller_button_to_int(.Y),		ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },

		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
	},
	.MoveUp = {
		{ .ControllerQuad,		controller_quad_to_int(.LeftStickUp),	QuadState.InQuad },
		{ .Key,					key_to_int(.W),							ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },

		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
	},
	.MoveRight = {
		{ .ControllerQuad,		controller_quad_to_int(.LeftStickRight),	QuadState.InQuad },
		{ .Key,					key_to_int(.D),								ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },

		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
	},
	.MoveDown = {
		{ .ControllerQuad,		controller_quad_to_int(.LeftStickDown),		QuadState.InQuad },
		{ .Key,					key_to_int(.S),								ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },

		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
	},
	.MoveLeft = {
		{ .ControllerQuad,		controller_quad_to_int(.LeftStickLeft),		QuadState.InQuad },
		{ .Key,					key_to_int(.A),								ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },

		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
		{ KEYBIND_NIL_ENTRY,	-1, ButtonState.Down },
	},
}
uprefs_init :: proc(up: ^Uprefs)
{
	// fmt.println(DEFAULT_KEY_BINDINGS)
	f_existed := true
	if !io_exists_static(UPREFS_FILE)
	{
		io_ensure_file_static(UPREFS_FILE)
		up_file, worked := io_open_static(UPREFS_FILE, IO_OPEN_READ_WRITE)
		assert(worked, "Could not open Uprefs file for default write even after io_ensure() call (?)")

		uprefs_load_default(up)
		uprefs_write(up, up_file)
		io_close(up_file)
		f_existed = false
	}

	if f_existed
	{
		// Load uprefs
		f_data, worked := io_read_entire_file_from_name_static(UPREFS_FILE)
		assert(worked)

		uprefs_load(up, f_data)
	}
}

uprefs_write :: proc(up: ^Uprefs, file: IOHandle)
{
	io_write_ptr_len(file, up, size_of(up^))
}

uprefs_load :: proc(up: ^Uprefs, file_data: []u8)
{
	copy_data_from_byte_slice_to_struct(up, file_data)
}

uprefs_load_default :: proc(up: ^Uprefs)
{
	up^ = DEFAULT_UPREFS
	up.bindings = DEFAULT_KEY_BINDINGS
}