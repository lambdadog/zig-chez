const std = @import("std");
const zbs = std.build;
const fs = std.fs;
const mem = std.mem;

const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});

    const build_chez = BuildChezStep.create(b);
    try build_chez.setTarget(target);

    const test_step = b.step("test", "Test building Chez");
    test_step.dependOn(&build_chez.step);
}

pub const BuildChezError = error{
    BuildChezNoGNUMake,
};

pub const BuildChezTargetError = error{
    BuildChezUnsupportedOS,
    BuildChezUnsupportedArch,
};

pub const BuildChezStep = struct {
    builder: *zbs.Builder,
    step: zbs.Step,

    chezObj: zbs.GeneratedFile,
    uuidLib: zbs.GeneratedFile,

    target: CrossTarget,

    pub fn create(builder: *zbs.Builder) *BuildChezStep {
        const ally = builder.allocator;
        const self = ally.create(BuildChezStep) catch oom();
        self.* = .{
            .builder = builder,
            .step = zbs.Step.init(.custom, "Build Chez Scheme", ally, make),

            .chezObj = .{ .step = &self.step, .path = null },
            .uuidLib = .{ .step = &self.step, .path = null },

            .target = CrossTarget.fromTarget(builder.host.target),
        };
        return self;
    }

    // TODO: support platforms & architectures supported by chez
    // but without vendored bootfiles: netbsd, freebsd, ppc-linux,
    // arm-linux
    //
    // Helped by https://github.com/cisco/ChezScheme/issues/646,
    // but not essential.
    pub fn setTarget(self: *BuildChezStep, target: CrossTarget) BuildChezTargetError!void {
        self.target = target;
    }

    pub fn staticLink(self: *BuildChezStep, b: *zbs.Builder) void {
        b.addStaticLibrarySource("ossp-uuid", zbs.FileSource{
            .generated = self.uuidLib,
        });
        b.addObjectFileSource(zbs.FileSource{
            .generated = self.chezObj,
        });
    }

    // check make exists
    //   gmake on host bsd?
    // generate compiler prefix from target
    //   if target = host then no prefix
    // check all required compiler/linker/etc exist
    // // check required libs exist? (how? -- should only be uuid)
    // generate chez machine type
    // configure
    //   ./configure -m=ti3le --threads --disable-x11 --kernelo
    //     consider --disable-curses for non-debug?
    // if cross, configure zlib # necessary for some reason?
    //   ti3le/zlib
    //   ex: `CHOST=i686-unknown-linux-gnu ./configure`
    // if cross, configure lz4 # also necessary
    //   ti3le/lz4
    //   set: AR, CC, TARGET_OS (uname) in Makefile.inc
    //     sed -e 's/TARGET_OS ?= $(shell uname)/TARGET_OS = Linux/' --in-place Makefile.inc
    //     echo 'AR=my-prefix-ar' >> Makefile.inc
    //     echo 'CC=my-prefix-cc' >> Makefile.inc
    // (cd ti3le/c && make -f Mf-ti3le cross=t o=o)
    // set output to ti3le/boot/ti3le/
    //
    // set env CC, AR, RANLIB to 'zig X --target=CrossTarget.zigTriple()'
    //
    // ossp/libuuid.a:
    //   ./configure --disable-shared --enable-static
    //   make libuuid.la
    //
    // -DUSE_OSSP_UUID
    fn make(step: *zbs.Step) !void {
        const self = @fieldParentPtr(BuildChezStep, "step", step);
        const ally = self.builder.allocator;

        const gnu_make = try self.builder.findProgram(&.{ "gmake", "make" }, &.{});
        if (!mem.startsWith(
            u8,
            mem.trim(
                u8,
                try self.builder.exec(&[_][]const u8{ gnu_make, "--version" }),
                &std.ascii.spaces,
            ),
            "GNU Make",
        )) {
            return error.BuildChezNoGNUMake;
        }

        const triple = try self.target.zigTriple(ally);
        const chez_target = try self.chezTarget(ally);

        const build_path = try fs.path.join(ally, &[_][]const u8{ self.builder.cache_root, "chez", triple });
        var repo_dir = try fs.cwd().openDir(fs.path.dirname(@src().file).?, .{});
        defer repo_dir.close();
        var root_dir = try fs.cwd().openDir(self.builder.build_root, .{});
        defer root_dir.close();
        var build_dir = try root_dir.makeOpenPath(build_path, .{});

        try build_dir.setAsCwd();
        _ = try self.builder.exec(
            &[_][]const u8{
                "cp",
                "--recursive",
                comptime getSubmodulePath("ossp-uuid"),
                ".",
            },
        );

        _ = try self.builder.exec(
            &[_][]const u8{
                "cp",
                "--recursive",
                comptime getSubmodulePath("ChezScheme"),
                ".",
            },
        );

        try fs.Dir.copyFile(repo_dir, "build.sh", build_dir, "build.sh", .{});

        _ = try self.builder.exec(
            &[_][]const u8{
                "./build.sh",
                gnu_make,
                triple,
                chez_target,
            },
        );

        self.chezObj.path = try fs.path.join(ally, &[_][]const u8{
            build_path,
            "ChezScheme",
            chez_target,
            "boot",
            chez_target,
            "kernel.o",
        });
        self.uuidLib.path = try fs.path.join(ally, &[_][]const u8{
            build_path,
            "ossp-uuid",
            ".libs",
            "libuuid.a",
        });
    }

    fn chezTarget(self: *BuildChezStep, ally: mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(ally);
        defer result.deinit();

        const target = self.target.toTarget();

        try switch (target.os.tag) {
            .linux => switch (target.cpu.arch) {
                .i386 => result.writer().print("ti3le", .{}),
                .x86_64 => result.writer().print("ta6le", .{}),
                else => return error.BuildChezUnsupportedArch,
            },
            else => return error.BuildChezUnsupportedOS,
        };

        return result.toOwnedSlice();
    }
};

fn oom() noreturn {
    @panic("out of memory");
}

fn getSubmodulePath(comptime name: []const u8) []const u8 {
    return fs.path.dirname(@src().file).? ++ fs.path.sep_str ++ name;
}
