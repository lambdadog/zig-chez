const std = @import("std");
const ally = std.heap.c_allocator;

const h = switch (@import("builtin").is_test) {
    true => @cImport({
        @cDefine("SCHEME_STATIC", "1");
        @cInclude("scheme.h");
    }),
    false => {},
};

test {
    // Initialize scheme kernel
    C.Sscheme_init(null);
    defer C.Sscheme_deinit();

    // TODO: find a way to make this cleaner -- I'd like to
    // provide {petite,scheme}.boot from build.zig somehow...
    C.Sregister_boot_file("./zig-cache/chez/native/out/petite.boot");
    C.Sregister_boot_file("./zig-cache/chez/native/out/scheme.boot");
    C.Sbuild_heap("test", null);

    _ = C;
}

// This won't work with portable bytecode
const bit_width = @import("builtin").target.cpu.arch.ptrBitWidth();

pub const C = struct {
    // iptr = isize
    // uptr = usize
    // scheme.h uses iptr and uptr because (u)intptr_t isn't available on all platforms

    // Customization
    pub extern "c" fn Skernel_version() [*:0]const u8;
    pub extern "c" fn Sscheme_init(?fn () callconv(.C) void) void;
    pub extern "c" fn Sset_verbose(c_int) void;
    pub extern "c" fn Sregister_boot_file([*]const u8) void;
    pub extern "c" fn Sregister_boot_file_fd([*]const u8, c_int) void;
    pub extern "c" fn Sbuild_heap([*c]const u8, ?fn () callconv(.C) void) void;
    pub extern "c" fn Senable_expeditor([*c]const u8) void;
    pub extern "c" fn Sretain_static_relocation() void;
    pub extern "c" fn Sscheme_start(c_int, [*c][*]const u8) c_int;
    pub extern "c" fn Sscheme_script([*]const u8, c_int, [*c][*]const u8) c_int;
    pub extern "c" fn Sscheme_program([*]const u8, c_int, [*c][*]const u8) c_int;
    pub extern "c" fn compact_heap() void;
    pub extern "c" fn Sscheme_deinit() void;

    // Predicates
    // pub inline fn Sfixnump(scm: *SCM) bool {}
    // pub inline fn Scharp(scm: *SCM) bool {}
    // pub inline fn Snullp(scm: *SCM) bool {}
    // pub inline fn Seof_objectp(scm: *SCM) bool {}
    // pub inline fn Sbwp_objectp(scm: *SCM) bool {}
    // pub inline fn Sbooleanp(scm: *SCM) bool {}
    // pub inline fn Spairp(scm: *SCM) bool {}
    // pub inline fn Ssymbolp(scm: *SCM) bool {}
    // pub inline fn Sprocedurep(scm: *SCM) bool {}
    // pub inline fn Sflonump(scm: *SCM) bool {}
    // pub inline fn Svectorp(scm: *SCM) bool {}
    // pub inline fn Sbytevectorp(scm: *SCM) bool {}
    // pub inline fn Sfxvectorp(scm: *SCM) bool {}
    // pub inline fn Sstringp(scm: *SCM) bool {}
    // pub inline fn Sbignump(scm: *SCM) bool {}
    // pub inline fn Sboxp(scm: *SCM) bool {}
    // pub inline fn Sinexactnump(scm: *SCM) bool {}
    // pub inline fn Sp(scm: *SCM) bool {}
    // pub inline fn Sxactnump(scm: *SCM) bool {}
    // pub inline fn Sratnump(scm: *SCM) bool {}
    // pub inline fn Sinputportp(scm: *SCM) bool {}
    // pub inline fn Soutputportp(scm: *SCM) bool {}
    // pub inline fn Srecordp(scm: *SCM) bool {}

    // Accessors
    pub inline fn Sfixnum_value(scm: *SCM) isize {
        return switch (comptime bit_width) {
            64 => @divExact(@bitCast(isize, @ptrToInt(scm)), 8),
            32 => @divExact(@bitCast(isize, @ptrToInt(scm)), 4),
            else => unreachable,
        };
    }
    pub inline fn Schar_value(scm: *SCM) c_uint {
        return @truncate(c_uint, @ptrToInt(scm) >> 8);
    }
    pub inline fn Sboolean_value(scm: *SCM) bool {
        return scm != Sfalse;
    }
    inline fn Sflonum_value(scm: *SCM) f64 {
        return @intToPtr([*]f64, @ptrToInt(scm) + 6)[0];
    }
    pub extern "c" fn Sinteger_value(*SCM) isize;
    pub inline fn Sunsigned_value(scm: *SCM) usize {
        return @bitCast(usize, Sinteger_value(scm));
    }
    pub extern "c" fn Sinteger32_value(*SCM) c_int;
    pub inline fn Sunsigned32_value(scm: *SCM) c_uint {
        return @bitCast(c_uint, Sinteger32_value(scm));
    }
    pub extern "c" fn Sinteger64_value(*SCM) c_long;
    pub inline fn Sunsigned64_value(scm: *SCM) c_ulong {
        return @bitCast(c_ulong, Sinteger64_value(scm));
    }
    pub inline fn Scar(scm: *SCM) *SCM {
        return @intToPtr([*]*SCM, @ptrToInt(scm) + 7)[0];
    }
    pub inline fn Scdr(scm: *SCM) *SCM {
        return switch (comptime bit_width) {
            64 => @intToPtr([*]*SCM, @ptrToInt(scm) + 15)[0],
            32 => @intToPtr([*]*SCM, @ptrToInt(scm) + 11)[0],
            else => unreachable,
        };
    }
    pub extern "c" fn Ssymbol_to_string(*SCM) *SCM;
    pub inline fn Sunbox(scm: *SCM) *SCM {
        return switch (comptime bit_width) {
            64 => @intToPtr([*]*SCM, @ptrToInt(scm) + 9)[0],
            32 => @intToPtr([*]*SCM, @ptrToInt(scm) + 5)[0],
            else => unreachable,
        };
    }
    pub inline fn Sstring_length(scm: *SCM) isize {
        return @bitCast(isize, @ptrToInt(@intToPtr([*]*SCM, @ptrToInt(scm) + 1)[0]) >> 4);
    }
    pub inline fn Svector_length(scm: *SCM) isize {
        return switch (comptime bit_width) {
            64 => @bitCast(isize, @ptrToInt(@intToPtr([*]*SCM, @ptrToInt(scm) + 1)[0]) >> 4),
            32 => @bitCast(isize, @ptrToInt(@intToPtr([*]*SCM, @ptrToInt(scm) + 1)[0]) >> 3),
            else => unreachable,
        };
    }
    pub inline fn Sbytevector_length(scm: *SCM) isize {
        return @bitCast(isize, @ptrToInt(@intToPtr([*]*SCM, @ptrToInt(scm) + 1)[0]) >> 3);
    }
    pub inline fn Sfxvector_length(scm: *SCM) isize {
        return @bitCast(isize, @ptrToInt(@intToPtr([*]*SCM, @ptrToInt(scm) + 1)[0]) >> 4);
    } // Schar_value
    pub inline fn Sstring_ref(scm: *SCM, index: isize) c_uint {
        return switch (comptime bit_width) {
            64 => @intToPtr([*]c_uint, @ptrToInt(scm) + 9)[@intCast(usize, index)] >> 8,
            32 => @intToPtr([*]c_uint, @ptrToInt(scm) + 5)[@intCast(usize, index)] >> 8,
            else => unreachable,
        };
    }
    pub inline fn Svector_ref(scm: *SCM, index: isize) *SCM {
        return switch (comptime bit_width) {
            64 => @intToPtr([*]*SCM, @ptrToInt(scm) + 9)[@intCast(usize, index)],
            32 => @intToPtr([*]*SCM, @ptrToInt(scm) + 5)[@intCast(usize, index)],
            else => unreachable,
        };
    }
    pub inline fn Sbytevector_u8_ref(scm: *SCM, index: isize) u8 {
        return @intToPtr([*]u8, @ptrToInt(scm) + 9)[@intCast(usize, index)];
    }
    pub inline fn Sfxvector_ref(scm: *SCM, index: isize) *SCM {
        return switch (comptime bit_width) {
            64 => @intToPtr([*]*SCM, @ptrToInt(scm) + 9)[@intCast(usize, index)],
            32 => @intToPtr([*]*SCM, @ptrToInt(scm) + 5)[@intCast(usize, index)],
            else => unreachable,
        };
    }
    pub inline fn Sbytevector_data(scm: *SCM) [*:0]u8 {
        return @intToPtr([*:0]u8, @ptrToInt(scm) + 9);
    }

    test "accessors" {
        try std.testing.expect(C.Sfixnum_value(@ptrCast(*SCM, h.Sfixnum(35).?)) == 35);
        try std.testing.expect(C.Sboolean_value(@ptrCast(*SCM, h.Strue.?)) == true);
        try std.testing.expect(@truncate(u8, C.Schar_value(@ptrCast(*SCM, h.Schar('h').?))) == 'h');
        try std.testing.expect(C.Sflonum_value(@ptrCast(*SCM, h.Sflonum(87.2).?)) == 87.2);

        const cons = @ptrCast(*SCM, h.Scons(h.Strue.?, h.Sfalse.?).?);
        try std.testing.expect(C.Scar(cons) == @ptrCast(*SCM, h.Strue.?));
        try std.testing.expect(C.Scdr(cons) == @ptrCast(*SCM, h.Sfalse.?));

        const box = @ptrCast(*SCM, h.Sbox(h.Strue.?).?);
        try std.testing.expect(C.Sunbox(box) == @ptrCast(*SCM, h.Strue.?));

        const string: []const u8 = "Hello, world!";
        const scm_string = @ptrCast(*SCM, h.Sstring_of_length(string.ptr, string.len).?);
        try std.testing.expect(C.Sstring_length(scm_string) == string.len);

        var i: isize = 0;
        while (@intCast(usize, i) < string.len) : (i += 1) {
            try std.testing.expect(@truncate(u8, C.Sstring_ref(scm_string, i)) == string[@intCast(usize, i)]);
        }

        const vector = @ptrCast(*SCM, h.Smake_vector(10, h.Strue.?));
        try std.testing.expect(C.Svector_length(vector) == 10);
        try std.testing.expect(C.Svector_ref(vector, 3) == @ptrCast(*SCM, h.Strue.?));

        const bytevector = @ptrCast(*SCM, h.Smake_bytevector(10, 'c'));
        try std.testing.expect(C.Sbytevector_length(bytevector) == 10);
        try std.testing.expect(C.Sbytevector_u8_ref(bytevector, 3) == 'c');

        const fxvector = @ptrCast(*SCM, h.Smake_fxvector(10, h.Sfixnum(35).?));
        try std.testing.expect(C.Sfxvector_length(fxvector) == 10);
        try std.testing.expect(C.Sfxvector_ref(fxvector, 7) == @ptrCast(*SCM, h.Sfixnum(35).?));

        const bv_data = C.Sbytevector_data(bytevector);
        try std.testing.expect(std.mem.eql(u8, @as([]const u8, std.mem.sliceTo(bv_data, 0)), "cccccccccc"));
    }

    // Mutators
    pub extern "c" fn Sset_box(*SCM, *SCM) void;
    pub extern "c" fn Sset_car(*SCM, *SCM) void;
    pub extern "c" fn Sset_cdr(*SCM, *SCM) void;
    inline fn Sstring_set(scm: *SCM, index: isize, char: u8) void {
        @intToPtr([*]c_uint, @ptrToInt(scm) + 9)[@intCast(usize, index)] = @truncate(c_uint, @intCast(usize, char) << 8 | 0x16);
    }
    pub extern "c" fn Svector_set(*SCM, isize, *SCM) void;
    inline fn Sbytevector_u8_set(scm: *SCM, index: isize, val: u8) void {
        @intToPtr([*]u8, @ptrToInt(scm) + 9)[@intCast(usize, index)] = val;
    }
    inline fn Sfxvector_set(scm: *SCM, index: isize, val: *SCM) void {
        @intToPtr([*]*SCM, @ptrToInt(scm) + 9)[@intCast(usize, index)] = val;
    }

    test "mutators" {
        const string: []const u8 = "Hello, vorld!";
        const scm_string = @ptrCast(*SCM, h.Sstring_of_length(string.ptr, string.len).?);
        C.Sstring_set(scm_string, 7, 'w');
        try std.testing.expect(C.Sstring_ref(scm_string, 7) == 'w');

        const bytevector = @ptrCast(*SCM, h.Smake_bytevector(10, 'c'));
        C.Sbytevector_u8_set(bytevector, 5, 'h');
        try std.testing.expect(C.Sbytevector_u8_ref(bytevector, 5) == 'h');

        const fxvector = @ptrCast(*SCM, h.Smake_fxvector(10, h.Sfixnum(35).?));
        C.Sfxvector_set(fxvector, 2, @ptrCast(*SCM, h.Strue.?));
        try std.testing.expect(C.Sfxvector_ref(fxvector, 2) == @ptrCast(*SCM, h.Strue.?));
    }

    // Constructors
    pub const Snil = @intToPtr(*SCM, 0x26);
    pub const Strue = @intToPtr(*SCM, 0xE);
    pub const Sfalse = @intToPtr(*SCM, 0x6);
    pub const Sbwp_object = @intToPtr(*SCM, 0x4E);
    pub const Seof_object = @intToPtr(*SCM, 0x36);
    pub const Svoid = @intToPtr(*SCM, 0x3E);
    pub inline fn Sfixnum(val: isize) *SCM {
        return switch (comptime bit_width) {
            64 => @intToPtr(*SCM, @bitCast(usize, val * 8)),
            32 => @intToPtr(*SCM, @bitCast(usize, val * 4)),
            else => unreachable,
        };
    }
    pub inline fn Schar(val: u8) *SCM {
        return @intToPtr(*SCM, @intCast(usize, val) << 8 | 0x16);
    }
    pub inline fn Sboolean(val: bool) *SCM {
        return if (val) {
            Strue;
        } else {
            Sfalse;
        };
    }
    pub extern "c" fn Sflonum(f64) *SCM;
    pub extern "c" fn Sstring([*]const u8) *SCM;
    pub extern "c" fn Sstring_of_length([*]const u8, isize) *SCM;
    pub extern "c" fn Sstring_utf8([*]const u8, isize) *SCM;
    pub extern "c" fn Sinteger(isize) *SCM;
    pub extern "c" fn Sunsigned(usize) *SCM;
    pub extern "c" fn Sinteger32(c_int) *SCM;
    pub extern "c" fn Sunsigned32(c_uint) *SCM;
    pub extern "c" fn Sinteger64(c_long) *SCM;
    pub extern "c" fn Sunsigned64(c_ulong) *SCM;
    pub extern "c" fn Scons(*SCM, *SCM) *SCM;
    pub extern "c" fn Sbox(*SCM) *SCM;
    pub extern "c" fn Sstring_to_symbol([*]const u8) *SCM;
    pub extern "c" fn Smake_string(isize, c_int) *SCM;
    pub extern "c" fn Smake_vector(isize, *SCM) *SCM;
    pub extern "c" fn Smake_bytevector(isize, c_int) *SCM;
    pub extern "c" fn Smake_fxvector(isize, *SCM) *SCM;
    pub extern "c" fn Smake_uninitialized_string(isize) *SCM;

    test "constructors" {
        try std.testing.expect(@ptrToInt(h.Snil.?) == @ptrToInt(C.Snil));
        try std.testing.expect(@ptrToInt(h.Strue.?) == @ptrToInt(C.Strue));
        try std.testing.expect(@ptrToInt(h.Sfalse.?) == @ptrToInt(C.Sfalse));
        try std.testing.expect(@ptrToInt(h.Sbwp_object.?) == @ptrToInt(C.Sbwp_object));
        try std.testing.expect(@ptrToInt(h.Seof_object.?) == @ptrToInt(C.Seof_object));
        try std.testing.expect(@ptrToInt(h.Svoid.?) == @ptrToInt(C.Svoid));
        try std.testing.expect(@ptrToInt(h.Schar('c').?) == @ptrToInt(C.Schar('c')));
        try std.testing.expect(@ptrToInt(h.Sfixnum(25).?) == @ptrToInt(C.Sfixnum(25)));
    }

    // Windows-specific helper functions
    // I have no intention of implementing these

    // Accessing top-level values
    pub extern "c" fn Stop_level_value(*SCM) *SCM;
    pub extern "c" fn Sset_top_level_value(*SCM, *SCM) void;

    // Locking Scheme objects
    pub extern "c" fn Slock_object(*SCM) void;
    pub extern "c" fn Sunlock_object(*SCM) void;
    pub extern "c" fn Slocked_objectp(*SCM) bool;

    // Registering foreign entry points
    pub extern "c" fn Sforeign_symbol([*]const u8, *anyopaque) void;
    pub extern "c" fn Sregister_symbol([*]const u8, *anyopaque) void;

    // Obtaining Scheme entry points
    // pub inline fn Sforeign_callable_entry_point(scm: *SCM) *anyopaque {}
    // pub inline fn Sforeign_callable_code_object(fun: *anyopaque) *SCM {}

    // Low-level support for calls into Scheme
    pub extern "c" fn Scall0(*SCM) *SCM;
    pub extern "c" fn Scall1(*SCM, *SCM) *SCM;
    pub extern "c" fn Scall2(*SCM, *SCM, *SCM) *SCM;
    pub extern "c" fn Scall3(*SCM, *SCM, *SCM, *SCM) *SCM;
    pub extern "c" fn Sinitframe(isize) void;
    pub extern "c" fn Sput_arg(isize, *SCM) void;
    pub extern "c" fn Scall(*SCM, isize) *SCM;

    // Activating, deactivating, and destroying threads
    pub extern "c" fn Sactivate_thread() bool;
    pub extern "c" fn Sdeactivate_thread() void;
    pub extern "c" fn Sdestroy_thread() bool;

    // Low-level synchronization primitives
    // pub usingnamespace switch (chez_threaded) {
    //   true => struct {
    //     pub inline fn INITLOCK(addr: *anyopaque) void {}
    //     pub inline fn SPINLOCK(addr: *anyopaque) void {}
    //     pub inline fn UNLOCK(addr: *anyopaque) void {}
    //     pub inline fn LOCKED_INCR(addr: *anyopaque, ret: *c_int) void {}
    //     pub inline fn LOCKED_DECR(addr: *anyopaque, ret: *c_int) void {}
    //   },
    //   false => {},
    // };

    // Undocumented
    pub extern "c" fn Ssave_heap([*c]const u8, c_int) void;
    pub extern "c" fn Sregister_heap_file([*]const u8) void;
};

pub const SCM = opaque {};

// untested
pub inline fn call(len: comptime_int, procedure: *SCM, args: *[len]SCM) *SCM {
    C.Sinitframe(len);
    comptime var i = 0;
    inline while (i < len) : (i += 1) {
        C.Sput_arg(i + 1, args[i]);
    }
    C.Scall(procedure, len);
}
