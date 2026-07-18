# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── sqflite ───────────────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── audioplayers ──────────────────────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }

# ── printing / pdf ────────────────────────────────────────────────────────────
-keep class com.github.DavBfr.dart_pdf.** { *; }

# ── share_plus ────────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ── Kotlin coroutines ─────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ── Evitar warnings de Android ────────────────────────────────────────────────
-dontwarn com.google.android.play.core.**
