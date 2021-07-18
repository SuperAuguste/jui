const std = @import("std");
const jui = @import("jui");

const Reflector = jui.Reflector;
const String = Reflector.String;

var reflector: Reflector = undefined;

fn onLoad(vm: *jui.JavaVM) !jui.jint {
    const version = jui.JNIVersion{ .major = 10, .minor = 0 };
    reflector = Reflector.init(std.heap.page_allocator, try vm.getEnv(version));
    return @bitCast(jui.jint, version);
}

fn onUnload(vm: *jui.JavaVM) void {
    _ = vm;
}

fn greet(env: *jui.JNIEnv, this_object: jui.jobject) !jui.jstring {
    _ = this_object;

    var Integer = try reflector.getClass("java/lang/Integer");
    var constructor = try Integer.getConstructor(fn (int: jui.jint) void);
    var int = try constructor.call(.{12});

    var toString = try Integer.getMethod("toString", fn () String);
    var string: String = try toString.call(int, .{});
    defer string.release();

    var buf: [256]u8 = undefined;
    return try env.newStringUTF(try std.fmt.bufPrintZ(&buf, "Your number is: {s}", .{string.chars.utf8}));
}

comptime {
    const wrapped = struct {
        fn onLoadWrapped(vm: *jui.JavaVM) callconv(.C) jui.jint {
            return jui.wrapErrors(onLoad, .{vm});
        }

        fn onUnloadWrapped(vm: *jui.JavaVM) callconv(.C) void {
            return jui.wrapErrors(onUnload, .{vm});
        }

        fn greetWrapped(env: *jui.JNIEnv, class: jui.jclass) callconv(.C) jui.jstring {
            return jui.wrapErrors(greet, .{ env, class });
        }
    };

    jui.exportUnder("com.jui.JNIExample", .{
        .onLoad = wrapped.onLoadWrapped,
        .onUnload = wrapped.onUnloadWrapped,
        .greet = wrapped.greetWrapped,
    });
}
