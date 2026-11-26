//! The rules of vein mining, with no dependency on the game or the mod API, so they
//! are unit-testable in plain Rust: which blocks count, which family a block belongs
//! to, the flood fill over the connected blocks, and the settings' defaults.

use std::collections::{HashSet, VecDeque};

/// The mod's id: its namespace, log name and settings folder.
pub const MOD_ID: &str = "vein_miner";

/// Setting keys, as they appear in the mod's settings page and its files.
pub const KEY_ENABLED: &str = "enabled";
pub const KEY_REQUIRE_SNEAK: &str = "require_sneak";
pub const KEY_MAX_BLOCKS: &str = "max_blocks";
pub const KEY_MINE_ORES: &str = "mine_ores";
pub const KEY_MINE_LOGS: &str = "mine_logs";
pub const KEY_CONNECT: &str = "connect";

/// The highest `max_blocks` a player may pick. The game also caps how many breaks one
/// hook may start (`player_destroy_block` refuses a break started from inside eight
/// others), so the fill asks for a few blocks per server tick rather than all at once.
pub const MAX_BLOCKS_LIMIT: usize = 512;
/// Default `max_blocks`.
pub const DEFAULT_MAX_BLOCKS: usize = 64;
/// Blocks broken per server tick. Small enough to stay well inside the game's nested
/// break limit, large enough that a full vein is gone within a few ticks.
pub const PER_TICK: usize = 4;
/// How long a queued vein may wait for the server ticks that break it, in ticks
/// (20 ticks = 1 second). A job older than this is dropped rather than run late.
pub const JOB_TTL_TICKS: i64 = 60;

/// A block position, kept as a plain array so the fill works without the game.
pub type Pos = [i32; 3];

/// Which kind of vein a block belongs to: ores and logs are configured separately.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Family {
    Ore,
    Log,
}

/// The settings page's choices for `connect`, in order.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Connect {
    /// Touching faces only (6 neighbours): the classic vein.
    Faces,
    /// Faces and edges (18 neighbours).
    FacesAndEdges,
    /// Faces, edges and corners (26 neighbours): the default, so a diagonal vein
    /// comes out whole.
    All,
}

impl Connect {
    /// From the settings page's option index.
    pub fn from_index(index: usize) -> Self {
        match index {
            0 => Self::Faces,
            1 => Self::FacesAndEdges,
            _ => Self::All,
        }
    }

    /// Every neighbour offset this mode connects through.
    pub fn offsets(self) -> Vec<[i32; 3]> {
        let mut out = Vec::with_capacity(26);
        for dx in -1..=1 {
            for dy in -1..=1 {
                for dz in -1..=1 {
                    if dx == 0 && dy == 0 && dz == 0 {
                        continue;
                    }
                    let touching = dx.abs() + dy.abs() + dz.abs();
                    let ok = match self {
                        Self::Faces => touching == 1,
                        Self::FacesAndEdges => touching <= 2,
                        Self::All => true,
                    };
                    if ok {
                        out.push([dx, dy, dz]);
                    }
                }
            }
        }
        out
    }
}

/// Everything the settings page holds, after the player's choices are read.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Settings {
    pub enabled: bool,
    pub require_sneak: bool,
    pub max_blocks: usize,
    pub mine_ores: bool,
    pub mine_logs: bool,
    pub connect: Connect,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            enabled: true,
            // Works without Shift, as asked.
            require_sneak: false,
            max_blocks: DEFAULT_MAX_BLOCKS,
            mine_ores: true,
            mine_logs: true,
            connect: Connect::All,
        }
    }
}

impl Settings {
    /// Clamps a raw `max_blocks` into the offered range.
    pub fn clamped_max_blocks(value: f64) -> usize {
        if !value.is_finite() || value < 1.0 {
            return 1;
        }
        (value as usize).min(MAX_BLOCKS_LIMIT)
    }

    /// Whether a block of `family` is eligible under these settings.
    pub fn mines(self, family: Option<Family>) -> bool {
        match family {
            Some(Family::Ore) => self.mine_ores,
            Some(Family::Log) => self.mine_logs,
            None => false,
        }
    }
}

/// The block id without its `minecraft:` prefix, or the id unchanged.
pub fn short_id(block: &str) -> &str {
    block.strip_prefix("minecraft:").unwrap_or(block)
}

/// Whether `block` is an ore this mod vein-mines, and never a block that only shares
/// the `_ore` suffix by accident.
pub fn is_ore(block: &str) -> bool {
    let short = short_id(block);
    matches!(
        short,
        "coal_ore"
            | "deepslate_coal_ore"
            | "iron_ore"
            | "deepslate_iron_ore"
            | "copper_ore"
            | "deepslate_copper_ore"
            | "gold_ore"
            | "deepslate_gold_ore"
            | "redstone_ore"
            | "deepslate_redstone_ore"
            | "emerald_ore"
            | "deepslate_emerald_ore"
            | "lapis_ore"
            | "deepslate_lapis_ore"
            | "diamond_ore"
            | "deepslate_diamond_ore"
            | "nether_gold_ore"
            | "nether_quartz_ore"
            | "ancient_debris"
    ) || short.ends_with("_ore")
}

/// Whether `block` is a log, wood, stem or hyphae: what a tree is made of.
pub fn is_log(block: &str) -> bool {
    let short = short_id(block);
    // A mushroom stem is not a tree's trunk and must not drag a giant mushroom with it.
    short != "mushroom_stem"
        && ["_log", "_wood", "_stem", "_hyphae"]
            .iter()
            .any(|suffix| short.ends_with(suffix))
}

/// The family a block belongs to, if this mod may vein-mine it at all.
pub fn family(block: &str) -> Option<Family> {
    if is_ore(block) {
        Some(Family::Ore)
    } else if is_log(block) {
        Some(Family::Log)
    } else {
        None
    }
}

/// Whether two blocks are the same vein. Regular and deepslate ores of one kind are one
/// vein, as are a log, its wood and its stripped forms, so a vein cut by stone or a
/// tree with mixed trunk blocks still comes out whole. Ores and logs never mix.
pub fn same_vein(origin: &str, other: &str) -> bool {
    match (family(origin), family(other)) {
        (Some(Family::Ore), Some(Family::Ore)) => {
            ore_kind(short_id(origin)) == ore_kind(short_id(other))
        }
        (Some(Family::Log), Some(Family::Log)) => {
            log_kind(short_id(origin)) == log_kind(short_id(other))
        }
        _ => false,
    }
}

/// The ore a block is a variant of: `deepslate_iron_ore` is `iron`.
pub fn ore_kind(short: &str) -> &str {
    let short = short.strip_prefix("deepslate_").unwrap_or(short);
    short.strip_suffix("_ore").unwrap_or(short)
}

/// The wood a log belongs to: `stripped_oak_wood` is `oak`.
pub fn log_kind(short: &str) -> &str {
    let short = short.strip_prefix("stripped_").unwrap_or(short);
    for suffix in ["_log", "_wood", "_stem", "_hyphae"] {
        if let Some(wood) = short.strip_suffix(suffix) {
            return wood;
        }
    }
    short
}

/// The flood fill's answer: the connected blocks to break, nearest first, without the
/// block the player broke (`origin`, which the game breaks itself).
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Vein {
    /// Positions to break, in the order the fill found them.
    pub blocks: Vec<Pos>,
    /// True when the fill stopped because `max_blocks` was reached: the vein is bigger.
    pub truncated: bool,
}

/// Breadth-first fill from `origin` over blocks `read` reports, keeping only the ones
/// `same_vein` accepts against the origin's id. `read` returns the block id at a
/// position, or `None` where it cannot be read (an unloaded chunk, air): those are
/// skipped and do not stop the fill.
pub fn fill(
    origin: Pos,
    origin_block: &str,
    settings: Settings,
    read: &mut dyn FnMut(Pos) -> Option<String>,
) -> Vein {
    let mut seen: HashSet<Pos> = HashSet::from([origin]);
    let mut queue = VecDeque::from([origin]);
    let mut blocks = Vec::new();
    let mut truncated = false;
    let offsets = settings.connect.offsets();

    'fill: while let Some(at) = queue.pop_front() {
        for offset in &offsets {
            let next = [
                at[0].saturating_add(offset[0]),
                at[1].saturating_add(offset[1]),
                at[2].saturating_add(offset[2]),
            ];
            if !seen.insert(next) {
                continue;
            }
            let Some(id) = read(next) else { continue };
            if !same_vein(origin_block, &id) {
                continue;
            }
            if blocks.len() >= settings.max_blocks {
                truncated = true;
                break 'fill;
            }
            blocks.push(next);
            queue.push_back(next);
        }
    }

    Vein { blocks, truncated }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn settings() -> Settings {
        Settings::default()
    }

    #[test]
    fn ores_and_logs_are_recognised_and_nothing_else_is() {
        assert!(is_ore("minecraft:diamond_ore"));
        assert!(is_ore("minecraft:deepslate_diamond_ore"));
        assert!(is_ore("minecraft:ancient_debris"));
        assert!(is_ore("modded:tin_ore"));
        assert!(!is_ore("minecraft:stone"));
        assert!(!is_ore("minecraft:wooden_pickaxe"));

        assert!(is_log("minecraft:oak_log"));
        assert!(is_log("minecraft:stripped_oak_wood"));
        assert!(is_log("minecraft:crimson_stem"));
        assert!(is_log("minecraft:warped_hyphae"));
        assert!(!is_log("minecraft:mushroom_stem"));
        assert!(!is_log("minecraft:oak_planks"));
        assert_eq!(family("minecraft:stone"), None);
    }

    #[test]
    fn deepslate_variants_share_their_ore_vein() {
        assert!(same_vein(
            "minecraft:iron_ore",
            "minecraft:deepslate_iron_ore"
        ));
        assert!(same_vein(
            "minecraft:deepslate_iron_ore",
            "minecraft:iron_ore"
        ));
        assert!(!same_vein("minecraft:iron_ore", "minecraft:gold_ore"));
    }

    #[test]
    fn stripped_and_plain_wood_share_their_tree() {
        assert!(same_vein("minecraft:oak_log", "minecraft:stripped_oak_log"));
        assert!(same_vein("minecraft:oak_log", "minecraft:oak_wood"));
        assert!(!same_vein("minecraft:oak_log", "minecraft:birch_log"));
    }

    #[test]
    fn ores_never_mix_with_logs() {
        assert!(!same_vein("minecraft:iron_ore", "minecraft:oak_log"));
    }

    #[test]
    fn the_fill_takes_the_connected_same_blocks_only() {
        // Three iron ore in a vertical column, one gold ore beside it, stone elsewhere.
        let world = |p: Pos| -> Option<String> {
            match (p[0], p[1], p[2]) {
                (0, 0, 0) => Some("minecraft:iron_ore".to_owned()),
                (0, 1, 0) => Some("minecraft:deepslate_iron_ore".to_owned()),
                (0, 2, 0) => Some("minecraft:iron_ore".to_owned()),
                (1, 0, 0) => Some("minecraft:gold_ore".to_owned()),
                (0, 3, 0) => Some("minecraft:stone".to_owned()),
                _ => None,
            }
        };
        let mut read = world;
        let vein = fill([0, 0, 0], "minecraft:iron_ore", settings(), &mut read);
        assert_eq!(vein.blocks, vec![[0, 1, 0], [0, 2, 0]]);
        assert!(!vein.truncated);
    }

    #[test]
    fn a_vein_is_cut_at_the_limit() {
        let mut s = settings();
        s.max_blocks = 2;
        let read = |p: Pos| -> Option<String> { Some(format!("minecraft:iron_ore@p{}", p[1])) };
        let mut read = read;
        let vein = fill([0, 0, 0], "minecraft:iron_ore", s, &mut read);
        assert_eq!(vein.blocks.len(), 2);
        assert!(vein.truncated);
    }

    #[test]
    fn the_connect_choice_limits_the_neighbours() {
        assert_eq!(Connect::Faces.offsets().len(), 6);
        assert_eq!(Connect::FacesAndEdges.offsets().len(), 18);
        assert_eq!(Connect::All.offsets().len(), 26);
        assert_eq!(Connect::from_index(0), Connect::Faces);
        assert_eq!(Connect::from_index(99), Connect::All);
    }

    #[test]
    fn the_settings_decide_what_may_be_mined() {
        let mut s = settings();
        assert!(s.mines(family("minecraft:iron_ore")));
        assert!(s.mines(family("minecraft:oak_log")));
        s.mine_ores = false;
        assert!(!s.mines(family("minecraft:iron_ore")));
        assert!(s.mines(family("minecraft:oak_log")));
        assert!(!s.mines(None));
    }

    #[test]
    fn max_blocks_is_clamped() {
        assert_eq!(Settings::clamped_max_blocks(0.0), 1);
        assert_eq!(Settings::clamped_max_blocks(f64::NAN), 1);
        assert_eq!(Settings::clamped_max_blocks(64.0), 64);
        assert_eq!(Settings::clamped_max_blocks(1e9), MAX_BLOCKS_LIMIT);
    }

    #[test]
    fn defaults_work_without_sneaking() {
        let s = Settings::default();
        assert!(s.enabled);
        assert!(!s.require_sneak);
        assert_eq!(s.max_blocks, DEFAULT_MAX_BLOCKS);
        assert_eq!(s.connect, Connect::All);
    }
}
