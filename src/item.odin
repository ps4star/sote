package SongOfTheEarth

WhichItem :: enum {
	// KeyItems
	ArsBellici,
	CraftersManual,
}
ItemInventory :: [dynamic]struct { item: WhichItem, quantity: int }

ITEM_CAP :: 999
ITEM_META_INFO := [WhichItem]struct {
	type: enum {
		Item_Curative,
		KeyItem_Tome,
	},
}{
	.ArsBellici = { type=.KeyItem_Tome },
	.CraftersManual = { type=.KeyItem_Tome },
}