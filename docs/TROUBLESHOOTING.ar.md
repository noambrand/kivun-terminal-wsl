# Kivun Terminal v1.4.25 — استكشاف الأخطاء وحلّها

<div dir="rtl">

> **macOS صار deprecated من v1.2.4.** الملف هاد لسا فيه أقسام لـ macOS لأنه المستخدمين اللي عندهم تثبيت `.pkg` من v1.2.0–v1.2.3 ممكن يحتاجوها للتشخيص أو الاسترجاع. أي تثبيت جديد لازم يكون على Windows أو Linux. شوف [`mac/README.md`](../mac/README.md) للسياق وطريقة إلغاء التثبيت.

## 🆘 ابعت تقرير تشخيص (أسرع طريقة تاخد مساعدة)

إذا في إشي مش شغّال، شغّل أداة التشخيص — بتكتب **`Kivun-Report.txt`** على سطح المكتب وبتفتحه بـ Notepad:

<ul dir="rtl">
<li><strong>التثبيت خلص منيح؟</strong> افتح <strong>"Kivun Diagnostics"</strong> من قائمة Start (بنركّب مع Kivun Terminal).</li>
<li><strong>التثبيت فشل / مفيش اختصار بقائمة Start؟</strong> (متلاً الـ virtualization كان مسكّر والمثبّت وقف قبل ما يخلّص) — نزّل <strong><code>kivun-diagnostics.cmd</code></strong> مباشرة من <a href="https://github.com/noambrand/kivun-terminal-wsl/releases/latest">آخر إصدار</a> واضغط عليه دبل-كلك. بشتغل لحاله، ما بدّو تثبيت.</li>
</ul>

**ابعت الملف بالإيميل لـ noambbb@gmail.com**، أو أرفقه بـ issue جديد على <https://github.com/noambrand/kivun-terminal-wsl/issues>.

التقرير بلقط إصدار Windows تبعك، إذا الـ **virtualization** شغّال، حالة الـ **WSL**، شو **antivirus** عم يشتغل، والـ **install log** تبع Kivun — بالضبط شو لازم لتشخيص معظم المشاكل. ما ببعت إشي تلقائياً، ما بدّو صلاحيات admin، وما بستخدم PowerShell.

## شريط الحالة: تخصيص شو بيبيّن على السطر الأول (v1.4.10+)

`payload/statusline.mjs` (إصدار داخلي v2.2) بقرا أربع متغيرات بيئة. كلها اختيارية.

<table dir="rtl">
<thead><tr><th>متغير البيئة</th><th>الافتراضي</th><th>التأثير</th></tr></thead>
<tbody>
<tr><td><code>CLAUDE_CODE_EFFORT_LEVEL</code></td><td><em>مش محدد</em></td><td>بجبر حقل الـ <code>effort:</code> بالسطر الأول على القيمة المعطاة (متلاً <code>low</code>، <code>medium</code>، <code>high</code>، <code>max</code>). بنستخدم لما <code>d.effort.level</code> مش موجود بالـ JSON تبع الـ statusline (مشكلة Anthropic <a href="https://github.com/anthropics/claude-code/issues/40261">#40261</a> — لسا مفتوحة) وما بدك تعتمد على الـ fallback من <code>~/.claude/settings.json</code>.</td></tr>
<tr><td><code>KIVUN_SL_COST</code></td><td>مش محدد</td><td>حطّه <code>1</code> / <code>true</code> / <code>yes</code> / <code>on</code> لعرض كلفة الجلسة بالدولار (<code>$X.XX</code>، أخضر) على السطر الأول بين الموديل والمدة.</td></tr>
<tr><td><code>KIVUN_SL_CACHE</code></td><td>مش محدد</td><td>حطّه على قيمة truthy لعرض الـ tokens المخزّنة (<code>cache:N</code>، أزرق) — مجموع <code>cache_read_input_tokens</code> + <code>cache_creation_input_tokens</code>.</td></tr>
<tr><td><code>KIVUN_SL_TPM</code></td><td>مش محدد</td><td>حطّه على قيمة truthy لعرض معدّل الـ tokens بالدقيقة (<code>tpm:N</code>، سماوي). بنحجب بأول 5 ثواني من الجلسة لتجنّب أرقام صغيرة مش مفيدة.</td></tr>
</tbody>
</table>

ضيف لـ shell rc تبعك (Linux/WSL/macOS):

```bash
export KIVUN_SL_COST=1
export KIVUN_SL_CACHE=1
export KIVUN_SL_TPM=1
```

على Windows (PowerShell)، ضيف لـ `$PROFILE` تبعك:

```powershell
$env:KIVUN_SL_COST = '1'
$env:KIVUN_SL_CACHE = '1'
$env:KIVUN_SL_TPM = '1'
```

أعد تشغيل جلسة Claude Code حتى التغييرات تمسك.

**ترتيب حلّ الـ effort** (`readEffort()` بـ `statusline.mjs`):

<ol dir="rtl">
<li><code>d.effort.level</code> من الـ JSON payload تبع الـ statusline (متوافق للأمام — بيبيّن لما Anthropic يشحنوا issue #40261).</li>
<li>متغير البيئة <code>CLAUDE_CODE_EFFORT_LEVEL</code>.</li>
<li>مفتاح <code>effortLevel</code> بـ <code>~/.claude/settings.json</code>. <strong>ثغرة معروفة:</strong> <code>settings.json</code> ما بنكتب من جديد لما تبدّل الـ effort بنص الجلسة عبر <code>/effort</code> — شريط الحالة رح يضل يعرض شو كان مظبوط ببداية الجلسة لحد ما #40261 يوصل.</li>
<li>إذا ولا إشي اتحلّ، الحقل بنخفى كلياً.</li>
</ol>

## أول إشي: اجمع الـ logs

كل مرة بتشغّل البرنامج بكتب ملفين log:

<ul dir="rtl">
<li><code>%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt</code> — خطوات الـ Windows batch launcher</li>
<li><code>%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt</code> — خطوات الـ bash launcher من جهة WSL</li>
</ul>

افتح الاثنين بـ Notepad. اقرأ من تحت لفوق ودوّر على السطور اللي بتبلّش بـ `ERROR` أو `WARNING`.

## العَرَض: "WSL not found or not working"

**السبب:** WSL2 مش مفعّل، أو ميزات Windows الاختيارية مش متركّبة.

**الحل:**

```cmd
wsl --install
```

اعمل reboot. شغّل مثبّت Kivun Terminal من جديد — رح يكتشف إنه WSL صار موجود ويكمّل.

## العَرَض: "Ubuntu not available"

**السبب:** WSL شغّال بس توزيعة Ubuntu مش مسجّلة.

**الحل:**

```cmd
wsl --install -d Ubuntu
```

استنى لمّا يخلص إعداد المستخدم لأول مرة، حدّد اسم المستخدم وكلمة السر تبعت Ubuntu، بعدين سكّر وافتح Kivun Terminal من جديد.

## العَرَض: "Claude Code: NOT FOUND"

**السبب:** الـ Claude Code CLI مش متركّب جوّا Ubuntu (قسم المثبّت فشل أو انحطّ على جنب). **Claude Code اللي على Windows ما بنفع هون** — Kivun Terminal بشغّل Konsole عبر WSL وبشوف بس الـ PATH تبع Ubuntu.

**v1.1.1 وأحدث:** الـ launcher نفسه هلا بعرض إنه يركّب Claude Code لمّا يكتشف إنه ناقص. جاوب `Y` على السؤال والـ launcher رح يشغّل المثبّت الرسمي. قبل v1.1.1 الـ launcher كان بدّعي إنه "fall back to direct Claude execution" وبعدين بكرَش بـ `bash: claude: command not found` — الـ fallback كان كذبة؛ انحلّ بـ v1.1.1.

**حل يدوي (مرة وحدة، نفس اللي v1.1.1 بعمله أوتوماتيكي):**

```cmd
wsl -d Ubuntu -u root -- bash -lc "curl -fsSL https://claude.ai/install.sh | bash"
```

إذا الـ curl installer فشل (mirror offline، شبكة محجوبة، إلخ)، ارجع لتثبيت npm:

```cmd
wsl -d Ubuntu -u root -- bash -lc "apt-get install -y nodejs npm && npm install -g @anthropic-ai/claude-code"
```

ملاحظة: `npm install -g @anthropic-ai/claude-code` صار deprecated حسب توثيق Anthropic الحالي؛ الـ launcher والمثبّت الاثنين بفضّلوا الـ curl script. طريق npm fallback لما الـ curl script ما بقدر يوصل لـ `claude.ai`.

بعد التثبيت، تحقّق: `wsl -d Ubuntu -- claude --version`. وبعدين شغّل Kivun Terminal من جديد.

## العَرَض: نافذة Konsole عمرها ما بتظهر (وضع WSLg)

الـ launcher log بقول إنه Konsole اشتغل (في PID مذكور، `wmctrl` و `xdotool` الاثنين "لقوا" نافذة) بس ولا نافذة بتبيّن على الـ desktop.

**السبب أ - فحوصات أمان runtime-dir تبع Qt.** Konsole تطبيق Qt و `QStandardPaths` تبع Qt برفض `XDG_RUNTIME_DIR` بحالتين:

1. الـ directory مش مملوك للـ UID الحالي.
2. صلاحيات الـ directory مش `0700`.

WSLg بشحن `/mnt/wslg/runtime-dir` مملوك لأول مستخدم Linux تم إنشاؤه (متلاً `noam` / UID 1000) بصلاحيات `0777`. إذا الـ launcher اشتغل كمستخدم WSL ثاني (متلاً `username` / UID 1001)، الفحصين الاثنين بفشلوا. Konsole بشتغل بس بفشل يلاقي الـ Wayland/D-Bus sockets تبعته، فالنافذة عمرها ما بترتسم بشكل مرئي — دوّر على `QStandardPaths: runtime directory '...' is not owned by UID ...` أو `wrong permissions ... 0777 instead of 0700` بـ `BASH_LAUNCH_LOG.txt`.

الـ launcher هلا بتعامل مع الاثنين: بكتشف مالك الـ runtime-dir تبع WSLg وبشتغل كهداك المستخدم (`wsl --user <owner>`)، وبشدّ الصلاحيات لـ `0700` عند البداية. إذا لسا عندك المشكلة بعد تثبيت قديم، اعمل الإشي يدوي:

```cmd
wsl -d Ubuntu --user root -- chmod 700 /mnt/wslg/runtime-dir
wsl -d Ubuntu --user root -- chown $(stat -c '%U' /mnt/wslg/runtime-dir) /mnt/wslg/runtime-dir
```

**السبب ب - زومبي Konsole قديم.** تشغيل سابق فشل خلّف process Konsole مخفي، و `xdotool search --class konsole` بطابق *هديك* النافذة القديمة بدل الجديدة (العلامة: نفس الـ window ID بكل تشغيل). اقتله:

```cmd
wsl -d Ubuntu -- pkill -x konsole
```

الـ launcher هلا بعمل هاد أوتوماتيكي عند البداية.

**السبب ج - WSLg فعلاً مش موجود** (إصدارات WSL أقدم) أو الـ GPU pass-through مش سليم.

```cmd
wsl --update
wsl --shutdown
```

**Fallback - ارجع لوضع text:** الـ launcher برجع يشغّل Claude مباشرة بنافذة CMD لما Konsole ما بشتغل. رح تخسر الخلفية الزرقا و BiDi rendering، بس Claude رح يشتغل.

## العَرَض: المثبّت بيبيّن متجمّد على "Installing Konsole..." لـ 10+ دقايق

**السبب:** الـ launcher كان بستخدم `sudo apt-get ...` جوّا `wsl -d Ubuntu -- bash -c "..."`. لمّا مستخدم Ubuntu ما عنده passwordless sudo معدّ، sudo بستنى كلمة سر بدون TTY يقرأ منها — التثبيت بعلّق للأبد.

سبب ثانوي: `nsExec::ExecToLog` تبع NSIS ممكن تعمل deadlock لمّا الـ child بنتج كمية كبيرة من الـ output (apt-get بفترة تنزيل Konsole 300-500 MB)، لأنه buffer الـ output-capture بمتلي وبعلّق الـ child.

المثبّت هلا بعمل التالي:

<ul dir="rtl">
<li>بشغّل apt كـ root (<code>wsl -d Ubuntu -u root</code>) — ولا sudo، ولا سؤال كلمة سر.</li>
<li>بحوّل output الـ apt لـ <code>/tmp/kivun-apt.log</code> وبستخدم <code>nsExec::Exec</code> (بدون output capture) — ولا buffer deadlock.</li>
<li>بقسّم التثبيت لـ 6 خطوات صغيرة عشان زر Cancel يضل قابل للاستخدام بين الخطوات.</li>
</ul>

إذا لسا عندك المشكلة بعد builds قديمة، اقتل الـ job العالق والمثبّت:

```cmd
wsl -d Ubuntu --user root -- pkill -9 -f apt-get
```

وبعدين شغّل المثبّت من جديد.

## العَرَض: الـ launcher batch بطلع بصمت بنص التشغيل / الـ shortcut بيبيّن إنه ما بعمل إشي

إذا `LAUNCH_LOG.txt` بيبيّن إنه السكربت وصل لنقطة معيّنة وبعدين وقف (مفي `ERROR`، بس مقطوع)، السبب الأكثر شيوعاً هو **CRLF line endings ضاعت بالطريق**. ملفات CMD batch بحاجتها CRLF. الملفات اللي معدّلة على Linux/WSL أو متنسوخة بـ `cp` من WSL غالباً رح تطلع LF بس، والـ parser تبع CMD بفشل بصمت بـ blocks `if (...)` / `for (...)` المتداخلة المعقّدة.

**الحل:** حوّل لـ DOS line endings:

```cmd
wsl -d Ubuntu -- unix2dos "/mnt/c/Users/%USERNAME%/AppData/Local/Kivun-WSL/kivun-terminal.bat"
```

`kivun-launch.sh` لازم يضل LF (هو Unix shell script). `kivun-terminal.bat` لازم يكون CRLF.

## العَرَض: "Permission denied" على `/tmp/kivun-claude-launch.sh`

**السبب:** تشغيل سابق (كمستخدم WSL ثاني) أنشأ السكربت المؤقت بملكيّته. مستخدمك الحالي ما بقدر يكتب فوقه.

الـ launcher هلا بستخدم path لكل UID (`/tmp/kivun-claude-launch-<uid>.sh`) عشان هاد التضارب ما يصير. للتثبيتات القديمة، نضّف يدوي:

```cmd
wsl -d Ubuntu --user root -- rm -f /tmp/kivun-claude-launch.sh
```

## العَرَض: رد Claude بالعبري/العربي محاذاته يسار بأول سطر

**انحلّ بـ v1.1.0 على الثلاث منصات** (Windows/WSL، Linux، macOS) لمّا BiDi wrapper مفعّل (وهاد الإفتراضي). إذا انت على v1.0.6 أو عندك `KIVUN_BIDI_WRAPPER=off`، البق لسا موجود.

مسارات launch log حسب المنصة (دوّر على `BiDi wrapper active` للتأكّد إنه الـ wrapper شغّال):

<ul dir="rtl">
<li><strong>Windows</strong>: <code>%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt</code></li>
<li><strong>Linux</strong>: <code>~/.local/share/kivun-terminal/launch.log</code></li>
<li><strong>macOS</strong>: شورتكت الـ <code>.command</code> بطبع على نافذة Terminal.app الخاصة فيه؛ postinstall log موجود على <code>/tmp/kivun_install.log</code>.</li>
</ul>

السبب الجذري: Claude Code بحط حرف bullet `●` قبل كل رسالة assistant. الـ BiDi auto-detect تبع Konsole بستخدم كشف اتجاه الفقرة بطريقة "first strong char wins"، بس عمليّاً (شوف `docs/research/paragraph-direction-test.sh`) هو بحترم أول strong char بس إذا ظهر **قبل أي حرف مرئي ثاني**. الـ `●` هو visible neutral، فـ Konsole برجع للـ LTR رغم العبري اللي بعده.

كيف v1.1.0 حلّها: الـ wrapper بحقن RLM zero-width (U+200F، strong-R) بالـ position 0 لكل سطر أول strong char فيه RTL. يعني السطر دايماً بيبلّش بـ strong-R من منظور Konsole، اتجاه الفقرة بصير RTL، والعبري (مع سطر الـ bullet) بترسم محاذاة يمين. السطور اللي بتبدأ بإنجليزي ما بتاخد RLM فالمحتوى اللاتيني بضل LTR.

**إذا شفت البق بـ v1.1.0:**
1. تحقّق من `BASH_LAUNCH_LOG.txt`. لازم تشوف `SUCCESS - BiDi wrapper active`. إذا بدلها شفت `BiDi wrapper off`، عدّل `%LOCALAPPDATA%\Kivun-WSL\config.txt`، حط `KIVUN_BIDI_WRAPPER=on`، شغّل من جديد.
2. إذا الـ log بيبيّن الـ wrapper شغّال بس سطر الـ bullet لسا LTR، هاد بق جديد — لو سمحت افتح issue مع screenshot وإصدار Konsole تبعك (`wsl -d Ubuntu -- konsole --version`).

Upstream tracker (مهم إذا بدك Anthropic تحلّها من المصدر): [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881).

## العَرَض: سطور bullet عبري بترسم مع الـ bullet عـ اليسار بدل اليمين

عندك `KIVUN_BIDI_WRAPPER=on`، الـ launch log بأكّد إنه الـ wrapper شغّال، نص العبري نفسه متشكّل right-to-left صح — بس السطور اللي بتبلّش بـ `● ` متبوع بعبري بثبّتوا الـ bullet على الحافة اليسرى للسطر، والعبري بتدفّق من هناك لليسار. انت توقّعت الـ bullet على الحافة اليمنى والعبري بتدفّق right-to-left عليه.

**السبب:** Konsole 23.08 (الإفتراضي بـ Ubuntu 24.04) بصنّف الـ `●` (U+25CF BLACK CIRCLE) على إنه *direction-anchoring neutral*. لمّا بظهر بعمود 0، Konsole بقفل اتجاه فقرة السطر على LTR والـ RLM (U+200F) ببداية السطر ما بكفّي يقلبه — الـ RLM بتم اعتباره hint أضعف من تأثير anchoring تبع الـ bullet. Konsole 24.04 على ما يقولوا بخفّف هاد وبعامل الـ bullet كـ neutral عادي (فحلّ الـ RLM ببداية السطر من v1.1.0 بشتغل عادي) — إذا انت على KDE Plasma 6 / Konsole 24.04+ غالباً ما بدّك هاد الـ workaround.

**الحل:** فعّل الـ workaround الاختياري لإزالة الـ bullet. عدّل config المنصة تبعك:

<ul dir="rtl">
<li><strong>Windows:</strong> <code>%LOCALAPPDATA%\Kivun-WSL\config.txt</code></li>
<li><strong>Linux:</strong> <code>~/.config/kivun-terminal/config.txt</code></li>
<li><strong>macOS:</strong> <code>~/Library/Application Support/Kivun-Terminal/config.txt</code></li>
</ul>

حط:

```ini
KIVUN_BIDI_STRIP_BULLET=on
```

شغّل Kivun Terminal من جديد. الـ wrapper هلا رح يشيل الـ `●` من بداية أي سطر أول strong char فيه RTL قبل ما يمرّره للـ terminal. العبري بصير أول حرف مرئي بالسطر، BiDi بقلب اتجاه الفقرة لـ RTL أوتوماتيكي، والسطر بترسم محاذاة يمين زي ما توقّعت.

**Trade-off:** علامة الـ `●` المرئية بتختفي على سطور bullet العبري (الـ indentation بضل، فلسا بتشوف السطور مجمّعة بصرياً). سطور الـ bullet الإنجليزية ما بتنمسّ — الـ `●` تبعتهم بضل يترسم عادي. إذا بتفضّل تخلي الـ bullet مرئي على حساب layout LTR على Konsole 23.x، خلّي `KIVUN_BIDI_STRIP_BULLET=off` (الإفتراضي).

## العَرَض: نافذة Konsole بتفتح بدون أيقونة (فاضية/بيضا) بشريط العنوان وtaskbar تبع Windows

**انحلّ بـ v1.1.17.** توثيق v1.1.16 وصف هاي بشكل غلط على إنها قيد معماري بـ WSLg — مش هيك. WSLg فعلاً ببيّن أيقونة Windows taskbar، بس بآلية ثانية غير `_NET_WM_ICON` تبع X11.

**كيف WSLg بختار أيقونة الـ taskbar:** WSLg بطابق `WM_CLASS` (X11) أو `app_id` (Wayland) تبع النافذة مع entry `StartupWMClass=` بملفات الـ `.desktop` المركّبة. الـ `Icon=` تبع الـ `.desktop` المتطابق بصير أيقونة Windows taskbar. الـ `WM_CLASS` الإفتراضي تبع Konsole هو `konsole`، اللي بطابق `/usr/share/applications/org.kde.konsole.desktop` ← الأيقونة المرفقة معه ← مش تبعتنا.

**حل v1.1.17 بـ `kivun-launch.sh`:**
1. بنشئ `~/.local/share/applications/kivun-terminal.desktop` بـ `Icon=<absolute path to kivun-icon.png>` و `StartupWMClass=kivun-terminal`.
2. بشغّل Konsole كـ `konsole --name kivun-terminal ...` فالـ `WM_CLASS` تبعه بصير `kivun-terminal` (الـ arg `--name` تبع Qt بحدّد `WM_CLASS` res_name).
3. WSLg هلا بطابق النافذة المُشغَّلة مع الـ `.desktop` تبعنا وبستخدم الأيقونة تبعتنا.

**ليش هاد ما انكشف من قبل:** الـ path تبع `python-xlib` بـ v1.1.7 *كان* بحدّد `_NET_WM_ICON` صح، وسطر الـ log تبع الـ launcher `SUCCESS - Window icon set` خلّى الإشي يبيّن إنه الأيقونة طُبّقت. تحت VcXsrv (target النشر الأصلي) كانت فعلاً مطبَّقة — VcXsrv بقرأ `_NET_WM_ICON`. تحت WSLg (الإفتراضي من v1.1+)، الخاصية بتتحدّد بس مش مستخدَمة. تسجيل الـ `.desktop` هو الـ path الأصيل لـ WSLg اللي فعلاً ببيّن أيقونة Windows taskbar.

**path الـ `_NET_WM_ICON` لسا بشتغل** جنب تسجيل الـ `.desktop` تحت WSLg. نافذة الـ "Launch Log" تبعت cmd بتحتفظ بأيقونتها من `kivun_icon.ico` تبع شورتكت الـ Desktop.

## العَرَض: الـ launcher اشتغل بعدين فجأة بتصرّف زي إنه نص الـ .bat ضايع — working directory غلط، مفي سطور log أوّلية، config ناقص

**السبب (regression بـ updater v1.1.16، انحلّ بـ v1.1.17):** `Kivun-Update-To-V1116.bat` نزّل `kivun-terminal.bat` من GitHub raw عبر `curl -fsSL`، اللي بحافظ على line endings تبع الـ repository (LF). **cmd بيتجاهل بصمت سطور بملفات `.bat` LF-only** — كثير statements عمرها ما بتنفّذ، من ضمنها setup الـ `WORK_DIR`. الـ launcher بعدين بسقط على fallback تحويل الـ path تبع v1.1.16 وبيوقع المستخدمين على `~` (home تبع WSL `/home/<user>`) بدل `%USERPROFILE%` (home Windows تبعهم `/mnt/c/Users/<user>`).

**نمط التشخيص:** إذا `LAUNCH_LOG.txt` بيبيّن الـ header (`KIVUN TERMINAL v1.1.16 LAUNCH LOG`، Date، Working Directory) متبوع مباشرة بـ `[hh:mm:ss] SUCCESS - python deps installed` — وما بيبيّن كل السطور الأوّلية `START - Launching`، `INFO - Using default work directory`، `SUCCESS - Config loaded`، `INFO - Checking WSL installation` اللي لازم تظهر بينهم — الـ .bat عنده line endings LF-only و cmd عم يركض فيه ويرمي أوامر.

**حل v1.1.17:**
<ul dir="rtl">
<li>الـ updater الجديد (<code>Kivun-Update-To-V1117.bat</code>) صراحة بطبّع الـ <code>.bat</code> المُنزَّل لـ CRLF بعد <code>curl</code>، عبر <code>tr -d '\r' | sed 's/$/\r/'</code> جوّا WSL.</li>
<li>إصلاح إضافي حزام-وحمّالات بـ <code>kivun-terminal.bat</code> نفسه: لمّا <code>WORK_DIR</code> فاضي أو <code>.</code>، بستبدلها بـ <code>%USERPROFILE%</code> upstream فـ <code>wslpath</code> بحوّل path Windows حقيقي ← <code>/mnt/c/Users/<user></code> بدل ما يتسلسل عبر fallback الـ <code>~</code> (home تبع WSL). يعني حتى لو بطريقة ما طلع عندك WORK_DIR غير صالح، الـ launcher بيوقع بالـ Windows home — بطابق وعد شورتكت الـ Desktop.</li>
</ul>

**استرجاع يدوي (بدون إعادة تشغيل updater):**

```cmd
wsl -d Ubuntu --user root -- bash -c "tr -d '\r' < /mnt/c/Users/<your-user>/AppData/Local/Kivun-WSL/kivun-terminal.bat | sed 's/\$/\r/' > /tmp/k.bat && mv /tmp/k.bat /mnt/c/Users/<your-user>/AppData/Local/Kivun-WSL/kivun-terminal.bat"
```

أو نزّل مثبّت v1.1.17 جديد من [releases page](https://github.com/noambrand/kivun-terminal-wsl/releases/latest) — مثبّت NSIS دايماً بشحن CRLF صح.

## العَرَض: Working directory هو `/mnt/c/Users/<you>/AppData/Local/Kivun-WSL` (مجلّد التثبيت) بدل home تبعك أو المجلد اللي عملت عليه right-click

**السبب (متحقَّق منه 27 نيسان 2026 بـ WSL 2.6.3.0):** `wslpath ""` و `wslpath "."` الاثنين برجّعوا string `.` حرفياً. `kivun-terminal.bat` قبل v1.1.16 كان يفحص بس إذا WSL_PATH فاضي؛ قيمة `.` كانت تمر، تنرسل لـ bash، و `cd .` كان يخلّي أي cwd ورثه bash من cmd — عادة مجلّد التثبيت لمّا يتم التشغيل من شورتكت الـ Desktop.

**حل جزئي بـ v1.1.16:** ضاف فحص `WSL_PATH=.`، رجع لـ `~` (home تبع WSL `/home/<user>`). تعليق المستخدم: هاد كان بالاتجاه الغلط — شورتكت الـ Desktop بضمّن `%USERPROFILE%` (Windows home)، مش WSL home.

**حل صحيح بـ v1.1.17:** لمّا `WORK_DIR` فاضي أو `.`، بستبدلها بـ `%USERPROFILE%` upfront فـ `wslpath` بحوّل path Windows حقيقي ← `/mnt/c/Users/<you>`. استدعاء `wslpath` ثاني حزام-وحمّالات على النتيجة إذا لسا رجعت فاضية/`.`. يعني تشغيل شورتكت الـ Desktop هلا بيوقعك على `/mnt/c/Users/<you>` (Windows home تبعك)، بطابق إيش الشورتكت بضمّنه.

**حل يدوي على v1.1.16 وأقدم:** نزّل مثبّت v1.1.17 أو updater bat تبع v1.1.17 — الاثنين بشحنوا المنطق المصحَّح. التعديل اليدوي للحالة هاي هشّ لأنه fallback v1.1.16 لسا بيطلع `~` ولازم تحلّها قبل ما wslpath ينستدعى.

## العَرَض: Konsole بفتح، بعدين Claude بطلع فوراً مع `--dangerously-skip-permissions cannot be used with root/sudo privileges`

**السبب:** المستخدم الإفتراضي تبع Ubuntu بـ WSL تبعك هو `root` (أو الـ runtime-dir تبع WSLg مملوك لـ root، اللي عادة معناه نفس الإشي). Kivun بكتشف مالك WSLg وبشتغل كهداك المستخدم — لمّا هاد المستخدم هو `root`، Claude Code برفض يبدأ بسبب الـ `--dangerously-skip-permissions` security guard. مسار الـ launcher اللي رح تشوفه بالخطأ هو `/root/.local/share/kivun-terminal/kivun-claude-bidi/...` — البادئة `/root/` بأكّد التشخيص.

**انحلّ بـ v1.1.14:** الـ launcher هلا بكتشف الحالة هاي أوتوماتيكي، بدوّر على أول مستخدم non-root (UID 1000)، وبستخدم هداك المستخدم. إذا مفي مستخدم non-root، الـ launcher بطلع قبل ما يوصل لـ Claude مع تعليمات نسخ-لصق لإنشاء واحد.

**حل يدوي على v1.1.13 وأقدم** (أو إذا الـ auto-detect تبع v1.1.14 ما لاقى مستخدم UID-1000):

```cmd
wsl -d Ubuntu --user root -- adduser yourname
wsl -d Ubuntu --user root -- usermod -aG sudo yourname
ubuntu config --default-user yourname
wsl --terminate Ubuntu
```

بعدين شغّل Kivun Terminal من جديد.

إذا `ubuntu config` مش موجود (Ubuntu image أقدم)، استخدم:

```cmd
wsl -d Ubuntu --user root -- bash -c "echo -e '[user]\ndefault=yourname' >> /etc/wsl.conf"
wsl --terminate Ubuntu
```

## العَرَض: السطور العبرية بترسم محاذاة يمين بس English/code/numbers بتيجي بالعمود الغلط جوّا الجمل العبرية

**متلاً** `אני משתמש ב-React כדי לרנדר את הקומפוננטות` بترسم مع "React" مثبّتة على الحافة اليسرى البصرية بدل ما تكون بنص الجملة بين `ב-` و `כדי`.

**السبب (مؤكَّد من المستخدم عبر DUMP_RAW capture، نيسان 2026):** الـ TUI تبع Claude Code **بطلع CSI cursor-forward escapes (`\x1b[1C`) بدل ما يطلع حرف space عادي بين كل كلمتين.** محرّك BiDi تبع Konsole بعامل كل cursor-forward غير مرئي على إنه حدود attribute-region نفس ما بعامل تغييرات لون SGR — بقسّم الـ BiDi run بين كل كلمتين، فكل جزء كلمة بنحلّ BiDi مستقلاً و Qt بيحط الأجزاء LTR بمكان غلط على الحافة اليسرى البصرية.

**الحل اللي شُحن بـ v1.1.13:** الـ wrapper هلا بعترض CSI cursor-forwards على السطور RTL وبستبدل كل `\x1b[NC` بـ N حرف space عادي. مظهرياً نفس الإشي (cursor-forward بتحرّك فوق خلايا مفترَض إنها فاضية؛ الـ spaces بتكتب على نفس الخلايا)، بس بدون حدود attribute-region فالسطر RTL كله بصير BiDi run وحده. مربوط بالـ flag الموجود `KIVUN_BIDI_FLATTEN_COLORS_RTL=on` (الإفتراضي on).

**إذا لسا شايفها على v1.1.13+:** تأكّد إنه الـ wrapper تنشر صح — `grep cursorForwardReplacedCount ~/.local/share/kivun-terminal/kivun-claude-bidi/lib/injector.js` لازم يطبع على الأقل match واحد. إذا لأ، شغّل المثبّت من جديد أو استخدم `Kivun-Update-To-V1113.bat` لتسحب آخر wrapper من `main`.

## العَرَض: العبري بيرسم بشكل مكسور بطريقة جديدة ما بتطابق أي عَرَض فوق

**وصفة تشخيص عامة** (هاي اللي استخدمناها لنلاقي بق cursor-forward تبع v1.1.13):

1. **شغّل raw stream capture.** عدّل `%LOCALAPPDATA%\Kivun-WSL\config.txt` (Linux: `~/.config/kivun-terminal/config.txt`، macOS: `~/Library/Application Support/Kivun-Terminal/config.txt`) وحط `KIVUN_BIDI_DUMP_RAW=on`. احفظ. سكّر + افتح Kivun.
2. **أعِد إنتاج بق الـ rendering.** ابعت لـ Claude prompt واحد بشغّله. سكّر Kivun.
3. **افحص الـ dump.** الـ wrapper التقط كل byte Claude بعته على:
   ```
   ~/.local/state/kivun-terminal/bidi-raw-dump.bin
   ```
4. **دوّر على CSI sequences غير مرئية بتشتغل كحدود attribute-region.** الـ escapes المرئية (ألوان عبر `\x1b[...m`، تموضع cursor عبر `\x1b[...H`، إلخ) واضحة. القتلة هي الـ sequences اللي بتبيّن بالـ dump زي text بس فعلاً escapes:
   <ul dir="rtl">
   <li><code>\x1b[NC</code> — cursor-forward (كان المسؤول عن v1.1.13)</li>
   <li><code>\x1b[ND</code> — cursor-back</li>
   <li><code>\x1b[NA</code> / <code>\x1b[NB</code> — cursor up / down</li>
   <li><code>\x1b[?Nh</code> / <code>\x1b[?Nl</code> — set / reset terminal modes</li>
   <li><code>\x1b]...\x1b\\</code> — OSC sequences (window title، hyperlinks، إلخ)</li>
   </ul>
5. **عدّ تكرارات سريع عبر Python:**
   ```bash
   python3 -c "
   import re, collections
   data = open('/path/to/bidi-raw-dump.bin', 'rb').read()
   finals = collections.Counter(m.group(1) for m in re.finditer(rb'\x1b\[[\x30-\x3f]*[\x20-\x2f]*([\x40-\x7e])', data))
   for byte, count in finals.most_common(10):
       print(f'  CSI ending in {chr(byte[0])!r:8} ({byte.hex()}): {count} occurrences')
   "
   ```
6. **أي final byte عنده مئات التكرارات جوّا النص العبري** هو الـ splitter المشتبه فيه. ثبّت استبداله بـ `kivun-claude-bidi/lib/injector.js` بنفس الطريقة اللي ثبّت فيها v1.1.13 cursor-forward.
7. **سكّر DUMP_RAW بعد التشخيص** عشان ما تعبّي الـ disk: ارجع `KIVUN_BIDI_DUMP_RAW=on` لـ `=off` بـ `config.txt`. (auto-rotation عند 5 MiB بسقف الاستخدام الكلي، بس أنظف يكون off لما مش فعلياً عم تحقّق.)

النمط: لمّا الـ output اللي رسمه الـ wrapper بيبيّن غلط رغم إنه كل الـ escapes *المرئية* مشيلة، دوّر على CSI sequences *غير مرئية* بتشتغل كحدود attribute-region. الـ side log تبع DUMP_RAW ببيّنهم.

## العَرَض: `KIVUN_BIDI_WRAPPER=on` بس العبري لسا بترسم معكوس

**السبب:** الـ BiDi wrapper (`kivun-claude-bidi`) default-on من v1.1.0 بس بحاجته `npm install` مرة وحدة عند أول تشغيل قبل ما يستخدَم. إذا إشي بهاد الـ flow فشل، الـ launcher بسقط على `claude` بدون wrapper بصمت من منظور المستخدم — بس الـ launch log بسجّل السبب.

**التشخيص:** افتح launch log المنصة (شوف المسارات بالعَرَض السابق) ودوّر على `BiDi` أو `wrapper`. ثلاث حالات ممكنة:

1. `BiDi wrapper active: <path>/kivun-claude-bidi/bin/kivun-claude-bidi` — الـ wrapper شغّال. إذا العبري لسا بيبيّن غلط، المشكلة مش بالـ wrapper؛ شوف قسم محرّك الـ BiDi تحت.
2. `WARNING - Wrapper deploy failed` / `npm install failed` — شوف العَرَض الجاي.
3. `BiDi wrapper off` — المفتاح مش متعيّن لـ `on`. عدّل الـ config تبعك وحط `KIVUN_BIDI_WRAPPER=on`. مسارات الـ config:
   <ul dir="rtl">
   <li><strong>Windows:</strong> <code>%LOCALAPPDATA%\Kivun-WSL\config.txt</code></li>
   <li><strong>Linux:</strong> <code>~/.config/kivun-terminal/config.txt</code></li>
   <li><strong>macOS:</strong> <code>~/Library/Application Support/Kivun-Terminal/config.txt</code></li>
   </ul>

   إذا المفتاح ناقص بالكامل (الترقية من قبل v1.1.0 بتحفظ `config.txt` القديم تبعك)، ضيفه يدوي. شغّل من جديد.

## العَرَض: نشر الـ wrapper بفشل مع "npm install failed"

**السبب:** `npm` أو `node` مش متركّب (أو الإصدار قديم على build الـ native تبع `node-pty`)، أو toolchain البناء (`build-essential`/Xcode CLT) ناقص.

**الحل - Windows (WSL Ubuntu):**

```bash
wsl -d Ubuntu -u root -- apt-get update
wsl -d Ubuntu -u root -- apt-get install -y nodejs npm build-essential python3
```

**الحل - Linux:**

```bash
# Debian/Ubuntu
sudo apt-get install -y nodejs npm build-essential python3
# Fedora/RHEL
sudo dnf install -y nodejs npm gcc-c++ make python3
# Arch
sudo pacman -S --needed nodejs npm base-devel python
```

**الحل - macOS:**

```bash
brew install node
xcode-select --install   # if Xcode CLT isn't present (provides the C++ toolchain node-pty needs)
```

بعدين شغّل من جديد. عند أول تشغيل مع الـ wrapper مفعّل، `npm install` بعيد المحاولة أوتوماتيكي. توقّع 5-15 ثانية أول مرة؛ التشغيلات اللي بعدها فورية (ملف `.kivun-install-stamp` بـ `<wrapper-dir>/node_modules/` ببوّب إعادة التثبيت).

إذا بدك تجبر إعادة تثبيت بعد تحديث Node/npm، احذف `node_modules` من مجلّد الـ wrapper تبع المنصة:

<ul dir="rtl">
<li><strong>Windows:</strong> <code>wsl -d Ubuntu -- rm -rf ~/.local/share/kivun-terminal/kivun-claude-bidi/node_modules</code></li>
<li><strong>Linux:</strong> <code>rm -rf ~/.local/share/kivun-terminal/kivun-claude-bidi/node_modules</code></li>
<li><strong>macOS:</strong> <code>rm -rf /usr/local/share/kivun-terminal/kivun-claude-bidi/node_modules</code> (الـ postinstall بعمل chown لشجرة الـ wrapper الفرعية لمستخدمك، فمفي حاجة لـ sudo)</li>
</ul>

تفقّد آخر سطور الـ launch log لرسالة الخطأ المحدّدة من npm — المسببين الشائعين شبكات offline، toolchain بناء ناقص، أو إصدار Node قديم على `node-pty`.

## العَرَض: نص ملصوق من Konsole فيه أحرف غير مرئية بتكسّر أوامر الـ shell

**السبب:** لمّا `KIVUN_BIDI_WRAPPER=on`، الـ wrapper بحقن RLE (U+202B) و PDF (U+202C) zero-width direction marks حوالين runs العبري بـ output Claude. أغلب الـ terminals الحديثة بتخفيهم عند النسخ، بس بعض الأدوات بتشوفهم كـ bytes حرفية وهدف الـ paste تبعك ممكن يرسمهم كـ مربعات، `‫` / `‬`، أو يقع بالـ parsing.

**الحل (مرة وحدة):** شيلهم بالطرف المستقبِل:

```bash
tr -d '‫‬' < pasted.txt > clean.txt
```

أو وصّل مباشرة بـ pipe:

```bash
pbpaste | tr -d '‫‬'   # macOS
xclip -selection clipboard -o | tr -d '‫‬'   # Linux
```

**الحل (دائم، بقايض صحّة الـ RTL بنسخ-لصق نظيف):** حط `KIVUN_BIDI_WRAPPER=off` بـ `config.txt`. بعتمد على محرّك BiDi الأصلي تبع Konsole لحاله — بشتغل لأغلب الـ output بس ممكن يفشل مع profile drift أو profiles Konsole مخصّصة.

## العَرَض: حروف عبرية/عربية بترسم left-to-right أو بتبيّن مشوّهة

**السبب:** محرّك BiDi تبع Konsole مطفي أو Konsole المركّب قديم.

**الحل:**

```bash
wsl -d Ubuntu -- konsole --version
```

بحاجتك Konsole 22.04 أو أحدث. إذا أقدم:

```bash
wsl -d Ubuntu -- sudo apt-get update
wsl -d Ubuntu -- sudo apt-get install --only-upgrade konsole
```

كمان تأكّد إنه ملف الـ profile فيه `BidiEnabled=true`:

```bash
wsl -d Ubuntu -- grep -i bidi ~/.local/share/konsole/KivunTerminal.profile
```

إذا ناقص، احذف ملف الـ profile وشغّل من جديد — الـ launcher بعيد توليده.

## العَرَض: Alt+Shift ما بغيّر تخطيط الكيبورد

**هاد غالباً مش خربان.** Kivun بفتح باللغة اللي عم تستخدمها **هلق** وبربط **Alt+Shift** للتبديل بين الإنجليزي وتخطيط الـ RTL تبعك (متلاً العبري). على Windows 11 حديث + WSL2، WSLg بتعالج هاد لحالها.

**إذا أول Alt+Shift كأنه ما عمل إشي:** اضغط مرة على نافذة Konsole حتى تعطيها focus، وبعدين اضغط Alt+Shift. Kivun بعيد تطبيق التخطيط لحظة ما النافذة تفتح حتى يكون هاد موثوق (v1.4.25+).

**إذا لسا ما بغيّر:** تأكّد إنّو WSLg محدَّث: شغّل `wsl --update` وبعدين `wsl --shutdown` بـ Windows، وبعدين شغّل من جديد.

## العَرَض: النافذة ما بتتكبّر

**السبب:** `wmctrl` أو `xdotool` ناقصين جوّا Ubuntu.

**الحل:**

```bash
wsl -d Ubuntu -- sudo apt-get install -y wmctrl xdotool
```

## العَرَض: "Installation path conversion failed" بالـ log

**السبب:** مجلّد المثبّت فيه أحرف ما بقدر `wslpath` يترجمها (عادة أحرف non-ASCII باسم مستخدم Windows تبعك).

**الحل:** أعد التثبيت على path ASCII-only، متلاً `C:\Kivun-WSL`. تجاوز مجلّد التثبيت من صفحة الـ *Directory* بالـ wizard.

## العَرَض: تضارب مع ClaudeCode Launchpad CLI

**السبب:** المنتجين الاثنين كانوا يستخدموا `%LOCALAPPDATA%\Kivun` بإصدارات سابقة. Kivun Terminal v1.0.6 بستخدم `%LOCALAPPDATA%\Kivun-WSL` تحديداً عشان يتجنّب هاد.

**الحل:** إذا شفت ملفات قديمة بـ `%LOCALAPPDATA%\Kivun\` من تثبيتات مختلطة، آمن إنك تحذفها — بس بعد ما تتأكّد إنه Launchpad CLI مش متركّب (تفقّد *Apps & Features*).

## لسا عالق؟

افتح issue على https://github.com/noambrand/kivun-terminal-wsl/issues مع:

1. ملفي الـ log الاثنين (احذف أي paths حسّاسة).
2. output:
   ```cmd
   wsl --version
   wsl --status
   wsl -l -v
   ```
3. محتويات `config.txt` تبعك (مش حسّاسة).

</div>
