# TensorFlow Lite Proguard Rules
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.support.**
-dontwarn org.tensorflow.lite.**
-keep class org.tensorflow.lite.** { *; }
