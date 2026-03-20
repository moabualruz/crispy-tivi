# CrispyTivi — Arabic messages (RTL)

## App
app-name = كريسبي تيفي
app-tagline = تجربتك السينمائية في بث IPTV

## Navigation
nav-home = لك
nav-live = مباشر
nav-movies = أفلام
nav-shows = مسلسلات
nav-library = المكتبة
nav-search = بحث

## Player controls
player-play = تشغيل
player-pause = إيقاف مؤقت
player-stop = إيقاف
player-seek-forward = تخطي للأمام
player-seek-backward = تخطي للخلف
player-volume-up = رفع الصوت
player-volume-down = خفض الصوت
player-fullscreen = ملء الشاشة
player-exit-fullscreen = الخروج من وضع ملء الشاشة
player-now-playing = يُعرض الآن

## Settings labels
settings-title = الإعدادات
settings-language = اللغة
settings-video-quality = جودة الفيديو
settings-audio-track = المسار الصوتي
settings-subtitles = الترجمة
settings-parental-controls = الرقابة الأبوية
settings-server-mode = وضع الخادم
settings-about = حول التطبيق

## Error messages
error-network = خطأ في الشبكة. يرجى التحقق من اتصالك.
error-stream-unavailable = هذا البث غير متاح حاليًا.
error-source-load-failed = فشل تحميل المصدر. يرجى المحاولة مرة أخرى.
error-auth-failed = فشل المصادقة. تحقق من بيانات الاعتماد الخاصة بك.
error-timeout = انتهت مهلة الطلب. يرجى المحاولة مرة أخرى.
error-unknown = حدث خطأ غير متوقع.

## Empty states
empty-channels = لم يتم العثور على قنوات.
empty-vod = لا يوجد محتوى متاح.
empty-search = لا نتائج لـ "{ $query }".
empty-history = سجل المشاهدة فارغ.
empty-favorites = لم تتم إضافة أي مفضلات بعد.

## Channels with count (Arabic has 6 plural categories)
channel-count = { $count ->
    [zero] لا قنوات
    [one] قناة واحدة
    [two] قناتان
    [few] { $count } قنوات
    [many] { $count } قناة
   *[other] { $count } قناة
}

## EPG / time
epg-now = الآن
epg-next = التالي
epg-no-info = لا توجد معلومات عن البرنامج

## Ratings
rating-label = التصنيف: { $rating }

## Duration
duration-hours-minutes = { $hours } ساعة { $minutes } دقيقة
duration-minutes = { $minutes } دقيقة

## Sync
sync-in-progress = جارٍ مزامنة { $source }…
sync-done = تمت مزامنة { $source } بنجاح.
sync-failed = فشلت المزامنة: { $reason }

## Profile
profile-guest = ضيف
profile-switch = تبديل الملف الشخصي
