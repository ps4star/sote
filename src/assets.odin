package SongOfTheEarth
import "core:fmt"

import sdl "vendor:sdl2"

Asset :: struct
{
	state: enum uint { NotLoaded = 0, LoadedRAM, LoadedVRAM },

	
}

/// ASSETS SYS
ASSET_TERRY_PORT :: "terry_port"
ASSET_VIOLA_PORT :: "viola_port"
ASSET_DEX_PORT :: "dex_port"

ASSET_FULLBG_INTRO :: "fullbg_intro"

ASSET_DIR :: "assets"
ASSET_MAP := map[string]string{
	ASSET_TERRY_PORT = "portrait/terry4.png",
	ASSET_VIOLA_PORT = "portrait/viola4.png",
	ASSET_DEX_PORT = "portrait/dex7.png",

	ASSET_FULLBG_INTRO = "fullscreen/intro_flower_can2.png",
}
NUM_EXPECTED_ASSETS :: 256

AssetSystem :: struct
{
	assets: map[string]Asset,
}

@private
asset_fullpath: string

asset_init :: proc(sys: ^AssetSystem)
{
	// asset_dir, worked := io_open_static(ASSET_DIR)
	// if !worked { io_ensure_dir_static(ASSET_DIR); asset_dir, worked = io_open_static(ASSET_DIR) }
	// assert(worked)

	// asset_files, errno := io_read_dir(asset_dir, NUM_EXPECTED_ASSETS)
	// assert(errno == IO_OK)

	// for f in asset_files
	// {
	// 	fmt.println(f)
	// }

	asset_fullpath = io_resolve_static(ASSET_DIR, context.allocator)
	for k, v in ASSET_MAP
	{
		thispath := io_resolve({ asset_fullpath, v }, context.temp_allocator)
		thisf, worked := io_open_raw(thispath)
		assert(worked, fmt.tprintln("Could not open a file in ASSETS_MAP: ", v))

		sys.assets[k] = Asset{
			state = .NotLoaded,
		}
	}
}

// @private
// asset_load :: proc(sys: ^AssetSystem, path: string)
// {
	
// }