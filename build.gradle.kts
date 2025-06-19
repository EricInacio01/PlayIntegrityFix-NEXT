plugins {
    id("com.android.application") version "8.1.0" apply false
    id("com.android.library") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.10" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    afterEvaluate {
        println("Configurando módulo: ${com.android}")
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}
