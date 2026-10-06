# Order Booker App - Build Instructions

## Quick Start (GitHub Actions - Recommended)

This is the easiest way to get the APK without installing anything.

### Steps:

1. **Create a GitHub repository**
   - Go to github.com and create a new public repository (e.g., `order-booker-app`)

2. **Upload the source code**
   - Upload all files from this folder to the repository
   - Make sure `.github/workflows/build-apk.yml` is included

3. **Trigger the build**
   - Go to the "Actions" tab in your repository
   - Click "Build APK" workflow
   - Click "Run workflow" (or push to main branch)

4. **Download the APK**
   - After the workflow completes (5-10 minutes), go to the workflow run
   - Download the `order-booker-apk` artifact
   - Install the APK on your Android phone

## Manual Build (Advanced)

If you want to build locally:

### Requirements:
- Flutter SDK 3.47.6 (stable)
- Android SDK with Platform 35, Build Tools 35.0.0
- JDK 17

### Steps:
```bash
# 1. Get dependencies
flutter pub get

# 2. Verify no issues
flutter analyze

# 3. Build release APK
flutter build apk --release

# 4. APK location
# build/app/outputs/flutter-apk/app-release.apk
```

## App Features

- **Shops & Routes**: Manage retailers by route and weekday
- **Orders**: Book orders with products, rates, quantities
- **Udhaar Ledger**: Track credit and payments per shop
- **Reminders**: Due-date reminders with WhatsApp/SMS
- **Dashboard**: Daily activity, outstanding dues, today's route
- **Urdu/English**: User-selectable language
- **Export**: CSV export organized by Route/Date/Shop
- **Backup**: Full database backup and restore
- **Stock**: Van stock load/return tracking

## Brands (Pre-configured)

- Al Saudia Sarf
- Smart Care Baby Diaper

You can add more brands and products in the app.

## Support

For issues, check:
- `flutter doctor` - verifies your setup
- GitHub Actions logs - shows build errors
