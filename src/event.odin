package SongOfTheEarth
import "core:fmt"
import "core:time"
import "core:os"
import "core:intrinsics"
import "core:mem"
import "core:slice"
import "core:runtime"

import sdl "vendor:sdl2"

Keycode :: sdl.Keycode
// Event :: sdl.Event
ControllerButton :: sdl.GameControllerButton
ControllerQuad :: enum
{
	LeftStickUp,
	LeftStickRight,
	LeftStickDown,
	LeftStickLeft,
	LeftStickMotion,

	RightStickUp,
	RightStickRight,
	RightStickDown,
	RightStickLeft,
	RightStickMotion,

	AnyStickMotion,
}

ButtonState :: enum { Down, Up }
QuadState :: enum { InQuad, OutOfQuad }
InputState :: union
{
	ButtonState,
	QuadState,
}

KeyEvent :: struct
{
	delta_state: ButtonState,
	key: sdl.Keycode,
}

PointerEventType :: enum { None, Move, Click }
MouseButton :: enum int { Left = 1, Middle = 2, Right = 3, X1 = 4, X2 = 5 }
MouseEvent :: struct
{
	pos: IVector2,
	// fpos: FVector2,
	pointer_event_type: PointerEventType,
	button: MouseButton,
	delta_state: ButtonState,
}

ControllerEvent :: struct
{
	pos: IVector2,
	// fpos: FVector2,
	pointer_event_type: PointerEventType,
	button: ControllerButton,
	delta_state: ButtonState,
	axis: ControllerQuad,
}

/// HIGH-LEVEL INPUT -> SIGNAL BINDING
KeybindMethod :: enum i32
{
	None,
	Key,
	ControllerButton,
	ControllerQuad,
}

KeybindName :: enum
{
	// None,
	Confirm,
	Cancel,
	Menu,

	MoveUp,
	MoveRight,
	MoveDown,
	MoveLeft,
}

KEYBIND_NIL_ENTRY :: KeybindMethod.None
KeybindInput :: struct { method: KeybindMethod, key: i32, state: InputState }
KeybindInputSet :: [8]KeybindInput
KeyBindings :: [KeybindName]KeybindInputSet

/// CONVERSIONS FOR KEYBINDS
key_to_int :: proc(key: sdl.Keycode) -> (i32) { return (i32)(key) }
controller_button_to_int :: proc(controller: sdl.GameControllerButton) -> (i32) { return (i32)(controller) }
controller_quad_to_int :: proc(controller: ControllerQuad) -> (i32) { return (i32)(controller) }

// Holds info on controllers
Controller :: struct
{
	index: i32,
	ptr: ^sdl.GameController,
	type: sdl.GameControllerType,
}

// KeyBindingState :: bool
// KeyBindingStates :: [KEYBIND_SLOTS]KeyBindingState
SignalTriggerInfo :: struct
{
	active: bool,
	triggered_binding: ^KeybindInput,
	event_ptr: rawptr,
}

EventAnalysis :: struct
{
	key_events: [dynamic]KeyEvent,
	mouse_events: [dynamic]MouseEvent,
	controller_events: [dynamic]ControllerEvent,

	runtime_signal_states: [KeybindName]SignalTriggerInfo,

	controllers: [dynamic]Controller,
}

/// NOTE
/// On the interface side, there is a distinction between mouse button/other mouse evts
/// Internally, mouse events are all 1 thingy

/// NOTE
/// For default key bindings, see <uprefs.odin>

/// EVT MGMT
event_init :: proc(ea: ^EventAnalysis, alloc := context.allocator)
{
	ea.mouse_events = make([dynamic]MouseEvent, 0, 20, alloc)
	ea.key_events = make([dynamic]KeyEvent, 0, 20, alloc)
	ea.controller_events = make([dynamic]ControllerEvent, 0, 20, alloc)

	ea.controllers = make([dynamic]Controller, 0, 32, alloc)

	// Open up game controllers found on system
	num_joysticks := sdl.NumJoysticks()
	if num_joysticks < 1
	{
		log(.Note, "No joysticks connected on initial check")
	}

	for i in 0..<num_joysticks
	{
		// Try to open each joystick as a gamepad
		is_gpad := sdl.IsGameController(i)
		if is_gpad
		{
			gpad_ptr := sdl.GameControllerOpen(i)
			if gpad_ptr == nil
			{
				log(.Warn, "Tried to <SDL>.GameControllerOpen a detected Joystick but it returned nil")
				continue
			}

			gpad_type := sdl.GameControllerGetType(gpad_ptr)
			if gpad_type == .UNKNOWN
			{
				log(.Warn, "Gamepad type is .UNKNOWN; continuing anyway.")
			}

			append(&ea.controllers, Controller{
				index = i,
				ptr = gpad_ptr,
				type = gpad_type,
			})
		} else
		{
			log(.Note, "Device connected but isn't a recognized gamepad.")
		}
	}
}

event_begin :: proc(ea: ^EventAnalysis)
{
	clear(&fctx.evt_analysis.key_events)
	clear(&fctx.evt_analysis.mouse_events)
	clear(&fctx.evt_analysis.controller_events)
}

event_push_key :: proc(ea: ^EventAnalysis, key: Keycode, down_or_up: ButtonState)
{
	append(&ea.key_events, KeyEvent{ delta_state = down_or_up, key = key })
}

event_push_mouse_button :: proc(ea: ^EventAnalysis, mouse_button: MouseButton, down_or_up: ButtonState)
{
	append(&ea.mouse_events, MouseEvent{
		pointer_event_type = .Click,
		delta_state = down_or_up,

		button = mouse_button,
	})
}

event_push_mouse_move :: proc(ea: ^EventAnalysis, pos: IVector2, down_or_up: ButtonState)
{
	append(&ea.mouse_events, MouseEvent{
		pointer_event_type = .Move,
		delta_state = down_or_up,

		pos = pos,
	})
}

event_push_controller_axis :: proc(ea: ^EventAnalysis, axis: ControllerQuad, pos: IVector2)
{
	append(&ea.controller_events, ControllerEvent{
		pointer_event_type = .Move,

		pos = pos,
		axis = axis,
	})
}

event_push_controller_button :: proc(ea: ^EventAnalysis, button: ControllerButton, down_or_up: ButtonState)
{
	append(&ea.controller_events, ControllerEvent{
		pointer_event_type = .None,
		delta_state = down_or_up,

		button = button,
	})
}

/// EVT CHECKING
event_check_key :: proc(ea: ^EventAnalysis, key: Keycode, down_or_up: ButtonState) -> (^KeyEvent, bool)
{
	for evt in &(ea.key_events)
	{
		if evt.key == key && evt.delta_state == down_or_up
		{
			return &evt, true
		}
	}

	return nil, false
}

event_check_controller_button :: proc(ea: ^EventAnalysis, button: ControllerButton, down_or_up: ButtonState) -> (^ControllerEvent, bool)
{
	for evt in &(ea.controller_events)
	{
		if evt.pointer_event_type == .None && evt.button == button && evt.delta_state == down_or_up
		{
			return &evt, true
		}
	}

	return nil, false
}

event_check_controller_axis :: proc(ea: ^EventAnalysis, axis: ControllerQuad) -> (^ControllerEvent, bool)
{
	for evt in &(ea.controller_events)
	{
		if evt.pointer_event_type == .Move && evt.axis == axis
		{
			return &evt, true
		}
	}

	return nil, false
}

event_check_mouse_button :: proc(ea: ^EventAnalysis, mouse_button: MouseButton, down_or_up: ButtonState) -> (^MouseEvent, bool)
{
	for evt in &(ea.mouse_events)
	{
		if evt.pointer_event_type == .Click && evt.button == mouse_button && evt.delta_state == down_or_up
		{
			return &evt, true
		}
	}

	return nil, false
}

/// RAW INPUT -> ABSTRACT SIGNAL CONVERSION
event_has_signal :: #force_inline proc(ea: ^EventAnalysis, signal: KeybindName) -> (bool)
{
	return ea.runtime_signal_states[signal].active
}

event_get_signal_trigger_info :: proc(ea: ^EventAnalysis, signal: KeybindName) -> (^SignalTriggerInfo)
{
	if !event_has_signal(ea, signal)
	{
		log(.Warn, "Requested info on a signal not triggered this frame. Weird.")
	}

	return &ea.runtime_signal_states[signal]
}

event_check_signal :: #force_inline proc(ea: ^EventAnalysis, signal: KeybindName) -> (^SignalTriggerInfo, bool)
{
	return event_get_signal_trigger_info(ea, signal), event_has_signal(ea, signal)
}

event_generate_signals_from_analysis :: proc(ea: ^EventAnalysis, bindings: ^KeyBindings)
{
	set_signal :: #force_inline proc(ea: ^EventAnalysis, index: KeybindName, bind: ^KeybindInput, evt: rawptr, to_set: bool)
	{
		ea.runtime_signal_states[index].active = to_set
		ea.runtime_signal_states[index].triggered_binding = bind
		ea.runtime_signal_states[index].event_ptr = evt
	}

	for _, i in ea.runtime_signal_states
	{
		set_signal(ea, i, nil, nil, false) // No signals initially
		for bind, j in bindings[i]
		{
			if bind.method != .None && bind.key > -1
			{
				switch bind.method {
				case .None: // Will never happen
				case .Key:
					unpacked_state, is_button := bind.state.(ButtonState)
					assert(is_button, fmt.tprintln(".Key signal gen failed; InputState is not ButtonState"))

					if check, has := event_check_key(ea, (Keycode)(bind.key), unpacked_state); has
					{
						set_signal(ea, i, &bindings[i][j], check, true)
					}
				case .ControllerButton:
					unpacked_state, is_joybutton := bind.state.(ButtonState)
					assert(is_joybutton, fmt.tprintln(".ControllerButton signal gen failed; InputState is not ButtonState"))

					if check, has := event_check_controller_button(ea, (ControllerButton)(bind.key), unpacked_state); has
					{
						set_signal(ea, i, &bindings[i][j], check, true)
					}
				case .ControllerQuad:
					unpacked, is_quad := bind.state.(QuadState)
				}
			}
		}
	}
}