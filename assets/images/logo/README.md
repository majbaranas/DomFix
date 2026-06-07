# 📋 DomFix Logo File - Placement Instructions

## 🎯 Action Required

**Place the DomFix logo image file at this exact location:**

```
assets/images/logo/domfix_logo.png
```

---

## 📁 Full Path

```
D:\FlutterProjects\DomFix\assets\images\logo\domfix_logo.png
```

---

## ✅ Logo Specifications

### Required Format:
- **File Type:** PNG
- **Transparency:** Yes (recommended)
- **Background:** Dark #101419 (as shown in provided image)
- **Logo Design:** Neon yellow/green "D" with house symbol

### Recommended Size:
- **Minimum:** 512x512 pixels
- **Optimal:** 1024x1024 pixels
- **Maximum:** 2048x2048 pixels

### Why these sizes?
- Sharp on high-DPI displays (Retina, 4K)
- Suitable for app icons
- Good for all screen densities
- Flutter will auto-scale as needed

---

## 🖼️ Logo Design Reference

Based on the provided image, your logo features:

```
┌─────────────────────┐
│   Dark Background   │
│     (#101419)       │
│                     │
│    [NEON YELLOW]    │
│         "D"         │
│    with house       │
│      symbol         │
│                     │
└─────────────────────┘
```

**Colors:**
- Background: Dark blue-gray (#101419)
- Logo: Neon yellow/lime (#D4FF00 approx)
- Style: Modern, tech, smart home

---

## 🚀 How to Place the Logo

### Option 1: Manual Copy

1. **Save your logo** as `domfix_logo.png`
2. **Copy** the file
3. **Paste** into:
   ```
   D:\FlutterProjects\DomFix\assets\images\logo\
   ```
4. **Verify** the file is there:
   ```bash
   dir assets\images\logo\
   ```

### Option 2: Command Line (Windows)

```powershell
# Navigate to project
cd D:\FlutterProjects\DomFix

# Copy your logo (adjust source path)
copy "C:\Path\To\Your\domfix_logo.png" "assets\images\logo\domfix_logo.png"
```

### Option 3: Drag and Drop

1. Open File Explorer
2. Navigate to: `D:\FlutterProjects\DomFix\assets\images\logo\`
3. Drag your `domfix_logo.png` file into this folder

---

## ✅ Verification

After placing the file, verify it's correct:

### Check File Exists:
```bash
cd D:\FlutterProjects\DomFix
dir assets\images\logo\domfix_logo.png
```

**Expected output:**
```
domfix_logo.png
```

### Check File Size:
- **Should be:** > 50 KB (if high quality)
- **If too small:** Image quality may be low

---

## 🧪 Test the Integration

1. **Run Flutter:**
   ```bash
   flutter pub get
   flutter run
   ```

2. **Check Splash Screen:**
   - Logo appears centered
   - Smooth pulse animation
   - Neon glow effect
   - No errors in console

3. **Check Login Screen:**
   - Logo at top
   - Clean presentation
   - Proper size

4. **Check Register Screen:**
   - Logo visible
   - Consistent with login

---

## ❗ Common Issues

### Issue: "Unable to load asset"
**Solution:** 
- Verify file path is exactly: `assets/images/logo/domfix_logo.png`
- Check filename is lowercase
- Run `flutter pub get`

### Issue: "Image appears pixelated"
**Solution:**
- Use higher resolution image (1024x1024+)
- Ensure PNG format (not JPEG)

### Issue: "Image has wrong colors"
**Solution:**
- Verify logo has dark background
- Check if transparency is causing issues
- Ensure RGB color space (not CMYK)

---

## 🎨 Logo Export Tips

If you need to export/create the logo:

### From Design Tools (Figma, Adobe XD, etc.):

1. **Export Settings:**
   - Format: PNG
   - Size: 2x or 3x (1024px or 1536px)
   - Background: Include dark background
   - Quality: Maximum

2. **Color Profile:**
   - RGB color space
   - sRGB color profile

3. **Compression:**
   - Light compression OK
   - Preserve quality for brand asset

---

## 🔄 After Placing Logo

1. ✅ Place `domfix_logo.png` in correct folder
2. ✅ Run `flutter pub get`
3. ✅ Run `flutter clean` (if needed)
4. ✅ Run `flutter run`
5. ✅ Test all screens
6. ✅ Generate app icons (optional)

---

## 📱 Next Step: App Icons

Once logo is working in-app, generate launcher icons:

```bash
# Add to pubspec.yaml dev_dependencies:
flutter_launcher_icons: ^0.14.0

# Then run:
flutter pub get
flutter pub run flutter_launcher_icons
```

---

## ✅ Quick Checklist

- [ ] Logo file saved as `domfix_logo.png`
- [ ] Logo is PNG format
- [ ] Logo is 512x512 or larger
- [ ] Logo has dark background
- [ ] Logo copied to `assets/images/logo/`
- [ ] File path verified
- [ ] `flutter pub get` executed
- [ ] App tested and logo appears
- [ ] All three screens checked (splash, login, register)

---

## 🆘 Need Help?

If logo still doesn't appear:

1. Check Flutter console for errors
2. Verify `pubspec.yaml` includes asset path
3. Try `flutter clean && flutter pub get`
4. Restart IDE
5. Check file permissions

---

## 🎯 Expected Result

After placing the logo, you should see:

✅ **Splash Screen:**
- Large logo (140x140)
- Smooth pulse animation
- Neon glow

✅ **Login Screen:**
- Logo at top (70-80px)
- Clean, professional

✅ **Register Screen:**
- Logo at top (70px)
- Consistent branding

---

**All code is ready - just add the logo file and test!** 🚀
