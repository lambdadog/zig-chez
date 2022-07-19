const std = @import("std");
const ally = std.heap.c_allocator;

// Excluded:
// extern "c" fn Sscheme_script([*c]const u8, c_int, [*c][*c]const u8) c_int;
// extern "c" fn Sscheme_program([*c]const u8, c_int, [*c][*c]const u8) c_int;

pub fn init(cb: ?fn () callconv(.C) void) void {
    Sscheme_init(cb);
}
extern "c" fn Sscheme_init(?fn () callconv(.C) void) void;

pub fn setVerbose(v: bool) void {
    Sset_verbose(@as(c_int, @boolToInt(v)));
}
extern "c" fn Sset_verbose(c_int) void;

pub fn registerBootFile(path: []const u8) void {
    Sregister_boot_file(path.ptr);
}
extern "c" fn Sregister_boot_file([*]const u8) void;

pub fn registerHeapFile(path: []const u8) void {
    Sregister_heap_file(&path);
}
extern "c" fn Sregister_heap_file([*]const u8) void;

/// Build the scheme heap, must be done before calling into scheme.
pub fn buildHeap(name: ?[]const u8, cb: ?fn () callconv(.C) void) void {
    if (name) |n| {
        Sbuild_heap(n.ptr, cb);
    } else {
        Sbuild_heap(@intToPtr([*c]const u8, 0), cb);
    }
}
extern "c" fn Sbuild_heap([*c]const u8, ?fn () callconv(.C) void) void;

/// Enable the scheme expression editor, optionally passing the path
/// to a history file.
pub fn enableExpeditor(history_file: ?[]const u8) void {
    if (history_file) |h_file| {
        Senable_expeditor(h_file.ptr);
    } else {
        Senable_expeditor(@intToPtr([*c]const u8, 0));
    }
}
extern "c" fn Senable_expeditor([*c]const u8) void;

/// Run start sequence. Takes `std.os.argv` rather than argc/argv pair
/// like in C api -- if you wish to use this on Windows then I suupose
/// you'll have to convert it somehow.
pub fn start(argv: ?[][*]u8) void {
    if (argv) |av| {
        _ = Sscheme_start(@truncate(c_int, @as(i128, av.len)), av.ptr);
    } else {
        _ = Sscheme_start(0, @intToPtr([*c][*]const u8, 0));
    }
}
extern "c" fn Sscheme_start(c_int, [*c][*]const u8) c_int;

/// De-init
pub fn deinit() void {
    Sscheme_deinit();
}
extern "c" fn Sscheme_deinit() void;

pub fn kernelVersion() []const u8 {
    return std.mem.sliceTo(Skernel_version(), 0);
}
extern "c" fn Skernel_version() [*c]const u8;

// This suffices as long as portable bytecode isn't in Chez
const native_endian = @import("builtin").target.cpu.arch.endian();
const Type = std.builtin.Type;
const Signedness = std.builtin.Signedness;

/// A scheme value
pub const SCM = opaque {
    /// Scheme value for nil
    pub const Snil = @intToPtr(*SCM, 0x26);

    /// Scheme value for true
    pub const Strue = @intToPtr(*SCM, 0xE);

    /// Scheme value for false
    pub const Sfalse = @intToPtr(*SCM, 0x6);

    /// Scheme value for a broken weak pointer object
    /// http://cisco.github.io/ChezScheme/csug9.5/smgmt.html#./smgmt:s21
    pub const Sbwp = @intToPtr(*SCM, 0x4E);

    /// Scheme value for an end-of-file (eof) object
    pub const Seof = @intToPtr(*SCM, 0x36);

    /// Scheme value for void
    pub const Svoid = @intToPtr(*SCM, 0x3E);

    /// Constructs a cons cell
    pub extern "c" fn Scons(*SCM, *SCM) *SCM;

    /// Constructs a box
    pub extern "c" fn Sbox(*SCM) *SCM;

    /// Constructs a scheme value from a string
    ///
    /// Zig strings are UTF-8 encoded by default so this uses
    /// Sstring_utf8 internally. `fromStringASCII` may have better
    /// performance, but doesn't validate that your input is actually
    /// ASCII.
    pub fn fromString(str: []const u8) *SCM {
        // We have to utf8 decode this to get the length, hopefully
        // it's not too slow...
        return Sstring_utf8(str.ptr, @as(c_long, std.unicode.utf8Decode(str).len));
    }
    extern "c" fn Sstring_utf8([*]const u8, c_long) *SCM;

    /// Constructs a scheme value from an ASCII string. Doesn't
    /// validate your input.
    ///
    /// See 'fromString' for a UTF-8 version.
    pub fn fromStringASCII(str: []const u8) *SCM {
        return Sstring_of_length(str.ptr, @as(c_long, str.len));
    }
    extern "c" fn Sstring_of_length([*]const u8, c_long) *SCM;

    /// Constructs a scheme value from a float
    pub fn fromFlonum(val: f64) *SCM {
        return Sflonum(val);
    }
    extern "c" fn Sflonum(f64) *SCM;

    /// Constructs a scheme value from a boolean
    pub fn fromBool(val: bool) *SCM {
        if (val) {
            return SCM.t;
        } else {
            return SCM.f;
        }
    }

    /// Constructs a scheme value from a char
    pub fn fromChar(c: u8) *SCM {
        // I honestly don't know how this works, I just copied it.
        return @as(*SCM, @as(c_longlong, c << 8 | 0x16));
    }

    // https://man.scheme.org/fixnum-width.3scheme
    /// Constructs a scheme value from a fixnum
    pub fn fromFixnum(val: @Type(Type.Int{
        .signedness = Signedness.signed,
        .bits = switch (native_endian) {
            .Big => 61,
            .Little => 30,
        },
    })) *SCM {
        switch (native_endian) {
            .Big => @as(*SCM, @as(c_longlong, val * 8)),
            .Little => @as(*SCM, @as(c_longlong, val * 4)),
        }
    }

    /// Constructs a scheme value from an integer
    pub fn fromInteger(val: isize) *SCM {
        return Sinteger(@as(c_long, val));
    }
    extern "c" fn Sinteger(c_long) *SCM;

    /// Constructs a scheme value from an unsigned integer
    pub fn fromUnsigned(val: usize) *SCM {
        return Sunsigned(@as(c_ulong, val));
    }
    extern "c" fn Sunsigned(c_ulong) *SCM;

    /// Constructs a scheme value from a 32 bit integer
    pub fn fromInteger32(val: i32) *SCM {
        return Sinteger32(@as(c_int, val));
    }
    extern "c" fn Sinteger32(c_int) *SCM;

    /// Constructs a scheme value from a 32 bit unsigned integer
    pub fn fromUnsigned32(val: u32) *SCM {
        return Sunsigned32(@as(c_uint, val));
    }
    extern "c" fn Sunsigned32(c_uint) *SCM;

    /// Constructs a scheme value from a 64 bit integer
    pub fn fromInteger64(val: i64) *SCM {
        return Sinteger65(@as(c_longlong, val));
    }
    extern "c" fn Sinteger65(c_longlong) *SCM;

    /// Constructs a scheme value from a 64 bit unsigned integer
    pub fn fromUnsigned64(val: u64) *SCM {
        return Sunsigned64(@as(c_ulonglong, val));
    }
    extern "c" fn Sunsigned64(c_ulonglong) *SCM;
};
