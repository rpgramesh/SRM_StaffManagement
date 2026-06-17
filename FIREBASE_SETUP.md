# Firebase Setup for Restaurant App

## Prerequisites

- Flutter SDK installed
- Firebase account
- Google Cloud Platform account (created automatically with Firebase)

## Setup Steps

### 1. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter a project name (e.g., "Restaurant App")
4. Follow the setup wizard to create your project

### 2. Register Your App with Firebase

#### For Android:

1. In the Firebase console, click on your project
2. Click the Android icon to add an Android app
3. Enter your app's package name (found in `android/app/build.gradle` under `applicationId`)
4. Enter a nickname for your app (optional)
5. Enter your app's SHA-1 signing certificate (required for Google Sign-In)
   - You can get this by running `cd android && ./gradlew signingReport` in your project directory
6. Click "Register app"
7. Download the `google-services.json` file
8. Place the file in the `android/app` directory of your Flutter project

#### For iOS:

1. In the Firebase console, click on your project
2. Click the iOS icon to add an iOS app
3. Enter your app's bundle ID (found in Xcode under the General tab of your project settings)
4. Enter a nickname for your app (optional)
5. Enter your App Store ID (optional)
6. Click "Register app"
7. Download the `GoogleService-Info.plist` file
8. Place the file in the `ios/Runner` directory of your Flutter project
   - You can add this file using Xcode: Right-click on the Runner directory and select "Add Files to 'Runner'"

### 3. Configure FlutterFire

1. Install the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Run the FlutterFire configure command in your project directory:
   ```bash
   flutterfire configure --project=your-firebase-project-id
   ```
   - This will generate the `firebase_options.dart` file in your `lib` directory
   - It will also update your platform-specific files with the necessary Firebase configurations

### 4. Configure Google Sign-In

#### For Android:

1. In the Firebase console, go to Authentication > Sign-in method
2. Enable Google as a sign-in provider
3. Make sure your SHA-1 certificate is added to your Firebase project

#### For iOS:

1. In the Firebase console, go to Authentication > Sign-in method
2. Enable Google as a sign-in provider
3. In Xcode, update your `Info.plist` file with the following:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
         <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
       </array>
     </dict>
   </array>
   ```

### 5. Update Your Code

Update your `main.dart` file to use the generated Firebase options:

```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### 6. Test Your Integration

1. Run your app
2. Try signing in with Google
3. Check the Firebase console to verify that users are being created

## Troubleshooting

### Common Issues:

1. **SHA-1 Certificate Issues**: Make sure you've added the correct SHA-1 certificate to your Firebase project. For debug builds, you need the debug certificate. For release builds, you need the release certificate.

2. **Google Sign-In Not Working**: Ensure that you've enabled Google as a sign-in provider in the Firebase Authentication console.

3. **Firebase Initialization Errors**: Check that your `firebase_options.dart` file is correctly generated and that you're using it when initializing Firebase.

4. **Platform-Specific Issues**:
   - Android: Make sure `google-services.json` is in the correct location
   - iOS: Make sure `GoogleService-Info.plist` is added to your Xcode project correctly

## Additional Resources

- [FlutterFire Documentation](https://firebase.flutter.dev/docs/overview)
- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)