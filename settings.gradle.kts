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
include(":app")                   // Módulo principal Android
include(":core")                  // Módulo com lógica e utilitários compartilhados
include(":feature:auth")          // Módulo da funcionalidade de autenticação
include(":feature:dashboard")     // Módulo da funcionalidade de painel/visualização

project(":feature:auth").projectDir = file("feature/auth")
project(":feature:dashboard").projectDir = file("feature/dashboard")
