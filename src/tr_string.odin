package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:intrinsics"

TR_STRINGS_PATH :: "strings.csv"
TR_STRINGS_DELIM :: ";;"
TrSystem :: struct
{
	strings: map[string]map[string]string,
}

// Read strings.csv and build an internal map
// Not too much error checking so make sure it's correct lol
TR_NUM_EXPECTED_STRINGS :: 8_192
tr_init :: proc(sys: ^TrSystem)
{
	full_path := io_resolve_static(TR_STRINGS_PATH, context.temp_allocator)
	f, worked := io_open_raw(full_path)
	assert(worked, "<tr_string.odin> Could not open TR file.")

	fcont, worked2 := io_read_entire_file(f)
	assert(worked2, "<tr_string.odin> Got TR file HND but could not read it as str.")
	assert(fcont != nil && len(fcont) > 0, "<tr_string.odin> Have read TR file, but string is empty.")

	split_lines := strings.split(cast(string) fcont, "\n", context.allocator)
	header_list := strings.split(split_lines[0], TR_STRINGS_DELIM, context.allocator)

	for i := 1; i < len(header_list); i += 1
	{
		// Write empty map to each lang section
		sys.strings[header_list[i]] = make(map[string]string, TR_NUM_EXPECTED_STRINGS, context.allocator)
	}

	for j := 1; j < len(split_lines); j += 1
	{
		delimed := strings.split(split_lines[j], TR_STRINGS_DELIM, context.allocator) // delimed[0] -> KEY
		assert((len(delimed) == len(header_list)) || (len(split_lines[j]) == 0),
			fmt.tprintln("<strings.csv> Number of values provided for a >0-length row incongruent with number of defined fields.", delimed))

		for k := 1; k < len(delimed); k += 1
		{
			// Write each string into the map under the right lang section, using first column for key
			m := &sys.strings[header_list[k]]
			m^[delimed[0]] = delimed[k]
		}
	}
}