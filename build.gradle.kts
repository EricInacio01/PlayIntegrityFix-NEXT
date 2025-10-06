// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
}

tasks.register("copyZygiskFiles") {
    val moduleFolder = project.rootDir.resolve("module")
    val zygiskModule = project.project(":zygisk")
    val zygiskBuildDir = zygiskModule.layout.buildDirectory
    val classesJar = zygiskBuildDir.file("intermediates/dex/release/minifyReleaseWithR8/classes.dex")
    val zygiskSoDir = zygiskBuildDir.file("intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib")

    inputs.dir(zygiskSoDir)
    inputs.file(classesJar)
    outputs.dir(moduleFolder)

    doLast {
        classesJar.get().asFile.copyTo(moduleFolder.resolve("classes.dex"), overwrite = true)
        zygiskSoDir.get().asFile.walk()
            .filter { it.isFile && it.name == "libzygisk.so" }
            .forEach { soFile ->
                val abiFolder = soFile.parentFile.name
                val destination = moduleFolder.resolve("zygisk/$abiFolder.so")
                soFile.copyTo(destination, overwrite = true)
            }
    }
}

tasks.register("copyInjectFiles") {
    val moduleFolder = project.rootDir.resolve("module")
    val injectModule = project.project(":inject")
    val injectBuildDir = injectModule.layout.buildDirectory
    val injectSoDir = injectBuildDir.file("intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib")

    inputs.dir(injectSoDir)
    outputs.dir(moduleFolder)

    doLast {
        injectSoDir.get().asFile.walk()
            .filter { it.isFile && it.name == "libinject.so" }
            .forEach { soFile ->
                val abiFolder = soFile.parentFile.name
                val destination = moduleFolder.resolve("inject/$abiFolder.so")
                soFile.copyTo(destination, overwrite = true)
            }
    }
}

tasks.register<Zip>("zip") {
    dependsOn("copyZygiskFiles", "copyInjectFiles")

    archiveFileName.set("PlayIntegrityFix.zip")
    destinationDirectory.set(project.rootDir.resolve("out"))

    from(project.rootDir.resolve("module"))
}