package SongOfTheEarth
import "core:fmt"
import "core:strings"

/// FOR MENU ANIMATION/HANDLING CODE, SEE PANIMPROC_MENU IN <anim.odin>

PartyMenuLayer :: enum
{
	Base,
		Create,
			Craft,
			Dismantle,
		SkillTree,
		Equip,
		Items,
			Battle,
			Components,
			Chemicals,
			KeyItems,
}

MenuStateSaveLocation :: enum
{
	PartyMenu, // cursor
	Battle, // cursors for all 3 members
}

MENU_NUM_STATES_PER_SET :: 8
MenuStateSaveSet :: [MenuStateSaveLocation][MENU_NUM_STATES_PER_SET]u8