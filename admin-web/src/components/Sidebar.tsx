import React, { useState, useEffect } from 'react';
import { 
  BarChart3, CalendarDays, Users2, Landmark, DollarSign, Settings, 
  LogOut, ShieldAlert, X, ClipboardCheck
} from 'lucide-react';

interface SidebarProps {
  currentRole: 'staff' | 'accountant' | 'admin';
  activeTab: string;
  setActiveTab: (tab: string) => void;
  onLogout: () => void;
}

export default function Sidebar({ currentRole, activeTab, setActiveTab, onLogout }: SidebarProps) {
  const [confirmLogout, setConfirmLogout] = useState(false);

  // Auto reset confirmation after 4 seconds
  useEffect(() => {
    if (confirmLogout) {
      const timer = setTimeout(() => {
        setConfirmLogout(false);
      }, 4000);
      return () => clearTimeout(timer);
    }
  }, [confirmLogout]);

  // Define all tabs definition
  const allTabs = [
    { id: 'dashboard', label: 'Tổng quan', icon: BarChart3, roles: ['admin', 'accountant'] },
    { id: 'pos', label: 'Lịch đặt sân', icon: CalendarDays, roles: ['admin', 'staff'] },
    { id: 'customers', label: 'Khách hàng', icon: Users2, roles: ['admin', 'staff'] },
    { id: 'courts', label: 'Quản lý sân', icon: Landmark, roles: ['admin'] },
    { id: 'refunds-review', label: 'Xét duyệt Hoàn tiền', icon: ClipboardCheck, roles: ['admin', 'accountant'] },
    { id: 'finance', label: 'Doanh thu', icon: DollarSign, roles: ['admin', 'accountant'] },
    { id: 'pricing', label: 'Cài đặt giá', icon: Settings, roles: ['admin'] },
  ];

  // Filter based on active role
  const visibleTabs = allTabs.filter(tab => tab.roles.includes(currentRole));

  return (
    <aside className="w-64 bg-slate-900 text-slate-350 flex flex-col justify-between h-screen shrink-0 border-r border-slate-800">
      {/* Brand logo header */}
      <div>
        <div className="p-6 flex items-center gap-3 border-b border-slate-800/60 font-sans">
          <div className="w-10 h-10 rounded-xl bg-indigo-600 flex items-center justify-center text-white shadow-lg shadow-indigo-600/10">
            {/* Direct custom elegant shuttlecock SVG design */}
            <svg viewBox="0 0 24 24" fill="none" className="w-6 h-6 stroke-white stroke-2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2L4 12V22L12 18L20 22V12L12 2Z" />
              <path d="M12 2V18" />
              <path d="M4 12H20" />
            </svg>
          </div>
          <div>
            <h2 className="text-sm font-extrabold text-white tracking-wider flex items-center gap-1">
              ProBadminton
            </h2>
            <p className="text-[10px] text-indigo-400 font-bold uppercase tracking-widest">
              Hệ Thống Quản Lý
            </p>
          </div>
        </div>

        {/* Dynamic menu items list */}
        <nav className="p-4 space-y-1">
          {visibleTabs.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={`w-full text-left font-semibold text-xs py-3 px-4 rounded-xl flex items-center gap-3 transition-all cursor-pointer ${
                  isActive
                    ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/10 font-black'
                    : 'text-slate-400 hover:bg-slate-800/50 hover:text-white'
                }`}
              >
                <Icon size={16} className={isActive ? 'text-white' : 'text-slate-400'} />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>
      </div>

      {/* Footer menu buttons */}
      <div className="p-4 border-t border-slate-800/60 bg-slate-950/20 space-y-1">
        <button 
          onClick={() => {
            if (confirmLogout) {
              onLogout();
            } else {
              setConfirmLogout(true);
            }
          }}
          className={`w-full text-left text-xs py-2.5 px-4 rounded-xl flex items-center justify-between cursor-pointer transition-all duration-200 border ${
            confirmLogout 
              ? 'bg-rose-950/40 border-rose-500/40 text-rose-300 shadow-lg shadow-rose-950/50 animate-pulse font-bold' 
              : 'border-transparent text-rose-400 hover:bg-rose-500/10 hover:text-rose-300'
          }`}
        >
          <div className="flex items-center gap-3">
            <LogOut size={15} className={confirmLogout ? 'text-rose-400' : 'text-rose-400'} />
            <span>{confirmLogout ? 'Nhấp một lần nữa để rời đi' : 'Đăng xuất'}</span>
          </div>
          {confirmLogout && (
            <span 
              onClick={(e) => {
                e.stopPropagation();
                setConfirmLogout(false);
              }}
              className="p-1 text-[9px] uppercase font-black tracking-widest bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 rounded-md transition-colors border border-rose-500/20 px-1.5 py-0.5 active:scale-95"
              title="Hủy thao tác"
            >
              Hủy
            </span>
          )}
        </button>
      </div>
    </aside>
  );
}
