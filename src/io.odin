package SongOfTheEarth
import "core:fmt"
import "core:os"
import "core:slice"
import fp "core:path/filepath"

@private
base_path: string

IOHandle :: os.Handle

IO_OK :: os.ERROR_NONE
IO_OPEN_READ_WRITE :: os.O_RDWR
IO_OPEN_APPEND :: os.O_APPEND
IO_OPEN_WRITE :: os.O_WRONLY

// LINUX_PERM :: 0o750
STD_LINUX_MODE :: 0o750

STATIC_DIR :: "static"

io_init :: #force_inline proc(exe_path: string)
{
	base_path = exe_path
}

io_resolve :: fp.join
io_resolve_static :: #force_inline proc(path: string, alloc := context.allocator) -> (string)
{
	return io_resolve({ base_path, STATIC_DIR, path }, alloc)
}

io_peel_back :: #force_inline proc(path: string, alloc := context.allocator) -> (string)
{
	return fp.dir(path, alloc)
}

io_last_only :: proc(path: string) -> (string)
{
	return fp.base(path)
}

io_open_raw :: proc(path: string, mode: int = os.O_RDONLY) -> (IOHandle, bool)
{
	out, worked := os.open(path, mode, STD_LINUX_MODE)
	// assert(worked == os.ERROR_NONE)
	return out, worked == os.ERROR_NONE
}

io_open_static :: proc(path: string, mode: int = os.O_RDONLY) -> (IOHandle, bool)
{
	return io_open_raw(io_resolve_static(path), mode)
}

io_close :: #force_inline proc(hnd: IOHandle)
{
	os.close(hnd)
}

io_ensure_file :: proc(path: string)
{
	f, worked := io_open_raw(path, os.O_CREATE)
	if !worked
	{
		io_write_string(f, "<EMPTY>")
	}

	io_close(f)
}

io_ensure_file_static :: #force_inline proc(path: string)
{
	p := io_resolve_static(path)
	// log(.Debug, "Ensuring static file:", p)
	io_ensure_file(p)
}

io_ensure_dir :: #force_inline proc(path: string)
{
	e_code := os.make_directory(path, STD_LINUX_MODE)
	log(.Debug, "Made directory with Errno", e_code)
}

io_ensure_dir_static :: proc(path: string)
{
	p := io_resolve_static(path)
	io_ensure_dir(p)
}

io_exists :: #force_inline proc(path: string) -> (bool)
{
	return os.exists(path)
}

io_exists_static :: #force_inline proc(path: string) -> (bool)
{
	p := io_resolve_static(path)
	return io_exists(p)
}

/// F READING
io_read_entire_file :: #force_inline proc(hnd: IOHandle, alloc := context.allocator) -> ([]u8, bool)
{
	return os.read_entire_file_from_handle(hnd)
}

io_read_entire_file_from_name_static :: #force_inline proc(name: string, alloc := context.allocator) -> ([]u8, bool)
{
	f, worked := io_open_static(name)
	if !worked { return nil, false }
	return io_read_entire_file(f, alloc)
}

/// F WRITING
io_write_string :: #force_inline proc(hnd: IOHandle, str: string)
{
	os.write(hnd, transmute([]u8) str)
}

io_write_ptr_len :: proc(hnd: IOHandle, byte_ptr: ^$T, length: int)
{
	os.write(hnd, slice.from_ptr(transmute([^]u8) byte_ptr, length))
}

/// READ DIR
io_read_dir :: os.read_dir