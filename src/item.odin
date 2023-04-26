package SongOfTheEarth

WhichItem :: enum {
	None = 0, // nil

	// In-battle use
	Water,

	// Components
	InsectPart,

	// Chemicals
	H,
	C,
	O,

	// KeyItems
	ArsBellici,
	CraftersManual,
}
ItemSlot :: struct { item: WhichItem, quantity: u32 }

MAX_NUM_INV_ITEMS :: 2_048
ITEM_CAP :: 999
ITEM_META_INFO := [WhichItem]struct {
	name: string,
	type: bit_set[enum {
		Item,
		Item_Curative,

		Component,

		Chemical,

		KeyItem,
		KeyItem_Tome,
	}],
	decomposes: []struct { base_amount: int, which: WhichItem },

	// ITM info
	segments: int,
	move: ITMProc,
}{
	.None = {					name="NIL",				type={},									decomposes={},							segments=0 },

	// ITM-usable
	.Water = { 					name="I_WATER",			type={ .Item, .Item_Curative },				decomposes={{32, .H}, {16, .O}},		segments=2, move=ITMProc_Water},

	// Components
	.InsectPart = {				name="I_INSECTP",		type={ .Component },						decomposes={{8, .C}, {4, .O}} },

	// Chemicals
	.H = {						name="I_HYDROGEN",		type={ .Chemical },							decomposes=nil },
	.C = {						name="I_CARBON",		type={ .Chemical },							decomposes=nil },
	.O = {						name="I_OXYGEN",		type={ .Chemical },							decomposes=nil },

	.ArsBellici = {				name="I_ARSB",			type={ .KeyItem, .KeyItem_Tome }, 			decomposes=nil, },
	.CraftersManual = { 		name="I_CRAFM",			type={ .KeyItem, .KeyItem_Tome }, 			decomposes=nil, },
}

ITMProc :: proc(bstate: ^BattleState)
ITMProc_Water :: proc(bstate: ^BattleState) { bat_heal(bstate, 40, .AllParty) }