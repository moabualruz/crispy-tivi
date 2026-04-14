pluginManagement {
    includeBuild("build-logic")
    repositories {
        gradlePluginPortal()
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "crispy-tivi"

// ---- App shells --------------------------------------------------------
include(":app:android")
include(":app:ios")
include(":app:desktop")
include(":app:web")

// ---- Core shared subsystems --------------------------------------------
include(":core:design-system")
include(":core:navigation")
include(":core:epg")
include(":core:playback")
include(":core:image")
include(":core:security")
include(":core:export-import")

// ---- Feature modules (match UIUX primary destinations + onboarding/player) ----
include(":feature:home")
include(":feature:live")
include(":feature:guide")
include(":feature:movies")
include(":feature:series")
include(":feature:search")
include(":feature:library")
include(":feature:sources")
include(":feature:settings")
include(":feature:player")
include(":feature:onboarding")

// ---- Domain layer ------------------------------------------------------
include(":domain:model")
include(":domain:services")
include(":domain:policies")

// ---- Data layer --------------------------------------------------------
include(":data:contracts")
include(":data:repositories")
include(":data:normalization")
include(":data:search")
include(":data:sync")
include(":data:restoration")
include(":data:observability")

// ---- Provider adapters (one module per source family) -----------------
include(":provider:contracts")
include(":provider:m3u")
include(":provider:xtream")
include(":provider:stalker")

// ---- Platform integration: playback ------------------------------------
include(":platform:player:android")
include(":platform:player:apple")
include(":platform:player:desktop")
include(":platform:player:web")

// ---- Platform integration: secure storage ------------------------------
include(":platform:security:android")
include(":platform:security:apple")
include(":platform:security:desktop")
include(":platform:security:web")

// ---- Platform integration: observability -------------------------------
include(":platform:observability:android")
include(":platform:observability:apple")
include(":platform:observability:desktop")
include(":platform:observability:web")

// ---- Test support ------------------------------------------------------
include(":test:fixtures")
include(":test:contracts")
