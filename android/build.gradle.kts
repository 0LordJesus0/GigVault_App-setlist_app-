allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // TÜM MODÜLLER İÇİN JVM SÜRÜMÜNÜ ZORLA EŞİTLE
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "11"
        }
    }

    // Java tarafını da 11'e sabitle (Bu kısım file_picker hatasını bitirecek)
    subprojects {
        afterEvaluate {
            if (project.hasProperty("android")) {
                val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
                android.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}