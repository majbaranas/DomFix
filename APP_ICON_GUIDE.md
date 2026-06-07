# 📱 DomFix App Icon Generation Guide

## 🎯 Generate Launcher Icons from Logo

Once you've placed `domfix_logo.png`, use it to create app launcher icons.

---

## 🚀 Method 1: Automated (Recommended)

### Step 1: Add Package
Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.0

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo/domfix_logo.png"
  min_sdk_android: 21
  
  # Android Adaptive Icon
  adaptive_icon_background: "#101419"
  adaptive_icon_foreground: "assets/images/logo/domfix_logo.png"
```

### Step 2: Generate Icons
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### Step 3: Verify
Icons generated at:
- **Android:** `android/app/src/main/res/mipmap-*/ic_launcher.png`
- **iOS:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

---

## 🎨 Method 2: Online Tools

### Option A: App Icon Generator
1. Go to: https://www.appicon.co/
2. Upload: `domfix_logo.png`
3. Download: Icon sets for Android & iOS
4. Extract and place in project

### Option B: Android Asset Studio
1. Go to: https://romannurik.github.io/AndroidAssetStudio/
2. Select "Launcher Icons"
3. Upload logo
4. Download assets
5. Replace in `android/app/src/main/res/`

---

## 📐 Required Icon Sizes

### Android (mipmap folders)
```
mipmap-mdpi/      48x48
mipmap-hdpi/      72x72
mipmap-xhdpi/     96x96
mipmap-xxhdpi/    144x144
mipmap-xxxhdpi/   192x192
```

### iOS (AppIcon.appiconset)
```
Icon-20@2x.png    40x40
Icon-20@3x.png    60x60
Icon-29@2x.png    58x58
Icon-29@3x.png    87x87
Icon-40@2x.png    80x80
Icon-40@3x.png    120x120
Icon-60@2x.png    120x120
Icon-60@3x.png    180x180
Icon-76.png       76x76
Icon-76@2x.png    152x152
Icon-83.5@2x.png  167x167
Icon-1024.png     1024x1024
```

---

## 🎯 Adaptive Icons (Android 8.0+)

Your logo works perfectly for adaptive icons:

**Foreground:** Logo (neon D)
**Background:** Dark #101419

Result: Logo centered, background fills safe area.

---

## ✅ Verification

After generating icons:

### Android
```bash
# Check icons exist
dir android\app\src\main\res\mipmap-*\ic_launcher.png
```

### iOS
```bash
# Check AppIcon.appiconset
dir ios\Runner\Assets.xcassets\AppIcon.appiconset\
```

### Build and Test
```bash
flutter clean
flutter pub get
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

---

## 📱 Testing on Device

1. **Install app** on physical device
2. **Check home screen** icon
3. **Verify** logo appears correctly
4. **Test** different device densities

---

## 🎨 Icon Design Tips

### For Best Results:
- ✅ Use high-res logo (1024x1024)
- ✅ Ensure logo is centered
- ✅ Keep important elements in safe zone
- ✅ Test on light and dark backgrounds

### Adaptive Icon Safe Zone:
- Center 66% (circle mask)
- Outer 17% may be cut on some devices

---

## 🔧 Troubleshooting

### Icons not updating?
```bash
flutter clean
flutter pub get
# Uninstall app from device
flutter run
```

### Wrong icon showing?
- Clear device cache
- Restart device
- Rebuild app

### Icons pixelated?
- Use larger source image
- Check mipmap densities generated correctly

---

## 📦 Alternative: Manual Generation

Use image editor (Photoshop, GIMP, etc.):

1. Open `domfix_logo.png`
2. Resize to each required size
3. Export as PNG
4. Place in correct folders
5. Update `AndroidManifest.xml` and `Info.plist` if needed

---

## 🎯 Quick Command

```bash
# One-line icon generation
flutter pub get && flutter pub run flutter_launcher_icons && flutter clean
```

---

## ✅ Checklist

- [ ] Logo file placed
- [ ] flutter_launcher_icons added to pubspec.yaml
- [ ] Icons generated successfully
- [ ] Android icons verified
- [ ] iOS icons verified
- [ ] Tested on physical device
- [ ] App icon looks correct on home screen

---

**Your app will have a professional icon matching your brand!** 🎨
