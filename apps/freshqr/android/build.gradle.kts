allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// camera_android_camerax (camera-core 1.5.3) kendi derleme sınıf yolunda bunu
// bekliyor ama Gradle otomatik çekmiyor (jspecify @NonNull annotation'ı
// CallbackToFutureAdapter'a referans veriyor) — eklenti modülünün KENDİ
// build.gradle'ını değiştiremediğimiz için TÜM alt projelere (allprojects)
// uyguluyoruz ki eklenti modülü de bunu görsün. Uygulamadan sonra
// kaldırılabilir (upstream düzeltilirse).
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
