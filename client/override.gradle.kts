// Buzz CI override: force SDK/NDK versions across all modules.
// Appended to android/settings.gradle.kts by the GitHub Actions workflow.
gradle.allprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val m = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                m.invoke(androidExt, 36)
            } catch (_: Throwable) {
            }
            try {
                val defCfg = androidExt.javaClass.getMethod("getDefaultConfig").invoke(androidExt)
                try {
                    defCfg.javaClass.getMethod("setMinSdkVersion", Int::class.javaPrimitiveType).invoke(defCfg, 23)
                } catch (_: Throwable) {
                }
                try {
                    defCfg.javaClass.getMethod("setTargetSdkVersion", Int::class.javaPrimitiveType).invoke(defCfg, 36)
                } catch (_: Throwable) {
                }
            } catch (_: Throwable) {
            }
            try {
                androidExt.javaClass.getMethod("setNdkVersion", String::class.java)
                    .invoke(androidExt, "28.2.13676358")
            } catch (_: Throwable) {
            }
        }
    }
}
