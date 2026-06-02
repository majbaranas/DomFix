# 🎨 DomFix Design System - Developer Quick Reference

## 🚀 Quick Start

```dart
import '../theme/app_colors.dart';
```

---

## 🎨 COLORS

### Primary Colors
```dart
AppColors.neonAccent          // #D9FF00 - Primary CTA, highlights
AppColors.background          // #0F1115 - Screen background
AppColors.surface             // #181A20 - Cards, containers
AppColors.onSurface           // #F5F5F7 - Primary text
AppColors.onSurfaceVariant    // #8E8E93 - Secondary text
```

### Semantic Colors
```dart
AppColors.success             // #34C759 - Success states
AppColors.error               // #FF3B30 - Error states
AppColors.divider             // White 6% - Borders, dividers
```

### Usage Examples
```dart
// Background
Container(color: AppColors.background)

// Card
Container(
  color: AppColors.surface,
  decoration: BoxDecoration(
    border: Border.all(color: AppColors.divider),
  ),
)

// Text
Text('Title', style: TextStyle(color: AppColors.onSurface))
Text('Subtitle', style: TextStyle(color: AppColors.onSurfaceVariant))
```

---

## 📏 SPACING (8px Grid)

```dart
AppColors.space4   // 4px  - Tight spacing
AppColors.space8   // 8px  - Minimal gap
AppColors.space12  // 12px - Small gap
AppColors.space16  // 16px - Standard gap
AppColors.space20  // 20px - Medium gap
AppColors.space24  // 24px - Large gap
AppColors.space32  // 32px - Section gap
AppColors.space40  // 40px - Major section
AppColors.space48  // 48px - Hero spacing
```

### Usage
```dart
// Padding
Padding(padding: EdgeInsets.all(AppColors.space16))

// Gap between elements
SizedBox(height: AppColors.space12)

// Section spacing
SizedBox(height: AppColors.space32)
```

---

## 🔘 BORDER RADIUS

```dart
AppColors.radiusSmall   // 8px  - Chips, badges
AppColors.radiusMedium  // 12px - Cards, buttons
AppColors.radiusLarge   // 16px - Modals, sheets
AppColors.radiusXL      // 24px - Hero elements
AppColors.radiusFull    // 999px - Circular
```

### Usage
```dart
// Card
BorderRadius.circular(AppColors.radiusMedium)

// Button
BorderRadius.circular(AppColors.radiusMedium)

// Avatar
BorderRadius.circular(AppColors.radiusFull)
```

---

## 🎭 SHADOWS

```dart
AppColors.shadowSm  // Subtle depth
AppColors.shadowMd  // Medium elevation
AppColors.shadowLg  // High elevation
```

### Usage
```dart
// Subtle shadow
Container(
  decoration: BoxDecoration(
    boxShadow: AppColors.shadowSm,
  ),
)

// Primary CTA glow
Container(
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: AppColors.neonAccent.withValues(alpha: 0.25),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
  ),
)
```

---

## 🔘 BUTTON STYLES

### Primary Button
```dart
Container(
  padding: EdgeInsets.symmetric(vertical: 16),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.neonAccent,
        AppColors.neonAccent.withValues(alpha: 0.85),
      ],
    ),
    borderRadius: BorderRadius.circular(AppColors.radiusMedium),
    boxShadow: [
      BoxShadow(
        color: AppColors.neonAccent.withValues(alpha: 0.25),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
  ),
  child: Text('Book Now', 
    style: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.onPrimary,
    ),
  ),
)
```

### Secondary Button
```dart
Container(
  padding: EdgeInsets.symmetric(vertical: 16),
  decoration: AppColors.secondaryButton,
  child: Text('Message',
    style: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.onSurface,
    ),
  ),
)
```

### Ghost Button
```dart
Container(
  padding: EdgeInsets.symmetric(vertical: 16),
  decoration: AppColors.ghostButton,
  child: Text('Cancel',
    style: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.neonAccent,
    ),
  ),
)
```

---

## 📝 TYPOGRAPHY

### Headings (Space Grotesk)
```dart
// Hero (32px)
GoogleFonts.spaceGrotesk(
  fontSize: 32,
  fontWeight: FontWeight.w700,
  color: AppColors.onSurface,
  letterSpacing: -0.8,
)

// Section Title (22px)
GoogleFonts.spaceGrotesk(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: AppColors.onSurface,
)

// Card Title (18px)
GoogleFonts.spaceGrotesk(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: AppColors.onSurface,
)
```

### Body Text (Inter)
```dart
// Body Large (15px)
GoogleFonts.inter(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: AppColors.onSurface,
)

// Body Medium (14px)
GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: AppColors.onSurface,
)

// Body Small (13px)
GoogleFonts.inter(
  fontSize: 13,
  color: AppColors.onSurfaceVariant,
)

// Caption (11px)
GoogleFonts.inter(
  fontSize: 11,
  color: AppColors.onSurfaceVariant,
)
```

---

## 🎴 CARD COMPONENT

```dart
Container(
  padding: EdgeInsets.all(AppColors.space16),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppColors.radiusMedium),
    border: Border.all(color: AppColors.divider),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Card content
    ],
  ),
)
```

---

## 💬 MESSAGE BUBBLE

```dart
// Sent message
Container(
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: AppColors.neonAccent.withValues(alpha: 0.15),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
      bottomRight: Radius.circular(4),
    ),
    border: Border.all(
      color: AppColors.neonAccent.withValues(alpha: 0.25),
    ),
  ),
  child: Text(message),
)

// Received message
Container(
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(18),
    ),
    border: Border.all(color: AppColors.divider),
  ),
  child: Text(message),
)
```

---

## 🏷️ BADGE COMPONENT

```dart
// Urgency badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: urgency == 'Emergency' 
      ? AppColors.error.withValues(alpha: 0.15)
      : AppColors.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    urgency,
    style: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: urgency == 'Emergency' 
        ? AppColors.error 
        : AppColors.onSurfaceVariant,
    ),
  ),
)

// Unread count badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.neonAccent,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    '$count',
    style: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.onPrimary,
    ),
  ),
)
```

---

## 👤 AVATAR COMPONENT

```dart
// Standard avatar (52px)
Container(
  width: 52,
  height: 52,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: AppColors.surface,
  ),
  child: ClipOval(
    child: photoUrl != null
      ? Image.network(photoUrl, fit: BoxFit.cover)
      : Icon(Icons.person, color: AppColors.onSurfaceVariant),
  ),
)

// Avatar with online indicator
Stack(
  children: [
    Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
      ),
      child: ClipOval(child: Image.network(photoUrl)),
    ),
    Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.background,
            width: 2,
          ),
        ),
      ),
    ),
  ],
)
```

---

## 📊 EMPTY STATE

```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.inbox_rounded,
        size: 48,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
      ),
      SizedBox(height: AppColors.space12),
      Text(
        'No items yet',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    ],
  ),
)
```

---

## ⏳ SKELETON LOADER

```dart
class ShimmerBox extends StatefulWidget {
  final Widget child;
  const ShimmerBox({required this.child});
  
  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> 
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: 0.4 + _anim.value * 0.3,
        child: child,
      ),
      child: widget.child,
    );
  }
}

// Usage
ShimmerBox(
  child: Container(
    width: 200,
    height: 100,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
    ),
  ),
)
```

---

## 🎯 COMMON PATTERNS

### Section Header with Action
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      'Section Title',
      style: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    ),
    GestureDetector(
      onTap: onSeeAll,
      child: Row(
        children: [
          Text(
            'See all',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neonAccent,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppColors.neonAccent,
          ),
        ],
      ),
    ),
  ],
)
```

### Info Row with Icon
```dart
Row(
  children: [
    Icon(
      Icons.location_on_outlined,
      size: 16,
      color: AppColors.onSurfaceVariant,
    ),
    SizedBox(width: 4),
    Text(
      '2.3 km',
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVariant,
      ),
    ),
  ],
)
```

---

## ✅ DO's and DON'Ts

### ✅ DO
- Use 8px spacing grid
- Apply consistent border radius
- Use Space Grotesk for headings
- Use Inter for body text
- Add shadows to primary CTAs
- Use neon accent strategically
- Maintain 48px minimum touch targets

### ❌ DON'T
- Use random spacing values
- Mix different radius sizes
- Use system fonts
- Overuse neon accent
- Create flat primary buttons
- Make touch targets < 44px
- Break the visual hierarchy

---

## 🚀 PERFORMANCE TIPS

```dart
// Cache network images
CachedNetworkImage(
  imageUrl: url,
  fit: BoxFit.cover,
  placeholder: (_, __) => ShimmerBox(...),
  errorWidget: (_, __, ___) => Icon(...),
)

// Dispose controllers
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}

// Use const constructors
const SizedBox(height: 16)
const Icon(Icons.star)

// Optimize lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ...,
)
```

---

## 📚 RESOURCES

### Documentation
- `UI_REDESIGN_SUMMARY.md` - Full redesign overview
- `UI_BEFORE_AFTER.md` - Visual comparisons
- `TESTING_CHECKLIST.md` - Testing guide

### Design Files
- Figma: [Link to design file]
- Assets: `assets/images/`

### Dependencies
```yaml
google_fonts: ^latest
cached_network_image: ^latest
```

---

## 🎯 QUICK CHECKLIST

Before committing code:
- [ ] Used AppColors constants
- [ ] Followed 8px spacing grid
- [ ] Applied correct typography
- [ ] Added proper shadows
- [ ] Maintained visual hierarchy
- [ ] Tested on multiple screens
- [ ] No hardcoded colors
- [ ] No magic numbers

---

**Last Updated**: 2024  
**Version**: 1.0  
**Maintainer**: DomFix Team
