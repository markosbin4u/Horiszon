# build log

run: https://github.com/markosbin4u/Horiszon/actions/runs/45906559179

```
SDK 4dc6455 (build 4dc6455d4a6773224792eb1f121a9b939dff3170) in ./.horizon/sdk
Installing Rust 1.99.1 with rust-src for wasm32-unknown-unknown…
info: syncing channel updates for 1.99.1-x86_64-unknown-linux-gnu
info: latest update on 2026-10-15 for version 1.99.1 (58cf8f9c3 2026-10-13)
info: downloading 5 components

  1.99.1-x86_64-unknown-linux-gnu installed - rustc 1.99.1 (58cf8f9c3 2026-10-13)

    Updating crates.io index
 Downloading crates ...
  Downloaded addr2line v0.27.1
  Downloaded foldhash v0.2.0
  Downloaded adler2 v2.0.1
  Downloaded cfg-if v1.0.4
  Downloaded getopts v0.2.24
  Downloaded rustc-demangle v0.1.28
  Downloaded rustc-literal-escaper v0.0.8
  Downloaded miniz_oxide v0.9.1
  Downloaded dlmalloc v0.2.14
  Downloaded hashbrown v0.17.1
  Downloaded object v0.39.1
  Downloaded gimli v0.34.0
  Downloaded libc v0.2.189
   Compiling compiler_builtins v0.1.160 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/compiler-builtins/compiler-builtins)
   Compiling core v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core)
   Compiling libc v0.2.189
   Compiling object v0.39.1
   Compiling std v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/std)
   Compiling proc-macro2 v1.0.107
   Compiling libc v0.2.191
   Compiling zerocopy v0.8.66
   Compiling quote v1.0.47
   Compiling unicode-ident v1.0.27
   Compiling serde_core v1.0.229
   Compiling cfg-if v1.0.5
   Compiling zmij v1.0.23
   Compiling syn v3.0.10
   Compiling getrandom v0.2.17
   Compiling rand_core v0.6.4
   Compiling siphasher v1.0.4
   Compiling phf_shared v0.11.3
   Compiling serde_json v1.0.154
   Compiling serde v1.0.229
   Compiling serde_derive v1.0.229
   Compiling libm v0.2.16
   Compiling ppv-lite86 v0.2.21
   Compiling itoa v1.0.19
   Compiling rand_chacha v0.3.1
   Compiling memchr v2.8.3
   Compiling rand v0.8.8
   Compiling phf_generator v0.11.3
   Compiling phf_codegen v0.11.3
   Compiling unicode_names2_generator v2.0.0
   Compiling unicode_names2 v2.0.0
   Compiling syn v2.0.119
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
   Compiling std_detect v0.1.5 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/std_detect)
   Compiling miniz_oxide v0.9.1
   Compiling hashbrown v0.17.1
   Compiling addr2line v0.27.1
   Compiling proc_macro v0.0.0 (/home/runner/.rustup/toolchains/1.99.1-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/proc_macro)
   Compiling phf v0.11.3
   Compiling log v0.4.35
   Compiling glam v0.30.10
   Compiling bytemuck v1.25.2
   Compiling horizon-core v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-core)
   Compiling horizon-mod-runtime v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-runtime)
   Compiling vein-miner v1.0.0 (/home/runner/work/Horiszon/Horiszon/target/horizon-mod/group/vein_miner)
    Finished `horizon-wasm` profile [optimized] target(s) in 1m 20s
Built ./target/horizon-mod/vein_miner.hmod
   Compiling libc v0.2.191
   Compiling zerocopy v0.8.66
   Compiling proc-macro2 v1.0.107
   Compiling unicode-ident v1.0.27
   Compiling cfg-if v1.0.5
   Compiling quote v1.0.47
   Compiling siphasher v1.0.4
   Compiling phf_shared v0.11.3
   Compiling serde_core v1.0.229
   Compiling zmij v1.0.23
   Compiling syn v3.0.10
   Compiling getrandom v0.2.17
   Compiling rand_core v0.6.4
   Compiling serde_json v1.0.154
   Compiling serde v1.0.229
   Compiling itoa v1.0.19
   Compiling memchr v2.8.3
   Compiling libm v0.2.16
   Compiling phf v0.11.3
   Compiling serde_derive v1.0.229
   Compiling ppv-lite86 v0.2.21
   Compiling rand_chacha v0.3.1
   Compiling rand v0.8.8
   Compiling syn v2.0.119
   Compiling bytemuck_derive v1.12.1
   Compiling phf_generator v0.11.3
   Compiling phf_codegen v0.11.3
   Compiling unicode_names2_generator v2.0.0
   Compiling horizon-mod-vocab v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-vocab)
   Compiling bytemuck v1.25.2
   Compiling log v0.4.35
   Compiling unicode_names2 v2.0.0
   Compiling glam v0.30.10
   Compiling horizon-mod-api v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-api)
   Compiling horizon-mod-point-shape v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-point-shape)
   Compiling horizon-mod-api-macros v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-api-macros)
   Compiling horizon-core v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-core)
   Compiling horizon-mod-runtime v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-runtime)
   Compiling vein-miner v1.0.0 (/home/runner/work/Horiszon/Horiszon)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 23.11s
     Running unittests src/lib.rs (target/debug/deps/vein_miner-baf55fdaf7905f2d)

running 15 tests
test core::tests::a_vein_is_cut_at_the_limit ... ok
test core::tests::deepslate_variants_share_their_ore_vein ... ok
test core::tests::defaults_work_without_sneaking ... ok
test core::tests::max_blocks_is_clamped ... ok
test core::tests::ores_and_logs_are_recognised_and_nothing_else_is ... ok
test core::tests::the_connect_choice_limits_the_neighbours ... ok
test core::tests::ores_never_mix_with_logs ... ok
test core::tests::the_settings_decide_what_may_be_mined ... ok
test core::tests::stripped_and_plain_wood_share_their_tree ... ok
test tests::a_kept_value_is_read_back_the_way_the_game_writes_it ... ok
test core::tests::the_fill_takes_the_connected_same_blocks_only ... ok
test tests::every_setting_is_named_in_the_language_file ... ok
test tests::every_setting_passes_the_games_own_check ... ok
test tests::the_defaults_work_without_sneaking ... ok
test tests::the_settings_registered_are_the_ones_the_mod_reads ... ok

test result: ok. 15 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Compiling libc v0.2.191
   Compiling proc-macro2 v1.0.107
   Compiling quote v1.0.47
   Compiling zerocopy v0.8.66
   Compiling unicode-ident v1.0.27
   Compiling cfg-if v1.0.5
   Compiling serde_core v1.0.229
   Compiling siphasher v1.0.4
   Compiling zmij v1.0.23
   Compiling phf_shared v0.11.3
   Compiling serde v1.0.229
   Compiling serde_json v1.0.154
   Compiling getrandom v0.2.17
   Compiling syn v3.0.10
   Compiling rand_core v0.6.4
   Compiling libm v0.2.16
    Checking phf v0.11.3
   Compiling ppv-lite86 v0.2.21
   Compiling serde_derive v1.0.229
    Checking itoa v1.0.19
   Compiling rand_chacha v0.3.1
   Compiling memchr v2.8.3
   Compiling rand v0.8.8
   Compiling phf_generator v0.11.3
   Compiling phf_codegen v0.11.3
   Compiling unicode_names2_generator v2.0.0
   Compiling unicode_names2 v2.0.0
   Compiling syn v2.0.119
   Compiling bytemuck_derive v1.12.1
   Compiling horizon-mod-vocab v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-vocab)
    Checking bytemuck v1.25.2
   Compiling horizon-mod-api v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-api)
    Checking glam v0.30.10
    Checking log v0.4.35
   Compiling horizon-mod-point-shape v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-point-shape)
    Checking horizon-core v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-core)
   Compiling horizon-mod-api-macros v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-api-macros)
    Checking horizon-mod-runtime v0.1.0 (/home/runner/work/Horiszon/Horiszon/.horizon/sdk/api/crates/horizon-mod-runtime)
    Checking vein-miner v1.0.0 (/home/runner/work/Horiszon/Horiszon)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 23.06s
   Compiling libc v0.2.191
   Compiling proc-macro2 v1.0.107
   Compiling zerocopy v0.8.66
   Compiling unicode-ident v1.0.27
   Compiling quote v1.0.47
   Compiling serde_core v1.0.229
   Compiling cfg-if v1.0.5
   Compiling zmij v1.0.23
   Compiling siphasher v1.0.4
   Compiling syn v3.0.10
   Compiling phf_shared v0.11.3
   Compiling getrandom v0.2.17
   Compiling serde v1.0.229
   Compiling rand_core v0.6.4
   Compiling serde_json v1.0.154
error[E0463]: can't find crate for `core`
  |
  = note: the `wasm32-unknown-unknown` target may not be installed
  = help: consider downloading the target with `rustup target add wasm32-unknown-unknown`

For more information about this error, try `rustc --explain E0463`.
error: could not compile `siphasher` (lib) due to 1 previous error
warning: build failed, waiting for other jobs to finish...
error: cargo check for wasm32-unknown-unknown failed
```
