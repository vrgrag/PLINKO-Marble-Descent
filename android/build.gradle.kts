allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ------------------------------------------------------------------
    // Force every Android library subproject to compile against the same
    // compileSdk as the app module (36). Some plugins pin compileSdk = 34
    // but their transitive deps (flutter_plugin_android_lifecycle etc.)
    // now require 36 → the build fails without this override.
    // Registered BEFORE the evaluationDependsOn(":app") block below.
    // ------------------------------------------------------------------
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
