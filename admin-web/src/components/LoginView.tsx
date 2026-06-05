import React, { useState } from 'react';
import { ShieldCheck, Mail, Lock, Eye, EyeOff, Loader2, UserCheck, Wallet, ChevronRight, BookOpen, AlertCircle } from 'lucide-react';

interface LoginViewProps {
  onLoginSuccess: (user: { id: string; name: string; email: string; phone: string; role: string }) => void;
}

const DEMO_ACCOUNTS = [
  {
    id: 'admin',
    name: 'Chủ Sân (Admin)',
    email: 'admin@gmail.com',
    roleLabel: 'Admin / Chủ Sân',
    icon: ShieldCheck,
    colorClass: 'border-indigo-500/30 bg-indigo-950/20 text-indigo-400 hover:bg-indigo-950/40',
    activeColorClass: 'ring-2 ring-indigo-500 bg-indigo-950/40 border-indigo-500/60',
    badgeClass: 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20',
    capabilities: [
      'Toàn quyền quản trị hệ thống',
      'Đại tu, chỉnh sửa cấu hình giá giờ chơi linh động',
      'Theo dõi trực tiếp sổ doanh thu, lợi nhuận thực tế',
      'Đóng/Mở hoạt động các phần sân cụ thể',
      'Khóa / Mở khóa tài khoản khách hàng, hội viên hệ thống'
    ]
  },
  {
    id: 'nhanvien1',
    name: 'Nhân viên trực sân 1',
    email: 'nhanvien1@gmail.com',
    roleLabel: 'Trực Sân (Staff)',
    icon: UserCheck,
    colorClass: 'border-emerald-500/30 bg-emerald-950/20 text-emerald-400 hover:bg-emerald-950/40',
    activeColorClass: 'ring-2 ring-emerald-500 bg-emerald-950/40 border-emerald-500/60',
    badgeClass: 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20',
    capabilities: [
      'Truy cập trang Lịch Đặt Sân POS nhanh chóng',
      'Thêm đơn đặt lịch, thu tiền của khách trực tiếp tại quầy',
      'Đánh dấu trạng thái khách đã nhận sân / vắng mặt',
      'Đăng ký thông tin tài khoản hội viên mới'
    ]
  },
  {
    id: 'nhanvien2',
    name: 'Nhân viên trực sân 2',
    email: 'nhanvien2@gmail.com',
    roleLabel: 'Trực Sân (Staff)',
    icon: UserCheck,
    colorClass: 'border-teal-500/30 bg-teal-950/20 text-teal-400 hover:bg-teal-950/40',
    activeColorClass: 'ring-2 ring-teal-500 bg-teal-950/40 border-teal-500/60',
    badgeClass: 'bg-teal-500/10 text-teal-400 border border-teal-500/20',
    capabilities: [
      'Theo dõi lịch đặt chống chéo giờ giữa các sân PVC/Sàn Gỗ',
      'Ghi nhận tích điểm tự động theo doanh số đơn đặt cho hội viên',
      'Hỗ trợ khách hàng check-in thuận tiện'
    ]
  },
  {
    id: 'ketoan',
    name: 'Kế toán (Accountant)',
    email: 'ketoan@gmail.com',
    roleLabel: 'Kế toán',
    icon: Wallet,
    colorClass: 'border-amber-500/30 bg-amber-950/20 text-amber-400 hover:bg-amber-950/40',
    activeColorClass: 'ring-2 ring-amber-500 bg-amber-950/40 border-amber-500/60',
    badgeClass: 'bg-amber-500/10 text-amber-400 border border-amber-500/20',
    capabilities: [
      'Kiểm soát toàn diện sổ sách Doanh Thu & tài chính',
      'Tra cứu và Duyệt yêu cầu hoàn trả tiền / hủy sân của khách hàng',
      'Giám sát hành trình số dư thu nhập theo thời gian thực',
      'Bảo vệ an toàn thông số giá cài đặt (Không có quyền can thiệp giá)'
    ]
  }
];

export default function LoginView({ onLoginSuccess }: LoginViewProps) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      setErrorMsg('Vui lòng nhập đầy đủ tài khoản và mật khẩu.');
      return;
    }

    setLoading(true);
    setErrorMsg(null);

    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          username: username.trim(),
          password: password,
        }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        onLoginSuccess(data.user);
      } else {
        setErrorMsg(data.error || 'Đăng nhập không thành công. Hãy kiểm tra lại thông tin.');
      }
    } catch (err: any) {
      console.error('Login error:', err);
      setErrorMsg('Không thể kết nối máy chủ xác thực. Vui lòng thử lại sau.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div id="login-screen-container" className="min-h-screen bg-slate-950 flex items-center justify-center p-4 xl:p-8 selection:bg-indigo-500 selection:text-white font-sans relative overflow-hidden">
      {/* Decorative ambient background elements */}
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-indigo-500/10 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-emerald-500/10 rounded-full blur-[140px] pointer-events-none" />

      {/* Main container with grid layout */}
      <div id="login-grid-container" className="max-w-5xl w-full grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch relative z-10">
        
        {/* Left column: Role & Capability Selector panel (takes 7 cols on lg) */}
        <div id="login-roles-guide-panel" className="lg:col-span-7 bg-slate-900/60 border border-slate-800/80 rounded-3xl p-6 flex flex-col justify-between backdrop-blur-md">
          <div>
            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 rounded-xl bg-indigo-600/10 flex items-center justify-center border border-indigo-500/20 text-indigo-400">
                <BookOpen size={18} />
              </div>
              <div>
                <span className="text-[10px] font-extrabold text-indigo-400 uppercase tracking-widest block font-mono">Chương trình thử nghiệm</span>
                <h3 className="text-base font-extrabold text-white">Sổ Tay Phân Quyền Theo Vai Trò</h3>
              </div>
            </div>
            
            <p className="text-xs text-slate-300 leading-relaxed mb-6 font-medium">
              Hệ thống được phát triển với cơ chế phân quyền chặt chẽ. Chọn một trong các tài khoản nhân sự mẫu dưới đây để tự động nhập thông tin đăng nhập và xem chi tiết phạm vi quyền hạn tương ứng:
            </p>

            {/* List of demo/employee cards */}
            <div className="space-y-3.5">
              {DEMO_ACCOUNTS.map((acc) => {
                const AccIcon = acc.icon;
                const isActive = username.toLowerCase() === acc.email.toLowerCase();
                return (
                  <button
                    key={acc.id}
                    type="button"
                    onClick={() => {
                      setUsername(acc.email);
                      setErrorMsg(null);
                    }}
                    className={`w-full text-left p-4 rounded-2xl border transition-all duration-200 cursor-pointer flex gap-4 items-start ${
                      isActive ? acc.activeColorClass : 'border-slate-800 bg-slate-900/40 text-slate-450 hover:border-slate-700 hover:bg-slate-800/30'
                    }`}
                  >
                    <div className={`p-2 rounded-xl shrink-0 ${isActive ? 'bg-indigo-650 text-white' : 'bg-slate-850 text-slate-400'}`}>
                      <AccIcon size={16} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-2">
                        <h4 className={`text-xs font-bold leading-none ${isActive ? 'text-white' : 'text-slate-250'}`}>
                          {acc.name}
                        </h4>
                        <span className={`text-[9px] font-extrabold uppercase px-2 py-0.5 rounded-md ${acc.badgeClass}`}>
                          {acc.roleLabel}
                        </span>
                      </div>
                      <p className="text-[10px] font-mono text-slate-500 mt-1.5">
                        Email: {acc.email}
                      </p>
                      
                      {/* Capabilities display - open only if active */}
                      {isActive && (
                        <div className="mt-3.5 pt-3 border-t border-slate-800 space-y-1.5 animate-in slide-in-from-top-1 duration-150">
                          <p className="text-[9px] font-extrabold text-white tracking-wider uppercase mb-1 flex items-center gap-1">
                            <span className="w-1.5 h-1.5 bg-indigo-500 rounded-full"></span> Chức năng khả dụng:
                          </p>
                          {acc.capabilities.map((cap, i) => (
                            <div key={i} className="text-[11px] text-slate-400 flex items-start gap-1.5 leading-relaxed font-sans font-medium">
                              <span className="text-indigo-400 font-bold">✓</span>
                              <span>{cap}</span>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-slate-800/80 text-[10px] text-slate-500 font-medium flex items-center gap-2">
            <AlertCircle size={12} className="text-slate-600" />
            <span>Mẹo: Click vào bất kỳ tài khoản mẫu nào để tự điền biểu mẫu nhập liệu.</span>
          </div>
        </div>

        {/* Right column: Login form card (takes 5 cols on lg) */}
        <div id="login-card-main-wrapper" className="lg:col-span-5 flex flex-col justify-center">
          <div id="login-card-main" className="bg-slate-900 border border-slate-800 rounded-3xl p-8 shadow-2xl animate-in fade-in zoom-in-95 duration-300">
            
            {/* Logo/Brand inside the form context */}
            <div className="flex flex-col items-center text-center mb-6">
              <div className="w-12 h-12 rounded-2xl bg-indigo-650 flex items-center justify-center text-white shadow-xl shadow-indigo-605/20 mb-3.5 ring-4 ring-indigo-950">
                <svg viewBox="0 0 24 24" fill="none" className="w-6 h-6 stroke-white stroke-[2.2]" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 2L4 12V22L12 18L20 22V12L12 2Z" />
                  <path d="M12 2V18" />
                  <path d="M4 12H20" />
                </svg>
              </div>
              <h2 className="text-xl font-black text-white tracking-tight">ProBadminton</h2>
              <p className="text-[11px] text-slate-400 mt-0.5">Hệ thống phân quyền thông minh</p>
            </div>

            {/* Form Inputs Container */}
            <form onSubmit={handleSubmit} className="space-y-4">
              {errorMsg && (
                <div id="login-error-alert" className="p-3 bg-rose-500/10 border border-rose-500/20 text-rose-400 rounded-xl text-xs font-semibold text-center animate-shake leading-relaxed">
                  {errorMsg}
                </div>
              )}

              {/* Account/Username input */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-extrabold text-slate-400 uppercase tracking-wider block">Email hoặc Số điện thoại</label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 flex items-center pl-3.5 pointer-events-none text-slate-500">
                    <Mail size={16} />
                  </div>
                  <input
                    id="login-username-input"
                    type="text"
                    required
                    disabled={loading}
                    className="w-full bg-slate-950 text-slate-100 text-xs pl-10 pr-4 py-3.5 rounded-xl border border-slate-800 focus:border-indigo-500 focus:outline-hidden transition-all font-medium placeholder-slate-600/70"
                    placeholder="email@example.com hoặc Sđt"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                  />
                </div>
              </div>

              {/* Password input */}
              <div className="space-y-1.5">
                <div className="flex justify-between items-center">
                  <label className="text-[10px] font-extrabold text-slate-400 uppercase tracking-wider">Mật khẩu</label>
                </div>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 flex items-center pl-3.5 pointer-events-none text-slate-500">
                    <Lock size={16} />
                  </div>
                  <input
                    id="login-password-input"
                    type={showPassword ? 'text' : 'password'}
                    required
                    disabled={loading}
                    className="w-full bg-slate-950 text-slate-100 text-xs pl-10 pr-10 py-3.5 rounded-xl border border-slate-800 focus:border-indigo-500 focus:outline-hidden transition-all font-mono tracking-wide placeholder-slate-600/70"
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute inset-y-0 right-0 flex items-center pr-3 text-slate-500 hover:text-slate-300 transition-colors cursor-pointer"
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>

              {/* Action Login button */}
              <button
                id="login-submit-button"
                type="submit"
                disabled={loading}
                className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:bg-slate-800 disabled:text-slate-500 text-white font-bold text-xs py-3.5 rounded-xl mt-3 flex items-center justify-center gap-2 cursor-pointer shadow-lg shadow-indigo-600/10 hover:shadow-indigo-600/20 active:scale-[0.98] transition-all border border-indigo-500"
              >
                {loading ? (
                  <>
                    <Loader2 size={16} className="animate-spin text-white" />
                    Đang đối chiếu dữ liệu...
                  </>
                ) : (
                  <>
                    <span>Đăng Nhập Hệ Thống</span>
                    <ChevronRight size={14} className="text-white/80" />
                  </>
                )}
              </button>
            </form>

            {/* Footer info lock system */}
            <div className="mt-6 border-t border-slate-800/60 pt-4 flex items-center justify-center text-[10px] text-slate-500 font-semibold gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
              <span>Cơ sở dữ liệu đám mây hoạt động ổn định</span>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
