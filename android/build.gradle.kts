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
}
// Some Flutter plugins (e.g. agora_rtc_engine) ship an Android module built
// against an older compileSdk than their own transitive androidx deps now
// require, which fails `checkReleaseAarMetadata`. Force every subproject's
// compileSdk up to match the app's, without needing to patch plugin sources.
// Registered before evaluationDependsOn below so it's queued on every
// project prior to any project being force-evaluated out of order.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { android ->
            val currentApi = android.compileSdkVersion?.removePrefix("android-")?.toIntOrNull() ?: 0
            if (currentApi in 1 until 33) {
                android.compileSdkVersion(33)
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
