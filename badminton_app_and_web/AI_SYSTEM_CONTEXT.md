# 🏸 BỘ NGỮ CẢNH HỆ THỐNG: QUẢN LÝ SÂN CẦU LÔNG (BADMINTON MANAGEMENT SYSTEM)

**[SYSTEM INSTRUCTION CHO AI ASSISTANTS]**
Tài liệu này định nghĩa toàn bộ kiến trúc, luồng dữ liệu, nghiệp vụ và các quy tắc bắt buộc của dự án. AI Developer phải đọc kỹ, hiểu rõ bối cảnh và tuân thủ nghiêm ngặt mọi quy chuẩn trong tài liệu này trước khi sinh code, tư vấn kiến trúc hoặc sửa lỗi.

---

## 🏗️ 1. KIẾN TRÚC HỆ THỐNG (HYBRID SERVERLESS)
Hệ thống sử dụng kiến trúc lai (Hybrid Serverless) để tối ưu hóa thời gian thực (Real-time), giảm tải máy chủ và bảo mật giao dịch tài chính.

### A. Tầng Frontend (Flutter - Đa nền tảng)
*   **Nhiệm vụ:** Xử lý 90% các tác vụ CRUD, UI/UX, và hiển thị dữ liệu thời gian thực.
*   **Giao tiếp:** Gọi **trực tiếp** tới Firebase (Authentication & Firestore) bằng SDK của Firebase. *Không đi qua Backend cho các tác vụ lấy dữ liệu thông thường*.
*   **Nền tảng:** Mobile App (Người chơi) & Web App (Quản trị viên/Nhân viên tại quầy).
*   **State Management:** Sử dụng **GetX Pattern** (Controllers, Bindings, Routes, State, Dependency Injection).

### B. Tầng Backend (C# .NET API - Gateway Bảo Mật)
*   **Nhiệm vụ:** Hoạt động độc lập như một Microservice bảo mật. Tuyệt đối không xử lý UI.
*   **Giao tiếp:** Chỉ được gọi bởi Frontend khi có các nghiệp vụ nhạy cảm, giao tiếp bên thứ 3.
*   **Nghiệp vụ đặc thù:**
    *   Tạo mã thanh toán VietQR động.
    *   Lắng nghe Webhook từ Ngân hàng/Cổng thanh toán.
    *   Xử lý giao dịch tài chính (Cộng điểm, hoàn tiền, xác nhận thanh toán).
    *   Chạy thuật toán nâng cao (chống trùng lịch bằng `RunTransactionAsync` trên Firestore).

---

## 💼 2. LUỒNG NGHIỆP VỤ CỐT LÕI (BUSINESS LOGIC)

AI cần nắm vững 2 luồng nghiệp vụ đặt sân chính và trạng thái thanh toán để sinh UI/UX và logic phù hợp:

### 2.1. Nghiệp vụ Đặt Sân (Booking Types)
*   **Đặt sân lẻ theo giờ (One-time Booking):** Khách hàng chọn ngày, chọn ca/giờ trống và thanh toán. Trạng thái phản hồi ngay lập tức.
*   **Đặt lịch cố định theo tháng (Fixed Schedule):** Khách hàng đăng ký một khung giờ cố định trong các ngày cụ thể của tháng (Ví dụ: Thứ 3 & Thứ 5 hàng tuần, ca 18h-20h). Cần logic kiểm tra xung đột lịch diện rộng.

### 2.2. Vòng đời Thanh Toán & Đơn hàng (Order Lifecycle)
Mọi giao diện Booking và Order phải luôn hỗ trợ hiển thị 3 trạng thái chuẩn:
1.  **Chờ thanh toán (Pending):** Đã giữ chỗ tạm thời, chờ quét mã QR.
2.  **Đã thanh toán (Paid/Success):** Nhận Webhook thành công từ Backend, hệ thống Firestore tự động cập nhật Real-time xuống App.
3.  **Đã hủy (Cancelled):** Quá hạn thanh toán hoặc người dùng tự hủy/Admin hủy.

---

## 📁 3. CẤU TRÚC THƯ MỤC & ĐỊNH HƯỚNG MÃ NGUỒN

Dự án được chia làm 2 nhánh chính, tên thư mục phải được giữ nguyên xác thực.

### 📱 A. Phân hệ Frontend: `badminton_app_and_web`
*Mô hình: Flutter - GetX Pattern.*
*Lưu ý: Tên thư mục dùng `_and_` thay vì `&` để tránh lỗi Terminal.*

```text
badminton_app_and_web/
├── android/ & ios/ & web/    # Cấu hình Native & Browser (Đã config SHA-1/256)
├── main.dart                 # Entry point, khởi tạo Firebase
└── lib/
    ├── apps/                 # Cấu hình gốc (GetMaterialApp)
    ├── bindings/             # Dependency Injection (GetX Bindings)
    ├── commons/              # Code/UI dùng chung 100% cho App và Web
    ├── constants/            # Constants (Color codes, Base URL, Enums)
    ├── state/                # Global states (Network status, Auth state)
    ├── styles/               # Themes (Light/Dark), Typography
    ├── widgets/              # Reusable UI Components
    ├── controllers/          # Business Logic (Tính tiền, Xử lý Form - GetxController)
    ├── localization/         # i18n (Tiếng Việt / Tiếng Anh)
    ├── middlewares/          # Route Guards (Chặn route yêu cầu Auth)
    ├── routes/               # Định tuyến (app_pages, app_routes, web_routes)
    ├── utils/                # Helpers (Format Date, Currency VNĐ)
    ├── data/                 # TẦNG DỮ LIỆU
    │   ├── local/            # Local storage (token and app preferences)
    │   ├── models/           # Dart Data Classes (From/To JSON)
    │   ├── network/          # Dio configurations & Interceptors
    │   └── repository/       # Quyết định lấy data từ Network hay Local
    └── views/                # TẦNG GIAO DIỆN
        ├── app/              # UI Mobile (auth, booking, wallet, home, history...)
        └── web/              # UI Desktop (dashboard, finance, pos...)
🖥️ B. Phân hệ Backend: backend_caulong
Mô hình: C# .NET API - NoSQL (Firestore).
Lưu ý: Đã gỡ bỏ Entity Framework Core & SQL.
backend_caulong/
├── Controllers/              # Thin Controllers (Chỉ public API Webhook & QR)
├── Models/                   # NoSQL Documents lồng nhau (Sử dụng [FirestoreData])
├── Services/                 # Core Logic (Thuật toán chống trùng sân, Transactions)
├── Data/                     # Firebase Auth & Service Account Key configs
├── appsettings.json          # Chứa đường dẫn trỏ đến Private Key .json của Firebase
└── Program.cs                # Entry point, Middleware & DI Registration
🗄️ 4. DATABASE & BẢO MẬT
Database: Hệ thống dùng Firestore NoSQL (Test Mode trong giai đoạn Dev). Dữ liệu thiết kế theo hướng Documents lồng nhau (Nested), không chia bảng quan hệ chuẩn hóa cao như SQL.

Core Collections: users, courts, bookings, orders.

Authentication: Sử dụng Firebase Auth (Email/Password & Phone OTP). Gói firebase_auth đã tích hợp.

Security Certificates: Mã SHA-1 & SHA-256 đã config thành công trên Firebase Console.

🤖 5. CHỈ THỊ BẮT BUỘC DÀNH CHO AI (STRICT INSTRUCTIONS)
Khi AI sinh code, tư vấn cấu trúc hay viết tài liệu cho dự án này, PHẢI tuân thủ các nguyên tắc sau:

QUY TẮC LUỒNG DỮ LIỆU (DATA FLOW):

Frontend Flutter: LUÔN ưu tiên gọi trực tiếp qua cloud_firestore và firebase_auth để lấy list sân, lịch sử, profile.

Backend C#: CHỈ viết API khi liên quan đến bảo mật (Webhook thanh toán, SMS, sinh QR). Tuyệt đối không viết API CRUD sân/user bằng C# để Flutter gọi lại.

QUY TẮC KHỞI TẠO FIREBASE FLUTTER:

Tuyệt đối không sinh code nạp cứng (hardcode) cấu hình từ file google-services.json hay GoogleService-Info.plist thủ công.

Bắt buộc phải sử dụng: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); (từ file lib/firebase_options.dart sinh ra bởi flutterfire).

QUY TẮC KIẾN TRÚC GETX:

Tách biệt rõ ràng tầng UI (Views) và logic (Controllers). Mọi xử lý tính toán tiền, lọc giờ trống phải nằm trong GetxController.

QUY TẮC CƠ SỞ DỮ LIỆU C#:

Không sử dụng Entity Framework Core, SQL Server hay MySQL. Mọi code liên quan đến Data Access ở C# phải dùng thư viện Google.Cloud.Firestore.
