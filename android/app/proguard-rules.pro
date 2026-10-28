# ALIVE NG — R8 / ProGuard rules for the release build.
# The Flutter Gradle plugin injects its own keep rules for the Flutter engine
# and plugins. These rules cover common third-party SDKs used by this app.

# Firebase / Google Play Services (FCM, Auth) — keep what is reflectively accessed.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# flutter_local_notifications / workmanager style plugins that use reflection.
-keep class com.dexterous.** { *; }

# Keep annotations used by plugins for reflection.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# lineq-style reflections guards: silence harmless warnings instead of failing the build.
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn org.slf4j.**

# OkHttp / Conscrypt / BouncyCastle / OpenJSSE TLS platform optional dependencies
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn okhttp3.**
-dontwarn io.sentry.**
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-dontwarn com.livekit.**
-dontwarn androidx.**

# Appwrite & WebAuth OAuth callbacks
-keep class io.appwrite.** { *; }
-dontwarn io.appwrite.**
-keep class com.linusu.flutter_web_auth_2.** { *; }
-dontwarn com.linusu.flutter_web_auth_2.**
