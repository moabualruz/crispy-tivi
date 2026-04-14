import com.android.build.api.dsl.KotlinMultiplatformAndroidLibraryExtension
import org.gradle.api.JavaVersion
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.plugins.JavaPluginExtension
import org.gradle.jvm.toolchain.JavaLanguageVersion
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.withType
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompilationTask

/**
 * Base Kotlin Multiplatform library convention.
 *
 * Uses AGP 9.0's new KMP-aware library plugin (`com.android.kotlin.multiplatform.library`)
 * which integrates the Android target into the KMP DSL via `androidLibrary { }`
 * instead of the old `androidTarget()` + `com.android.library` pair.
 *
 * Targets:
 *  - jvm()           — desktop / shared-JVM code paths
 *  - androidLibrary  — Android compilation, wired via AGP's KMP plugin
 *
 * iOS and wasmJs targets will be added in phase B once macOS/Xcode and wasm
 * tooling are available on the build host.
 *
 * Android namespace defaults to `tivi.crispy.<moduleNameWithDotsNotDashes>`.
 * Override in the module build file if a different namespace is needed.
 */
class CrispyKmpLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            with(pluginManager) {
                apply("org.jetbrains.kotlin.multiplatform")
                apply("com.android.kotlin.multiplatform.library")
            }

            extensions.configure<KotlinMultiplatformExtension> {
                jvm()

                // AGP 9.0 extension within the kotlin { } block.
                @Suppress("UnstableApiUsage")
                (this as org.gradle.api.plugins.ExtensionAware)
                    .extensions
                    .configure<KotlinMultiplatformAndroidLibraryExtension>("androidLibrary") {
                        // Build a unique Android namespace from the module path so
                        // grouped modules like `:core:design-system` and
                        // `:domain:model` never collide on R class generation.
                        namespace = "tivi.crispy" +
                            project.path
                                .trimStart(':')
                                .replace(':', '.')
                                .replace('-', '.')
                                .let { if (it.isEmpty()) "" else ".$it" }
                        compileSdk = 36
                        minSdk = 24
                    }

                sourceSets.apply {
                    commonMain.configure {
                        // common-only dependencies go here per module
                    }
                    commonTest.configure {
                        dependencies {
                            implementation(kotlin("test"))
                        }
                    }
                }
            }

            extensions.configure<JavaPluginExtension> {
                toolchain {
                    languageVersion.set(JavaLanguageVersion.of(21))
                }
            }

            tasks.withType<KotlinCompilationTask<*>>().configureEach {
                compilerOptions.freeCompilerArgs.add("-Xexpect-actual-classes")
            }
        }
    }
}
