# Deployment Guide for MovieHub Flutter App

## Platform Deployment Configuration

### Android Deployment

#### 1. App Signing Configuration

Create or obtain a keystore file:
```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

#### 2. Android Build Configuration (android/app/build.gradle)

```gradle
android {
    compileSdkVersion 33
    
    defaultConfig {
        applicationId "com.moviehub.app"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.0"
    }
    
    signingConfigs {
        release {
            keyAlias = 'key'
            keyPassword = 'your_key_password'
            storeFile = file('/path/to/key.jks')
            storePassword = 'your_store_password'
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### 3. Firebase Configuration (android/app/google-services.json)

Download from Firebase Console and place in `android/app/`

#### 4. Build Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk
```

#### 5. Build App Bundle (Google Play)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS Deployment

#### 1. Code Signing Setup

```bash
# List available signing identities
security find-identity -v -p codesigning

# Export provisioning profile from Developer Account
# Place in ~/Library/MobileDevice/Provisioning\ Profiles/
```

#### 2. Xcode Configuration

Open `ios/Runner.xcworkspace` in Xcode:
- Select Runner project
- General tab:
  - Bundle Identifier: com.moviehub.app
  - Version: 1.0.0
  - Build: 1
- Signing & Capabilities:
  - Team: Select your Apple Developer account
  - Signing Certificate: Automatic

#### 3. Firebase Configuration (GoogleService-Info.plist)

Download from Firebase Console and add to Xcode:
1. Download GoogleService-Info.plist
2. Open Xcode
3. Drag and drop the file into Runner folder
4. Check "Copy items if needed"

#### 4. Build Release

```bash
flutter build ios --release

# Or for App Store
flutter build ipa --release
# Output: build/ios/ipa/Runner.ipa
```

### Google Play Store Submission

#### 1. Create App on Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app
3. Fill in app information

#### 2. Configure App Signing

1. Create signed APK/AAB
2. Upload to Google Play Console
3. Configure store listing:
   - Title: MovieHub
   - Short description
   - Full description
   - App icon, screenshots, feature graphics
   - Category: Entertainment
   - Content rating: Self-rate content
   - Privacy policy URL

#### 3. Create Release

1. Go to "App releases" → "Production"
2. Create new release
3. Upload APK/AAB
4. Fill in release notes
5. Submit for review

### Apple App Store Submission

#### 1. Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Create new app
3. Fill in app information

#### 2. Build and Archive

```bash
flutter build ios --release

# In Xcode:
# 1. Select "Runner" scheme
# 2. Select "Generic iOS Device"
# 3. Product → Archive
# 4. Validate and upload to App Store

# Or via CLI:
xcrun altool --upload-app --type ios --file build/ios/ipa/Runner.ipa \
    --apiKey /path/to/api_key.json
```

#### 3. Submit for Review

1. Go to App Store Connect
2. Select build from TestFlight
3. Fill in submission information:
   - Screenshots for all device sizes
   - App preview video (optional)
   - Keywords
   - Support URL
   - Privacy Policy URL
4. Submit for review

### Firebase Setup for Production

#### Configuration per Platform

**Android (android/app/google-services.json)**
```json
{
  "project_info": {
    "project_number": "YOUR_PROJECT_NUMBER",
    "firebase_url": "YOUR_FIREBASE_URL",
    "project_id": "YOUR_PROJECT_ID",
    "storage_bucket": "YOUR_STORAGE_BUCKET"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID",
        "android_client_info": {
          "package_name": "com.moviehub.app"
        }
      },
      "oauth_client": [],
      "api_key": []
    }
  ]
}
```

**iOS (ios/Runner/GoogleService-Info.plist)**
- Add via Xcode as described above

### Environment Variables Setup

Create `.env` file in project root:
```
MOVIE_API_KEY=your_tmdb_api_key
FIREBASE_API_KEY=your_firebase_api_key
GOOGLE_MOBILE_ADS_APP_ID=your_google_mobile_ads_app_id
GOOGLE_MOBILE_ADS_BANNER_AD_UNIT_ID=your_banner_ad_unit_id
GOOGLE_MOBILE_ADS_INTERSTITIAL_AD_UNIT_ID=your_interstitial_ad_unit_id
```

### Production Checklist

- [ ] Firebase project created and configured
- [ ] TMDB API key obtained
- [ ] Google Mobile Ads configured
- [ ] Android signing key generated
- [ ] iOS provisioning profiles created
- [ ] App icons designed (all sizes)
- [ ] Screenshots prepared (all devices)
- [ ] Privacy policy written
- [ ] Terms of service written
- [ ] App description optimized for SEO
- [ ] All links tested (privacy policy, support)
- [ ] Firebase Analytics verified
- [ ] Crashlytics configured
- [ ] Ad network configured
- [ ] Test builds on physical devices
- [ ] Performance tested on low-end devices

### Post-Launch Monitoring

1. **Firebase Console**
   - Monitor crash reports
   - Track analytics
   - Monitor performance

2. **Google Play Console / App Store Connect**
   - Monitor ratings and reviews
   - Track installation metrics
   - Monitor user feedback

3. **Set up alerts**
   - Crash rate threshold
   - Performance metrics
   - User feedback keywords

### Update Procedure

1. Update version in `pubspec.yaml`
2. Build new release
3. Upload to respective app stores
4. Monitor launch metrics
5. Respond to user feedback

### Common Issues and Solutions

**Issue: Build fails on iOS**
- Solution: Run `flutter clean` and `pod install`

**Issue: Android signing fails**
- Solution: Verify keystore path and passwords in gradle file

**Issue: Firebase not initializing**
- Solution: Ensure google-services.json is in correct location

**Issue: Ads not showing**
- Solution: Verify ad unit IDs in code and Firebase console