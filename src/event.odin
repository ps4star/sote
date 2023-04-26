package SongOfTheEarth
import "core:fmt"
import "core:time"
import "core:os"
import "core:intrinsics"
import "core:mem"
import "core:slice"
import "core:runtime"

import sdl "vendor:sdl2"

// Raw event accumulator
EventState :: struct {
	// Window events
	was_window_resized: bool,
	// win_w, win_h: int,
	gained_focus, lost_focus: bool,
	
	was_mouse_moved: bool,
	mouse_x, mouse_y: int,

	was_gamepad_connected: bool,
	connected_gamepad: ^sdl.GameController,
}