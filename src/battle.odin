package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:time"
import "core:os"
import "core:intrinsics"
import "core:mem"
import "core:strconv"

import sdl "vendor:sdl2"

WhichAlteration :: enum {
	G_Scavenger,
	G_Survivalist,
}

Alteration :: struct {
	which: WhichAlteration,
	degree: int,
	turns_left: int, // -1 = infinite
}

Entity :: struct {
	hp, max_hp,
	dext,
	intl: i32,

	alterations: [dynamic]Alteration,
}

PartyMember :: struct {
	using entity: Entity,
	items: ItemInventory,
	recruited: bool,
}

Enemy :: struct {
	using entity: Entity,
}