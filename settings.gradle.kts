pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "PlayIntegrityFix-NEXT"
include(":app")
include(":core")                  
include(":feature:auth")          
include(":feature:dashboard")     

project(":feature:auth").projectDir = file("feature/auth")
project(":feature:dashboard").projectDir = file("feature/dashboard")
