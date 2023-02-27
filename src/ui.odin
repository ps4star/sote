package SongOfTheEarth

UIState :: struct {
	width: int,
	layout: []FRect,
	current: int, // @Default(-1)
	wraps: bool,
}

@private anim_ui_vecs := [2]FVector2{ {0.0, 0.0}, {0.0, 0.0} }
ui_update :: proc(siglist: ^map[KeybindName]SignalTriggerInfo, state: ^UIState) {
	moved := false
	if state.current == -1 {
		if (.MoveDown in siglist^) || (.MoveUp in siglist^) || (.MoveRight in siglist^) || (.MoveDown in siglist^) {
			state.current = 0
			moved = true
		} else { return }
	}

	max_x := state.width - 1
	max_y := (len(state.layout) / state.width) - 1
	// fmt.println(max_x, max_y)

	c_x := (state.current) % state.width
	c_y := (state.current) / state.width

	if !moved {
		if (.MoveDown in siglist^) {
			if c_y + 1 > max_y {
				if state.wraps {
					c_y = 0
				} else {
					c_y = max_y
				}
			} else {
				c_y += 1
			}
			moved = true
		} else if (.MoveUp in siglist^) {
			if c_y - 1 < 0 {
				if state.wraps {
					c_y = max_y
				} else {
					c_y = 0
				}
			} else {
				c_y -= 1
			}
			moved = true
		} else if (.MoveRight in siglist^) {
			if c_x + 1 > max_x {
				if state.wraps {
					c_x = 0
				} else {
					c_x = max_x
				}
			} else {
				c_x += 1
			}
			moved = true
		} else if (.MoveLeft in siglist^) {
			if c_x - 1 < 0 {
				if state.wraps {
					c_x = max_y
				} else {
					c_x = 0
				}
			} else {
				c_x -= 1
			}
			moved = true
		}
	}

	animptr := anim_get(ANIM_UI_PTR)
	assert(animptr != nil)
	if (.PtrMove in siglist^) { // user cursor movement cancels everything
		anim_reset_inactive(ANIM_UI_PTR)
		state.current = -1
		return
	}

	if moved {
		anim_reset_active(ANIM_UI_PTR)

		next_idx := (c_x % state.width) + (c_y * state.width)
		this_layout_rect := state.layout[next_idx]

		anim_ui_vecs[0] = { this_layout_rect.x, this_layout_rect.y } // target
		anim_ui_vecs[1] = g.mouse_v2 // current mouse
		state.current = next_idx
	}

	adjusted_perc := animptr.deltas * (60 / 5)
	if animptr.active {
		final_vec := FVector2{ ((anim_ui_vecs[0].x - anim_ui_vecs[1].x)*adjusted_perc + anim_ui_vecs[1].x),
			((anim_ui_vecs[0].y - anim_ui_vecs[1].y)*adjusted_perc + anim_ui_vecs[1].y) }
		if adjusted_perc >= 1.0 {
			final_vec = anim_ui_vecs[0]
		}

		update_mouse(final_vec.x, final_vec.y, true)
	}
	if adjusted_perc >= 1.0 {
		anim_reset_inactive(ANIM_UI_PTR)
		return
	}
}

ui_snap :: proc(state: ^UIState) {
	if state.current == -1 { return }
	if !anim_active(ANIM_UI_PTR) { return }

	anim_reset_inactive(ANIM_UI_PTR)
	update_mouse(anim_ui_vecs[0].x, anim_ui_vecs[0].y, true)
}