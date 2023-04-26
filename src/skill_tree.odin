package SongOfTheEarth

/*
TOMES
Ars Bellici
	- unlocks Terry:Ars Bellici
	- unlocks OBL role in Terry:Intuition (if unchosen)

Crafter's Manual
	- unlocks Terry:Crafter's Manual
	- unlocks ITM role in Terry:Intuition (if unchosen)
*/

/*
TERRY:INTUITION







	  (RL: OBL)      (RL: ITM)
      (LK=ArsB)      (LK=CrafM)
				FORK
				|
				(Survivalist - Terry is more likely to dodge enemy attacks; EVA +25%)
				|
			    (Scavenger - Terry may randomly pick up items; initial chance 10% from battles or (10% / 100) chance per step)
			    |
			    (Creativity - unlocks crafting in the menu; unlocks when ST unlocks)
				- BEGINNING -


*/
StaticSkillTreeNode :: struct {
	name, desc: string,
	advance: []struct { angle: enum { Up, UpLeft, UpRight, Left, Right, Down, DownLeft, DownRight }, node: int },
	tomes_required: []WhichItem, // only applies to fork paths (len(advance) >= 2); see <item.odin>
}

StaticSkillTreeDef :: struct {
	nodes: []StaticSkillTreeNode,
}

TERRY_ST_INTUITION := StaticSkillTreeDef{
	nodes = {
		{ // 0 (Creativity)
			name = "ST_TERRY_CREATIVITY_NAME",
			desc = "ST_TERRY_CREATIVITY_DESC",
			advance = { {.Up, 1} }, // -> (Scavenger)
		},
		{ // 1 (Scavenger)
			name = "ST_TERRY_SCAVENGER_NAME",
			desc = "ST_TERRY_SCAVENGER_DESC",
			advance = { {.Up, 2} }, // -> (Survivalist)
		},
		{ // 2 (Survivalist)
			name = "ST_TERRY_SURVIVALIST_NAME",
			desc = "ST_TERRY_SURVIVALIST_DESC",
			advance = { {.UpLeft, 3}, {.UpRight, 4} }, // -> (RL: OBL) || (RL: ITM)

			tomes_required = { .ArsBellici, .CraftersManual },
		},
		{ // 3 (Role: Obliterator)
			name = "ST_TERRY_RLOBL_NAME",
			desc = "ST_TERRY_RLOBL_DESC",
			advance = nil,
		},
		{ // 4 (Role: Itemer)
			name = "ST_TERRY_RLITM_NAME",
			desc = "ST_TERRY_RLITM_DESC",
			advance = nil,
		},
	},
}

StaticSkillTreeMetaItem :: struct {
	char: int,
	tome_required: WhichItem,
}
SKILL_TREE_META := [?][NUM_CHARACTERS]StaticSkillTreeMetaItem{
	{ // Terry [0]
		{ // Terry:Intuition
			char = TERRY,
			tome_required = .None,
		},
		{ // Terry:Ars Bellici

		},
		{ // Terry:Crafter's Manual

		},
	},
	{ // Viola [1]

	},
}