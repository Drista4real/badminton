# Badminton Management System

Hệ thống quản lý sân cầu lông gồm ứng dụng Flutter cho khách hàng, backend ASP.NET Core xử lý nghiệp vụ/thanh toán, và trang quản trị React/Vite cho chủ sân, nhân viên và kế toán.

## Nội dung repo

```text
.
├── BaoCao/
│   └── BC Quản lý sân cầu lông.pdf
├── badminton_app_and_web/      # Flutter app/web cho khách hàng
├── backend_caulong/            # ASP.NET Core Web API
├── admin-web/                  # React + Vite + Express admin web
├── firestore.rules             # Firestore Security Rules
├── start.bat                   # Chạy nhanh backend + Flutter web trên Windows
└── README.md
```

## Công nghệ sử dụng

- Mobile/Web app: Flutter, Dart, GetX, Firebase Auth, Cloud Firestore, HTTP client, Google Sign-In.
- Backend API: ASP.NET Core Web API, .NET 8 target framework, Firebase Admin SDK, Google Cloud Firestore, Swagger, VietQR, SePay.
- Admin web: React 19, TypeScript, Vite, Tailwind CSS 4, Express, Firebase Admin SDK.
- Database: Firebase Firestore. Dự án không dùng MySQL, SQL Server hoặc SQLite.

Phiên bản đã kiểm tra trên máy phát triển:

- Flutter `3.41.2`
- Dart `3.11.0`
- .NET SDK: project target `net8.0`, `global.json` yêu cầu `8.0.100` và cho phép roll forward; máy hiện tại chạy được với SDK `9.0.314`
- Node.js `24.15.0`
- npm `11.12.1`

## Chuẩn bị môi trường

Cài các công cụ sau trước khi chạy:

- Git
- Flutter SDK 3.41.x hoặc mới hơn tương thích Dart 3.11
- Android Studio hoặc Android Emulator
- .NET SDK 8.0 trở lên
- Node.js 20 LTS trở lên
- Firebase CLI nếu cần triển khai lại Firestore rules, FlutterFire CLI nếu cần cấu hình thêm iOS:

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

Nếu cần nhận webhook từ SePay khi chạy local, cài thêm ngrok.

## Cấu hình Firebase

Project này chạy trên Firebase có sẵn của đồ án: `badminton-d689a`. Người clone repo để chấm/chạy lại **không cần tạo Firebase project mới**. Nhóm đã mời tài khoản `ntduong@st.utc2.edu.vn` vào Firebase project này với vai trò **Owner**.

File cấu hình client hiện có:

- Android: `badminton_app_and_web/android/app/google-services.json`
- Flutter options: `badminton_app_and_web/lib/firebase_options.dart`
- Firestore rules: `firestore.rules`

File `google-services.json` trong repo đã trỏ về project `badminton-d689a`, nên app Android/Flutter web sẽ dùng đúng Firebase của đồ án. Backend và admin-web cần thêm Firebase Admin Service Account để đọc/ghi Firestore bằng quyền server; file này là khóa bí mật nên không commit trực tiếp trong repo. Vì tài khoản `ntduong@st.utc2.edu.vn` đã là Owner, GV có thể tự tải file này tại Firebase Console > Project settings > Service accounts > Generate new private key.

Repo hiện không có `badminton_app_and_web/ios/Runner/GoogleService-Info.plist` vì bản nộp tập trung Android/Web. Nếu cần build iOS, dùng chính Firebase project `badminton-d689a` để tải `GoogleService-Info.plist` từ Firebase Console hoặc chạy:

```powershell
cd badminton_app_and_web
flutterfire configure
```

Firebase project `badminton-d689a` đã được cấu hình với các thành phần tối thiểu sau:

- Authentication: Email/Password, Google Sign-In
- Firestore Database
- Android app package: `com.example.badminton`
- Với Google Sign-In Android: thêm SHA-1/SHA-256 của máy build vào Firebase Console, sau đó tải lại `google-services.json` nếu có thay đổi.

Rules Firestore của đồ án nằm ở `firestore.rules`. GV không cần triển khai lại nếu chỉ clone và chạy kiểm thử. Nếu cần cập nhật rules lên project `badminton-d689a`:

```powershell
firebase deploy --only firestore:rules
```

## Cấu hình backend

Backend đọc cấu hình từ `backend_caulong/appsettings.json`, `appsettings.Development.json`, biến môi trường hoặc .NET user-secrets. Không commit Service Account JSON, API key hoặc secret thật.

Khuyến nghị tạo file local:

```powershell
cd backend_caulong
Copy-Item appsettings.json appsettings.Development.json
```

Điền các giá trị sau trong `appsettings.Development.json`:

```json
{
  "Firebase": {
    "ProjectId": "badminton-d689a",
    "CredentialsPath": "C:\\path\\to\\firebase-service-account.json"
  },
  "VietQr": {
    "ClientId": "YOUR_VIETQR_CLIENT_ID",
    "ApiKey": "YOUR_VIETQR_API_KEY",
    "BankBin": "YOUR_BANK_BIN",
    "AccountNo": "YOUR_BANK_ACCOUNT_NUMBER",
    "AccountName": "YOUR_BANK_ACCOUNT_NAME"
  },
  "Payment": {
    "ReferencePrefix": "BDM",
    "TransferContentPrefix": "SEVQR"
  },
  "SePay": {
    "ApiToken": "YOUR_SEPAY_API_TOKEN",
    "TransactionsEndpoint": "https://userapi.sepay.vn/v2/transactions",
    "WebhookSecret": "YOUR_SEPAY_WEBHOOK_SECRET",
    "WebhookApiKey": "YOUR_OPTIONAL_WEBHOOK_API_KEY",
    "AccountNumber": "YOUR_BANK_ACCOUNT_NUMBER"
  },
  "Webhook": {
    "Secret": "YOUR_GENERAL_WEBHOOK_SECRET"
  }
}
```

Ý nghĩa các giá trị cần điền:

- `Firebase:ProjectId`: giữ nguyên `badminton-d689a` để chạy trên Firebase của đồ án.
- `Firebase:CredentialsPath`: đường dẫn tới file Service Account JSON của project `badminton-d689a`. GV có thể đăng nhập bằng `ntduong@st.utc2.edu.vn` và tải file tại Firebase Console > Project settings > Service accounts > Generate new private key.
- `VietQr:ClientId`, `VietQr:ApiKey`: lấy trong tài khoản VietQR/API.
- `VietQr:BankBin`: mã BIN ngân hàng nhận tiền, ví dụ MB Bank là `970422`, VietinBank là `970415`; dùng đúng mã tài khoản của bạn.
- `VietQr:AccountNo`, `VietQr:AccountName`: số tài khoản và tên chủ tài khoản nhận tiền.
- `Payment:ReferencePrefix`: tiền tố mã thanh toán lưu trong Firestore, mặc định `BDM`.
- `Payment:TransferContentPrefix`: tiền tố nội dung chuyển khoản, mặc định `SEVQR`. Nội dung QR sẽ có dạng `SEVQR BDM<orderId>`.
- `SePay:ApiToken`: token để backend polling danh sách giao dịch SePay khi người dùng bấm kiểm tra thanh toán.
- `SePay:WebhookSecret`: secret để xác thực webhook HMAC nếu SePay cấu hình gửi chữ ký.
- `SePay:WebhookApiKey`: tùy chọn, dùng khi webhook gửi header `Authorization: Apikey <key>`.
- `SePay:AccountNumber`: số tài khoản nhận tiền để backend bỏ qua giao dịch không thuộc tài khoản này.
- `Webhook:Secret`: secret bắt buộc vì backend validate cấu hình lúc khởi động.

Chạy backend:

```powershell
cd backend_caulong
dotnet restore
dotnet run --launch-profile http
```

Backend chạy tại:

- API: `http://localhost:5011`
- Swagger: `http://localhost:5011/swagger`

## Seed dữ liệu mẫu Firestore

Chạy seeder để tạo dữ liệu tối thiểu cho hệ thống:

```powershell
dotnet run --project backend_caulong\Tools\FirestoreSeeder -- `
  --project-id badminton-d689a `
  --credentials C:\path\to\firebase-service-account.json
```

Seeder tạo:

- `courts/court-01` đến `courts/court-10`
- bảng giá theo khung giờ trong field `hourlyPrices`
- Firebase Auth user test:
  - Email: `qa.test@badminton.local`
  - Password: `Test@123456`
- document `users/{uid}` có ví `500000` và điểm thưởng mẫu.

Các collection chính hệ thống dùng:

- `users`: thông tin tài khoản, role, ví, điểm thưởng
- `phoneNumbers`: mapping số điện thoại khi đăng ký
- `courts`: danh sách sân và bảng giá
- `orders`: đơn thanh toán
- `bookings`: lịch đặt sân
- `bookingSlotLocks`: khóa slot chống đặt trùng
- `walletTransactions`: giao dịch ví/hoàn tiền/rút tiền
- `notifications`: thông báo cho khách hàng
- `pricingRules`: bảng giá dùng bởi admin-web

## Chạy Flutter app

Cài package:

```powershell
cd badminton_app_and_web
flutter pub get
```

Chạy trên Android Emulator, backend local:

```powershell
flutter devices
flutter run -d <android-emulator-id>
```

Với Android Emulator, app tự gọi backend qua `http://10.0.2.2:5011`.

Chạy Flutter web:

```powershell
flutter run -d chrome
```

Flutter web tự gọi backend qua `http://localhost:5011`.

Nếu chạy trên thiết bị thật hoặc muốn dùng ngrok, truyền API URL rõ ràng:

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=https://YOUR_NGROK_DOMAIN
```

Nếu build APK:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://YOUR_NGROK_DOMAIN
```

## Chạy ngrok cho webhook/thanh toán

Khi test SePay webhook ở môi trường local, backend phải có URL public. Mở terminal mới:

```powershell
ngrok http 5011
```

Ngrok sẽ in ra URL dạng `https://xxxx.ngrok-free.app`. Cấu hình trên SePay:

- Webhook URL: `https://xxxx.ngrok-free.app/api/webhook/sepay/payment`
- Nếu dùng webhook HMAC: secret trên SePay phải trùng `SePay:WebhookSecret`
- Nếu dùng API key header: gửi `Authorization: Apikey <SePay:WebhookApiKey>`

Luồng thanh toán:

1. App tạo order trong Firestore qua backend.
2. Backend gọi VietQR để tạo QR với nội dung `SEVQR BDM<orderId>`.
3. Khách chuyển khoản đúng số tiền và nội dung.
4. SePay gửi webhook về URL ngrok hoặc app gọi `/api/payment/reconcile` để backend polling SePay.
5. Backend xác nhận order, booking và thông báo trong Firestore.

## Chạy admin-web

Admin web là project riêng trong `admin-web`, chạy tại port `3000`.

```powershell
cd admin-web
npm install
Copy-Item .env.example .env
```

Điền `.env` bằng giá trị thật:

```env
GEMINI_API_KEY="OPTIONAL_IF_ONLY_RUNNING_ADMIN_WEB"
APP_URL="http://localhost:3000"

FIREBASE_PROJECT_ID="badminton-d689a"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@badminton-d689a.iam.gserviceaccount.com"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n"

VIETQR_CLIENT_ID="YOUR_VIETQR_CLIENT_ID"
VIETQR_API_KEY="YOUR_VIETQR_API_KEY"
VIETQR_BANK_BIN="YOUR_BANK_BIN"
VIETQR_ACCOUNT_NO="YOUR_BANK_ACCOUNT_NUMBER"
VIETQR_ACCOUNT_NAME="YOUR_BANK_ACCOUNT_NAME"

SEPAY_API_TOKEN="YOUR_SEPAY_API_TOKEN"
SEPAY_WEBHOOK_SECRET="YOUR_SEPAY_WEBHOOK_SECRET"
```

`GEMINI_API_KEY` và `APP_URL` là biến còn lại từ mẫu AI Studio; luồng quản trị sân, Firebase, VietQR và SePay không phụ thuộc vào Gemini. Nếu chỉ chạy admin-web để chấm chức năng quản lý, có thể giữ `GEMINI_API_KEY` ở giá trị placeholder.

Lưu ý: `admin-web/server.ts` đọc trực tiếp `process.env`. Nếu chạy `npm run dev` hoặc `npm run start` mà biến trong `.env` chưa được nạp, dùng PowerShell để nạp biến trước:

```powershell
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim().Trim('"'), 'Process')
  }
}
npm run dev
```

Nếu đã nạp biến trong terminal từ trước, có thể chạy dev trực tiếp:

```powershell
npm run dev
```

Mở `http://localhost:3000`.

Tài khoản admin-web có sẵn:

| Vai trò | Email | Mật khẩu |
| --- | --- | --- |
| Admin / Chủ sân | `admin@gmail.com` | `Abc@123` |
| Nhân viên 1 | `nhanvien1@gmail.com` | `Abc@123` |
| Nhân viên 2 | `nhanvien2@gmail.com` | `Abc@123` |
| Kế toán | `ketoan@gmail.com` | `Abc@123` |

Build admin-web:

```powershell
npm run build
npm run start
```

Khi chạy `npm run start`, cũng cần nạp các biến Firebase/VietQR/SePay như phần dev.

## Chạy nhanh trên Windows

Sau khi đã cấu hình backend và Firebase:

```powershell
.\start.bat
```

Script này mở:

- Backend ASP.NET Core: `http://localhost:5011`
- Flutter web trên Chrome

Script không tự chạy ngrok và không tự seed dữ liệu.

## Quy trình clone và chạy lại từ đầu

1. Clone repo.
2. Đăng nhập Firebase Console bằng tài khoản `ntduong@st.utc2.edu.vn`, mở project `badminton-d689a`, tải Service Account JSON tại Project settings > Service accounts > Generate new private key, rồi đặt file ngoài repo.
3. Tạo `backend_caulong/appsettings.Development.json` theo mẫu ở trên.
4. Chạy seeder Firestore.
5. Chạy backend bằng `dotnet run --launch-profile http`.
6. Nếu test thanh toán thật, chạy `ngrok http 5011` và cấu hình webhook SePay.
7. Chạy Flutter app hoặc Flutter web.
8. Nếu cần trang quản trị, cấu hình `admin-web/.env`, chạy `npm install`, rồi `npm run dev`.

## Lưu ý quan trọng

- Không commit Service Account JSON, `.env`, API key, webhook secret hoặc thông tin ngân hàng thật.
- Nếu backend báo thiếu cấu hình lúc khởi động, kiểm tra lại `Firebase:CredentialsPath`, VietQR và `Webhook:Secret`.
- Nếu Android Emulator không gọi được backend, đảm bảo backend đang chạy tại port `5011`; emulator dùng `10.0.2.2`, không dùng `localhost`.
- Nếu dùng thiết bị Android thật, máy và điện thoại phải cùng mạng LAN hoặc dùng ngrok rồi truyền `--dart-define=API_BASE_URL=...`.
- Nếu tạo QR được nhưng không tự xác nhận thanh toán, kiểm tra `SePay:ApiToken`, `SePay:AccountNumber`, nội dung chuyển khoản `SEVQR BDM<orderId>` và URL webhook ngrok.
- File báo cáo hoàn chỉnh nằm tại `BaoCao/BC Quản lý sân cầu lông.pdf`.
