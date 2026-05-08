<div dir="rtl">

# Kivun Terminal v1.4.3

ثلاث إصلاحات من تجربة المستخدمين المستمرة لإصدارات v1.4.x.

## ١. البروفايلات الموجودة بتنضّف `--effort low` تلقائياً

إصدار v1.4.2 شال شيب `+ Low effort`، بس ما لمس البروفايلات اللي عندها `--effort low` محفور بفلاغاتها المخصّصة. المستخدمين اللي عندهم `CLAUDE_FLAGS=--effort low` بـ `config.txt` تبعهم من قبل v1.4.0، انتقل هاد الفلاغ للبروفايل الافتراضي وضلّوا يشوفوه.

v1.4.3 بضيف فحص `scrubDeprecatedFlags()` بكل تحميل بروفايل، بشيل `--effort low` من الفلاغات المخصّصة وبحفظ التنضيف. مرة وحدة بتفتح فيها البيكر = `--effort low` راح من كل بروفايلاتك.

## ٢. شيبس البروفايلات بتظهر بشكل موثوق

v1.4.1 بدّل الـ `<select>` المعطّل بأزرار شيب، بس بناهم بـ `document.createElement("button")` + `btn.onclick = function() {...}`. هاد النمط بيشتغل لعناصر HTML الستاتيكية (شيبس الفلاغات الموجودة)، بس ما بيكون موثوق للأزرار اللي بتنخلق ديناميكياً بـ HTA — أحياناً الـ handlers ما بتشتغل حتى لو الزر طلع بالشكل. v1.4.3 ببني صف الشيبس كـ `innerHTML` واحد مع خصائص `onclick="switchToProfile('Name')"` inline، اللي بخلّي IE يحلّل الـ handler وقت الـ render. أسماء البروفايلات بتنحمى بـ HTML escaping عشان الأسماء اللي فيها علامات اقتباس أو `&` تضل آمنة.

## ٣. شيلنا الـ placeholder من خانة الفلاغات المخصّصة

النص اللي كان `placeholder` بخانة الفلاغات المخصّصة (*"Click chips above, or type any flags here verbatim"*) كان مزعج. هلأ فاضي. سطر المساعدة تحت لسا بفسّر شو الخانة بتعمل.

## الملفات اللي تغيّرت

- `payload/folder-picker.hta` — رسم الشيبس عبر innerHTML، scrubDeprecatedFlags، تنضيف placeholder
- `VERSION`, `docs/CHANGELOG.md` — رفع الإصدار + سجل التغييرات
- `docs/README.md`, `docs/README_INSTALLATION.md`, `docs/TROUBLESHOOTING.md` — تحديث ختم الإصدار

## إعادة التثبيت

نزّل `Kivun_Terminal_Setup.exe` من صفحة إصدار v1.4.3 وشغّله. NSIS بيدعس فوق التثبيت الموجود. بأول فتح للبيكر: `--effort low` راح يكون مرحول من البروفايل الافتراضي، صف الشيبس راح يظهر، وخانة Custom ما راح يكون فيها الـ placeholder المكروه.

</div>
