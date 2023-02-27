package SongOfTheEarth
import "core:fmt"
import "core:time"
import "core:os"
import "core:intrinsics"
import "core:mem"
import "core:slice"
import "core:runtime"

import rl "vendor:raylib"

Keycode :: rl.KeyboardKey
// Event :: sdl.Event
ControllerButton :: rl.GamepadButton
ControllerQuad :: enum {
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
QuadState :: enum { EntersQuad, LeavesQuad, InQuad, OutOfQuad }
InputState :: union {
	ButtonState,
	QuadState,
}

KeyEvent :: struct {
	state: ButtonState,
	key: Keycode,
}

PointerEventType :: enum { None, Move, Click }
MouseButton :: rl.MouseButton
MouseEvent :: struct {
	pos: IVector2,
	// fpos: FVector2,
	pointer_event_type: PointerEventType,
	button: MouseButton,
	state: ButtonState,
}

ControllerEvent :: struct {
	pos: IVector2,
	// fpos: FVector2,
	pointer_event_type: PointerEventType,
	button: ControllerButton,
	state: ButtonState,
	axis: ControllerQuad,
}

Event :: union {
	KeyEvent,
	MouseEvent,
	ControllerEvent,
}

/// HIGH-LEVEL INPUT -> SIGNAL BINDING
KeybindMethod :: enum i32 {
	None,
	Key,
	MouseMovement,
	MouseButton,
	ControllerButton,
	ControllerQuad,
}

KeybindName :: enum {
	// None,
	Confirm,
	Cancel,
	Menu,

	MoveUp,
	MoveRight,
	MoveDown,
	MoveLeft,

	PtrMove,

	DEBUG,
}

KeybindInput :: [4]struct { method: KeybindMethod, key: i32, state: InputState }
KeybindInputSet :: [8]KeybindInput // OR the outers, AND the inners

KeyBindings :: [KeybindName]KeybindInputSet

/// CONVERSIONS FOR KEYBINDS
key_to_int :: proc(key: Keycode) -> (i32) { return i32(key) }
mouse_button_to_int :: proc(mb: MouseButton) -> (i32) { return i32(mb) }
controller_button_to_int :: proc(controller: ControllerButton) -> (i32) { return i32(controller) }
controller_quad_to_int :: proc(controller: ControllerQuad) -> (i32) { return i32(controller) }

// Holds info on controllers
Controller :: struct {
	recognized: bool, // @Default(false)
	axis_movements: [rl.GamepadAxis]f32,
	axis_movement_deltas: [rl.GamepadAxis]f32,
}

// KeyBindingState :: bool
// KeyBindingStates :: [KEYBIND_SLOTS]KeyBindingState
ControllerMovementInfo :: [][rl.GamepadAxis]f32

SignalExtraControllerQuad :: ControllerMovementInfo
SignalExtra :: union {
	SignalExtraControllerQuad,
}

SignalTriggerInfo :: struct {
	active: bool,
	triggered_bindings: [dynamic]^KeybindInput,
	extra: SignalExtra,
}

/// RAW INPUT -> ABSTRACT SIGNAL CONVERSION
event_get_signal_analysis_from_events :: proc(bindings: ^KeyBindings, controllers: ^[$N]Controller, mouse_delta: FVector2, alloc := context.allocator) -> (out: map[KeybindName]SignalTriggerInfo) {
	set_signal :: #force_inline proc(m: ^map[KeybindName]SignalTriggerInfo, index: KeybindName, binds: [dynamic]^KeybindInput, extra: SignalExtra, to_set: bool) {
		m^[index] = SignalTriggerInfo{
			active = to_set,
			triggered_bindings = binds,
			extra = extra,
		}		
	}

	out = make(type_of(out), 16, alloc)
	extra: SignalExtra
	has: bool
	for bind_name, i in bindings^ {
		triggered_bindings := make([dynamic]^KeybindInput, 0, 24, context.temp_allocator)
		for bindlist, j in bindings^[i] {
			value := false
			each_bind_loop: for bind, k in bindings^[i][j] {
				if bind.method != .None && bind.key > -1 {
					cond := false

					switch bind.method {
					case .None: // Will never happen
					case .Key:
						unpacked_state, is_button := bind.state.(ButtonState)
						assert(is_button, fmt.tprintln(".Key signal gen failed; InputState is not ButtonState"))

						cond = unpacked_state == .Down ? rl.IsKeyPressed(cast(Keycode) bind.key) : rl.IsKeyReleased(cast(Keycode) bind.key)
						if !cond {
							ch: rune
							for {
								ch = rl.GetCharPressed()
								if ch == 0 { break }

								cond ||= rune(u8(bind.key)) == ch
							}
						}
						extra = nil
					case .MouseMovement:
						cond = !(float_is_near(mouse_delta.x, 0)) && !(float_is_near(mouse_delta.y, 0))
						extra = nil
					case .MouseButton:
						unpacked_state, is_mb := bind.state.(ButtonState)
						assert(is_mb, fmt.tprintln(".MouseButton signal gen failed; InputState is not ButtonState"))

						cond = unpacked_state == .Down ? rl.IsMouseButtonPressed(MouseButton(bind.key)) : rl.IsMouseButtonReleased(MouseButton(bind.key))
						extra = nil
					case .ControllerButton:
						unpacked_state, is_joybutton := bind.state.(ButtonState)
						assert(is_joybutton, fmt.tprintln(".ControllerButton signal gen failed; InputState is not ButtonState"))

						i: i32 = 0
						for {
							if rl.IsGamepadAvailable(i) {
								if unpacked_state == .Down {
									cond ||= rl.IsGamepadButtonPressed(i, cast(ControllerButton) bind.key)
								} else if unpacked_state == .Up {
									cond ||= rl.IsGamepadButtonReleased(i, cast(ControllerButton) bind.key)
								}
							} else {
								break
							}

							i += 1
						}

						extra = nil
					case .ControllerQuad:
						unpacked_state, is_quad := bind.state.(QuadState)
						log_assert(is_quad, fmt.tprintln(".ControllerQuad signal gen failed; InputState is not QuadState"))

						check_motion :: proc(controllers: ^[$N2]Controller, which: []rl.GamepadAxis, pos_or_neg: []f32, delta: bool) -> (bool) {
							log_assert(len(which) == len(pos_or_neg), "check_motion: axis and pos_or_neg slice length mismatch")
							log_assert(len(which) <= 6, "check_motion: length of slices must be <=6")

							out := false
							i: i32 = 0
							for gpad in controllers^ {
								for axis, j in which {
									movement := gpad.axis_movement_deltas[axis]
									static_pos := gpad.axis_movements[axis]
									if float_is_near(pos_or_neg[j], 0) { // either -1 or 1
										if delta {
											out ||= !float_is_near(movement, 0)
										} else {
											out ||= !float_is_near(static_pos, 0)
										}
									} else if float_is_near(pos_or_neg[j], -1) {
										out ||= (f32(movement) if delta else static_pos) < 0
									} else if float_is_near(pos_or_neg[j], 1) {
										out ||= (f32(movement) if delta else static_pos) > 0
									}
								}
								i += 1
							}
							return out
						}

						key := ControllerQuad(bind.key)
						check_delta: bool
						if unpacked_state == .EntersQuad {
							check_delta = true
						} else if unpacked_state == .InQuad {
							check_delta = false
						} else if unpacked_state == .OutOfQuad {
							check_delta = false
						} else {
							fmt.println(".LeavesQuad case not implemented:", i, bindings^[i][j])
							panic("")
						}

						if key == .LeftStickMotion {
							cond = check_motion(controllers, { .LEFT_X, .LEFT_Y }, { 0, 0 }, check_delta)
						} else if key == .LeftStickUp {
							cond = check_motion(controllers, { .LEFT_Y }, { -1 }, check_delta)
						} else if key == .LeftStickDown {
							cond = check_motion(controllers, { .LEFT_Y }, { 1 }, check_delta)
						}

						if unpacked_state == .OutOfQuad {
							cond = !cond
						}
					}

					if cond {
						value = true
					} else {
						value = false
						break each_bind_loop
					}
				}
			}
			if value {
				append(&triggered_bindings, &(bindings^[i][j]))
				set_signal(&out, i, triggered_bindings, extra, true)
				break // since rest are ORs, we don't need to check anything past first true
			}
		}
	}
	return out
}
// has_signal :: #force_inline proc(siglist: ^map[KeybindName]SignalTriggerInfo, index: KeybindName) -> (bool) { return siglist^[index].active }
trigger_includes_method :: #force_inline proc(trig: ^SignalTriggerInfo, test_method: KeybindMethod) -> (bool) {
	out := false
	for b, j in trig^.triggered_bindings {
		for _, i in b {
			this := &(b[i])
			if this.key < 0 { continue }
			out ||= (this.method == test_method)
		}
	}
	return out
}