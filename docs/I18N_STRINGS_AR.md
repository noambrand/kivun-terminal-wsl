<div dir="rtl">

# مرجع الترجمة العربية لواجهات Kivun Terminal

هاد الملف بيوثّق كل النصوص الإنجليزية اللي بتظهر للمستخدم بـ `payload/folder-picker.hta` و `installer/Kivun_Terminal_Setup.nsi`، مع ترجمة فلسطينية محكية. الـ maintainer ممكن يستعمله لربط واجهة عربية لاحقاً (مثلاً عن طريق ملف `lang_ar.json` للـ HTA و `LangString` للـ NSIS).

كل سطر من الجدول بيشمل: السطر التقريبي بالملف الأصلي، النص الإنجليزي زي ما هو، الترجمة المقترحة، وسياق الاستخدام (زر، عنوان، tooltip، رسالة خطأ، إلخ).

---

## payload/folder-picker.hta

| السطر التقريبي | الإنجليزي الأصلي | الترجمة العربية | السياق |
|---|---|---|---|
| 24 | "Kivun Terminal - Pick Folder" | "Kivun Terminal — اختار مجلّد" | عنوان النافذة (`<title>`) |
| 27 | "Kivun Terminal Folder Picker" | "Kivun Terminal — اختيار المجلّد" | اسم تطبيق HTA (`APPLICATIONNAME`) |
| 539 | "Download v" + safeNew | "نزّل النسخة v" + safeNew | زر تنزيل التحديث ببانر التحديث |
| 540 | "✕" / "Hide until next launch" | "✕" / "إخفاء لحد التشغيل الجاي" | زر إغلاق بانر التحديث + tooltip |
| 536 | "🆕 Update available:" v + safeNew | "🆕 في تحديث جديد متوفّر: v" + safeNew | نص بانر التحديث |
| 537 | "(you have v" + safeCur + ")" | "(عندك حالياً v" + safeCur + ")" | النسخة الحالية بجنب التحديث |
| 538 | "release notes" | "ملاحظات الإصدار" | رابط ضمن بانر التحديث |
| 644 | "Pick a folder" | "اختار مجلّد" | عنوان نافذة BrowseForFolder الـ Windows |
| 654 | "config.txt not found at " + configFile | "ملف config.txt مش موجود بـ " + configFile | رسالة خطأ — ملف الإعدادات مفقود |
| 795 | "(none — default Claude behavior)" | "(ما في — تشغيل Claude الافتراضي)" | معاينة الأمر لمّا ما في فلاغات |
| 809 | "↳ then types: " | "↳ وبعدين بيكتب: " | معاينة أوامر البداية |
| 832 | "↳ with env (masked): " | "↳ مع متغيّرات بيئة (مخفيّة): " | معاينة env vars (مخفيّة) |
| 832 | "↳ with env: " | "↳ مع متغيّرات بيئة: " | معاينة env vars (ظاهرة) |
| 827 | "…(set)" | "…(محدّدة)" | قيمة env مخفيّة بالمعاينة |
| 913 | "Enter a folder path or click Browse." | "اكتب مسار مجلّد أو اضغط Browse." | خطأ — ما في مسار |
| 918 | "Folder does not exist: " + p | "المجلّد مش موجود: " + p | خطأ — مسار مش صحيح |
| 983 | "Picker error (line " + line + "): " + msg | "صار خطأ بالـ Picker (السطر " + line + "): " + msg | خطأ JScript عام |
| 1075 | "Could not save profiles: " + e | "تعذّر حفظ البروفايلات: " + e | خطأ — حفظ profiles.json فشل |
| 1146 | "Active profile — already loaded" | "البروفايل المفعّل — محمّل أصلاً" | tooltip للبروفايل النشط |
| 1146 | "Switch to profile: " + name | "بدّل للبروفايل: " + name | tooltip لبروفايل غير نشط |
| 1184 | "✓ saved" | "✓ تم الحفظ" | إشعار حفظ سريع |
| 1184 | "✓ loaded" | "✓ تم التحميل" | إشعار تحميل سريع |
| 1191 | "Save current settings as a new profile.\nProfile name:" | "احفظ الإعدادات الحالية كبروفايل جديد.\nاسم البروفايل:" | window.prompt لحفظ بروفايل جديد |
| 1194 | "Profile name cannot be empty." | "اسم البروفايل ما بيقدر يكون فاضي." | خطأ — اسم فاضي |
| 1195 | "A profile named \"" + name + "\" already exists." | "في بروفايل بهاد الاسم \"" + name + "\" موجود أصلاً." | خطأ — اسم متكرّر |
| 1212 | "Rename profile \"" + oldName + "\" to:" | "غيّر اسم البروفايل \"" + oldName + "\" لـ:" | window.prompt لإعادة تسمية |
| 1216 | "A profile named \"" + newName + "\" already exists." | "في بروفايل بهاد الاسم \"" + newName + "\" موجود أصلاً." | خطأ — اسم متكرّر بالتعديل |
| 1231 | "The Default profile cannot be deleted (it auto-rebuilds on next launch)." | "ما بتقدر تمسح بروفايل Default (بيتعاد بناؤه تلقائياً بأول تشغيل جاي)." | منع حذف Default |
| 1235 | "Delete profile \"" + name + "\"? This cannot be undone." | "بدك تحذف البروفايل \"" + name + "\"؟ ما بترجع وراء." | confirm لحذف بروفايل |
| 1288 | "👁 show values" | "👁 إظهار القيم" | زر تبديل عرض قيم env |
| 1288 | "🙈 hide values" | "🙈 إخفاء القيم" | زر تبديل عرض قيم env |
| 1309 | "init error: " + e | "خطأ بالتهيئة: " + e | خطأ تهيئة المربّع |
| 716 | "addCustomFlag error: " + e | "خطأ بإضافة الفلاغ: " + e | خطأ داخلي بإضافة فلاغ |
| 1318 | "Profile:" | "البروفايل:" | label شريط البروفايلات |
| 1320 | "+ New" | "+ جديد" | زر إضافة بروفايل |
| 1320 | "Save current settings as a new profile" | "احفظ الإعدادات الحالية كبروفايل جديد" | tooltip زر "+ New" |
| 1321 | "Rename" | "تعديل الاسم" | زر إعادة تسمية بروفايل |
| 1321 | "Rename the current profile" | "غيّر اسم البروفايل الحالي" | tooltip زر Rename |
| 1322 | "Delete" | "حذف" | زر حذف بروفايل |
| 1322 | "Delete the current profile (Default cannot be deleted)" | "احذف البروفايل الحالي (Default ما بيتحذف)" | tooltip زر Delete |
| 1326 | "Pick a folder for Kivun Terminal" | "اختار مجلّد لـ Kivun Terminal" | العنوان الرئيسي `<h1>` |
| 1328 | "Choose **one** of the two options below, optionally tune the Claude flags + startup commands, then click **Launch Kivun Terminal**." | "اختار **خيار واحد** من الخيارات تحت، وإذا بدك ظبّط فلاغات Claude + أوامر البداية، وبعدين اضغط **شغّل Kivun Terminal**." | hint رئيسي |
| 1329 | "Switch **Profile** at the top to load a saved combo (folder, model, flags, startup commands, env vars)." | "بدّل **البروفايل** من فوق لتحميل توليفة محفوظة (مجلّد، موديل، فلاغات، أوامر بداية، متغيّرات بيئة)." | hint رئيسي — ثاني سطر |
| 1333 | "Type or paste a Windows path:" | "اكتب أو الصق مسار Windows:" | label الخيار 1 |
| 1334 | "C:\Users\you\Documents\MyProject" | "C:\Users\you\Documents\MyProject" | placeholder مسار (يفضّل يبقى زي ما هو لأنه مثال تقني) |
| 1337 | "OR" | "أو" | فاصل بين الخيارين |
| 1340 | "Pick a folder from the Windows folder tree:" | "اختار مجلّد من شجرة مجلّدات Windows:" | label الخيار 2 |
| 1341 | "Browse Folder Tree..." | "تصفّح شجرة المجلّدات…" | زر التصفّح |
| 1344 | "Click to expand: model, conversation flags, startup slash commands, environment variables" | "اضغط للتوسيع: الموديل، فلاغات المحادثة، أوامر سلاش للبداية، متغيّرات البيئة" | tooltip زر "Advanced options" |
| 1346 | "Advanced options" | "الإعدادات المتقدّمة" | زر طيّ/توسيع الإعدادات المتقدّمة |
| 1347 | "— click to show model, flags, startup slash commands, env vars" | "— اضغط لإظهار الموديل، الفلاغات، أوامر السلاش، متغيّرات البيئة" | نص فرعي بزر Advanced |
| 1352 | "Claude flags (optional):" | "فلاغات Claude (اختياري):" | label الخيار 3 |
| 1355 | "Model:" | "الموديل:" | label اختيار الموديل |
| 1357 | "Opus" / "(most capable)" | "Opus" / "(الأقدر)" | راديو موديل |
| 1358 | "Sonnet" / "(balanced)" | "Sonnet" / "(متوازن)" | راديو موديل |
| 1359 | "Haiku" / "(fastest)" | "Haiku" / "(الأسرع)" | راديو موديل |
| 1360 | "Let Claude decide" | "خلّي Claude يختار" | راديو موديل |
| 1363 | "Conversation:" | "المحادثة:" | label فلاغ المحادثة |
| 1365 | "Start fresh" | "ابدأ من الصفر" | راديو محادثة |
| 1366 | "Continue last" | "كمّل آخر محادثة" | راديو محادثة |
| 1367 | "Pick from history" | "اختار من السجلّ" | راديو محادثة |
| 1370 | "Quick options:" | "خيارات سريعة:" | label شيبس الفلاغات |
| 1372 | "+ Respond in Hebrew" | "+ يردّ بالعبري" | شيب |
| 1372 | "Asks Claude to reply in Hebrew" | "بيطلب من Claude يردّ بالعبري" | tooltip للشيب |
| 1373 | "+ High effort" | "+ مجهود عالي" | شيب |
| 1373 | "--effort high — Claude thinks harder before answering; slower and more thorough" | "--effort high — Claude بيفكّر أكتر قبل ما يردّ؛ أبطأ بس أعمق" | tooltip للشيب |
| 1374 | "+ Concise responses" | "+ ردود مختصرة" | شيب |
| 1374 | "Tells Claude to keep replies short and to the point" | "بيقول لـ Claude يخلّي الردود قصيرة وللنقطة" | tooltip للشيب |
| 1375 | "+ Step-by-step reasoning" | "+ شرح خطوة خطوة" | شيب |
| 1375 | "Tells Claude to explain its reasoning step by step before any conclusion" | "بيقول لـ Claude يشرح تفكيره خطوة خطوة قبل أي نتيجة" | tooltip للشيب |
| 1376 | "+ Always include tests" | "+ يضيف tests دايماً" | شيب |
| 1376 | "Tells Claude to always include tests when writing or changing code" | "بيقول لـ Claude يضيف tests دايماً لمّا يكتب أو يغيّر كود" | tooltip للشيب |
| 1377 | "+ Auto-accept file edits" | "+ قبول التعديلات تلقائياً" | شيب |
| 1377 | "--permission-mode acceptEdits — auto-accept file edits without asking each time (Shift+Tab inside Claude does the same per-session)" | "--permission-mode acceptEdits — يقبل تعديلات الملفات تلقائياً بدون ما يسأل كل مرّة (Shift+Tab جوّا Claude بيعمل نفس الإشي للجلسة)" | tooltip للشيب |
| 1378 | "+ Read-only (no file edits)" | "+ قراءة فقط (بدون تعديلات)" | شيب |
| 1378 | "Disable Edit/Write/MultiEdit tools — Claude can read and explain code but can't modify files" | "بيعطّل أدوات Edit/Write/MultiEdit — Claude بيقدر يقرأ ويشرح بس مش رح يعدّل ملفات" | tooltip للشيب |
| 1379 | "+ Don't fail if Opus is busy" | "+ ما تفشل إذا Opus مشغول" | شيب |
| 1379 | "--fallback-model sonnet — if Opus is at capacity at launch, auto-switch to Sonnet so the session still starts" | "--fallback-model sonnet — إذا Opus مشغول وقت التشغيل، بيبدّل تلقائياً لـ Sonnet عشان الجلسة تشتغل" | tooltip للشيب |
| 1380 | "+ Confirm before changes" | "+ يأكّد قبل أي تعديل" | شيب |
| 1380 | "Tells Claude to describe planned changes before making them" | "بيقول لـ Claude يوصف التعديلات اللي ناوي يعملها قبل ما يعملها" | tooltip للشيب |
| 1383 | "Custom:" | "مخصّص:" | label إدخال فلاغ مخصّص |
| 1386 | "Anything in this box is appended verbatim to the Claude command. Chips above append into here; you can also edit freely." | "أي إشي بهاد الخانة بنحطّه حرفياً بأمر Claude. الشيبس فوق بتضيف هون؛ بتقدر تعدّل يدوياً كمان." | شرح خانة Custom |
| 1391 | "Will run:" | "بدنا نشغّل:" | label معاينة الأمر |
| 1393 | "$ claude (none)" | "$ claude (ما في)" | معاينة الأمر — افتراضي |
| 1401 | "Startup slash commands (optional):" | "أوامر سلاش للبداية (اختياري):" | label الخيار 4 |
| 1402 | "One per line, e.g.\n/voicemode:converse\n/model opus" | "كل أمر بسطر، مثلاً\n/voicemode:converse\n/model opus" | placeholder textarea |
| 1403 | "Each line is typed into Claude after the session opens. Use this to auto-launch voice mode, switch to a specific model, etc. Leave empty for normal launch." | "كل سطر بيتكتب جوّا Claude بعد ما تفتح الجلسة. استعمل هاي لتشغيل voice mode تلقائياً، تبديل موديل معيّن، إلخ. خلّيها فاضية للتشغيل العادي." | شرح أوامر البداية |
| 1408 | "Environment variables (optional):" | "متغيّرات البيئة (اختياري):" | label الخيار 5 |
| 1409 | "Toggle whether env-var values are shown in the preview below. Values are always masked by default — click to reveal." | "بدّل عرض قيم متغيّرات البيئة بالمعاينة تحت. القيم دايماً مخفيّة افتراضياً — اضغط لإظهارها." | tooltip زر إخفاء/إظهار |
| 1412 | "KEY=VAL, one per line. Lines starting with # are ignored.\ne.g.\nANTHROPIC_API_KEY=sk-ant-...\nDEBUG=1" | "KEY=VAL، كل واحد بسطر. الأسطر اللي بتبدأ بـ # بتتجاهل.\nمثلاً\nANTHROPIC_API_KEY=sk-ant-...\nDEBUG=1" | placeholder env vars |
| 1414 | "Per-profile environment variables passed into the Claude session. Values are masked in the preview by default for screenshot safety — click **👁 show values** above to reveal." | "متغيّرات بيئة خاصّة بكل بروفايل بتتمرّر لجلسة Claude. القيم مخفيّة بالمعاينة افتراضياً لحماية الـ screenshots — اضغط **👁 إظهار القيم** فوق لكشفها." | شرح env vars |
| 1420 | "Open config.txt (advanced)" | "افتح config.txt (متقدّم)" | زر فتح ملف الإعدادات |
| 1420 | "Open config.txt in Notepad for advanced settings (language, theme, BiDi tunables)" | "افتح config.txt بالـ Notepad للإعدادات المتقدّمة (اللغة، الثيم، إعدادات BiDi)" | tooltip زر config.txt |
| 1422 | "Cancel" | "إلغاء" | زر الإلغاء |
| 1423 | "Launch Kivun Terminal" | "شغّل Kivun Terminal" | الزر الرئيسي للتشغيل |

---

## installer/Kivun_Terminal_Setup.nsi

| السطر التقريبي | الإنجليزي الأصلي | الترجمة العربية | السياق |
|---|---|---|---|
| 7 | "Kivun Terminal" | "Kivun Terminal" | اسم المنتج (عادة بيظل بالإنجليزي كاسم تجاري) |
| 11 | "WSL+Konsole launcher for Claude Code with RTL/BiDi support" | "مشغّل WSL+Konsole لـ Claude Code مع دعم RTL/BiDi" | وصف المنتج |
| 49 | "Welcome to ${PRODUCT_NAME} v${PRODUCT_VERSION}" | "أهلاً وسهلاً بـ ${PRODUCT_NAME} نسخة v${PRODUCT_VERSION}" | عنوان صفحة الترحيب |
| 50 | "This installer will set up ${PRODUCT_NAME} on your computer." | "هاد الـ installer رح يثبّت ${PRODUCT_NAME} على جهازك." | نصّ صفحة الترحيب — بداية |
| 50 | "What will be installed:" | "اللي رح ينثبّت:" | عنوان فرعي بصفحة الترحيب |
| 50 | "WSL2 + Ubuntu (if missing)" | "WSL2 + Ubuntu (إذا ناقص)" | عنصر بقائمة الترحيب |
| 50 | "Konsole terminal emulator (inside Ubuntu)" | "محاكي طرفية Konsole (جوّا Ubuntu)" | عنصر بقائمة الترحيب |
| 50 | "wmctrl + xdotool (window management)" | "wmctrl + xdotool (إدارة نوافذ)" | عنصر بقائمة الترحيب |
| 50 | "Claude Code CLI (inside Ubuntu)" | "Claude Code CLI (جوّا Ubuntu)" | عنصر بقائمة الترحيب |
| 50 | "VcXsrv X Server (optional, enables Alt+Shift keyboard switching)" | "VcXsrv X Server (اختياري، بيفعّل تبديل الكيبورد بـ Alt+Shift)" | عنصر بقائمة الترحيب |
| 50 | "Features:" | "المميّزات:" | عنوان فرعي |
| 50 | "Real RTL/BiDi text rendering (Hebrew, Arabic, Persian, Urdu, etc.)" | "عرض نصّ RTL/BiDi حقيقي (عربي، عبري، فارسي، أردو، إلخ.)" | ميزة |
| 50 | "Light blue terminal color scheme" | "ثيم ألوان طرفية أزرق فاتح" | ميزة |
| 50 | "Desktop shortcut + right-click folder integration" | "اختصار سطح المكتب + تكامل مع كبسة يمين على المجلّدات" | ميزة |
| 50 | "11 supported RTL languages" | "11 لغة RTL مدعومة" | ميزة |
| 50 | "Note: If WSL is not yet installed, Windows may require a reboot." | "ملاحظة: إذا WSL مش متثبّت، ممكن Windows يطلب إعادة تشغيل." | ملاحظة بصفحة الترحيب |
| 50 | "Click Next to continue." | "اضغط Next للمتابعة." | تعليمة ختام صفحة الترحيب |
| 58 | "${PRODUCT_NAME} Installation Complete!" | "تم تثبيت ${PRODUCT_NAME} بنجاح!" | عنوان صفحة Finish |
| 59 | "${PRODUCT_NAME} v${PRODUCT_VERSION} has been installed successfully." | "تم تثبيت ${PRODUCT_NAME} نسخة v${PRODUCT_VERSION} بنجاح." | نصّ صفحة Finish |
| 59 | "Launch it from the desktop shortcut or right-click any folder and choose \"Open with Kivun Terminal\"." | "شغّله من اختصار سطح المكتب أو كبسة يمين على أي مجلّد واختار \"Open with Kivun Terminal\"." | تعليمات تشغيل |
| 59 | "You will need a Claude Pro/Max subscription or an Anthropic API key." | "بدك اشتراك Claude Pro/Max أو مفتاح API من Anthropic." | متطلّبات |
| 59 | "Get one at: https://console.anthropic.com/" | "بتحصل عليه من: https://console.anthropic.com/" | رابط متطلّبات |
| 61 | "Launch Kivun Terminal now" | "شغّل Kivun Terminal هلّأ" | checkbox بصفحة Finish |
| 63 | "View Quick Start Guide" | "اعرض دليل البداية السريعة" | checkbox بصفحة Finish |
| 75 | "Core Files" | "الملفات الأساسية" | اسم Section |
| 111 | "Preserving existing config.txt (user edits kept)" | "بنحافظ على config.txt الموجود (تعديلات المستخدم محفوظة)" | DetailPrint |
| 121 | "Installed BiDi wrapper source (enable via KIVUN_BIDI_WRAPPER=on in config.txt)" | "تم تثبيت سورس wrapper الـ BiDi (فعّله عن طريق KIVUN_BIDI_WRAPPER=on بـ config.txt)" | DetailPrint |
| 130 | "${PRODUCT_NAME} v${PRODUCT_VERSION}" | "${PRODUCT_NAME} v${PRODUCT_VERSION}" | اسم العرض بـ Add/Remove Programs (اسم تجاري — يبقى) |
| 138 | "WSL2 + Ubuntu" | "WSL2 + Ubuntu" | اسم Section (اسم تقني — يبقى) |
| 140 | "Checking WSL..." | "جاري التحقّق من WSL…" | DetailPrint |
| 148 | "WSL is not installed on this system." | "WSL مش متثبّت على هاد الجهاز." | MessageBox — بداية |
| 148 | "Kivun Terminal installs to your user profile and does not need admin rights — but WSL installation does. Please:" | "Kivun Terminal بينثبّت ببروفايل المستخدم تبعك ومش بحاجة صلاحيات admin — بس تثبيت WSL بحاجة. الرجاء:" | MessageBox — شرح |
| 148 | "1. Close this installer" | "1. سكّر هاد الـ installer" | MessageBox — خطوة |
| 148 | "2. Open PowerShell as Administrator (right-click Start > Terminal (Admin))" | "2. افتح PowerShell كـ Administrator (كبسة يمين على Start > Terminal (Admin))" | MessageBox — خطوة |
| 148 | "3. Run:   wsl --install" | "3. شغّل:   wsl --install" | MessageBox — خطوة |
| 148 | "4. Reboot your computer" | "4. أعد تشغيل الجهاز" | MessageBox — خطوة |
| 148 | "5. Run this installer again (normal double-click, no admin needed)" | "5. شغّل الـ installer مرّة ثانية (دبل-كليك عادي، مش بحاجة admin)" | MessageBox — خطوة |
| 148 | "If 'wsl --install' reports it is not recognized, you are on an older Windows build — see https://learn.microsoft.com/en-us/windows/wsl/install" | "إذا 'wsl --install' بطلّع رسالة إنه غير معروف، يعني عندك نسخة Windows قديمة — شوف https://learn.microsoft.com/en-us/windows/wsl/install" | MessageBox — توجيه إضافي |
| 149 | "WSL not installed — please install it first via admin PowerShell." | "WSL مش متثبّت — رجاءً ثبّته أوّل من PowerShell كـ admin." | رسالة Abort |
| 155 | "Setting WSL default version to 2 (best-effort)..." | "جاري ضبط WSL النسخة 2 كافتراضي (محاولة best-effort)…" | DetailPrint |
| 159 | "Could not set WSL2 default (may need admin PowerShell: wsl --set-default-version 2). Continuing..." | "تعذّر ضبط WSL2 كافتراضي (ممكن بحاجة PowerShell admin: wsl --set-default-version 2). بنكمّل…" | DetailPrint |
| 162 | "Checking Ubuntu distribution..." | "جاري التحقّق من توزيعة Ubuntu…" | DetailPrint |
| 166 | "Installing Ubuntu distribution (no admin needed once WSL2 is up)..." | "جاري تثبيت توزيعة Ubuntu (مش بحاجة admin بعد ما WSL2 يشتغل)…" | DetailPrint |
| 170 | "Ubuntu installation failed." | "فشل تثبيت Ubuntu." | MessageBox — بداية |
| 170 | "Please try:" | "جرّب:" | MessageBox |
| 170 | "1. Open Microsoft Store" | "1. افتح Microsoft Store" | MessageBox — خطوة |
| 170 | "2. Search for 'Ubuntu'" | "2. ابحث عن 'Ubuntu'" | MessageBox — خطوة |
| 170 | "3. Install 'Ubuntu' (the latest LTS version)" | "3. ثبّت 'Ubuntu' (آخر نسخة LTS)" | MessageBox — خطوة |
| 170 | "4. Run this installer again" | "4. شغّل الـ installer مرّة ثانية" | MessageBox — خطوة |
| 171 | "Ubuntu installation failed." | "فشل تثبيت Ubuntu." | رسالة Abort |
| 173 | "Waiting for Ubuntu to initialize..." | "بنستنّى Ubuntu يجهّز…" | DetailPrint |
| 176 | "Ubuntu already installed." | "Ubuntu متثبّت أصلاً." | DetailPrint |
| 179 | "Ensuring Ubuntu uses WSL2..." | "بنتأكّد إنّ Ubuntu بيستعمل WSL2…" | DetailPrint |
| 183 | "Ubuntu converted to WSL2 successfully." | "تم تحويل Ubuntu لـ WSL2 بنجاح." | DetailPrint |
| 187 | "Ubuntu is already on WSL2." | "Ubuntu أصلاً على WSL2." | DetailPrint |
| 192 | "Konsole + window tools" | "Konsole + أدوات النوافذ" | اسم Section |
| 201 | "[1/7] Updating package lists (~30-60 seconds)..." | "[1/7] جاري تحديث قوائم الحزم (~30–60 ثانية)…" | DetailPrint |
| 205 | "apt-get update failed (code $0)." | "apt-get update فشل (الكود $0)." | MessageBox — بداية |
| 205 | "Most common cause: Ubuntu has no internet access." | "السبب الأكتر شيوعاً: Ubuntu ما عندها اتصال بالإنترنت." | MessageBox |
| 205 | "Log: wsl -d Ubuntu -- cat /tmp/kivun-apt.log" | "السجلّ: wsl -d Ubuntu -- cat /tmp/kivun-apt.log" | MessageBox |
| 205 | "Click OK to continue anyway, or Cancel to abort." | "اضغط OK للمتابعة بأي حال، أو Cancel للإلغاء." | MessageBox |
| 206 | "Cancelled by user." | "تم الإلغاء من المستخدم." | رسالة Abort (متكرّرة لكل خطوة) |
| 210 | "[2/7] Installing wmctrl (~20-40 seconds)..." | "[2/7] جاري تثبيت wmctrl (~20–40 ثانية)…" | DetailPrint |
| 214 | "Failed to install wmctrl (code $0)." | "فشل تثبيت wmctrl (الكود $0)." | MessageBox |
| 214 | "Click OK to continue or Cancel to abort." | "اضغط OK للمتابعة أو Cancel للإلغاء." | MessageBox (متكرّرة) |
| 219 | "[3/7] Installing xdotool (~20-40 seconds)..." | "[3/7] جاري تثبيت xdotool (~20–40 ثانية)…" | DetailPrint |
| 223 | "Failed to install xdotool (code $0)." | "فشل تثبيت xdotool (الكود $0)." | MessageBox |
| 228 | "[4/7] Installing x11-utils + x11-xserver-utils + color-emoji font (~40-60 seconds)..." | "[4/7] جاري تثبيت x11-utils + x11-xserver-utils + خط الإيموجي الملوّن (~40–60 ثانية)…" | DetailPrint |
| 232 | "Failed to install x11-utils (code $0)." | "فشل تثبيت x11-utils (الكود $0)." | MessageBox |
| 237 | "[5/7] Ensuring Node.js is available..." | "[5/7] بنتأكّد إنّ Node.js متوفّر…" | DetailPrint |
| 245 | "Node already present, skipping apt install." | "Node موجود أصلاً، بنتخطّى تثبيت apt." | DetailPrint |
| 247 | "Node missing, installing nodejs + npm via apt..." | "Node ناقص، جاري تثبيت nodejs + npm عن طريق apt…" | DetailPrint |
| 251 | "Failed to install Node.js + npm (code $0)." | "فشل تثبيت Node.js + npm (الكود $0)." | MessageBox |
| 251 | "The statusline at the bottom of Claude Code TUI won't work without Node." | "شريط الحالة بأسفل واجهة Claude Code TUI ما رح يشتغل بدون Node." | MessageBox |
| 251 | "Click OK to continue (you can install manually later), or Cancel to abort." | "اضغط OK للمتابعة (بتقدر تثبّت يدوياً لاحقاً)، أو Cancel للإلغاء." | MessageBox |
| 257 | "[6/7] Downloading Konsole + KDE dependencies..." | "[6/7] جاري تنزيل Konsole + اعتماديات KDE…" | DetailPrint |
| 258 | "(3-8 minutes. Downloads ~300MB of packages.)" | "(3–8 دقايق. بينزّل تقريباً 300MB من الحزم.)" | DetailPrint |
| 259 | "The installer is working - please be patient." | "الـ installer شغّال — رجاءً اصبر." | DetailPrint |
| 263 | "Failed to download Konsole packages (code $0)." | "فشل تنزيل حزم Konsole (الكود $0)." | MessageBox |
| 268 | "[7/7] Unpacking and configuring Konsole (~2-4 minutes)..." | "[7/7] جاري فكّ الضغط وضبط Konsole (~2–4 دقايق)…" | DetailPrint |
| 272 | "Failed to install Konsole (code $0)." | "فشل تثبيت Konsole (الكود $0)." | MessageBox |
| 272 | "You can retry later via:" | "بتقدر تجرّب مرّة ثانية لاحقاً عن طريق:" | MessageBox |
| 276 | "Konsole and window tools installed successfully." | "تم تثبيت Konsole وأدوات النوافذ بنجاح." | DetailPrint |
| 280 | "Claude Code CLI" | "Claude Code CLI" | اسم Section (تقني — يبقى) |
| 282 | "Checking for Claude Code in Ubuntu..." | "جاري التحقّق من Claude Code جوّا Ubuntu…" | DetailPrint |
| 286 | "Installing Claude Code CLI via official installer (~1-2 minutes)..." | "جاري تثبيت Claude Code CLI عن طريق الـ installer الرسمي (~1–2 دقيقة)…" | DetailPrint |
| 298 | "Installer script failed, trying npm fallback (~2-3 minutes)..." | "سكربت الـ installer فشل، بنجرّب npm كبديل (~2–3 دقايق)…" | DetailPrint |
| 302 | "Claude Code CLI installation failed." | "فشل تثبيت Claude Code CLI." | MessageBox |
| 302 | "You can install it manually later by running (in WSL):" | "بتقدر تثبّته يدوياً لاحقاً عن طريق تشغيل (جوّا WSL):" | MessageBox |
| 302 | "Click OK to continue, or Cancel to abort." | "اضغط OK للمتابعة، أو Cancel للإلغاء." | MessageBox |
| 303 | "Installation cancelled by user." | "تم إلغاء التثبيت من المستخدم." | رسالة Abort |
| 307 | "Claude Code installed successfully." | "تم تثبيت Claude Code بنجاح." | DetailPrint |
| 310 | "Claude Code already installed, skipping." | "Claude Code متثبّت أصلاً، بنتخطّى." | DetailPrint |
| 314 | "Open VcXsrv download page (optional, manual install)" | "افتح صفحة تنزيل VcXsrv (اختياري، تثبيت يدوي)" | اسم Section |
| 319 | "VcXsrv already installed at $PROGRAMFILES64\VcXsrv - skipping." | "VcXsrv متثبّت أصلاً بـ $PROGRAMFILES64\VcXsrv — بنتخطّى." | DetailPrint |
| 323 | "VcXsrv already installed at $PROGRAMFILES32\VcXsrv - skipping." | "VcXsrv متثبّت أصلاً بـ $PROGRAMFILES32\VcXsrv — بنتخطّى." | DetailPrint |
| 329 | "VcXsrv detected via registry ($0) - skipping download." | "تم اكتشاف VcXsrv عن طريق الـ registry ($0) — بنتخطّى التنزيل." | DetailPrint |
| 336 | "VcXsrv detected via 64-bit registry ($0) - skipping download." | "تم اكتشاف VcXsrv عن طريق registry بنسخة 64-bit ($0) — بنتخطّى التنزيل." | DetailPrint |
| 349 | "Opening the VcXsrv download page in your browser..." | "جاري فتح صفحة تنزيل VcXsrv بالمتصفّح…" | DetailPrint |
| 351 | "VcXsrv was not found on this system." | "ما لقينا VcXsrv على هاد الجهاز." | MessageBox |
| 351 | "To enable Alt+Shift keyboard-layout switching inside Konsole, install VcXsrv from the page that just opened, then set USE_VCXSRV=true in $INSTDIR\config.txt." | "لتفعيل تبديل تخطيط الكيبورد بـ Alt+Shift جوّا Konsole، ثبّت VcXsrv من الصفحة اللي فتحت هلّأ، وبعدين عيّن USE_VCXSRV=true بـ $INSTDIR\config.txt." | MessageBox |
| 351 | "This step is optional — if you skip it, Kivun Terminal falls back to WSLg (Alt+Shift will not work but everything else does)." | "هاي الخطوة اختيارية — إذا تخطّيتها، Kivun Terminal بيرجع لـ WSLg (Alt+Shift ما رح يشتغل بس كل الباقي بيشتغل)." | MessageBox |
| 355 | "Desktop Shortcut" | "اختصار سطح المكتب" | اسم Section |
| 356 | "Launch Kivun Terminal" (shortcut comment) | "شغّل Kivun Terminal" | تعليق اختصار سطح المكتب |
| 357 | "Launch Kivun Terminal" (Start Menu) | "شغّل Kivun Terminal" | تعليق اختصار قائمة البداية |
| 356 | "Kivun Terminal.lnk" (display name) | "Kivun Terminal" | اسم اختصار سطح المكتب |
| 357 | "Kivun Terminal.lnk" (Start Menu name) | "Kivun Terminal" | اسم اختصار قائمة البداية |
| 368 | "Right-Click Menu Integration" | "تكامل قائمة الكبسة اليمين" | اسم Section |
| 370 | "Open with Kivun Terminal" | "افتح بـ Kivun Terminal" | عنصر قائمة كبسة يمين على مجلّد |
| 375 | "Open with Kivun Terminal" | "افتح بـ Kivun Terminal" | عنصر قائمة كبسة يمين على خلفية مجلّد |
| 382 | "Launcher scripts, config, docs (required)." | "سكربتات التشغيل، الإعدادات، الوثائق (إلزامي)." | وصف Section CORE |
| 383 | "Install WSL2 and Ubuntu if missing (required)." | "تثبيت WSL2 و Ubuntu إذا ناقصين (إلزامي)." | وصف Section WSL |
| 384 | "Install Konsole terminal and window tools inside Ubuntu (required)." | "تثبيت طرفية Konsole وأدوات النوافذ جوّا Ubuntu (إلزامي)." | وصف Section KONSOLE |
| 385 | "Install Claude Code CLI inside Ubuntu (required)." | "تثبيت Claude Code CLI جوّا Ubuntu (إلزامي)." | وصف Section CLAUDE |
| 386 | "Opens the VcXsrv download page in your browser. Install it manually to enable Alt+Shift keyboard switching. Skip if you don't need it." | "بيفتح صفحة تنزيل VcXsrv بالمتصفّح تبعك. ثبّته يدوياً لتفعيل تبديل الكيبورد بـ Alt+Shift. تخطّى إذا مش محتاجه." | وصف Section VCXSRV |
| 387 | "Desktop and Start Menu shortcuts." | "اختصارات سطح المكتب وقائمة البداية." | وصف Section SHORTCUT |
| 388 | "Right-click any folder -> Open with Kivun Terminal." | "كبسة يمين على أي مجلّد ← افتح بـ Kivun Terminal." | وصف Section RCLICK |
| 395 | "Uninstall" | "إزالة التثبيت" | اسم Section الـ Uninstall |
| 440 | "Kivun Terminal has been uninstalled." | "تم إزالة تثبيت Kivun Terminal." | MessageBox — Uninstall |
| 440 | "WSL, Ubuntu, Konsole, and Claude Code were left intact." | "WSL، Ubuntu، Konsole، و Claude Code تركناهم زي ما هم." | MessageBox |
| 440 | "Remove them manually via 'wsl --unregister Ubuntu' if desired." | "بتقدر تحذفهم يدوياً عن طريق 'wsl --unregister Ubuntu' إذا بتحبّ." | MessageBox |
| 440 | "Logs preserved at: $LOCALAPPDATA\Kivun-WSL" | "السجلّات محفوظة بـ: $LOCALAPPDATA\Kivun-WSL" | MessageBox |

---

## ملاحظات على الترجمة

- **اسم المنتج:** "Kivun Terminal" تركناه بالإنجليزي لأنّه اسم تجاري/علامة، نفس الإشي للأسماء التقنية مثل WSL، Ubuntu، Konsole، Claude Code، VcXsrv، wmctrl، xdotool، Node.js، npm، PowerShell، Notepad — كلها بتظلّ بالإنجليزي.
- **مصطلحات تقنية:** folder = مجلّد، profile = بروفايل، model = موديل، flags = فلاغات، startup commands = أوامر البداية، environment variables = متغيّرات البيئة، installer = installer (أو "برنامج التثبيت" حسب السياق)، session = جلسة، shortcut = اختصار، registry = registry (تقني — يبقى)، script = سكربت، log = سجلّ.
- **أزرار قصيرة:** "شغّل" بدل "ابدأ التشغيل"، "إلغاء" بدل "ألغِ"، "حذف"، "+ جديد"، "تعديل الاسم".
- **Tooltips مختصرة وحكية:** "بدّل للبروفايل"، "بنحافظ على"، "بنتخطّى"، "بنتأكّد إنّ".
- **رسائل خطأ:** اللهجة الفلسطينية بصيغة المتكلّم/المخاطب: "اكتب مسار"، "ما بتقدر تمسح"، "ما بترجع وراء".
- **Placeholders بأمثلة:** المسارات والأمثلة التقنية (مثل `C:\Users\you\Documents\MyProject` و `KEY=VAL`) ما تترجمت — هاي أمثلة كود يفضّل تظلّ بالإنجليزي.
- **عبارات داخل code blocks (`wsl --install`, `apt-get install`, إلخ):** تركناها بالإنجليزي لأنّها أوامر بتنكتب حرفياً.
- **علامات الترقيم:** استعملنا الـ ellipsis "…" بدل ثلاث نقاط منفصلة، ودواش "—" بدل "-".
- **الأرقام:** خلّيناها أرقام عربية شرقية (1234567890) بدل الهندية لأنّها أكتر متعارف عليها بسياقات تقنية.

</div>
