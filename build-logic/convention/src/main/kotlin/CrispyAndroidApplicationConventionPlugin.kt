import com.android.build.api.dsl.ApplicationExtension
import org.gradle.api.JavaVersion
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.plugins.JavaPluginExtension
import org.gradle.jvm.toolchain.JavaLanguageVersion
import org.gradle.kotlin.dsl.configure

/**
 * Convention for the Android application module (`app-android`).
 *
 * Keeps app-android as a pure Android module (not KMP) — it consumes shared
 * KMP library modules but does not itself produce common-Kotlin output.
 * Simplest layout for an Android app shell.
 */
class CrispyAndroidApplicationConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            // AGP 9.0+ has built-in Kotlin support, so `org.jetbrains.kotlin.android`
            // is no longer needed (and is now an error if applied).
            pluginManager.apply("com.android.application")

            extensions.configure<ApplicationExtension> {
                namespace = "tivi.crispy.app.android"
                compileSdk = 36

                defaultConfig {
                    applicationId = "tivi.crispy"
                    minSdk = 24
                    targetSdk = 36
                    versionCode = 1
                    versionName = "0.1.0"
                }

                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_21
                    targetCompatibility = JavaVersion.VERSION_21
                }
            }

            extensions.configure<JavaPluginExtension> {
                toolchain {
                    languageVersion.set(JavaLanguageVersion.of(21))
                }
            }
        }
    }
}
