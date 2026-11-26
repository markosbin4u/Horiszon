use std::collections::{HashSet, VecDeque};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::RwLock;

use mod_api::{self, BlockPos, BreakBlockEvent, Flow, Hooks, ServerHost};

/// Mod settings for Vein Miner.
#[derive(Debug, Clone)]
pub struct VeinMinerConfig {
    /// Enable or disable vein mining.
    pub enabled: bool,
    /// If true, player must sneak (Shift) to vein mine. Default: false (works without Shift).
    pub require_sneak: bool,
    /// Maximum number of connected blocks to break at once.
    pub max_blocks: usize,
    /// Mine ores (*_ore, ancient_debris).
    pub mine_ores: bool,
    /// Mine trees/logs (*_log, *_wood, *_stem).
    pub mine_logs: bool,
}

impl Default for VeinMinerConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            require_sneak: false,
            max_blocks: 64,
            mine_ores: true,
            mine_logs: true,
        }
    }
}

fn is_vein_mineable(block_id: &str, cfg: &VeinMinerConfig) -> bool {
    if cfg.mine_ores
        && (block_id.ends_with("_ore")
            || block_id == "minecraft:ancient_debris"
            || block_id == "minecraft:glowstone")
    {
        return true;
    }
    if cfg.mine_logs
        && (block_id.ends_with("_log")
            || block_id.ends_with("_wood")
            || block_id.ends_with("_stem"))
    {
        return true;
    }
    block_id == "minecraft:clay"
}

fn neighbors_26(pos: BlockPos) -> impl Iterator<Item = BlockPos> {
    (-1..=1).flat_map(move |dx| {
        (-1..=1).flat_map(move |dy| {
            (-1..=1).filter_map(move |dz| {
                if dx == 0 && dy == 0 && dz == 0 {
                    None
                } else {
                    Some(BlockPos::new(pos.x + dx, pos.y + dy, pos.z + dz))
                }
            })
        })
    })
}

#[derive(Default)]
pub struct VeinMinerMod {
    config: RwLock<VeinMinerConfig>,
    is_vein_mining: AtomicBool,
}

#[mod_api::horizon_mod]
impl Hooks for VeinMinerMod {
    fn break_block(&self, host: &mut dyn ServerHost, event: &mut BreakBlockEvent<'_>) -> Flow {
        if self.is_vein_mining.load(Ordering::Relaxed) {
            return Flow::Continue;
        }

        let cfg = self.config.read().map(|c| c.clone()).unwrap_or_default();
        if !cfg.enabled {
            return Flow::Continue;
        }

        let Some(player_id) = event.player else {
            return Flow::Continue;
        };
        let Some(player) = host.player(player_id) else {
            return Flow::Continue;
        };

        // Only check sneak if require_sneak is enabled in settings.
        if cfg.require_sneak && !player.is_sneaking(host) {
            return Flow::Continue;
        }

        let target_block = event.block.as_str();
        if !is_vein_mineable(target_block, &cfg) {
            return Flow::Continue;
        }

        let mut visited = HashSet::new();
        let mut queue = VecDeque::new();
        let mut to_break = Vec::new();

        visited.insert(event.pos);
        queue.push_back(event.pos);

        while let Some(current) = queue.pop_front() {
            for next in neighbors_26(current) {
                if visited.contains(&next) {
                    continue;
                }
                visited.insert(next);

                if host.level().block_id_at(next).as_deref() == Some(target_block) {
                    to_break.push(next);
                    if to_break.len() >= cfg.max_blocks {
                        break;
                    }
                    queue.push_back(next);
                }
            }
            if to_break.len() >= cfg.max_blocks {
                break;
            }
        }

        if to_break.is_empty() {
            return Flow::Continue;
        }

        self.is_vein_mining.store(true, Ordering::Relaxed);
        for pos in to_break {
            let _ = host.tool_break_block(player_id, pos);
        }
        self.is_vein_mining.store(false, Ordering::Relaxed);

        Flow::Continue
    }
}
