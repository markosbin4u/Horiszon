//! Vein Miner for Horizon (Minecraft: Java Edition 26.3 in Rust).
//!
//! Break one ore or one log and the whole connected vein comes with it. Every extra block is
//! broken **as the player**, through `PlayerRef::destroy_block`, so the drops are the game's
//! own: Fortune, Silk Touch, Unbreaking wear, the mined statistic and the exhaustion all come
//! from Horizon rather than being re-implemented here.
//!
//! No sneak needed unless the player turns that on in the mod's own settings page
//! (**Options > Mods > Vein Miner > Config**).
//!
//! Why a queue: a break run inside `break_block` is heard by `break_block` again, and the game
//! refuses a break started from inside eight others. So the hook finds the vein and only queues
//! it; the server tick then breaks a few blocks per tick. That keeps the nesting at zero and
//! spreads a large vein over a moment instead of stalling the tick.

mod core;

use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};

use core::{Connect, MOD_ID, Pos, Settings};
use mod_api::{
    BreakBlockEvent, Flow, Hooks, ServerHost, ServerTickEvent, ServerTickPhase, SettingSpec,
    SettingValue,
};

/// A vein still waiting for the server ticks that break it.
struct Job {
    /// Who broke the vein: their UUID, resolved to a live handle when it runs, so a player who
    /// leaves is never broken for.
    player: u128,
    /// The blocks to break, nearest first, without the block the player broke.
    blocks: Vec<Pos>,
    /// The id of the block the vein is made of, for the same-vein test.
    block: String,
    /// The tick the job was made on, for the age limit.
    made: i64,
}

#[derive(Default)]
struct VeinMiner {
    /// True while this mod's own breaks run, so they are not vein-mined again.
    breaking: AtomicBool,
    /// The server ticks seen so far, for the job age limit.
    tick: AtomicI64,
    /// Veins waiting to be broken.
    jobs: Mutex<Vec<Job>>,
}

/// The settings page's rows, with their defaults.
fn setting_specs() -> [SettingSpec; 6] {
    [
        SettingSpec::toggle(core::KEY_ENABLED, format!("{MOD_ID}.setting.enabled"), true)
            .tooltip(format!("{MOD_ID}.setting.enabled.tooltip")),
        SettingSpec::toggle(
            core::KEY_REQUIRE_SNEAK,
            format!("{MOD_ID}.setting.require_sneak"),
            false,
        )
        .tooltip(format!("{MOD_ID}.setting.require_sneak.tooltip")),
        SettingSpec::range(
            core::KEY_MAX_BLOCKS,
            format!("{MOD_ID}.setting.max_blocks"),
            1.0,
            core::MAX_BLOCKS_LIMIT as f64,
            1.0,
            core::DEFAULT_MAX_BLOCKS as f64,
        )
        .tooltip(format!("{MOD_ID}.setting.max_blocks.tooltip")),
        SettingSpec::toggle(
            core::KEY_MINE_ORES,
            format!("{MOD_ID}.setting.mine_ores"),
            true,
        )
        .tooltip(format!("{MOD_ID}.setting.mine_ores.tooltip")),
        SettingSpec::toggle(
            core::KEY_MINE_LOGS,
            format!("{MOD_ID}.setting.mine_logs"),
            true,
        )
        .tooltip(format!("{MOD_ID}.setting.mine_logs.tooltip")),
        SettingSpec::choice(
            core::KEY_CONNECT,
            format!("{MOD_ID}.setting.connect"),
            [
                format!("{MOD_ID}.setting.connect.faces"),
                format!("{MOD_ID}.setting.connect.faces_and_edges"),
                format!("{MOD_ID}.setting.connect.all"),
            ],
            // All: a vein that runs corner to corner comes out whole.
            2,
        )
        .tooltip(format!("{MOD_ID}.setting.connect.tooltip")),
    ]
}

/// One setting's value as the game keeps it, or the spec's default when nothing is kept.
fn read_setting(host: &dyn ServerHost, spec: &SettingSpec) -> SettingValue {
    spec.read(host.setting(MOD_ID, &spec.key).as_deref())
}

/// The player's settings, right now.
fn current_settings(host: &dyn ServerHost) -> Settings {
    let specs = setting_specs();
    let toggle = |index: usize, fallback: bool| match read_setting(host, &specs[index]) {
        SettingValue::Toggle(on) => on,
        _ => fallback,
    };
    let max_blocks = match read_setting(host, &specs[2]) {
        SettingValue::Range(value) => Settings::clamped_max_blocks(value),
        _ => core::DEFAULT_MAX_BLOCKS,
    };
    let connect = match read_setting(host, &specs[5]) {
        SettingValue::Choice(index) => Connect::from_index(index),
        _ => Connect::All,
    };
    Settings {
        enabled: toggle(0, true),
        require_sneak: toggle(1, false),
        max_blocks,
        mine_ores: toggle(3, true),
        mine_logs: toggle(4, true),
        connect,
    }
}

impl VeinMiner {
    /// Queues the vein `origin` belongs to, if this player may vein-mine here.
    fn on_break(&self, host: &mut dyn ServerHost, event: &BreakBlockEvent<'_>) {
        // Our own breaks come back through here: leave them alone.
        if self.breaking.load(Ordering::Relaxed) {
            return;
        }
        let settings = current_settings(&*host);
        if !settings.enabled {
            return;
        }
        let Some(player) = host.players().acting_player() else {
            return;
        };
        let sneaking = player.entity().is_shift_key_down(&*host);
        if settings.require_sneak && sneaking != Some(true) {
            return;
        }
        let Some(level) = player.level(&*host) else {
            return;
        };

        let origin = event.pos;
        let origin_block = event.state.block().id(&*host);
        let Some(family) = core::family(&origin_block) else {
            return;
        };
        if !settings.mines(Some(family)) {
            return;
        }

        // The vein as the level shows it right now: an unloaded chunk or a different block
        // simply ends a branch of the fill.
        let mut read = |pos: Pos| -> Option<String> { level.block(&*host, pos).map(|key| key.id(&*host)) };
        let vein = core::fill(origin, &origin_block, settings, &mut read);
        if vein.blocks.is_empty() {
            // A lone block: the game's own break is the whole of it.
            return;
        }
        if vein.truncated {
            eprintln!("[{MOD_ID}] vein cut at {} blocks", settings.max_blocks);
        }

        let job = Job {
            player: player.uuid(),
            blocks: vein.blocks,
            block: origin_block,
            made: self.tick.load(Ordering::Relaxed),
        };
        let mut jobs = self.jobs.lock().unwrap_or_else(|e| e.into_inner());
        // One vein per player at a time: a second break replaces the first, so a fast miner
        // never stacks jobs whose positions the world has already moved past.
        jobs.retain(|other| other.player != job.player);
        jobs.push(job);
    }

    /// Breaks a few blocks of every waiting vein, once per server tick.
    fn on_tick(&self, host: &mut dyn ServerHost, event: &ServerTickEvent<'_>) {
        if !matches!(event.phase, ServerTickPhase::ServerTickEnd { .. }) {
            return;
        }
        let now = self.tick.fetch_add(1, Ordering::Relaxed) + 1;
        // Take the jobs out: no lock is held while the game breaks blocks, since those breaks
        // call back into this mod.
        let mut jobs = {
            let mut guard = self.jobs.lock().unwrap_or_else(|e| e.into_inner());
            std::mem::take(&mut *guard)
        };
        if jobs.is_empty() {
            return;
        }
        if !host.on(MOD_ID) {
            // Turned off in Options > Mods while a vein was waiting.
            return;
        }

        self.breaking.store(true, Ordering::Relaxed);
        for job in &mut jobs {
            // A job that waited too long would break blocks the world has moved on from.
            if now.saturating_sub(job.made) > core::JOB_TTL_TICKS {
                job.blocks.clear();
                continue;
            }
            let Some(player) = host.player(job.player) else {
                job.blocks.clear();
                continue;
            };
            let Some(level) = player.level(&*host) else {
                job.blocks.clear();
                continue;
            };
            let mut broken = 0;
            while broken < core::PER_TICK {
                let Some(pos) = job.blocks.pop() else { break };
                // Only a block that is still part of the vein: a piston, a creeper or another
                // player may have changed the world under us.
                let still = level
                    .block(&*host, pos)
                    .map(|key| key.id(&*host))
                    .is_some_and(|id| core::same_vein(&job.block, &id));
                if !still {
                    continue;
                }
                // Broken as the player: the game's own drops, enchantments and tool wear.
                if !player.destroy_block(host, pos, false) {
                    // Refused (an unbreakable block, a protected one, a stale handle): drop the
                    // rest instead of retrying every tick.
                    job.blocks.clear();
                    break;
                }
                broken += 1;
            }
        }
        self.breaking.store(false, Ordering::Relaxed);

        // Keep what is left for the next tick.
        jobs.retain(|job| !job.blocks.is_empty());
        if !jobs.is_empty() {
            let mut guard = self.jobs.lock().unwrap_or_else(|e| e.into_inner());
            guard.append(&mut jobs);
        }
    }
}

#[mod_api::horizon_mod]
impl Hooks for VeinMiner {
    /// The mod's page in Options > Mods: every setting, with its default.
    fn register(&self, r: &mut dyn mod_api::Registrar, _: &mod_api::RegistrationContext) {
        for spec in setting_specs() {
            if let Err(error) = r.register_setting(spec.clone()) {
                eprintln!("[{MOD_ID}] setting {} was refused: {error}", spec.key);
            }
        }
    }

    /// One block broke: find the vein it belongs to and queue it.
    fn break_block(&self, host: &mut dyn ServerHost, event: &mut BreakBlockEvent<'_>) -> Flow {
        self.on_break(host, event);
        // Never cancelled: the block the player aimed at breaks exactly as it would without
        // this mod, drops and all. The rest follow on the next ticks.
        Flow::Continue
    }

    /// The ticks that break the queued veins.
    fn server_tick(&self, host: &mut dyn ServerHost, event: &mut ServerTickEvent<'_>) {
        self.on_tick(host, event);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LANG: &str = include_str!("../assets/vein_miner/lang/en_us.json");

    #[test]
    fn every_setting_passes_the_games_own_check() {
        for spec in setting_specs() {
            assert_eq!(spec.check(), Ok(()), "{} is refused", spec.key);
        }
    }

    #[test]
    fn every_setting_is_named_in_the_language_file() {
        for spec in setting_specs() {
            assert!(
                LANG.contains(&format!("\"{}\"", spec.label)),
                "no translation for {}",
                spec.label
            );
            if let Some(tooltip) = &spec.tooltip {
                assert!(
                    LANG.contains(&format!("\"{tooltip}\"")),
                    "no translation for {tooltip}"
                );
            }
        }
        for option in ["faces", "faces_and_edges", "all"] {
            assert!(
                LANG.contains(&format!("\"{MOD_ID}.setting.connect.{option}\"")),
                "no translation for option {option}"
            );
        }
    }

    #[test]
    fn the_settings_registered_are_the_ones_the_mod_reads() {
        let keys: Vec<String> = setting_specs().into_iter().map(|spec| spec.key).collect();
        assert_eq!(
            keys,
            [
                core::KEY_ENABLED,
                core::KEY_REQUIRE_SNEAK,
                core::KEY_MAX_BLOCKS,
                core::KEY_MINE_ORES,
                core::KEY_MINE_LOGS,
                core::KEY_CONNECT,
            ]
        );
    }

    #[test]
    fn the_defaults_work_without_sneaking() {
        let specs = setting_specs();
        assert_eq!(specs[0].default_value(), SettingValue::Toggle(true));
        // The whole point of the mod: no Shift.
        assert_eq!(specs[1].default_value(), SettingValue::Toggle(false));
        assert_eq!(specs[2].default_value(), SettingValue::Range(64.0));
        assert_eq!(specs[3].default_value(), SettingValue::Toggle(true));
        assert_eq!(specs[4].default_value(), SettingValue::Toggle(true));
        assert_eq!(specs[5].default_value(), SettingValue::Choice(2));
    }

    #[test]
    fn a_kept_value_is_read_back_the_way_the_game_writes_it() {
        let specs = setting_specs();
        assert_eq!(specs[1].read(Some("true")), SettingValue::Toggle(true));
        assert_eq!(specs[1].read(None), SettingValue::Toggle(false));
        assert_eq!(specs[2].read(Some("128")), SettingValue::Range(128.0));
        // A value the setting does not have falls back to its default.
        assert_eq!(specs[2].read(Some("99999")), SettingValue::Range(64.0));
        assert_eq!(specs[5].read(Some("0")), SettingValue::Choice(0));
    }
}
