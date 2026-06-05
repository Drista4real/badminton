import React from 'react';
import { ShieldCheck, UserCheck, Wallet, RefreshCw, Calendar, Search, Bell, HelpCircle, ChevronLeft, ChevronRight } from 'lucide-react';

interface RoleHeaderProps {
  currentRole: 'staff' | 'accountant' | 'admin';
  setRole: (role: 'staff' | 'accountant' | 'admin') => void;
  selectedDate: string;
  setSelectedDate: (date: string) => void;
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  activeTab?: string;
}

// Helper to format date into "T{x}, DD Tháng MM, YYYY" (Vietnamese style)
export const formatVietnameseDate = (date: Date): string => {
  const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  const dayName = days[date.getDay()];
  const dd = String(date.getDate()).padStart(2, '0');
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const yyyy = date.getFullYear();
  return `${dayName}, ${dd} Tháng ${mm}, ${yyyy}`;
};

// Timezone-safe Vietnamese date formatter from "YYYY-MM-DD" string
export const formatVietnameseDateStr = (dateStr: string): string => {
  if (!dateStr) return '';
  const [year, month, day] = dateStr.split('-').map(Number);
  const dateObj = new Date(year, month - 1, day);
  const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  const dayName = days[dateObj.getDay()];
  const dd = String(day).padStart(2, '0');
  const mm = String(month).padStart(2, '0');
  const yyyy = year;
  return `${dayName}, ${dd} Tháng ${mm}, ${yyyy}`;
};

// Helper to parse "T{x}, DD Tháng MM, YYYY" back to ISO "YYYY-MM-DD"
export const parseVietnameseDateToISO = (dateStr: string): string => {
  const match = dateStr.match(/(\d{1,2})\s*Tháng\s*(\d{1,2}),\s*(\d{4})/i);
  if (match) {
    const dd = match[1].padStart(2, '0');
    const mm = match[2].padStart(2, '0');
    const yyyy = match[3];
    return `${yyyy}-${mm}-${dd}`;
  }
  // If parsing fails, return local today string
  const today = new Date();
  return `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
};

export default function RoleHeader({
  currentRole,
  setRole,
  selectedDate,
  setSelectedDate,
  searchQuery,
  setSearchQuery,
  activeTab
}: RoleHeaderProps) {
  const handlePrevDay = () => {
    const [year, month, day] = selectedDate.split('-').map(Number);
    const d = new Date(year, month - 1, day);
    d.setDate(d.getDate() - 1);
    const yr = d.getFullYear();
    const mo = String(d.getMonth() + 1).padStart(2, '0');
    const dy = String(d.getDate()).padStart(2, '0');
    setSelectedDate(`${yr}-${mo}-${dy}`);
  };

  const handleNextDay = () => {
    const [year, month, day] = selectedDate.split('-').map(Number);
    const d = new Date(year, month - 1, day);
    d.setDate(d.getDate() + 1);
    const yr = d.getFullYear();
    const mo = String(d.getMonth() + 1).padStart(2, '0');
    const dy = String(d.getDate()).padStart(2, '0');
    setSelectedDate(`${yr}-${mo}-${dy}`);
  };

  const handleGoToday = () => {
    const today = new Date();
    const yr = today.getFullYear();
    const mo = String(today.getMonth() + 1).padStart(2, '0');
    const dy = String(today.getDate()).padStart(2, '0');
    setSelectedDate(`${yr}-${mo}-${dy}`);
  };

  return (
    <header className="bg-white border-b border-gray-100 px-6 py-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4 sticky top-0 z-10 shadow-xs">
      {/* Search Bar / Left Side */}
      <div className="flex items-center gap-4 flex-1">
        <div className="relative w-full max-w-md">
          <span className="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none text-gray-400">
            <Search size={18} />
          </span>
          <input
            type="text"
            placeholder="Tìm kiếm khách hàng, mã đơn, số điện thoại..."
            className="w-full bg-slate-50 text-sm text-gray-700 pl-10 pr-4 py-2 rounded-xl outline-hidden border border-slate-200 focus:border-indigo-500 focus:bg-white transition-all shadow-xs"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>

        {/* Dynamic Date display & picker: Only visible on Court Booking Schedule tab ('pos') */}
        {activeTab === 'pos' && (
          <div id="header-date-picker-container" className="flex items-center gap-2 transition-all duration-200 animate-in fade-in slide-in-from-top-1">
            {/* Previous day button */}
            <button
              id="decrease-date-btn"
              onClick={handlePrevDay}
              className="p-1.5 border border-slate-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-indigo-600 rounded-lg transition-all cursor-pointer shadow-xs shrink-0"
              title="Ngày trước đó"
            >
              <ChevronLeft size={14} />
            </button>

            {/* Current date text with native input picker overlay */}
            <div id="datepicker-input-wrapper" className="relative flex items-center justify-center shrink-0">
              <div className="flex items-center gap-2 bg-slate-50 border border-slate-200 hover:border-indigo-400 hover:bg-white text-slate-700 hover:text-indigo-600 px-2.5 py-1.5 rounded-lg text-xs font-bold shadow-xs transition-all cursor-pointer">
                <Calendar size={13} className="text-indigo-500" />
                <span>{selectedDate ? formatVietnameseDateStr(selectedDate) : 'Chọn ngày'}</span>
              </div>
              <input
                id="datepicker-native-input"
                type="date"
                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10 [&::-webkit-calendar-picker-indicator]:absolute [&::-webkit-calendar-picker-indicator]:w-full [&::-webkit-calendar-picker-indicator]:h-full [&::-webkit-calendar-picker-indicator]:opacity-0 [&::-webkit-calendar-picker-indicator]:cursor-pointer [&::-webkit-calendar-picker-indicator]:inset-0"
                value={selectedDate}
                onChange={(e) => {
                  if (e.target.value) {
                    setSelectedDate(e.target.value);
                  }
                }}
              />
            </div>

            {/* Next day button */}
            <button
              id="increase-date-btn"
              onClick={handleNextDay}
              className="p-1.5 border border-slate-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-indigo-600 rounded-lg transition-all cursor-pointer shadow-xs shrink-0"
              title="Ngày tiếp theo"
            >
              <ChevronRight size={14} />
            </button>

            {/* Today button */}
            <button
              id="today-reset-btn"
              onClick={handleGoToday}
              className="px-2.5 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-lg shadow-xs transition-all cursor-pointer shrink-0"
              title="Quay lại ngày hôm nay"
            >
              Hôm nay
            </button>
          </div>
        )}
      </div>

      {/* Notifications / User Info */}
      <div className="flex items-center justify-end gap-4">
        {/* Role Display Capsule */}
        <div id="role-selector-capsule" className="flex items-center">
          {currentRole === 'admin' && (
            <span className="px-3 py-1.5 bg-indigo-50 border border-indigo-150 text-indigo-700 text-[10px] font-extrabold rounded-xl flex items-center gap-1.5 shadow-xs uppercase tracking-wider animate-in fade-in zoom-in-95 duration-200">
              <ShieldCheck size={14} className="text-indigo-600 animate-pulse" />
              <span>Chủ Sân (Admin)</span>
            </span>
          )}
          {currentRole === 'accountant' && (
            <span className="px-3 py-1.5 bg-amber-50 border border-amber-150 text-amber-700 text-[10px] font-extrabold rounded-xl flex items-center gap-1.5 shadow-xs uppercase tracking-wider animate-in fade-in zoom-in-95 duration-200">
              <Wallet size={14} className="text-amber-600 animate-pulse" />
              <span>Bộ phận Kế toán</span>
            </span>
          )}
          {currentRole === 'staff' && (
            <span className="px-3 py-1.5 bg-emerald-50 border border-emerald-150 text-emerald-700 text-[10px] font-extrabold rounded-xl flex items-center gap-1.5 shadow-xs uppercase tracking-wider animate-in fade-in zoom-in-95 duration-200">
              <UserCheck size={14} className="text-emerald-500 animate-pulse" />
              <span>Nhân viên trực sân</span>
            </span>
          )}
        </div>

        {/* Action icons & Account Avatar */}
        <div className="flex items-center gap-3 pl-2">
          <button className="text-slate-400 hover:text-slate-600 relative p-1.5 rounded-lg hover:bg-slate-50 cursor-pointer">
            <Bell size={20} />
            <span className="absolute top-1 right-1 w-2 h-2 bg-indigo-600 rounded-full"></span>
          </button>
          <button className="text-slate-400 hover:text-slate-600 p-1.5 rounded-lg hover:bg-slate-50 cursor-pointer">
            <HelpCircle size={20} />
          </button>

          {/* User profile bubble */}
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 rounded-full overflow-hidden bg-indigo-500 flex items-center justify-center text-white font-bold shadow-xs">
              <img
                src="https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80"
                alt="Admin Profile"
                className="w-full h-full object-cover"
                referrerPolicy="no-referrer"
              />
            </div>
            <div className="hidden xl:block text-left">
              {(() => {
                const saved = localStorage.getItem('court_admin_user');
                let name = 'Admin - Chủ sân';
                let email = 'Admin@gmail.com';
                if (saved) {
                  try {
                    const u = JSON.parse(saved);
                    name = u.name || 'Admin';
                    email = u.email || 'Admin@gmail.com';
                  } catch (e) {}
                }
                return (
                  <>
                    <p className="text-xs font-bold text-slate-900 font-sans">
                      {name}
                    </p>
                    <p className="text-[10px] text-slate-500">{email}</p>
                  </>
                );
              })()}
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
