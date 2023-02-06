package SongOfTheEarth
import "core:fmt"
import "core:os"

import rl "vendor:raylib"

Alteration :: enum
{
	// None,
	/// PER-ENTITY
	HP,
	MaxHP,
	Dex,
	Intl,

	S_Survivalist,
	S_Scavenger, // Find items randomly and after battles

	/// GLOBAL / PER-PARTY
	G_Deception,
}

AlterationDegreePair :: struct
{
	which: Alteration,
	degree: int, // around [-10, 10] incl. 0 for the range on this

	count, max_count: uint,
}

FightEntity :: struct
{
	hp, max_hp,
	dex,
	intl: uint,

	alterations: [dynamic]AlterationDegreePair,
}

Enemy :: struct
{

}

PartyMember :: struct
{

}

