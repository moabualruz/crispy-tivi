// Root build file — intentionally minimal.
// Plugin versions live in gradle/libs.versions.toml, module configs come from
// build-logic/convention plugins (crispy.kmp.library, crispy.kmp.feature, ...).
//
// Adding plugin IDs here with `apply false` lets Gradle resolve them once for
// the whole build instead of re-resolving per module.

plugins {
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.kotlin.multiplatform.library) apply false
}
