plugins {
    `kotlin-dsl`
}

group = "tivi.crispy.buildlogic"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

dependencies {
    compileOnly(libs.kotlin.gradle.plugin)
    compileOnly(libs.android.gradle.plugin)
}

gradlePlugin {
    plugins {
        register("crispyKmpLibrary") {
            id = "crispy.kmp.library"
            implementationClass = "CrispyKmpLibraryConventionPlugin"
        }
        register("crispyKmpFeature") {
            id = "crispy.kmp.feature"
            implementationClass = "CrispyKmpFeatureConventionPlugin"
        }
        register("crispyAndroidApplication") {
            id = "crispy.android.application"
            implementationClass = "CrispyAndroidApplicationConventionPlugin"
        }
    }
}
