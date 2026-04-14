import org.gradle.api.Plugin
import org.gradle.api.Project

/**
 * Feature module convention: a KMP library that also applies Compose
 * Multiplatform. Used by every `feature-*` module plus `design-system`.
 *
 * Phase A: inherits `crispy.kmp.library`'s JVM-only targets. The Compose
 * Multiplatform plugin is intentionally NOT yet applied here — it will be
 * turned on once targets beyond JVM (android / ios / wasmJs) are wired in,
 * because Compose Multiplatform is primarily useful on those targets.
 *
 * For now this plugin is a thin passthrough that reserves the plugin ID
 * in settings so feature modules can reference it without breaking builds.
 */
class CrispyKmpFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        target.pluginManager.apply("crispy.kmp.library")
    }
}
