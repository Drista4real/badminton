🏸 DỰ ÁN QUẢN LÝ SÂN CẦU LÔNG (Badminton Management System)

Chào mừng các AI Assistant và Developers đến với dự án Quản lý Sân Cầu Lông. Đây là tài liệu hướng dẫn bối cảnh (Context), cấu trúc thư mục và kiến trúc hệ thống để định hướng phát triển đồng bộ.

🏗️ 1. KIẾN TRÚC HỆ THỐNG (System Architecture)
Dự án áp dụng mô hình **Hybrid Serverless (Kiến trúc lai)** nhằm tối ưu tốc độ phát triển và hiệu năng:
Frontend Mobile/Web (Flutter):** Kết nối trực tiếp với **Firebase (Authentication & Firestore)** để xử lý 90% các tác vụ hiển thị dữ liệu (Xem danh sách sân, đặt lịch lẻ/cố định, quản lý profile, lịch sử đơn hàng).
Backend (C# .NET API):** Chạy độc lập, đóng vai trò là cổng xử lý nghiệp vụ nặng và bảo mật (Xử lý cổng thanh toán ngân hàng, sinh mã **VietQR động**, nhận Webhook thông báo chuyển khoản thành công và xử lý đồng bộ hóa nâng cao).

📁 2. CẤU TRÚC THƯ MỤC & CÔNG DỤNG (Project Structure)
Dự án tổng được quản lý trong thư mục `badminton_project/`, chia thành 2 nhánh chính độc lập:
📱 A. Phân hệ Frontend: `badminton_app_and_web` (Flutter - GetX Pattern)
```text
badminton_app_and_web/
├── android/                  # Cấu hình Native Android (Đã tích hợp SHA-1, SHA-256)
├── ios/                      # Cấu hình Native iOS
├── web/                      # Cấu hình bản Web App nền tảng Browser
├── build/                    # Chứa các file biên dịch đầu ra (Ví dụ: app-debug.apk)
├── main.dart                 # File chạy đầu tiên của toàn bộ project Flutter, khởi tạo Firebase
└── lib/
    ├── apps/                 # Cấu hình cấp cao nhất để khởi tạo ứng dụng (GetMaterialApp, môi trường gốc)
    ├── bindings/             # Nơi chứa code Tiêm phụ thuộc (Dependency Injection) của GetX
    ├── commons/              # Các thành phần logic/giao diện dùng chung 100% cho cả App và Web
    ├── constants/            # Biến hằng số (Mã màu lưới trạng thái, link Base URL của API)
    ├── state/                # Quản lý các trạng thái toàn cục (Ví dụ: kiểm tra kết nối mạng)
    ├── styles/               # Cấu hình giao diện (Theme sáng/tối, Font chữ mặc định)
    ├── widgets/              # Các UI Component tự code tái sử dụng (Nút bấm, ô nhập liệu chuẩn)
    ├── controllers/          # "Bộ não" Frontend: Chứa logic nghiệp vụ, tính toán tổng tiền, xử lý form
    ├── localization/         # File dịch thuật đa ngôn ngữ (Tiếng Việt / Tiếng Anh)
    ├── middlewares/          # Các lớp chặn luồng điều hướng (Chặn vào Đặt sân nếu chưa đăng nhập)
    ├── routes/               # Định nghĩa đường dẫn điều hướng (app_pages.dart, app_routes.dart, web_routes.dart)
    ├── utils/                # Hàm tiện ích dùng chung (Format ngày giờ, format tiền tệ VNĐ)
    ├── data/                 # TẦNG QUẢN LÝ VÀ GIAO TIẾP DỮ LIỆU
    │   ├── local/            # Cấu hình lưu trữ dưới máy (Lưu Token FaceID/Vân tay vào Secure Storage)
    │   ├── models/           # Class ép kiểu dữ liệu từ JSON (Backend) sang Object của Dart
    │   ├── network/          # Cấu hình kết nối mạng (Dio), Interceptor và kết nối Real-time
    │   └── repository/       # Tầng trung gian điều phối: Quyết định lấy dữ liệu từ Network hay Local Cache
    └── views/                # TẦNG PHÂN TÁCH GIAO DIỆN UI
        ├── app/              # Giao diện Mobile App cho Người chơi (auth, booking, wallet, home, history, profile)
        └── web/              # Giao diện Web Desktop cho Quản trị viên (dashboard, finance, management, pos tại quầy)
🖥️ B. Phân hệ Backend: backend_caulong (C# .NET API - NoSQL Architecture)
Plaintext
backend_caulong/
├── Connected Services/       # Quản lý gói thư viện bên thứ 3. Đã gỡ bỏ EF Core, thay thế bằng Google.Cloud.Firestore
├── Controllers/              # Thiết kế cực mỏng, chỉ chứa API bảo mật: Nhận Webhook ngân hàng và sinh mã VietQR
├── Models/                   # Class đại diện cho Documents NoSQL. Thiết kế dạng lồng nhau, dùng Attribute [FirestoreData]
├── Services/                 # Logic kinh doanh cốt lõi: Thuật toán chống trùng sân (RunTransactionAsync), xử lý cộng điểm/hoàn tiền
├── Data/                     # (Hoặc Repositories/): Thiết kế kết nối hệ thống Firebase thông qua chứng chỉ bảo mật Service Account Key
├── appsettings.json          # File cấu hình. Đã xóa kết nối SQL, thay bằng đường dẫn chứa file Private Key .json của Firebase
└── Program.cs                # Gốc khởi chạy hệ thống, đăng ký các Services và Middleware
```
🛠️ 3. TRẠNG THÁI CẤU HÌNH HỆ THỐNG
🔐 Authentication (Xác thực)
Đã kích hoạt trên Firebase Console các phương thức: Email/Password và Phone (OTP).

Thư viện firebase_auth đã được tích hợp vào dự án Flutter.

🗄️ Database (Firestore)
Đang cấu hình ở chế độ Test Mode (Mở quyền Đọc/Ghi tự do phục vụ phát triển).

Định hướng lưu trữ: NoSQL (Collections & Documents lồng nhau, không chia bảng quan hệ). Các Collection cốt lõi dự kiến: users, courts, bookings, orders.

🔏 Chứng chỉ Bảo mật (Android SHA)
Đã cấu hình thành công mã SHA-1 và SHA-256 của máy phát triển gốc lên Firebase Console.

Dự án Flutter đã kết nối đồng bộ thông qua flutterfire configure.

🤖 4. CHỈ THỊ DÀNH CHO AI (Instruction for AI Assistants)
Khi tham gia hỗ trợ code hoặc thiết kế hệ thống trong dự án này, AI cần tuân thủ nghiêm ngặt các nguyên tắc sau:

Luồng đi của dữ liệu: Ưu tiên cho Flutter tương tác trực tiếp với Firebase thông qua các gói cloud_firestore và firebase_auth. Chỉ thiết kế API qua backend_caulong (C#) khi xử lý các tính năng liên quan đến bảo mật cao hoặc tích hợp bên thứ ba (Cổng thanh toán, Ngân hàng, SMS Gateway).

Khởi tạo Firebase: Tuyệt đối không thay đổi cấu hình nạp cứng file google-services.json thủ công. Dự án đang sử dụng DefaultFirebaseOptions.currentPlatform từ file lib/firebase_options.dart.

Tên thư mục: Lưu ý thư mục chứa mã nguồn Flutter hiện tại đã được đổi tên thành badminton_app_and_web (không dùng ký tự & để tránh lỗi biên dịch trên môi trường Windows Terminal).

Cấu trúc UI/UX: Khi sinh code giao diện, bám sát nghiệp vụ đặt sân (Đặt sân lẻ theo giờ / Đặt lịch cố định theo tháng) và tích hợp sẵn các vị trí hiển thị trạng thái thanh toán (Chờ thanh toán, Đã thanh toán, Đã hủy).
