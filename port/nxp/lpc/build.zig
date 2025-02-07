const std = @import("std");
const microzig = @import("microzig/build-internals");

const Self = @This();

chips: struct {
    lpc176x5x: *const microzig.Target,
    lpc55s69: *const microzig.Target,
},

boards: struct {
    nxp: struct {
        lpcxpresso55s69: *const microzig.Target,
    },
    mbed: struct {
        lpc1768: *const microzig.Target,
    },
},

pub fn init(dep: *std.Build.Dependency) Self {
    const b = dep.builder;

    const chip_lpc176x5x: microzig.Target = .{
        .dep = dep,
        .preferred_binary_format = .elf,
        .chip = .{
            .name = "LPC176x5x",
            .cpu = .{
                .cpu_arch = .thumb,
                .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m3 },
                .os_tag = .freestanding,
                .abi = .eabi,
            },
            // Downloaded from http://ds.arm.com/media/resources/db/chip/nxp/lpc1768/LPC176x5x.svd
            .register_definition = .{ .svd = b.path("src/chips/LPC176x5x.svd") },
            .memory_regions = &.{
                .{ .offset = 0x00000000, .length = 512 * 1024, .kind = .flash },
                .{ .offset = 0x10000000, .length = 32 * 1024, .kind = .ram },
                .{ .offset = 0x2007C000, .length = 32 * 1024, .kind = .ram },
            },
        },
        .hal = .{
            .root_source_file = b.path("src/hals/LPC176x5x.zig"),
        },
        .patch_elf = lpc176x5x_patch_elf,
    };

    const chip_lpc55s69: microzig.Target = .{
        .dep = dep,
        .preferred_binary_format = .elf,
        .chip = .{
            .name = "LPC55S69_cm33_core0",
            .cpu = .{
                .cpu_arch = .thumb,
                .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m33 },
                .os_tag = .freestanding,
                .abi = .eabi,
            },
            .register_definition = .{
                .svd = b.path("src/chips/LPC55S69_cm33_core0.svd"),
            },
            .memory_regions = &.{
                .{ .kind = .flash, .offset = 0x00000000, .length = 1024 * 630 },
                .{ .kind = .ram, .offset = 0x20000000, .length = 1024 * 256 },
                .{ .kind = .ram, .offset = 0x40100000, .length = 1024 * 16 },
            },
        },
    };

    return .{
        .chips = .{
            .lpc176x5x = chip_lpc176x5x.derive(.{}),
            .lpc55s69 = chip_lpc55s69.derive(.{}),
        },
        .boards = .{
            .nxp = .{
                .lpcxpresso55s69 = chip_lpc55s69.derive(.{
                    .board = .{
                        .name = "LPCXpresso55S69",
                        .root_source_file = b.path("src/boards/nxp_LPCXpresso55S69.zig"),
                    },
                }),
            },
            .mbed = .{
                .lpc1768 = chip_lpc176x5x.derive(.{
                    .board = .{
                        .name = "mbed LPC1768",
                        .url = "https://os.mbed.com/platforms/mbed-LPC1768/",
                        .root_source_file = b.path("src/boards/mbed_LPC1768.zig"),
                    },
                }),
            },
        },
    };
}

pub fn build(b: *std.Build) void {
    const lpc176x5x_patch_elf_exe = b.addExecutable(.{
        .name = "lpc176x5x-patchelf",
        .root_source_file = b.path("src/tools/patchelf.zig"),
        .target = b.host,
    });
    b.installArtifact(lpc176x5x_patch_elf_exe);
}

/// Patch an ELF file to add a checksum over the first 8 words so the
/// cpu will properly boot.
fn lpc176x5x_patch_elf(dep: *std.Build.Dependency, input: std.Build.LazyPath) std.Build.LazyPath {
    const patch_elf_exe = dep.artifact("lpc176x5x-patchelf");
    const run = dep.builder.addRunArtifact(patch_elf_exe);
    run.addFileArg(input);
    return run.addOutputFileArg("output.elf");
}
