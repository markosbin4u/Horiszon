# build log

run: https://github.com/markosbin4u/Horiszon/actions/runs/45893112940

```
SDK 4dc6455 (build 4dc6455d4a6773224792eb1f121a9b939dff3170) in ./.horizon/sdk
Installing Rust 1.99.1 with rust-src for wasm32-unknown-unknown…
info: syncing channel updates for 1.99.1-x86_64-unknown-linux-gnu
info: latest update on 2026-10-15 for version 1.99.1 (58cf8f9c3 2026-10-13)
info: downloading 5 components

  1.99.1-x86_64-unknown-linux-gnu installed - rustc 1.99.1 (58cf8f9c3 2026-10-13)

    Updating crates.io index
 Downloading crates ...
  Downloaded cfg-if v1.0.4
  Downloaded getopts v0.2.24
  Downloaded addr2line v0.27.1
  Downloaded dlmalloc v0.2.14
  Downloaded rustc-literal-escaper v0.0.8
  Downloaded gimli v0.34.0
  Downloaded object v0.39.1
  Downloaded libc v0.2.189
   Compiling compiler_builtins v0.1.160 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/compiler-builtins/compiler-builtins)
   Compiling core v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core)
   Compiling libc v0.2.189
   Compiling object v0.39.1
   Compiling std v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/std)
   Compiling libc v0.2.191
   Compiling proc-macro2 v1.0.107
   Compiling zerocopy v0.8.66
   Compiling quote v1.0.47
   Compiling unicode-ident v1.0.27
   Compiling serde_core v1.0.229
   Compiling cfg-if v1.0.5
   Compiling zmij v1.0.23
   Compiling getrandom v0.2.17
   Compiling syn v3.0.10
   Compiling rand_core v0.6.4
   Compiling siphasher v1.0.4
   Compiling phf_shared v0.11.3
   Compiling serde_json v1.0.154
   Compiling serde v1.0.229
   Compiling serde_derive v1.0.229
   Compiling libm v0.2.16
   Compiling ppv-lite86 v0.2.21
   Compiling itoa v1.0.19
   Compiling memchr v2.8.3
   Compiling rand_chacha v0.3.1
   Compiling rand v0.8.8
   Compiling phf_generator v0.11.3
   Compiling phf_codegen v0.11.3
   Compiling unicode_names2_generator v2.0.0
   Compiling syn v2.0.119
   Compiling unicode_names2 v2.0.0
   Compiling bytemuck_derive v1.12.1
   Compiling horizon-mod-vocab v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-vocab)
   Compiling horizon-mod-api v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-api)
   Compiling horizon-mod-point-shape v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-point-shape)
   Compiling horizon-mod-api-macros v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-api-macros)
   Compiling rustc-std-workspace-core v1.99.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/rustc-std-workspace-core)
   Compiling alloc v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/alloc)
   Compiling unwind v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/unwind)
   Compiling adler2 v2.0.1
   Compiling cfg-if v1.0.4
   Compiling dlmalloc v0.2.14
   Compiling rustc-demangle v0.1.28
   Compiling panic_abort v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/panic_abort)
   Compiling rustc-literal-escaper v0.0.8
   Compiling rustc-std-workspace-alloc v1.99.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/rustc-std-workspace-alloc)
   Compiling panic_unwind v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/panic_unwind)
   Compiling gimli v0.34.0
   Compiling hashbrown v0.17.1
   Compiling std_detect v0.1.5 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/std_detect)
   Compiling miniz_oxide v0.9.1
   Compiling addr2line v0.27.1
   Compiling proc_macro v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/proc_macro)
   Compiling phf v0.11.3
   Compiling log v0.4.35
   Compiling glam v0.30.10
   Compiling bytemuck v1.25.2
   Compiling horizon-core v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-core)
   Compiling horizon-mod-runtime v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-runtime)
   Compiling vein-miner v1.0.0 (/home/runner/work/Horiszon/Horiszon/target/horizon-mod/group/vein_miner)
error[E0689]: can't call method `abs` on ambiguous numeric type `{integer}`
  --> vein_miner/src/core.rs:72:39
   |
66 |         for dx in -1..=1 {
   |             -- you must specify a type for this binding, like `i32`
...
72 |                     let touching = dx.abs() + dy.abs() + dz.abs();
   |                                       ^^^

error[E0689]: can't call method `abs` on ambiguous numeric type `{integer}`
  --> vein_miner/src/core.rs:72:50
   |
67 |             for dy in -1..=1 {
   |                 -- you must specify a type for this binding, like `i32`
...
72 |                     let touching = dx.abs() + dy.abs() + dz.abs();
   |                                                  ^^^

error[E0689]: can't call method `abs` on ambiguous numeric type `{integer}`
  --> vein_miner/src/core.rs:72:61
   |
68 |                 for dz in -1..=1 {
   |                     -- you must specify a type for this binding, like `i32`
...
72 |                     let touching = dx.abs() + dy.abs() + dz.abs();
   |                                                             ^^^

For more information about this error, try `rustc --explain E0689`.
error: rustc failed: exit status: 1
error: could not compile `vein-miner` (lib) due to 3 previous errors
error: Cargo group build failed
```
