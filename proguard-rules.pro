# proguard-rules.pro  —  AIDE Pro / Gradle
# ----------------------------------------
# Ye R8/ProGuard ke rules hain. R8 build-time pe class + package ka naam
# badal deta hai (MainActivity -> a.a, com.* chhup jaata hai) AUR manifest /
# resources / reflection ko khud sahi handle karta hai. Yahi SAFE tarika hai.
#
# Enable karne ke liye app ke build.gradle me (release buildType):
#   minifyEnabled true
#   shrinkResources true
#   proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
#
# AIDE Pro: apne module folder me build.gradle kholo, release block me ye 3
# lines daalo, aur ye file module ke root me rakho.

# ---- Keep Android entry points (system inhe by-name dhoondhta hai) ----
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference

# ---- Custom Views used in XML layouts ----
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# ---- Reflection / serialization you rely on (edit to YOUR class names) ----
# Agar tumhare paas model/POJO classes hain jinhe JSON (Gson/Moshi) se
# banate ho, unke naam mat badlo warna parse fail hoga:
-keep class com.example.app.model.** { *; }        # <-- apna package likho
-keepclassmembers class * implements java.io.Serializable { *; }
-keepnames class * implements java.io.Serializable

# ---- Native (JNI) methods ----
-keepclasseswithmembernames class * { native <methods>; }

# ---- Enums ----
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---- Parcelable ----
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ---- Keep annotations + metadata ----
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# ---- Cleaner output ----
-renamesourcefileattribute SourceFile
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}
