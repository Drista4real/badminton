# 📋 HƯỚNG DẪN SETUP DỰ ÁN (Badminton Management System)

Hướng dẫn này dành cho những người muốn chạy dự án Badminton sau khi pull code từ repository.

---

## 🔧 ĐIỀU KIỆN TIÊN QUYẾT (Prerequisites)

### 1. **Flutter (cho Frontend)**
- Cài đặt Flutter SDK: https://flutter.dev/docs/get-started/install
- Phiên bản yêu cầu: **Dart 3.11.0 trở lên**
- Kiểm tra:
  ```bash
  flutter --version
  dart --version
  ```

### 2. **.NET 8 SDK (cho Backend)**
- Cài đặt .NET 8 SDK: https://dotnet.microsoft.com/download/dotnet/8.0
- Kiểm tra:
  ```bash
  dotnet --version
  ```

### 3. **Firebase Project**
- Tạo Firebase project trên: https://console.firebase.google.com
- Kích hoạt các dịch vụ:
  - ✅ Firebase Authentication (Email/Password + Phone OTP)
  - ✅ Firestore Database
- Tải file `google-services.json` từ Firebase Console

---

## 📦 PHẦN 1: SETUP FRONTEND (Flutter)

### Bước 1: Lấy file cấu hình Firebase
1. Vào **Firebase Console** → Project của bạn
2. Chọn **Cài đặt dự án** (Project Settings)
3. Tải **`google-services.json`** từ ứng dụng Android
4. Copy vào: `badminton_app_and_web/android/app/google-services.json`

> **Lưu ý**: Frontend sẽ tự động load Firebase config qua `lib/firebase_options.dart` (đã được `flutterfire configure` khởi tạo)

### Bước 2: Cài đặt dependencies
```bash
cd badminton_app_and_web
flutter pub get
```

### Bước 3: Kiểm tra Flutter Setup
```bash
flutter doctor
```
Đảm bảo:
- ✅ Flutter SDK
- ✅ Android Toolchain / Xcode (tùy nền tảng)
- ✅ Connected device (hoặc emulator/simulator)

### Bước 4: Chạy ứng dụng
**Chạy trên Android Emulator:**
```bash
flutter run -d emulator-5554
```

**Chạy trên Web:**
```bash
flutter run -d chrome
```

**Chạy trên iOS (macOS only):**
```bash
flutter run -d ios
```

---

## 🖥️ PHẦN 2: SETUP BACKEND (.NET C#)

### Bước 1: Lấy Firebase Service Account Key
1. Vào **Firebase Console** → **Project Settings**
2. Chọn tab **Service Accounts**
3. Click **Generate New Private Key**
4. Lưu file `.json` vào máy (ví dụ: `C:\Firebase\firebase-key.json`)

### Bước 2: Cấu hình `appsettings.json`

**File**: `backend_caulong\appsettings.json`

Cập nhật các giá trị sau:

```json
{
  "Firebase": {
    "ProjectId": "YOUR_FIREBASE_PROJECT_ID",
    "CredentialsPath": "C:\\Firebase\\firebase-key.json"
  },
  "VietQr": {
    "ClientId": "YOUR_VIETQR_CLIENT_ID",
    "ApiKey": "YOUR_VIETQR_API_KEY",
    "BankBin": "YOUR_BANK_BIN",
    "AccountNo": "YOUR_ACCOUNT_NUMBER",
    "AccountName": "YOUR_ACCOUNT_NAME"
  },
  "SePay": {
    "ApiToken": "YOUR_SEPAY_API_TOKEN",
    "TransactionsEndpoint": "https://userapi.sepay.vn/v2/transactions",
    "WebhookSecret": "YOUR_SEPAY_WEBHOOK_SECRET",
    "AccountNumber": "YOUR_SEPAY_ACCOUNT_NUMBER"
  },
  "Webhook": {
    "Secret": "YOUR_WEBHOOK_SECRET"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

**Giải thích các tham số:**

| Tham số | Mô tả | Ví dụ |
|--------|-------|-------|
| `Firebase:ProjectId` | ID dự án Firebase | `badminton-project-123` |
| `Firebase:CredentialsPath` | Đường dẫn file key Firebase | `C:\Firebase\firebase-key.json` |
| `VietQr:ClientId` | Client ID từ VietQR | Lấy từ VietQR Dashboard |
| `VietQr:ApiKey` | API Key VietQR | Lấy từ VietQR Dashboard |
| `VietQr:BankBin` | Mã ngân hàng | `970405` (VietcomBank) |
| `VietQr:AccountNo` | Số tài khoản | `123456789` |
| `VietQr:AccountName` | Tên chủ tài khoản | `Badminton Court` |
| `SePay:ApiToken` | Token API SePay | Lấy từ SePay Dashboard |
| `SePay:WebhookSecret` | Secret để xác minh webhook | Tự tạo hoặc từ SePay |
| `Webhook:Secret` | Secret webhook chung | Tự tạo |

### Bước 3: Cài đặt NuGet Dependencies
```bash
cd backend_caulong
dotnet restore
```

### Bước 4: Chạy Backend
```bash
dotnet run
```

Backend sẽ chạy tại: **http://localhost:5011** (hoặc port khác nếu config)

**Kiểm tra API Documentation (Swagger):**
- Mở: http://localhost:5011/swagger

---

## 🔐 PHẦN 3: CẤU HÌNH FIRESTORE RULES (Firestore Security)

### Bước 1: Thiết lập Firestore Rules
Vào **Firebase Console** → **Firestore Database** → **Rules**

**Rules cho Development (Test Mode)** - ⚠️ Chỉ dùng để phát triển:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Rules cho Production** - 🔒 Bảo mật cao:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, update: if request.auth.uid == userId;
      allow create: if request.auth.uid == userId;
    }

    // Bookings (chỉ user mình tạo hoặc backend có quyền)
    match /bookings/{bookingId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow write: if request.auth.uid == resource.data.userId || request.auth.token.admin == true;
    }

    // Courts (công khai để đọc)
    match /courts/{courtId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }

    // Orders (chỉ backend)
    match /orders/{orderId} {
      allow read, write: if request.auth.token.admin == true;
    }
  }
}
```

---

## 🌍 PHẦN 4: CẤU HÌNH ĐIỂM CUỐI API (API Endpoints)

### Frontend phải biết endpoint Backend
Tệp: `badminton_app_and_web/lib/constants/app_constants.dart`

Cập nhật:
```dart
class ApiConstants {
  static const String baseUrl = 'http://localhost:5011'; // Web/iOS simulator/desktop
  // Android emulator dùng: http://10.0.2.2:5011
  // hoặc
  static const String baseUrl = 'https://your-api-domain.com'; // Production
}
```

---

## 📲 PHẦN 5: CẤU HÌNH ANDROID SHA-1 & SHA-256

**Lấy SHA-1 & SHA-256 của máy tính:**

```bash
# Windows
cd badminton_app_and_web/android
./gradlew signingReport
```

**Output ví dụ:**
```
SHA1: 1A:2B:3C:4D:5E:6F:7G:8H:9I:0J:1K:2L:3M:4N:5O:6P:7Q:8R:9S:0T
SHA256: 1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T1U2V3W4X5Y6Z7A8B9C0D1E2F3G
```

Thêm vào **Firebase Console** → **Project Settings** → **Android** → **SHA certificate fingerprints**

---

## ✅ HƯỚNG DẪN KIỂM TRA (Testing Checklist)

### Frontend:
- [ ] `flutter pub get` thành công
- [ ] `flutter doctor` không có lỗi
- [ ] Ứng dụng chạy mà không crash
- [ ] Đăng nhập Firebase hoạt động
- [ ] Có thể xem danh sách sân từ Firestore

### Backend:
- [ ] `dotnet restore` thành công
- [ ] `dotnet run` chạy mà không lỗi
- [ ] Swagger UI có sẵn tại `http://localhost:5011/swagger`
- [ ] Có thể gọi API từ Frontend

### Firestore:
- [ ] Database có dữ liệu mẫu (collections: `users`, `courts`, `bookings`)
- [ ] Rules được thiết lập đúng

---

## 🚀 CHỈ DẪN CHẠY FULL STACK

**Terminal 1 (Backend):**
```bash
cd backend_caulong
dotnet run
```

**Terminal 2 (Frontend - Web):**
```bash
cd badminton_app_and_web
flutter run -d chrome
```

**Terminal 3 (Frontend - Android/iOS):**
```bash
cd badminton_app_and_web
flutter run
```

---

## 🔗 TÍCH HỢP THANH TOÁN (VietQR + SePay)

### VietQR Setup:
1. Đăng ký tài khoản: https://vietqr.io
2. Lấy `ClientId` và `ApiKey`
3. Cập nhật vào `appsettings.json`

### SePay Setup:
1. Đăng ký: https://sepay.vn
2. Lấy `ApiToken` và `WebhookSecret`
3. Cập nhật vào `appsettings.json`
4. Config webhook URL: `https://your-backend-domain/api/webhook/sepay`

---

## ⚠️ CẤP CHỨNG CHỉ SSL (HTTPS - Production)

**Tạo chứng chỉ tự ký (Development):**
```bash
dotnet dev-certs https --trust
```

**Production:** Sử dụng Let's Encrypt hoặc chứng chỉ từ nhà cung cấp.

---

## 📞 TROUBLESHOOTING

### Flutter
| Lỗi | Giải pháp |
|-----|----------|
| `Gradle build failed` | `flutter clean` → `flutter pub get` |
| `Android emulator not found` | Tạo AVD mới: `flutter emulators --create --name test` |
| `Firebase connection failed` | Kiểm tra `google-services.json` trong `android/app/` |

### Backend (.NET)
| Lỗi | Giải pháp |
|-----|----------|
| `Firebase credentials not found` | Kiểm tra đường dẫn trong `appsettings.json` |
| `Port already in use` | Đổi port: `dotnet run --urls http://localhost:5001` |
| `CORS error` | Kiểm tra `appsettings.json` - `AllowedHosts` phải là `*` |

---

## 📚 TÀI LIỆU THAM KHẢO

- **Flutter Docs**: https://flutter.dev/docs
- **Firebase**: https://firebase.google.com/docs
- **.NET 8**: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-8
- **VietQR**: https://vietqr.io/docs
- **SePay**: https://sepay.vn/docs

---

**Ghi chú**: Nếu gặp vấn đề, hãy kiểm tra logs chi tiết hoặc liên hệ với team!
