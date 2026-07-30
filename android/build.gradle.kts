import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.KotlinVersion

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
    val rootDrive = rootProject.projectDir.absolutePath.substringBefore(java.io.File.separator)
    val projectDrive = project.projectDir.absolutePath.substringBefore(java.io.File.separator)
    if (rootDrive.equals(projectDrive, ignoreCase = true)) {
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(KotlinVersion.KOTLIN_1_8)
            apiVersion.set(KotlinVersion.KOTLIN_1_8)
        }
    }
}

subprojects {
    val project = this
    project.plugins.configureEach {
        if (this is com.android.build.gradle.BasePlugin) {
            val android = project.extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                // 1. Configure namespace if missing
                if (android.namespace == null) {
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestContent = manifestFile.readText()
                        val matcher = java.util.regex.Pattern.compile("package=\"([^\"]+)\"").matcher(manifestContent)
                        if (matcher.find()) {
                            android.namespace = matcher.group(1)
                        } else {
                            android.namespace = "com.safetrace.app.${project.name.replace("-", "_").replace(".", "_")}"
                        }
                    } else {
                        android.namespace = "com.safetrace.app.${project.name.replace("-", "_").replace(".", "_")}"
                    }
                }
                // 2. Align Kotlin JVM target with Java compatibility
                project.tasks.withType<KotlinCompile>().configureEach {
                    val targetCompatibility = android.compileOptions.targetCompatibility
                    val jvmTargetStr = targetCompatibility.toString()
                    compilerOptions {
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(jvmTargetStr))
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
