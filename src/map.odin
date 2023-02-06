package SongOfTheEarth

import sdl "vendor:sdl2"

TILE_SIZE :: 32

/// TILE MAP
TileMapSystem :: struct
{
	current_map: uint,
	map_store: []TileMap,
}

TileMod :: struct
{
	at: IVector2,
	which: uint,
	args: []u8,
}

TileMap :: struct
{
	descriptive_name: string,
	env: enum { None, Snowy, Rainy, Sunny, Indoors, Cloudy },

	size: IVector2,
	tiles: []Tile,

	mods: []TileMod,
}
Tile :: u32

MAX_LAYERS :: 8
TilePutoffList :: [MAX_LAYERS][dynamic]Tile // For layered drawing

/// TMID
TMID_NONE :: 0
TMID_DEBUG :: 1

TMID_TOWN :: 2
TMID_ACADEMY_INTERIOR :: 3
TMID_TERRY_CLASS :: 4

/// TILE IDS
T_VOID :: 0
T_DEBUG :: 1

/// TMODS
TMOD_LAYER :: 0

/// TILE LAYERS
TILE_LAYER_0 :: 0
TILE_LAYER_1 :: 1
TILE_LAYER_2 :: 2
TILE_LAYER_3 :: 3
TILE_LAYER_4 :: 4
TILE_LAYER_5 :: 5
TILE_LAYER_6 :: 6
TILE_LAYER_7 :: 7

/// TM DATA
TM_DATA := TileMapSystem{
	current_map = 0,
	map_store = {
		{ // Empty (main menus, etc)
			descriptive_name = "Nothing",
			env = .None,

			size = { 1, 1 },
			tiles = { 1 },
		},
		{ // Debug
			descriptive_name = "Debug",
			env = .Indoors,
			
			size = { 3, 3 },
			tiles = {
				0, 			T_DEBUG, 0,			
				T_DEBUG, 	T_DEBUG, T_DEBUG,	
				0, 			T_DEBUG, 0,			
			},

			mods = {
				{ {1, 1}, TMOD_LAYER, {1, 0} },
			},
		},
	},
}

/// TM FUNCTIONS
tm_set_map :: #force_inline proc(sys: ^TileMapSystem, mapid: uint)
{
	sys.current_map = mapid
}

tm_get_current_ptr :: proc(sys: ^TileMapSystem) -> (^TileMap)
{
	return &sys.map_store[sys.current_map]
}

tm_draw_layer :: proc(sys: ^TileMapSystem, layer: u8, pixel_offset: IVector2)
{
	cmap := tm_get_current_ptr(sys)
	match_mod :: proc(cmap: ^TileMap, mod: uint, tile_coords: IVector2) -> (^TileMod, bool)
	{
		for m, i in &(cmap.mods)
		{
			if v2_equal(m.at, tile_coords)
			{
				return &m, true
			}
		}

		return nil, false
	}

	i := 0
	tx := 0
	ty := 0

	for
	{
		/*if sys.tiles[i].z_index == cur_z_index
		{
			drew_any_tile = true
		}*/

		match: ^TileMod
		matched: bool

		match, matched = match_mod(cmap, TMOD_LAYER, { (i32)(tx), (i32)(ty) })
		if (layer > 0 && matched && match.args[0] == layer) || layer == 0
		{
			// Draw

		}

		tx += 1
		if tx >= (int)(cmap.size.x)
		{
			tx = 0
			ty += 1
		}

		i += 1
	}
}