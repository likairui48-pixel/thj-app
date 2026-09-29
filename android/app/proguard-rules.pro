# flutter_secure_storage / dartssh2 / 自定义 Socket 所需保留项
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.aifish.mc.** { *; }

# dartssh2 依赖的 BouncyCastle / net_ssh 相关
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# 保留被反射使用的枚举
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
