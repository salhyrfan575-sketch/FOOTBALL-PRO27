# VFX Studio Mobile

Android video-editor prototype using Kotlin, Jetpack Compose and AndroidX Media3.

## Current foundation
- Import multiple video, image and audio files with Android document picker
- Video preview and playback using ExoPlayer
- Selectable media layer list
- Remove media layers
- Playback speed control from 0.25x to 3x
- Dark mobile editing workspace
- GitHub Actions workflow to build a debug APK

## Build
Open this folder in Android Studio with JDK 17 and Android SDK 35, sync Gradle and run the app. Alternatively, use Actions > Build VFX Studio APK > Run workflow. The APK is uploaded as artifact VFX-Studio-Mobile-debug.

## Development status
This is an early functional foundation, not a completed InShot replacement. Real trimming/splitting, multi-clip rendering, text/image compositing, transitions, color filters, audio mixing, project persistence and rendered MP4 export remain to be implemented.
