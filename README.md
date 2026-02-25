Here is the complete, consolidated `README.md` file. It incorporates all the core setup instructions along with the specific, crucial configurations required for local notifications and desugaring on both platforms.

---

# Quick Chat WMS

A fully featured Flutter package that embeds a WebView-based Quick Connect Chat SDK into your mobile application. It handles local storage, permissions, network connectivity tracking, file uploads (camera, gallery, video), and local notifications natively.

## Features

- 💬 **Seamless Web Chat Integration**: Embeds your custom chat widget securely.
- 📎 **Media Attachments**: Native bottom sheets for capturing photos/videos or selecting files from the gallery.
- 🔔 **Local Notifications**: Inbox-style notification grouping and handling built-in.
- 🔒 **Secure Storage**: Safely stores user preferences and FCM tokens using encrypted storage.
- 📡 **Connectivity Awareness**: Automatically pauses and retries connection when the network drops.

---

## 🛠 Platform Setup

Because this package interacts with native device features (Camera, Storage, Notifications), you must configure specific permissions and settings for both Android and iOS.

### Android Setup

**1. Minimum SDK**
Ensure your app-level `android/app/build.gradle` has a `minSdkVersion` of at least **21** (required by `flutter_secure_storage`).

**2. Permissions & Receivers**
Add the following permissions and local notification receivers to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />

    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>


</manifest>

```

**3. App-Level Build Configuration (`build.gradle.kts`)**
If your project uses the Kotlin DSL (`build.gradle.kts`), enable MultiDex and Core Library Desugaring for the notification plugin to compile and run properly on all Android versions. Add these to `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        // Enable MultiDex
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8

        // Enable Core Library Desugaring
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    // Add the desugaring library
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

```

### iOS Setup

**1. Info.plist Permissions**
Add the following keys to your `ios/Runner/Info.plist` to explain why the app needs access to the camera and photo library:

```xml
<dict>
    <key>NSCameraUsageDescription</key>
    <string>We need camera access to allow you to take and share photos in the chat.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>We need photo library access to allow you to select and upload images or videos.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>We need microphone access to record videos for the chat.</string>
</dict>

```

**2. Podfile Configuration**
Uncomment the global platform definition at the top of your `ios/Podfile` and set it to iOS 13.0 or higher:

```ruby
platform :ios, '13.0'

```

**3. AppDelegate.swift Configuration**
To display notifications while the app is in the foreground and handle tap events, update `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import flutter_local_notifications // Add this import

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register the local notifications plugin
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }

    // Show notifications when the app is in the foreground
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

```

**4. Enable Xcode Capabilities**
Open `ios/Runner.xcworkspace` in Xcode.

- Go to **Signing & Capabilities**.
- Click **+ Capability** and add **Push Notifications**.
- Click **+ Capability** and add **Background Modes**. Check **Remote notifications**.

---

## 🚀 Usage Guide

### 1. Initialization

Initialize the chat widget configurations early in your app lifecycle or right before navigating to the chat screen. You can customize the UI colors and titles here.

```dart
import 'package:quick_chat_wms/quick_chat_wms.dart';

void setupChat(BuildContext context) {
  QuickChatWms.init(
    context,
    widgetCode: 'YOUR_WIDGET_CODE_HERE', // Required
    appBarTitle: 'Support Chat',
    appBarBackgroundColor: Colors.blueAccent,
    appBarTitleColor: Colors.white,
    appBarBackButtonColor: Colors.white,
    backgroundColor: Colors.white,
  );
}

```

### 2. Setting User Data

Pass the current user's details and FCM token to the package so it can sync with your backend.

```dart
// Set user details after successful login
QuickChatWms.setUserName('John Doe');
QuickChatWms.setEmail('johndoe@example.com');
QuickChatWms.setFcmToken('your_firebase_messaging_token');

```

### 3. Displaying the Chat Screen

Whenever you want to display the chat UI, simply navigate to the screen provided by the package:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => QuickChatWms.screen, // Returns the QuickChatWidget
  ),
);

```

### 4. Handling Notifications

The package includes built-in methods to handle local notifications for incoming chat messages.

**Initialize Notifications:**
Call this in your `main.dart` or initialization flow.

```dart
QuickChatWms.initializeNotification(context);

```

**Show a Notification:**
When you receive a silent push notification or a web socket event containing a new message, pass it to the package:

```dart
// Assuming 'data' is a Map<String, dynamic> from your push payload
if (QuickChatWms.isQuickChatNotification(data)) {
  QuickChatWms.showQuickChatNotification({
    'title': 'New Message',
    'body': 'Hello, how can we help you today?',
  });
}

```

### 5. Logging Out / Resetting

If the user logs out of your app, make sure to reset the chat data to clear secure storage and clear the backend tokens.

```dart
await QuickChatWms.resetUser();

```

---

## 🏗 Dependencies Used

This package relies on the following major Flutter plugins under the hood:

- `webview_flutter` & `webview_flutter_android`
- `flutter_secure_storage`
- `flutter_local_notifications`
- `permission_handler`
- `image_picker` & `file_picker`
- `connectivity_plus`
- `url_launcher`
- `freezed` & `json_serializable`

---

Would you like me to review any other parts of the package architecture or help set up any tests for these services?
