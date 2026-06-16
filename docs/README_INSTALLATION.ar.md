<div dir="rtl">

# Kivun Terminal v1.4.25 — دليل التثبيت الكامل

## متطلبات النظام

- Windows 10 إصدار 2004+ (build 19041) أو Windows 11
- معالج 64-bit x86-64 مع تفعيل الـ virtualization من BIOS/UEFI
- ٤ غيغا RAM كحد أدنى (٨ غيغا منيح أكتر)
- مساحة فاضية تقريباً ٢ غيغا على قرص النظام

## خطوة ١ — تنزيل

روح على [صفحة الإصدارات](https://github.com/noambrand/kivun-terminal-wsl/releases/latest) ونزّل `Kivun_Terminal_Setup.exe`.

برنامج التثبيت حالياً **مش موقّع** (unsigned). فممكن تواجه واحدة من اتنين من حمايات Windows:

- **Smart App Control (SAC)** على Windows 11: بيطلع dialog بيقول *"Smart App Control blocked an app that may be unsafe"* مع زر **Ok** بس — مفي override. SAC برفض البرامج المش موقّعة كلياً. عشان تثبّت، افتح **Start** → دوّر على **Smart App Control** → حوّله لـ **Off**. SAC ما بينحط ON تاني إلا بإعادة تثبيت Windows، فبلّش OFF بس إذا كنت مرتاح بتشغيل برامج تانية مش موقّعة.
- **SmartScreen** (التحذير الأخف): بيقول *"Windows protected your PC"*. اضغط **More info** ← **Run anyway**.

## خطوة ٢ — متطلب أساسي: WSL2

تأكّد إذا WSL2 مثبّت عندك:

```cmd
wsl --status
```

إذا الأمر طبع معلومات WSL، انت تمام — روح على خطوة ٣. إذا قال WSL مش مثبّت، اعمل هاي الخطوة الإدارية مرة وحدة:

١. اضغط Start كبسة يمين ← **Terminal (Admin)** (أو "Windows PowerShell (Admin)" على Win10).  
٢. شغّل: `wsl --install`  
٣. اعمل ريستارت لما يطلب منك.

بعد ما WSL2 يكون مظبوط، **ما** راح تحتاج صلاحيات Admin تاني.

## خطوة ٣ — شغّل برنامج التثبيت (بدون Admin)

اضغط دبل-كليك على `Kivun_Terminal_Setup.exe`. التثبيت بيشتغل كمستخدم عادي وبيكتب بس على بروفايلك (`%LOCALAPPDATA%\Kivun-WSL`).

ملاحظة: لحدّ ما يصير التثبيت موقّع بـ code-sign، ممكن SmartScreen يطلع "Windows protected your PC". اضغط *More info* ← *Run anyway*. على Windows 11 مع **Smart App Control** شغّال، التثبيت راح ينحجب كلياً — راجع خطوة ١ لكيف تطفّي SAC.

خطوات الـ wizard:

١. **Welcome** — بيعرض شو رح ينثبّت.  
٢. **License** — MIT.  
٣. **Components** — كل الأقسام المطلوبة معلّمة من قبل. اختياري:  
   - *Right-Click Menu Integration* — بيضيف "Open with Kivun Terminal" لقوائم الكبسة اليمنى عالمجلدات.  
٤. **Directory** — `%LOCALAPPDATA%\Kivun-WSL` الافتراضي مفضّل. ما تستعمل `%LOCALAPPDATA%\Kivun` (هاد تبع Launchpad CLI v2.4.x).  
٥. **Install** — بثبّت Ubuntu (إذا مش موجود)، Konsole، Claude Code. هاد ممكن ياخد ٥–١٥ دقيقة على Ubuntu نظيفة.  
٦. **Finish** — شغّل فوراً أو شوف هاد الدليل.

## خطوة ٤ — إعداد Ubuntu أول مرة

بأول تشغيل، Ubuntu بيطلب منك بالـ terminal تعمل اسم مستخدم وباسوورد لحساب WSL Ubuntu. اختار أي قيم — هدول محليين بس، بنستخدموا فقط لـ `sudo` جوّا WSL، وما بلمسوا Claude API ولا أي شبكة. شوف [SECURITY.txt](SECURITY.txt) للتفاصيل.

## خطوة ٥ — التشغيل

تلات طرق:

- **Desktop shortcut** — اضغط دبل-كليك على `Kivun Terminal`. بيفتح dialog لاختيار مجلّد: اكتب/الصق Windows path أو تصفّح الشجرة، وبعدين اضغط **Launch Kivun Terminal**. الإلغاء بيرجع لـ `%USERPROFILE%`. نفس الـ dialog فيه زر **Edit Default Flags** بيفتح `config.txt` للتعديل.
- **كبسة يمين على مجلّد** — اختار *Open with Kivun Terminal* (إذا فعّلت هاد الكومبوننت). بيفتح بهداك المجلّد.
- **من CMD** — `"%LOCALAPPDATA%\Kivun-WSL\kivun-terminal.bat" "C:\path\to\project"`.

بأول تشغيل، Claude Code راح يطلب منك تسجيل الدخول باشتراك Pro/Max أو لصق API key. هاد بصير مرة وحدة فقط لكل مستخدم Ubuntu.

## خطوة ٦ — إعداد اللغة والاتجاه

عدّل `%LOCALAPPDATA%\Kivun-WSL\config.txt`:

```ini
CLAUDE_FLAGS=                  # فلاغات مفصولة بمسافة بتنضاف لكل تشغيل لـ claude؛ مثلاً --model opus --continue
FOLDER_PICKER=true             # عرض dialog البيكر من اختصار الدسكتوب؛ false بيتخطّاه ويفتح بـ %USERPROFILE%
PRIMARY_LANGUAGE=arabic        # أو hebrew, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani
RESPONSE_LANGUAGE=arabic       # بتحكّم بـ --append-system-prompt اللي بنبعت لـ Claude
TEXT_DIRECTION=rtl             # rtl = العربي/العبري بيلتزق بحافة اليمين؛ ltr = افتراضي
AUTO_INSTALL_CLAUDE=true       # تثبيت Claude Code تلقائياً بأول تشغيل إذا مش موجود
```

قائمة المرجع الكاملة (~٢٥ فلاغ مدعوم من `claude --help`) موجودة بآخر `config.txt`.

احفظ، وبعدين سكّر وافتح Kivun Terminal من جديد عشان التغييرات تشتغل.

## خطوة ٧ — تأكّد من التثبيت

شغّل هاي الفحوصات من CMD:

```cmd
wsl --status
wsl -d Ubuntu -- command -v claude
wsl -d Ubuntu -- command -v konsole
```

التلاتة لازم ينجحوا. إذا واحد فشل، شوف [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## إلغاء التثبيت

استعمل *Apps & Features* ← **Kivun Terminal** ← *Uninstall*، أو شغّل `%LOCALAPPDATA%\Kivun-WSL\Uninstall.exe`.

برنامج الإلغاء بشيل:
- سكربتات التشغيل، الإعدادات، الوثائق
- Desktop shortcut، Start Menu entry، قائمة الكبسة اليمنى

برنامج الإلغاء بشكل مقصود **بترك**:
- WSL2، توزيعة Ubuntu (مشتركة مع أدوات تانية)
- Konsole، Claude Code جوّا Ubuntu
- لوغات التشغيل بـ `%LOCALAPPDATA%\Kivun-WSL\*.txt`

عشان تشيل Ubuntu كلياً: `wsl --unregister Ubuntu` (هاد بيدمّر كل الداتا بالتوزيعة).

</div>
