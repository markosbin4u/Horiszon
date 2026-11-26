# Vein Miner — context to paste into a fresh chat

ملف واحد يشرح كل شيء: ما طُلب، ما تقرّر، ما بُني، وأين توقّف العمل. الصقه كاملاً في محادثة
جديدة موصولة بـ GitHub، والمحادثة الجديدة تكمل من حيث توقّفنا بدون أن تعيد أي بحث.

---

## 1. الطلب (بالعربية، كما طلبه المستخدم)

- مود **Vein Miner** لماينكرافت يعمل على **هاتف أندرويد** عبر **Horizon Launcher**
  (نسخة Horizon من Minecraft: Java Edition 26.3، مكتوبة بالكامل بـ Rust).
- **بدون الحاجة إلى Sneak / Shift**: كسر خامة واحدة يكسر العرق كله.
- **إعدادات خاصة بالمود**: `enabled`, `require_sneak`, `max_blocks`, `mine_ores`, `mine_logs`.
- يكسر البلوكات المتصلة **من نفس النوع** بأداة اللاعب نفسها (الدروبات والإنشانتمنتات واستهلاك
  الأداة كلها من اللعبة نفسها).
- **الحد الأقصى 64 بلوك**.
- التوزيع يجب أن يعمل **بدون كتالوج المودات داخل Horizon** (المستخدم يقول إنه معطّل/لا يعمل)،
  عبر **GitHub Actions** في مستودع `markosbin4u/Horiszon`.
- المستخدم **على الهاتف فقط**: لا حاسوب، ولا Rust مثبّت محلياً. كل شيء يجب أن يُدار من الهاتف.

### قيود ثابتة
- الرد بالعربية.
- الحل المختار من المستخدم: **البناء عبر GitHub Actions** ("الحل الثاني").
- ملف التسليم بامتداد `.hmod` (حزمة مود، ليست تطبيق أندرويد — نوّضّح ذلك للمستخدم).

---

## 2. المستودع والحالة

- المستودع: `github.com/markosbin4u/Horiszon`
- الفرع الحالي: `arena/8c86d73c-horiszon` (من `main` عند `60bda52`)
- Pull Request: `#1` — https://github.com/markosbin4u/Horiszon/pull/1

### ملفات المود (كلها في جذر المستودع)
```
horizon-mod.toml                        وصف الحزمة (id=vein_miner, api="0.2", side="both")
Cargo.toml                              الحزمة + تثبيت SDK في [package.metadata.horizon]
src/core.rs                             قواعد المود بدون أي اعتماد على اللعبة + اختبارات
src/lib.rs                              سطح الـ API: register / break_block / server_tick
assets/vein_miner/lang/en_us.json       نصوص صفحة الإعدادات
.github/workflows/build.yml             بناء على Linux + رفع vein_miner.hmod
.gitignore                              .horizon/ و target/
```

`lib.rs` القديم في الجذر (API وهمي: `host.tool_break_block`, `player.is_sneaking()`) حُذف —
لا داعي لإعادته.

---

## 3. حقائق API مُتحقَّق منها

كل رقم سطر أدناه من SDK مثبَّت في `Cargo.toml`:
`sdk = "4dc6455d4a6773224792eb1f121a9b939dff3170"` (إصدار 2026-11-15).
أداة البناء: `tools/ci/rust-version` = **1.99.1**.

### الهوكس
```rust
#[mod_api::horizon_mod]
impl Hooks for VeinMiner {
    fn register(&self, r: &mut dyn Registrar, _: &RegistrationContext) { … }
    fn break_block(&self, host: &mut dyn ServerHost, event: &mut BreakBlockEvent<'_>) -> Flow { … }
    fn server_tick(&self, host: &mut dyn ServerHost, event: &mut ServerTickEvent<'_>) { … }
}
```
- `break_block`: `side="server"`, `contract="cancel"`, `out="canceled"`, يقابل NeoForge `BreakBlockEvent`.
- `ServerTickPhase::{ServerTickStart, ServerTickEnd}`.
- `event.pos` للحقل، و`event.state.block().id(host)` لاسم البلوك.

### كسر بلوك «كما يفعل اللاعب»
```rust
player.destroy_block(host, pos, false) -> bool   // PlayerRef::destroy_block
```
هذه أهم دالة في المود: تُشغّل مسار اللعبة الحقيقي — الدروبات، Fortune، Silk Touch،
استهلاك الأداة، الإحصاء، الـ exhaustion. (`host/players.rs` → `PlayersBackendMut`,
السطر ~992؛ تُعرض للمود على الهاندل.)

### قراءة العالم
```rust
let level = player.level(&*host)?;                 // Option<LevelRef>
let key   = level.block(&*host, pos)?;             // Option<BlockKey>
let name  = key.id(&*host);                        // String, مثل "minecraft:iron_ore"
```

### اللاعبون والإعدادات
```rust
let player = host.players().acting_player()?;      // Option<PlayerRef>
player.uuid() -> u128
player.entity().is_shift_key_down(&*host) -> Option<bool>
host.on("vein_miner") -> bool                     // مفتاح اللعبة في Options > Mods
host.setting("vein_miner", key) -> Option<String> // نص الإعداد كما حفظته اللعبة
spec.read(stored.as_deref()) -> SettingValue      // يحوّله مع الرجوع للافتراضي
```

### صفحة الإعدادات
```rust
SettingSpec::toggle(key, "vein_miner.setting.<key>", default).tooltip("….tooltip")
SettingSpec::range(key, label, min, max, step, default)
SettingSpec::choice(key, label, [options…], default_index)
```
`SettingValue::{Toggle(bool), Choice(usize), Range(f64), Color(u32)}`.

---

## 4. قرارات التصميم ولماذا

1. **طابور بدل كسر فوري في الـ hook.** `destroy_block` تُطلق `break_block` من جديد، واللعبة
   ترفض كسراً يبدأ من داخل ثمانية كسرات. لذلك `break_block` **يجد** العرق ويضعه في طابور،
   و`server_tick` يكسر **4 بلوكات في التيك** (`PER_TICK`). النتيجة: لا تعشيش، وعرق كبير
   ينتهي خلال لحظات بدل تعليق التيك.
2. **لا إلغاء لكسر اللاعب.** الهوك يعيد `Flow::Continue` دائماً: البلوك المستهدف يُكسر كما
   تكسره اللعبة تماماً، والبقية تُكسر كذلك عبر `destroy_block` — فلا داعي لإعادة تنفيذ
   الدروبات يدوياً.
3. **قفل إعادة الدخول** (`AtomicBool breaking`) حتى لا يُعاد تعدين كسرات المود نفسه.
4. **وظيفة لكل لاعب**: كسر جديد لنفس اللاعب يستبدل القديم، حتى لا تتراكم مواقع قديمة.
5. **`JOB_TTL_TICKS = 60`**: مهمة قديمة تُسقط بدل أن تكسر بلوكات تغيّر العالم تحتها.
6. **العائلات**: حجر وأرضية (`iron_ore` + `deepslate_iron_ore`) عرق واحد؛
   `oak_log` + `stripped_oak_wood` شجرة واحدة؛ الخام لا يختلط بالخشب أبداً؛
   `mushroom_stem` مستثنى.
7. **`connect`**: 6 / 18 / 26 جار، الافتراضي 26 حتى لا يُقطع عرق مائل.
8. **`side = "both"`**: صفحة الإعدادات واجهة عميل، والمنطق خادم — والمود يحتاج الاثنين.

---

## 5. حالة البناء (CI)

الـ workflow القديم كان يفشل عند أول خطوة:
```
Installing cargo-horizon-mod … exit 101
cargo install --locked --git https://github.com/horizon-rust/horizon cargo-horizon-mod
```
السبب: `horizon-rust/horizon` لم يبقَ موجوداً. المشروع الآن في `arismoko/horizon`.

الـ workflow الحالي:
1. يقرأ تثبيت SDK من `Cargo.toml`.
2. يجلب **تلك الـ commit بالذات** من `arismoko/horizon` ويبني `cargo-horizon-mod` منها
   (`--release --locked`) — الأداة والـ SDK يجب أن يكونا نفس البناء.
3. يشغّل `cargo horizon-mod build --wasm` (الأداة تنزّل الـ SDK إلى `.horizon/sdk/` وتثبّت
   Rust 1.99.1 مع `rust-src` بنفسها، وتبني std من المصدر عبر `-Zbuild-std`).
4. يشغّل `cargo horizon-mod check`.
5. يرفع `target/horizon-mod/vein_miner.hmod` كـ artifact باسم `vein_miner-hmod`.

ملاحظة: `workflow_dispatch` غير متاح للـ GitHub App المستخدم هنا (403)، لذلك البناء يُشغَّل
بفتح Pull Request — والـ workflow يستمع إلى `pull_request`.

### أين نُقلع الآن
آخر تشغيل: https://github.com/markosbin4u/Horiszon/actions/runs/45892116964
(PR #1، job `140157045142`). الخطوات التي نجحت: checkout، قراءة التثبيت، الكاش.
الخطوة الجارية: **Build cargo-horizon-mod at the SDK commit** (بناء الأداة من المصدر يستغرق
عدة دقائق). بعدها تُبنى `mod.wasm` وننتظر الـ artifact.

---

## 6. الخطوة التالية بالضبط

1. افتح `gh run list` / صفحة Actions، وانتظر انتهاء `45892116964`.
2. إن نجح: نزّل `vein_miner-hmod` من صفحة التشغيل، وفك الضغط → `vein_miner.hmod`.
3. إن فشل في `cargo horizon-mod build --wasm`: الرسالة ستكون خطأ Rust في `src/lib.rs`.
   أشهر احتمال: import أو توقيع دالة تغيّر بين إصدارات الـ SDK. عندئذٍ:
   - تحقّق من الاسم في الـ SDK نفسه داخل التشغيل (`.horizon/sdk/api/crates/horizon-mod-vocab/src/…`)،
   - لا تعتمد على الذاكرة: الملفات موجودة في الـ runner بعد فشل الخطوة.
4. بعد نجاح الـ artifact: تُنشر الحزمة في Release ليكون الرابط ثابتاً للهاتف:
   `gh release create v1.0.0 target/horizon-mod/vein_miner.hmod`
   (لا يعمل رفع الـ artifact من متصفح الهاتف بدون تسجيل دخول، أما رابط Release فمباشر.)

### التثبيت على الهاتف
1. نزّل `vein_miner.hmod`.
2. في Horizon: نسخة اللعبة ⋮ ← **Open folder** ← مجلد `horizon-mods/`.
3. انسخ الملف هناك.
4. بجانب `options.txt` يوجد `horizon-mods.txt` — أضف سطراً:
   ```
   mod.vein_miner:true
   ```
5. شغّل اللعبة. الإعدادات: **Options > Mods > Vein Miner > Config**.

---

## 7. أفخاخ واجهناها (لا تُعاد)

- `horizon-rust/*` غير موجود. الصحيح: `arismoko/horizon`.
- الساندبوكس لا يصل إلى `raw.githubusercontent.com` ولا `release-assets.githubusercontent.com`
  ولا `crates.io` ولا `static.rust-lang.org`. تحميل أصول Releases يفشل بـ SSL (exit 35).
  لكن `gh api .../contents` و`curl` إلى GitHub API يعملان — استخدمهما لقراءة المصدر.
- لا يوجد Rust محلياً: التحقق الوحيد عبر CI.
- `setting_bool` / `setting_choice` / `setting_f64` عميلية (`ClientSetup`/`WorldOnly`)؛ مود
  يعمل على الخادم يقرأ بـ `host.setting(MOD_ID, key)` ثم `spec.read(...)`.
- لا تُخمّن مسارات ملفات الـ API — اسرد المجلد أولاً:
  `gh api "repos/arismoko/horizon/contents/<dir>?ref=<sha>" --jq '.[].name'`
- `gh workflow run` يعطي 403 مع هذا التكامل: شغّل البناء بـ PR.
- `gh api .../tarball > file` يكتب JSON خطأ 404؛ لا يوجد `--output` في هذه النسخة.

---

## 8. مراجع سريعة

| ما تريده | المسار |
|---|---|
| بناء wasm وواجهته | `crates/cargo-horizon-mod/src/wasm.rs` (TOOLCHAIN, `-Zbuild-std`) |
| توقيع دوال الهوكس | `crates/horizon-mod-vocab/src/hooks/break_block.rs` |
| `destroy_block` | `crates/horizon-mod-vocab/src/host/players.rs` |
| الإعدادات | `crates/horizon-mod-vocab/src/content/mod_settings.rs` |
| مخطط `horizon-mod.toml` | `crates/horizon-mod-package/src/manifest.rs` |
| مود wasm حقيقي بإعدادات | `vstxx/shulkerpeek` → `wasm/src/lib.rs` |
| مود veinminer سابق (native، API قديم) | `Rismose/veinminer-horizon` → `src/lib.rs` |
| مود بـ `server_tick` + طابور | `fallingtrees` (ضمن `arismoko` mods) |

كل ما سبق يُقرأ عبر:
```
gh api "repos/arismoko/horizon/contents/<path>?ref=4dc6455d4a6773224792eb1f121a9b939dff3170" \
  -H "Accept: application/vnd.github.raw"
```
