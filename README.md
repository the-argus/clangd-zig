# clangd-zig

A build script for clangd written in zig, so it can be statically linked and/or
cross compiled easily.

Ideally, you can get clangd on your system by downloading a zig binary, a zip
file of this repo, and then doing `zig build`. For another archtecture you could
do something like `zig build -Dtarget=aarch64-linux`.
