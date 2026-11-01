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
// Một số plugin (vd. file_picker) khai báo compileSdk thấp hơn mức mà androidx lifecycle yêu cầu (36), làm
// checkReleaseAarMetadata thất bại. Nâng compileSdk của mọi module lên tối thiểu 36 (chỉ ảnh hưởng biên dịch,
// không đổi targetSdk hay minSdk). Phải đăng ký trước evaluationDependsOn bên dưới.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            val current = android.compileSdkVersion?.removePrefix("android-")?.toIntOrNull() ?: 0
            if (current < 36) {
                android.compileSdkVersion(36)
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

subprojects {
    val configureAndroid: () -> Unit = {
        val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        android?.compileSdkVersion(36)
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}