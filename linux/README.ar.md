<div dir="rtl">

# Kivun Terminal — البداية السريعة لـ Linux

سكربت تثبيت بيركّب Claude Code مع بروفايل Konsole بستايل Kivun واندماج مع مدراء الملفات للعربي/العبري/الفارسي وباقي لغات RTL.

## التوزيعات المدعومة

| العيلة         | مدير الباكاجات | متجرّبة على                       |
|----------------|----------------|------------------------------------|
| Debian/Ubuntu  | `apt`          | Ubuntu 22.04 / 24.04, Debian 12   |
| Fedora/RHEL    | `dnf`          | Fedora 40                          |
| Arch/Manjaro   | `pacman`       | Arch Linux, Manjaro                |
| openSUSE       | `zypper`       | openSUSE Tumbleweed                |

التوزيعات التانية بتشتغل إذا ثبّتت `konsole`, `nodejs`, `git`, و `zenity` (أو `kdialog`) يدوياً، وبعدين شغّل التثبيت — راح يتخطّى خطوة الباكاجات.

## شو بعمل برنامج التثبيت

١. بكشف مدير الباكاجات وبيئة سطح المكتب وبثبّت: `konsole`, `nodejs`, `git`, خط emoji ملوّن، ومساعد لاختيار المجلّدات — `kdialog` على KDE/Plasma (عشان نتجنّب جر اعتماديات GTK)، `zenity` بأي مكان تاني.  
٢. بثبّت Claude Code CLI عبر برنامج التثبيت الرسمي تبع Anthropic (بيتخطّاه إذا `claude` موجود بالـ PATH).  
٣. بنزّل `statusline.mjs` على `~/.local/share/kivun-terminal/` وبسجّله بـ `~/.claude/settings.json`.  
٤. بكتب بروفايل Konsole اسمه `KivunTerminal` مع `BidiEnabled=true` وschema لون أزرق فاتح اسمه `ColorSchemeNoam`.  
٥. بثبّت اللانشر بـ `~/.local/bin/kivun-terminal` وبضيف `~/.local/bin` لـ `$PATH` (بـ `.bashrc` / `.zshrc`).  
٦. بنشئ entry بقائمة التطبيقات `~/.local/share/applications/kivun-terminal.desktop` ولانشر دسكتوب بـ `~/Desktop/Kivun Terminal.desktop`.  
٧. بثبّت اندماج الكبسة اليمنى لـ GNOME Files (Nautilus scripts) و KDE Dolphin (service menu).  
٨. بنشر الـ **`kivun-claude-bidi` wrapper** على `~/.local/share/kivun-terminal/kivun-claude-bidi/` وبشغّل `npm install --production` مرة وحدة. اللانشر بمرّر Claude Code من خلال هاد الـ wrapper عشان يصلّح باغ اتجاه السطر بالعربي/العبري بغض النظر عن إعدادات BiDi بـ Konsole (شغّال افتراضياً؛ تحكّم فيه عبر `KIVUN_BIDI_WRAPPER`). إذا `npm` مش بـ PATH وقت التثبيت، اللانشر رح يحاول كمان مرة بأول تشغيل.  
٩. بنشئ `~/.config/kivun-terminal/config.txt` بإعدادات افتراضية (RTL، ألوان Kivun، رد بالإنجليزي، تبديل كيبورد بـ Alt+Shift، الـ BiDi wrapper شغّال).

باكاجات النظام بتنثبّت كـ root عبر `sudo`؛ كل شي تاني بنحط بهوم المستخدم — مفي ملفات على مستوى النظام.

## التثبيت

```bash
git clone https://github.com/noambrand/Kivun-Terminal_website.git
cd Kivun-Terminal_website/kivun-terminal-wsl
chmod +x linux/install.sh
./linux/install.sh
```

راح يطلب منك باسوورد sudo مرة وحدة (لخطوة تثبيت الباكاجات). بعد ما يخلص التثبيت، إمّا:

- ابدأ shell جديد (عشان `~/.local/bin` يكون بـ `$PATH`)، وبعدين شغّل `kivun-terminal`، أو
- دوّر بقائمة التطبيقات على **Kivun Terminal**، أو
- اضغط دبل-كليك على **Kivun Terminal.desktop** عالدسكتوب، أو
- كبسة يمين على أي مجلّد ← **Scripts → Open with Kivun Terminal** (Nautilus) / **Open with Kivun Terminal** (Dolphin).

لوغ التثبيت: `/tmp/kivun_install.log`

## ملف الإعدادات

`~/.config/kivun-terminal/config.txt`:

| المفتاح | القيم | الافتراضي | ملاحظات |
|---|---|---|---|
| `RESPONSE_LANGUAGE` | ٢٣ قيمة (شوف تحت) | `english` | بنضاف كـ `--append-system-prompt "Always respond in …"` |
| `TEXT_DIRECTION` | `rtl` / `ltr` | `rtl` | بحوّل `BidiEnabled` بـ Konsole |
| `TERMINAL_COLOR` | `kivun` / `dark` / `black` / `white` / `default` / `#RRGGBB` | `kivun` | لون الخلفية؛ لون النص يُختار تلقائياً. `default` يُبقي ثيم Konsole الخاص بك |
| `KEYBOARD_TOGGLE` | `true` / `false` | `true` | بظبّط Alt+Shift US ↔ ليّاوت السكربت الأساسي عبر setxkbmap (X11 بس) |
| `FOLDER_PICKER` | `true` / `false` | `false` | بيطلّع zenity/kdialog لاختيار مجلّد قبل التشغيل |
| `CLAUDE_FLAGS` | - | فاضي | فلاغات إضافية بتنبعت لكل تشغيل لـ `claude` (مثلاً `--continue`) |
| `KIVUN_BIDI_WRAPPER` | `on` / `off` | `on` | تمرير Claude من الـ BiDi wrapper للحصول على عرض صحيح للعربي/العبري |

قيم `RESPONSE_LANGUAGE` المدعومة: `english, hebrew, arabic, persian, urdu, kurdish, pashto, sindhi, yiddish, syriac, dhivehi, nko, adlam, mandaic, samaritan, dari, uyghur, balochi, kashmiri, shahmukhi, azeri-south, jawi, turoyo`.

التغييرات بتشتغل بالتشغيل الجاي — مش لازم إعادة تثبيت.

## إلغاء التثبيت

```bash
./linux/uninstall.sh
```

بشيل اللانشر، الإعدادات، بروفايل Konsole، entries الدسكتوب، واندماج مدير الملفات. باكاجات النظام (konsole, nodejs, git, claude) **ما بنشيلها** — إذا بدك شيلهم بإيدك.

## تبديل الكيبورد على Wayland

`setxkbmap` بشتغل بس على X11. بجلسات Wayland (GNOME Wayland، KDE Plasma Wayland بالإصدارات الحديثة)، استعمل لوحة إعدادات الكيبورد بسطح المكتب لتضيف ليّاوت تاني وتربط Alt+Shift كمفتاح التبديل — برنامج التثبيت رح يلوغ تحذير ويتخطّى الإعداد التلقائي بهيك حالة.

## محدوديات معروفة

- **اتجاه أول سطر بالعربي/العبري**: اتصلّح بـ v1.1.0 من خلال الـ `kivun-claude-bidi` wrapper المدمج (شغّال افتراضياً). الـ wrapper بحقن RLM ببداية السطر لما الحرف القوي الأول يكون RTL، وهيك بفرض اتجاه الفقرة. عطّله بـ `KIVUN_BIDI_WRAPPER=off` إذا بدك تجربة copy-paste نظيفة. issue التتبّع upstream: [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881).
- **تبديل كيبورد على Wayland**: `setxkbmap` لـ X11 بس. شوف القسم اللي فوق.
- **خط emoji على توزيعات قديمة**: على Ubuntu < 22.04 أو Fedora < 38، `fonts-noto-color-emoji` ممكن ما يكون موجود؛ ثبّت `noto-fonts-emoji` أو شي مشابه يدوياً.

## بناء من المصدر

مفي خطوة "build" على Linux — `install.sh` بنسخ الملفات مباشرة من `payload/` و `linux/` لـ `~/.local/`. إذا بدك أرشيف توزيعي، اعمل tar للريبو:

```bash
tar -czf kivun-terminal-linux-$(cat VERSION).tar.gz \
    linux/ payload/ LICENSE VERSION
```

## بناء CI

`.github/workflows/build-linux.yml` بشغّل `install.sh` على Ubuntu runner نظيف بكل tag push وبرفع الـ tarball الناتج كـ workflow artifact + GitHub Release asset.

</div>
