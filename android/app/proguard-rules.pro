-keep class androidx.lifecycle.DefaultLifecycleObserver
-keepnames interface org.tinylog.**
-keepnames class * implements org.tinylog.**
-keepclassmembers class * implements org.tinylog.** { <init>(...); }

-dontwarn dalvik.system.VMStack
-dontwarn java.lang.**
-dontwarn javax.naming.**
-dontwarn sun.reflect.Reflection