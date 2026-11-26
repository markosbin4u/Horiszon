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
- Pull Request: `#1` — **مدموج** في `main`
- العمل كله موجود أيضاً على `main`؛ وأي push إلى `main` يعيد البناء ويُحدّث الـ Release

### ملفات المود (كلها في جذر المستودع)
```
horizon-mod.toml                        وصف الحزمة (id=vein_miner, api="0.2", side="both")
Cargo.toml                              الحزمة + تثبيت SDK في [package.metadata.horizon]
src/core.rs                             قواعد المود بدون أي اعتماد على اللعبة + اختبارات
src/lib.rs                              سطح الـ API: register / break_block / server_tick
assets/vein_miner/lang/en_us.json       نصوص صفحة الإعدادات
.github/workflows/build.yml             بناء على Linux + اختبارات + Release + سجل
.gitignore                              .horizon/ و target/
HANDOFF.md                              هذا الملف
ci-build-log.md                         يُكتب تلقائياً من CI (لا يُحرَّر يدوياً)
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

## 5. حالة البناء — تمّ بنجاح ✅

الـ workflow القديم كان يفشل عند أول خطوة:
```
Installing cargo-horizon-mod … exit 101
cargo install --locked --git https://github.com/horizon-rust/horizon cargo-horizon-mod
```
السبب: `horizon-rust/horizon` لم يبقَ موجوداً. المشروع الآن في `arismoko/horizon`.

### الـ workflow النهائي (`.github/workflows/build.yml`)
1. يقرأ تثبيت SDK من `Cargo.toml`.
2. يجلب **تلك الـ commit بالذات** من `arismoko/horizon` ويبني `cargo-horizon-mod`
   (`--release --locked`) — الأداة والـ SDK يجب أن يكونا نفس البناء.
3. `cargo horizon-mod build --wasm` → الأداة تنزّل الـ SDK إلى `.horizon/sdk/`، وتثبّت
   Rust 1.99.1 مع `rust-src` بنفسها، وتبني std من المصدر (`-Zbuild-std`)، وتُخرج
   `target/horizon-mod/vein_miner.hmod`.
4. `cargo "+1.99.1" test --lib` → 15 اختبار (`core` + الإعدادات)، كلها ناجحة.
5. `cargo horizon-mod check` — **استشارية** (`continue-on-error`): تُعيد تصريف المود
   لـ wasm32 بدون `-Zbuild-std`، وهذه السلسلة لا تحمل std مبنية مسبقاً لـ wasm32، فتفشل
   بـ `E0463` على `serde_core` حتى للمود السليم. ليست خطأ في المود.
6. عند push إلى `main`: يُنشئ Release ويعلّق الملف عليه.
7. في كل الحالات: يكتب `ci-build-log.md` في الفرع (لأن سجلّ التشغيل وملف الـ artifact
   يستخدمان نطاقات قد لا تُفتح من الهاتف ولا من الساندبوكس).

### أخطاء واجهناها وأُصلحت
| الخطأ | الإصلاح |
|---|---|
| `error[E0689]: can't call method abs on ambiguous numeric type` ×3 في `core.rs:72` | حلقات الجيران صارت `-1i32..=1` |
| اختبار `a_vein_is_cut_at_the_limit` يفشل (`left: 0`) | كان الـ fixture يُرجع `minecraft:iron_ore@pN`، وهذا ليس id خامة، فرفض `same_vein` كل جار. صار يُرجع `minecraft:iron_ore` |
| خطوة `check` تفشل بـ `E0463` | صارت استشارية؛ البناء الحقيقي هو ما كتب sha512 في المانيفست |

### المخرَج
- Release: **https://github.com/markosbin4u/Horiszon/releases/tag/v1.0.0**
- تحميل مباشر (يُفتح من متصفح الهاتف):
  **https://github.com/markosbin4u/Horiszon/releases/download/v1.0.0/vein_miner.hmod**
- الحجم: 2,667,734 بايت. آخر تشغيل ناجح على `main`: https://github.com/markosbin4u/Horiszon/actions/runs/45895283054
- PR #1 مدموج في `main`.

### التثبيت على الهاتف
1. افتح رابط التحميل أعلاه ونزّل `vein_miner.hmod`.
2. في Horizon: نسخة اللعبة ← **Mods**، أو من نظام الملفات إلى مجلد اللعبة (الذي فيه `options.txt`)
   ← أنشئ/افتح `horizon-mods/` ← انسخ الملف هناك.
   (مودات WebAssembly `.hmod` تُوضع في `horizon-mods/` — وليس `horizon-native-mods/`.)
3. أضف سطراً في `horizon-mods.txt` بجانب `options.txt`:
   ```
   mod.vein_miner:true
   ```
   (المود المنسوخ يدوياً يبدأ مطفأً؛ السطر `mod.<id>:true` هو ما يشتّغله.)
4. شغّل اللعبة، ثم: **Options > Mods > Vein Miner > Config** للإعدادات.

> ملاحظة للمستخدم: `.hmod` **حزمة مود** (داخلها `mod.wasm` + المانيفست + النصوص)، وليست
> تطبيق أندرويد ولا تُثبَّت من مدير التطبيقات.

### إن أردت بناءً جديداً بعد أي تعديل
ادفع إلى `main` (أو افتح PR) — البناء يعمل تلقائياً، ويُحدّث الـ Release إن تغيّر رقم
`version` في `horizon-mod.toml`.

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
