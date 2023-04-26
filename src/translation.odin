package SongOfTheEarth

import "core:fmt"
import "core:strings"

// TR
TR_STRINGS_PATH :: "strings.csv"
TR_STRINGS_DELIM :: ";;"

TranslationRecord :: map[string]map[string]string
tr_get :: #force_inline proc(tr: TranslationRecord, key: [2]u8, input: string) -> (string) {
	key := key
	got, worked := tr[cast(string) key[:]][input]
	if !worked { return "MISSINGSTR" }
	return got
}

tr_get_cstring :: #force_inline proc(tr: TranslationRecord, key: [2]u8, input: string, alloc := context.temp_allocator) -> (cstring) {
	return strings.clone_to_cstring(tr_get(tr, key, input), alloc)
}