# Android Studio Setup Guide for Alive Flutter App

## Prerequisites

### 1. Install Android Studio
- Download Android Studio from: https://developer.android.com/studio
- Install with default settings
- Make sure to install Android SDK, Android SDK Platform-Tools, and Android Virtual Device (AVD)
- Ensure Java Development Kit (JDK) 11+ is installed (Android Studio includes this, or install separately)
- Set JAVA_HOME environment variable to your JDK installation path

### 2. Install Flutter
- Download Flutter SDK from: https://flutter.dev/docs/get-started/install/windows
- Extract to `C:\flutter` (or your preferred location)
- Add Flutter to your PATH environment variable:
  - Add `C:\flutter\bin` to your system PATH
- Run `flutter doctor` to verify installation

### 3. Configure Android Studio for Flutter
1. Open Android Studio
2. Go to **File > Settings > Plugins**
3. Install the **Flutter** plugin (this will also install Dart plugin)
4. Restart Android Studio

## Project Setup

### 1. Clone and Open Project
```bash
git clone git@github.com:timsd/alive-ng-app.git
cd alive-ng-app/alive_flutter_app
```

### 2. Open in Android Studio
1. Open Android Studio
2. Click **Open an existing Android Studio project**
3. Navigate to `alive-ng-app/alive_flutter_app` folder
4. Click **OK**

### 3. Install Dependencies
```bash
flutter pub get
```

## Android Emulator Setup

### 1. Create Virtual Device
1. In Android Studio, go to **Tools > AVD Manager**
2. Click **Create Virtual Device**
3. Choose a device (recommended: Pixel 4 or newer)
4. Select a system image (recommended: API 30 or higher)
5. Click **Next** and **Finish**

### 2. Launch Emulator
1. In AVD Manager, click the **Play** button next to your virtual device
2. Wait for the emulator to boot up completely

## Running the App

### Method 1: Using Android Studio
1. Make sure your emulator is running
2. In Android Studio, click the **Run** button (green triangle)
3. Select your target device from the dropdown

### Method 2: Using Command Line
```bash
# Check available devices
flutter devices

# Run on emulator
flutter run

# Run on specific device
flutter run -d <device_id>
```

## Troubleshooting

### Common Issues

1. **Flutter Doctor Issues**
   ```bash
   flutter doctor
   ```
   Follow the suggestions to fix any issues

2. **Android License Issues**
   ```bash
   flutter doctor --android-licenses
   ```
   Accept all licenses

3. **Gradle Build Issues**
   - Clean and rebuild:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Emulator Not Detected**
   - Ensure emulator is fully booted
   - Check if USB debugging is enabled (for physical devices)
   - Restart ADB:
   ```bash
   adb kill-server
   adb start-server
   ```

### Performance Tips

1. **Enable Hardware Acceleration**
   - Ensure Intel HAXM or Hyper-V is enabled
   - Use x86_64 system images for better performance

2. **Increase Emulator RAM**
   - In AVD Manager, edit your virtual device
   - Increase RAM to 4GB or more

3. **Use Physical Device**
   - Enable Developer Options on your Android device
   - Enable USB Debugging
   - Connect via USB cable

## Firebase Configuration

The project uses Firebase for various services with the latest Google Services plugin configuration:

### Required Files:
1. **google-services.json**: Place this file in `android/app/` directory
2. **GoogleService-Info.plist**: Place this file in `ios/Runner/` directory

### Updated Configuration:
The project has been updated with:
- **Google Services Plugin**: Version 4.4.3 (latest)
- **Firebase BoM**: Version 34.2.0 for consistent dependency management
- **Automatic Version Management**: Firebase dependency versions are managed by the BoM

### Gradle Configuration:
- **Project-level** (`android/build.gradle`): Updated Google services plugin to v4.4.3
- **App-level** (`android/app/build.gradle`): Added Firebase BoM for better dependency management

These files contain your Firebase project configuration and are required for Firebase services to work.

## Next Steps

After successful setup:
1. Configure Firebase (see API_REQUIREMENTS.md)
2. Set up environment variables
3. Configure Supabase connection
4. Test all app features

## Useful Commands

```bash
# Check Flutter installation
flutter doctor -v

# List available devices
flutter devices

# Run in debug mode
flutter run

# Run in release mode
flutter run --release

# Build APK
flutter build apk

# Build App Bundle
flutter build appbundle

# Clean project
flutter clean

# Update dependencies
flutter pub upgrade
```