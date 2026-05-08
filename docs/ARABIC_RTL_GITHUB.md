<div dir="rtl">

# كتابة عربي (وباقي لغات RTL) بـ Markdown على GitHub

دليل عملي مبني على الباغات اللي صادفناها لما كنّا نبني README ثنائي اللغة لـ Kivun Terminal. نفس القواعد بتنطبق على العبري، الفارسي، الأردو، وأي لغة RTL تانية.

GitHub بيرندر Markdown لـ HTML وبعدين بعرضه من خلال CSS تبعه. كل خطوة بهاي السلسلة عندها رأي خاص بشأن اتجاه النص. السلسلة بتغلط افتراضياً مع محتوى RTL، والحلول المؤقتة مش متناظرة — اللي بصلّح فقرة ما بصلّح قائمة، واللي بصلّح قائمة ما بصلّح blockquote.

هاي الصفحة بتوثّق الأنماط اللي فعلاً بتشتغل على github.com اليوم (أيار ٢٠٢٦، آخر تأكيد على README بهاد الريبو).

## المشكلة الأساسية

مصدر Markdown مفي عنده metadata للاتجاه. GitHub بيرندر كل فقرة كـ LTR افتراضياً. النص العربي جوّا فقرة LTR بضل بنكتب وبنخزّن من اليسار لليمين بترتيب المصدر — *الانعكاس البصري* بصير وقت الـ render فقط إذا الرندرر قرّر إنّ السطر RTL.

الرندرر بقرّر لكل عنصر، مش لكل document. لفّ كل قسم العربي بـ `<div dir="rtl">` ضروري بس مش كافي: في عناصر فرعية كتير (قوائم markdown، blockquotes، خلايا جداول) بتفلت بصمت من سياق الاتجاه هاد.

## الأنماط اللي بتشتغل

### ١. لفّ القسم بـ `<div dir="rtl">`

```markdown
<div dir="rtl">

## شرح بالعربي

نص عربي هون.

</div>
```

السطور الفاضية جوّا الـ `<div>` مهمّة — بدونها، parser تبع GitHub ممكن يوقف يفسّر المحتويات كـ Markdown.

هاد الـ wrapper بيتعامل مع الفقرات والعناوين البسيطة بشكل صحيح. القوائم، blockquotes، الجداول: شوف تحت.

### ٢. حوّل قوائم markdown (`- ...`) لـ `<ul dir="rtl">` خام

هاد الباغ اللي عضّنا أكتر شي. قائمة نقطية بـ markdown جوّا الـ `<div dir="rtl">` wrapper بترندر كـ LTR إذا أي سطر بدأ بحرف إنجليزي قوي — `**Windows:**`, `[Adaptive-RTL-Extension]`, code span متل `` `wsl --install` ``. الرندرر بقرّر اتجاه القائمة حسب أول حرف قوي بكل سطر، مش حسب العنصر الأب.

ما تحارب باستخدام markdown. استبدل القائمة كاملة بـ HTML خام:

```html
<ul dir="rtl" align="right">
  <li><strong>Windows:</strong> <code>wsl --install</code> مرة وحدة، بعدين نزّل <code>Kivun_Terminal_Setup.exe</code> من <a href="...">آخر إصدار</a> وشغّل.</li>
  <li><strong>Linux:</strong> <code>git clone</code> + <code>./linux/install.sh</code>.</li>
</ul>
```

`align="right"` احتياط — `dir="rtl"` المفروض كافي على الرندررز الملتزمة، بس `align` كل نسخ markdown اللي جرّبناها على GitHub بتحترمه.

بتفقد ergonomics تبع markdown (`-` بصير `<li>`, `**bold**` بصير `<strong>`, `[text](url)` بصير `<a href="url">text</a>`, إلخ). بستاهل.

### ٣. حوّل blockquotes الـ markdown (`> ...`) لـ `<blockquote dir="rtl">` خام

نفس السبب الجذري متل القوائم. صيغة `>` بـ Markdown بتنتج `<blockquote>` ما بترث الاتجاه من `<div dir="rtl">` بشكل موثوق:

```html
<blockquote dir="rtl" align="right">
<strong>Windows 11 — Smart App Control بحجب التثبيت.</strong> نص متابعة هون.
</blockquote>
```

### ٤. اقلب رموز الأسهم (`→` ↔ `←`)

الأسهم رموز اتجاهية بتمر من أي محرك BiDi بدون تغيير. بتنظر لوين موجّهة بترتيب المصدر، مش بالتدفّق البصري. فبسياق RTL عربي:

| المصدر | بقرأ كـ | صح؟ |
|---|---|---|
| `Start → Smart App Control → Off` | "Start" بتطلع عاليمين، السهم بشير بعيد عنها (صح بصرياً لقرّاء LTR، غلط لـ RTL) | غلط بـ RTL |
| `Start ← Smart App Control ← Off` | السهم بشير من اليمين لليسار — نفس اتجاه قراءة العربي | صح بـ RTL |

القاعدة: بنص عربي/عبري/فارسي بصف *تسلسل بصري* من اليسار لليمين، استعمل `←`. عين القارئ بتتحرّك من اليمين لليسار والسهم لازم يطابق.

نفس الشي لأي رمز اتجاهي — `▶ ◀`, `» «`, إلخ. استعمل النسخة اللي بتشير لـ RTL بنص RTL.

### ٥. ما تترجم كود، paths، أوامر

```markdown
- **Windows:** `wsl --install` مرة وحدة
```

`wsl --install` بضل بالإنجليزي. وكذلك file paths، رسائل commit، نصوص الأخطاء، وأي شي حدا ممكن يعمل Cmd+F عليه. ترجمتها بتنتج وثائق شكلها أصيل بس عديمة الفايدة للـ debugging.

### ٦. ما تستعمل em-dash جوّا نص عربي

بالطباعة العربية، الـ em-dash `—` بقرأ بصرياً كجزء من الكلمة اللي قبله وبعمل seam-bugs بأعمدة ضيّقة على بعض الرندررز. استعمل `-` (هايفن عادي، U+002D) بشكل دائم. هاي تفضيل المشروع، مش قاعدة عامة.

### ٧. انتبه لقاعدة "أول حرف قوي بالسطر"

حتى برّا القوائم، فقرة أو خلية جدول بتبدأ بمحتوى LTR قوي رح ترندر LTR. إذا عندك فقرة عربي بتفتح بمصطلح إنجليزي:

```
الـ-VS Code هو IDE منيح، بس...
```

البداية `الـ-` عربي قوي، فهاي بترندر RTL. بس:

```
VS Code هو IDE منيح، بس...
```

بترندر LTR (السطر *بيبدأ* بـ `V` اللي LTR قوي) والعربي بيظل تايه بنص السطر. أعد ترتيب عشان حرف عربي يجي أول، أو لفّ السطر:

```html
<p dir="rtl"><strong>VS Code</strong> هو IDE منيح، بس...</p>
```

### ٨. أعلام الدول: استعمل `<table>`، مش `<p>` ولا قائمة markdown

هاي خدت خمسة PRs لنعملها صح. الباغ اللي ضليّنا نقع فيه:

- إيموجيات regional-indicator (`🇬🇧 🇸🇦`) بترندر كأزواج الحروف الحرفية "GB"/"SA" على **Windows** — خط emoji تبع Microsoft مفي عنده flag glyphs، عن قصد. معظم قرّاء GitHub على Windows. ما تستعمل هاي الإيموجيات حيث القرّاء بتوقّعوا أعلام.
- فحوّلنا لـ PNG flags من [`flagcdn.com`](https://flagcdn.com) — صور حقيقية بترندر نفس الشي على كل OS. **بس:** الرندرر تبع GitHub بيحقن `style="...display: block"` على كل `<img>` جوّا محتوى markdown. الـ `display: block` هاد بخلّي العلم يتراكم على سطره الخاص فوق أي نص أو لينك مجاور، مهما كان شكل الـ markup. الـ width، height، `align="absmiddle"`، `valign`، wrappers `<picture>`، صورة برّا الـ anchor — مفي شي بيتجاوز الـ `display: block` المحقون، لأنّ HTML sanitizer تبع GitHub بشيل خاصية `style` تبعك وselector الـ CSS class بيغلب.
- اختصارات Gemoji (`:uk:`, `:saudi_arabia:`) **جزئياً** بتشتغل — GitHub بيرندرها كـ unicode chars خام بمخرجات الـ API (مفي wrapper `<g-emoji>`)، وعلى الصفحة الفعلية Twemoji بنطبق، بس بس أحياناً ومش موثوق بكل الـ viewers. كمان، بس أسماء معيّنة بتشتغل: `:uk:`, `:gb:`, `:flag_gb:` صحاح؛ `:saudi_arabia:`, `:flag_sa:` صحاح؛ `:flag-sa:` (هايفن) **مش** صحيح.
- شارات `shields.io` مع `?logo=linkedin` (وما يشبهها) **معطّلة** — أيقونة LinkedIn اتشالت من قائمة named-logos تبع shields.io. الأيقونة ما بتنغرس بالـ SVG. اشطب الـ `?logo=` param واستعمل شارة نص نظيفة.

الشي الوحيد اللي فعلاً بحط صورة العلم + النص على سطر واحد:

```html
<table align="center" border="0" cellspacing="0" cellpadding="6"><tr>
<td valign="middle"><img src="https://flagcdn.com/20x15/gb.png" alt="GB" width="20" height="15"></td>
<td valign="middle"><a href="#english"><b>English</b></a></td>
<td valign="middle"><img src="https://flagcdn.com/20x15/sa.png" alt="SA" width="20" height="15"></td>
<td valign="middle"><a href="#%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9"><b>العربية</b></a></td>
</tr></table>
```

كل `<td>` بحدد الـ `display: block` على عرض الخلية الطبيعي؛ صف الجدول بفرض ليّاوت أفقي. الـ trade-off: CSS تبع GitHub بضيف حدود مرئية ١px على كل `<th>`/`<td>` بجداول markdown، وما بتقدر تخفيها — `style="border:none"` بنشال. رح تشوف حدود خلايا رمادية. مفي طريقة تتجاوز هاد بـ markup المحتوى-فقط؛ البديل (مفي جدول) هي مشكلة العلم-فوق-النص.

GitHub بشيل `<img>` inline من anchor slugs، فـ `## English 🇬🇧` بنتج slug `english-` (شرطة من نهاية الإيموجي المشيوله)، و `## English <img ...>` بنتج `english`. حدّث anchor links بنفس التعديل لما تغيّر أعلام العناوين.

### ٩. مجموعة named-logos تبع shields.io مش مستقرّة

`?logo=NAME` على shields.io بيدوّر `NAME` بقائمتها الداخلية للـ named-logos. هاي القائمة مش نفس مجموعة simple-icons.org الكاملة، وshields.io دورياً بشيل logos (لاحظنا `linkedin` بمنتصف ٢٠٢٦). لما الـ logo مش موجود، shields.io بصمت بيرجّع الشارة بدونه — مفي خطأ، مفي تحذير، بس مفي أيقونة. تأكّد بـ curl للـ badge SVG وتفحّص لـ `<image>`:

```bash
curl -s "https://img.shields.io/badge/X-Y-blue?logo=NAME" | grep -c '<image'
# 1 = الـ logo مغروس؛ 0 = NAME مش بقائمة named-logos تبع shields.io
```

إذا الـ logo مش موجود، الخيارات:
١. اشطب الـ `?logo=` param واستعمل شارة نص نظيفة.  
٢. استعمل بادج جنريتر تاني (`custom-icon-badges.demolab.com` بغطي بعض اللي shields.io شالها، بس أسامي الأيقونات تبعه كمان مش portable).  
٣. استعمل `<img>` منفصل مع الأيقونة جنب الشارة.

`<svg>` inline **مش** خيار — sanitizer تبع GitHub بشيل `<svg>` من محتوى markdown كلياً.

## شو جرّبنا بس ما استعملنا

- **`<bdi>`** — بشتغل بمتصفحات حقيقية بس CSP/sanitizer تبع GitHub بشيله من Markdown المرندر.
- **`text-align: right` عبر inline `style=""`** — sanitizer تبع GitHub بشيل خصائص `style` على معظم العناصر.
- **توجيهات CSS isolation بـ code blocks** — مش متعلّق؛ كنّا بدنا *عرض* RTL، مش عزل على مستوى الحرف.
- **Unicode RLM (U+200F) ببداية السطر** — بشتغل بس مخفي بالمصدر، فبربك مستقبل-إلنا لما يقرأ الـ diff. بنستعمله برمجياً جوّا الـ `kivun-claude-bidi` wrapper (مخرجات الترمنال) بس مش بـ Markdown اللي البشر بحرّروه.
- **`<svg>` inline لأيقونات الأعلام** — بنشال من sanitizer تبع GitHub.
- **`<picture>` wrapper لتجاوز عرض img** — الـ `<img>` الداخلي لسا بياخد `display: block` من حقن CSS تبع GitHub.
- **`align="absmiddle"` / `valign="middle"` على `<img>`** — خصائص HTML4 ملغاة، بنشالوا من GitHub.
- **`style="border:none"` على `<table>`/`<td>`** — GitHub بشيل `style` من عناصر الجدول؛ حدود الخلايا بتضل.

## checklist سريع لما تضيف عربي لـ README

١. القسم ملفوف بـ `<div dir="rtl">` مع سطور فاضية جوّاه؟ ✅  
٢. أي قوائم نقطية بهاد القسم محوّلة لـ `<ul dir="rtl">`؟ ✅  
٣. أي blockquotes محوّلة لـ `<blockquote dir="rtl">`؟ ✅  
٤. أي أسهم `→` بنص عربي مقلوبة لـ `←`؟ ✅  
٥. الكود، paths، الأوامر مخلّيها بالإنجليزي؟ ✅  
٦. em-dashes مستبدلة بـ هايفن؟ ✅  
٧. السطور اللي بتفتح بمحتوى إنجليزي معاد ترتيبها أو ملفوفة بـ `<p dir="rtl">`؟ ✅  
٨. أعلام الدول مرندرة عبر PNG `<img>` جوّا `<table>` (مش عبر إيموجيات regional-indicator، مش بـ `<p>` — Windows بعرض الإيموجيات كأزواج حروف، وليّاوت الـ `<p>` بكدّس العلم فوق النص)؟ ✅  
٩. shields.io `?logo=` params متأكّد منها بـ curl للـ SVG وفحص لـ `<image>` (قائمة named-logos مش مستقرّة؛ إذا مش موجود، اشطب الـ `?logo=`)؟ ✅

إذا قسم لسا بيرندر LTR بعد كل هاد، الخطوة الجاية للـ debugging "شوف الـ HTML المرندر على github.com، لاقي العنصر اللي اتجاهه غلط، شوف شو wrapper محتاج." دائماً تقريباً construct من markdown-لـ-HTML اللي ما ورث اتجاه الأب.

## شوف كمان

- [Anthropic Claude Code BiDi tracking issue](https://github.com/anthropics/claude-code/issues/39881) — الباغ الـ upstream اللي كل هاد المشروع بشتغل حواليه.
- [`docs/specs/BIDI_ALGORITHM.md`](specs/BIDI_ALGORITHM.md) — الـ algorithm اللي بستعمله `kivun-claude-bidi` wrapper تبع Kivun Terminal لـ BiDi مخرجات الترمنال (مشكلة مختلفة عن رندر Markdown، نفس السبب الجذري: مفي metadata للاتجاه بالمصدر).

</div>
