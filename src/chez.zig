const std = @import("std");

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
    // TODO: factor out some bits: 0x7 seems to be "magic" in some way
    pub inline fn Sfixnump(scm: *SCM) bool {
        return switch (comptime bit_width) {
            64 => @ptrToInt(scm) & 0x7 == 0x0,
            32 => @ptrToInt(scm) & 0x3 == 0x0,
            else => unreachable,
        };
    }
    pub inline fn Scharp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0xFF == 0x16;
    }
    pub inline fn Snullp(scm: *SCM) bool {
        return @ptrToInt(scm) == 0x26;
    }
    pub inline fn Seof_objectp(scm: *SCM) bool {
        return @ptrToInt(scm) == 0x36;
    }
    pub inline fn Sbwp_objectp(scm: *SCM) bool {
        return @ptrToInt(scm) == 0x4E;
    }
    pub inline fn Sbooleanp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0xF7 == 0x6;
    }
    pub inline fn Spairp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x1;
    }
    pub inline fn Ssymbolp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x3;
    }
    pub inline fn Sprocedurep(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x5;
    }
    pub inline fn Sflonump(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x2;
    }
    pub inline fn Svectorp(scm: *SCM) bool {
        return switch (comptime bit_width) {
            64 => @ptrToInt(scm) & 0x7 == 0x7 and
                @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x7 == 0x0,
            32 => @ptrToInt(scm) & 0x7 == 0x7 and
                @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x3 == 0x0,
            else => unreachable,
        };
    }
    // rest of predicates untested for now
    pub inline fn Sbytevectorp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x7 == 0x3;
    }
    pub inline fn Sfxvectorp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x3 == 0x1;
    }
    pub inline fn Sstringp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x7 == 0x2;
    }
    pub inline fn Sbignump(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x1F == 0x6;
    }
    pub inline fn Sboxp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x7F == 0xE;
    }
    pub inline fn Sinexactnump(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) == 0x36;
    }
    pub inline fn Sexactnump(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) == 0x56;
    }
    pub inline fn Sratnump(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) == 0x16;
    }
    pub inline fn Sinputportp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x1FF == 0x11E;
    }
    pub inline fn Soutputportp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x2FF == 0x21E;
    }
    pub inline fn Srecordp(scm: *SCM) bool {
        return @ptrToInt(scm) & 0x7 == 0x7 and
            @ptrToInt(@intToPtr(*SCM, @ptrToInt(scm) + 1)) & 0x7 == 0x7;
    }

    test "predicates" {
        const h = @cImport({
            @cDefine("SCHEME_STATIC", "1");
            @cInclude("scheme.h");
        });

        // More extensive testing than one arbitrarytrue and one false
        // case might be nice, but :\
        try std.testing.expect(C.Sfixnump(@ptrCast(*SCM, h.Sfixnum(32))) == true);
        try std.testing.expect(C.Sfixnump(@ptrCast(*SCM, h.Sflonum(32.3))) == false);
        try std.testing.expect(C.Scharp(@ptrCast(*SCM, h.Schar('c'))) == true);
        try std.testing.expect(C.Scharp(@ptrCast(*SCM, h.Sflonum(32.3))) == false);
        try std.testing.expect(C.Snullp(@ptrCast(*SCM, h.Snil)) == true);
        try std.testing.expect(C.Snullp(@ptrCast(*SCM, h.Svoid)) == false);
        try std.testing.expect(C.Seof_objectp(@ptrCast(*SCM, h.Seof_object)) == true);
        try std.testing.expect(C.Seof_objectp(@ptrCast(*SCM, h.Sbwp_object)) == false);
        try std.testing.expect(C.Sbwp_objectp(@ptrCast(*SCM, h.Sbwp_object)) == true);
        try std.testing.expect(C.Sbwp_objectp(@ptrCast(*SCM, h.Seof_object)) == false);
        try std.testing.expect(C.Sbooleanp(@ptrCast(*SCM, h.Strue)) == true);
        try std.testing.expect(C.Sbooleanp(@ptrCast(*SCM, h.Schar('a'))) == false);
        try std.testing.expect(C.Spairp(@ptrCast(*SCM, h.Scons(h.Strue, h.Sfalse))) == true);
        try std.testing.expect(C.Spairp(@ptrCast(*SCM, h.Strue)) == false);
        const read_sym = C.Sstring_to_symbol("read");
        try std.testing.expect(C.Ssymbolp(read_sym) == true);
        try std.testing.expect(C.Ssymbolp(@ptrCast(*SCM, h.Schar('z'))) == false);
        const read_proc = C.Stop_level_value(read_sym);
        try std.testing.expect(C.Sprocedurep(read_proc) == true);
        try std.testing.expect(C.Sprocedurep(read_sym) == false);
        try std.testing.expect(C.Sflonump(@ptrCast(*SCM, h.Sflonum(1.234))) == true);
        try std.testing.expect(C.Sflonump(@ptrCast(*SCM, h.Schar('"'))) == false);
        try std.testing.expect(C.Svectorp(@ptrCast(*SCM, h.Smake_vector(3, h.Strue))) == true);
        try std.testing.expect(C.Svectorp(@ptrCast(*SCM, h.Schar('"'))) == false);
    }

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
    }
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
        const h = @cImport({
            @cDefine("SCHEME_STATIC", "1");
            @cInclude("scheme.h");
        });

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
        switch (comptime bit_width) {
            64 => @intToPtr([*]c_uint, @ptrToInt(scm) + 9)[@intCast(usize, index)] = @truncate(c_uint, @intCast(usize, char) << 8 | 0x16),
            32 => @intToPtr([*]c_uint, @ptrToInt(scm) + 5)[@intCast(usize, index)] = @truncate(c_uint, @intCast(usize, char) << 8 | 0x16),
            else => unreachable,
        }
    }
    pub extern "c" fn Svector_set(*SCM, isize, *SCM) void;
    inline fn Sbytevector_u8_set(scm: *SCM, index: isize, val: u8) void {
        switch (comptime bit_width) {
            64 => @intToPtr([*]u8, @ptrToInt(scm) + 9)[@intCast(usize, index)] = val,
            32 => @intToPtr([*]u8, @ptrToInt(scm) + 5)[@intCast(usize, index)] = val,
            else => unreachable,
        }
    }
    inline fn Sfxvector_set(scm: *SCM, index: isize, val: *SCM) void {
        switch (comptime bit_width) {
            64 => @intToPtr([*]*SCM, @ptrToInt(scm) + 9)[@intCast(usize, index)] = val,
            32 => @intToPtr([*]*SCM, @ptrToInt(scm) + 5)[@intCast(usize, index)] = val,
            else => unreachable,
        }
    }

    test "mutators" {
        const h = @cImport({
            @cDefine("SCHEME_STATIC", "1");
            @cInclude("scheme.h");
        });

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
        const h = @cImport({
            @cDefine("SCHEME_STATIC", "1");
            @cInclude("scheme.h");
        });

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
    // I have no intention of implementing these for now

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
    pub inline fn Sforeign_callable_entry_point(scm: *SCM) *anyopaque {
        return switch (comptime bit_width) {
            64 => @intToPtr(*anyopaque, @ptrToInt(scm) + 65),
            32 => @intToPtr(*anyopaque, @ptrToInt(scm) + 33),
            else => unreachable,
        };
    }
    pub inline fn Sforeign_callable_code_object(fun: *const anyopaque) *SCM {
        return switch (comptime bit_width) {
            64 => @intToPtr(*SCM, @ptrToInt(fun) - 65),
            32 => @intToPtr(*SCM, @ptrToInt(fun) - 33),
            else => unreachable,
        };
    }

    test "scheme entry points" {
        const sexpr = "(foreign-callable (lambda (x) (not x)) (scheme-object) scheme-object)";
        const ois = C.Stop_level_value(C.Sstring_to_symbol("open-input-string"));
        const sip = C.Scall1(ois, C.Sstring_of_length(sexpr, sexpr.len));
        const read = C.Stop_level_value(C.Sstring_to_symbol("read"));
        const expr = C.Scall1(read, sip);
        const eval = C.Stop_level_value(C.Sstring_to_symbol("eval"));
        const scm_not = C.Scall1(eval, expr);

        Slock_object(scm_not);
        defer Sunlock_object(scm_not);

        const not_through_scm = @ptrCast(fn (*SCM) *SCM, Sforeign_callable_entry_point(scm_not));
        try std.testing.expect(not_through_scm(C.Sfalse) == C.Strue);
        try std.testing.expect(C.Sforeign_callable_code_object(not_through_scm) == scm_not);
    }

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
    //
    // I'll need to implement these with ASM so I'm being lazy about
    // them...
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

pub const SCM = opaque {
    pub const Error = error{
        NotAProcedure,
    };

    pub const Type = enum {
        Fixnum,
        Char,
        Nil,
        EOF,
        BWP,
        Boolean,
        Cons,
        Symbol,
        Procedure,
        Flonum,
        Vector,
        Bytevector,
        Bytevector,
        String,
        Bignum,
        Box,
        InexactNumber,
        ExactNumber,
        RationalNumber,
        InputPort,
        OutputPort,
        Record,
    };

    pub inline fn call(
        self: *SCM,
        comptime len: comptime_int,
        args: [len]*SCM,
    ) SCM.Error!*SCM {
        if (C.Sprocedurep(procedure)) {
            C.Sinitframe(len);
            comptime var i = 0;
            inline while (i < len) : (i += 1) {
                C.Sput_arg(i + 1, args[i]);
            }
            return C.Scall(procedure, len);
        } else return SCM.Error.NotAProcedure;
    }

    pub fn is(self: *SCM, scm_type: SCM.Type) bool {
        return switch (scm_type) {
            .Fixnum => C.Sfixnump(self),
            .Char => C.Scharp(self),
            .Nil => C.Snullp(self),
            .EOF => C.Seof_objectp(self),
            .BWP => C.Sbwp_objectp(self),
            .Boolean => C.Sbooleanp(self),
            .Cons => C.Spairp(self),
            .Symbol => C.Ssymbolp(self),
            .Procedure => C.Sprocedurep(self),
            .Flonum => C.Sflonump(self),
            .Vector => C.Svectorp(self),
            .Fixvector => C.Sfxvectorp(self),
            .Bytevector => C.Sbytevectorp(self),
            .String => C.Sstringp(self),
            .Bignum => C.Sbignump(self),
            .Box => C.Sboxp(self),
            .InexactNumber => C.Sinexactnump(self),
            .ExactNumber => C.Sexactnump(self),
            .RationalNumber => C.Sratnump(self),
            .InputPort => C.Sinputportp(self),
            .OutputPort => C.Soutputportp(self),
            .Record => C.Srecordp(self),
        };
    }
};

pub inline fn call(
    comptime len: comptime_int,
    procedure_name: []const u8,
    args: [len]*SCM,
) SCM.Error!*SCM {
    const procedure = C.Stop_level_value(C.string_to_symbol(procedure_name));
    try procedure.call(len, args);
}

test "call()" {
    const result = try call(1, "not", .{C.Sfalse});
    try std.testing.expect(result == C.Strue);
}
