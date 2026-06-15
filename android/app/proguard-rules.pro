# flutter_local_notifications stores scheduled notifications through Gson.
# R8 full mode can strip the generic Signature used by Gson TypeToken.
-keepattributes Signature
-keepattributes *Annotation*

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

-keep class com.dexterous.flutterlocalnotifications.** { *; }
