plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.example.minimal"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.example.minimal"
        minSdk = 36
        targetSdk = 37
        versionCode = providers.gradleProperty("releaseVersionCode").orElse("1").get().toInt()
        versionName = providers.gradleProperty("releaseVersionName").orElse("1.0").get()

    }

    val releaseKeystorePath = providers.environmentVariable("ANDROID_KEYSTORE_PATH").orNull
    signingConfigs {
        if (releaseKeystorePath != null) {
            create("release") {
                storeFile = file(releaseKeystorePath)
                storePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("ANDROID_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("ANDROID_KEY_PASSWORD").get()
                enableV1Signing = false
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            if (releaseKeystorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
            optimization {
                enable = true
                packageScope = setOf("androidx.**", "kotlin.**", "kotlinx.**")
            }
        }
    }
    sourceSets.getByName("main").res.srcDir(layout.buildDirectory.dir("generated/refinement/res").get().asFile)
    enableKotlin = false
}

apply(from = "refinement-assets.gradle.kts")

dependencies {
}