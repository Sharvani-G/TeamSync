# Preserve Firebase Firestore data mapping serialization parameters
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}
-keep class com.google.firebase.** { *; }

# Preserve Native WebRTC/Jitsi binary bridging pointers
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
