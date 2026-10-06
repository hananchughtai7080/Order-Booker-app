# Order Booker — آرڈر بکر

Offline Android app for order bookers / distributors (Dera Ghazi Khan).
Brands: Al Saudia Sarf, Smart Care Baby Diaper (aur koi bhi brand add ho sakta hai).

## Features

- **Shops** — dukandaar ki list, route-wise, search ke sath
- **Order booking** — shop select karo, products + qty + rate, auto total, stock auto-update
- **Payments / Ledger** — udhaar tracking, har shop ka balance, full khata
- **Reminders** — due-date reminders, **WhatsApp / SMS** par shop owner ko reminder bhejo
- **Routes** — hafte ke hisaab se route plan (Monday..Sunday), dashboard par "aaj ka route" + next shop
- **Products** — rate/quantity manage, van stock load/return
- **Dashboard** — aaj ki sale, recovery, total udhaar, pending reminders, daily target progress
- **Reports** — phone storage me folders: `OrderBooker / <Route> / <Date> / <Shop>` (CSV files)
- **Backup / Restore** — poora record backup karke share karo
- **Language** — English + اردو, user khud select kare

## APK kaise banayein (GitHub Actions — free)

Mere paas yahan Android SDK nahi hai, is liye APK GitHub par free me banega:

1. GitHub par naya repository banao (naam: `order-booker-app`).
2. Is folder ki **saari files** upload kar do (drag-drop ya git push).
   - `.github/workflows/build-apk.yml` zaroor include ho.
3. GitHub repo me **Actions** tab kholo → `Build APK` workflow chalega (push par auto).
4. Workflow complete hone par **Artifacts** me `order-booker-apk` download karo.
5. APK ko apne Android phone par install karo (unknown sources allow karna parega).

Har nayi push par naya APK auto ban jayega.

## Pehli dafa app kholne par

1. Settings → Language select karo (English / اردو).
2. Routes banao (jaise "City Route — Monday").
3. Shops add karo aur unhe route assign karo.
4. Products add karo (Al Saudia Sarf / Smart Care) with rates.
5. Bas! Dashboard se New Order book karo.

## Tech

Flutter 3.47, sqflite (offline database — koi internet nahi chahiye),
provider, url_launcher (WhatsApp/SMS), flutter_local_notifications,
share_plus, csv, file_picker.
