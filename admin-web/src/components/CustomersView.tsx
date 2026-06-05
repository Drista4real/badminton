import React, { useState } from 'react';
import { UserPlus, Search, Lock, Unlock, Mail, Phone, Calendar, UserCheck, X } from 'lucide-react';
import { Customer } from '../types';

interface CustomersViewProps {
  customers: Customer[];
  onToggleLockCustomer: (id: string) => void;
  onAddCustomer: (customer: Customer) => void;
}

export default function CustomersView({
  customers,
  onToggleLockCustomer,
  onAddCustomer
}: CustomersViewProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);

  // Form states
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');

  const handleAddSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !email || !phone) return;

    const id = `c${customers.length + 1}`;
    const newCustomer: Customer = {
      id,
      name,
      email,
      phone,
      points: 0,
      isLocked: false,
      joinedDate: `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`
    };

    onAddCustomer(newCustomer);
    setShowAddModal(false);
    setName('');
    setEmail('');
    setPhone('');
  };

  const filtered = customers.filter(c =>
    (c.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (c.email || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (c.phone || '').includes(searchQuery)
  );

  return (
    <div className="space-y-6">
      {/* Header controls */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Danh sách khách hàng</h1>
          <p className="text-sm text-gray-500">Quản lý thông tin và tài khoản người dùng hệ thống.</p>
        </div>
        
        <button
          onClick={() => setShowAddModal(true)}
          className="bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold px-4 py-2.5 rounded-xl flex items-center justify-center gap-1.5 shadow-xs transition-all cursor-pointer"
        >
          <UserPlus size={16} />
          Thêm khách mới
        </button>
      </div>

      {/* Main Table card */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-xs overflow-hidden">
        {/* Search & Statistics bar */}
        <div className="p-4 bg-slate-50/50 border-b border-gray-100 flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="relative w-full max-w-sm">
            <span className="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none text-gray-400">
              <Search size={16} />
            </span>
            <input
              type="text"
              placeholder="Tìm kiếm người chơi..."
              className="w-full bg-white text-xs text-gray-700 pl-9 pr-4 py-2.5 rounded-xl border border-gray-200 focus:outline-hidden focus:border-indigo-500 transition-all font-medium"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
          <div className="text-xs text-gray-500 font-medium">
            Hiển thị <b>{filtered.length}</b> trên <b>{customers.length}</b> khách hàng
          </div>
        </div>

        {/* The data table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="bg-slate-50 border-b border-gray-100 divide-x divide-gray-100/50 text-gray-400 uppercase tracking-widest font-bold">
                <th className="px-6 py-4">Tên khách hàng</th>
                <th className="px-6 py-4">Email</th>
                <th className="px-6 py-4">Số điện thoại</th>
                <th className="px-6 py-4 text-center">Trạng thái</th>
                <th className="px-6 py-4 text-center">Điểm tích lũy</th>
                <th className="px-6 py-4 text-center">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filtered.map(c => (
                <tr key={c.id} className="hover:bg-slate-50/40 transition-all">
                  {/* Name field with avatar circle */}
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs uppercase shadow-inner ${
                        c.isLocked 
                          ? 'bg-rose-100 text-rose-700 font-black ring-2 ring-rose-200' 
                          : 'bg-indigo-50 text-indigo-700 border border-indigo-100'
                      }`}>
                        {c.name.split(' ').pop()?.slice(0, 2) || 'KH'}
                      </div>
                      <div className="space-y-0.5">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className={`font-bold block ${c.isLocked ? 'text-gray-400 line-through' : 'text-gray-900'}`}>
                            {c.name}
                          </span>
                          {c.isLocked && (
                            <span className="bg-rose-100 text-rose-700 text-[9px] font-black px-1.5 py-0.5 rounded-md flex items-center gap-0.5 border border-rose-200">
                              <Lock size={9} /> BỊ KHÓA
                            </span>
                          )}
                        </div>
                        <span className="text-[10px] text-gray-400 font-medium flex items-center gap-1">
                          <Calendar size={11} /> Tham gia: {c.joinedDate}
                        </span>
                      </div>
                    </div>
                  </td>

                  {/* Email */}
                  <td className="px-6 py-4 font-mono font-medium text-gray-600">
                    <div className="flex items-center gap-1.5">
                      <Mail size={12} className="text-gray-400" />
                      {c.email}
                    </div>
                  </td>

                  {/* SĐT */}
                  <td className="px-6 py-4 font-mono font-semibold text-gray-700">
                    <div className="flex items-center gap-1.5">
                      <Phone size={12} className="text-gray-400" />
                      {c.phone}
                    </div>
                  </td>

                  {/* Trạng thái */}
                  <td className="px-6 py-4 text-center">
                    {c.isLocked ? (
                      <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[10px] font-bold bg-rose-50 text-rose-600 border border-rose-200 shadow-2xs">
                        <span className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse"></span>
                        Khóa tạm thời
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-600 border border-emerald-200 shadow-2xs">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                        Đang hoạt động
                      </span>
                    )}
                  </td>

                  {/* Accumulation points */}
                  <td className="px-6 py-4 text-center font-bold font-mono text-sm text-indigo-600">
                    {c.points.toLocaleString('vi-VN')}
                  </td>

                  {/* Actions lock/unlock button */}
                  <td className="px-6 py-4 text-center">
                    {c.email === 'Admin@gmail.com' || c.phone === '0987654321' ? (
                      <span className="text-[10px] text-gray-400 font-bold tracking-wide select-none bg-gray-100 px-2.5 py-1.5 rounded-lg border border-gray-200">
                        🔒 Hệ Thống Admin
                      </span>
                    ) : c.isLocked ? (
                      <button
                        onClick={() => {
                          onToggleLockCustomer(c.id);
                          alert(`Đã mở khóa tài khoản cho khách hàng: ${c.name}`);
                        }}
                        className="bg-slate-100 hover:bg-slate-200 text-slate-700 text-[10px] font-bold px-3.5 py-2 rounded-xl flex items-center justify-center gap-1 mx-auto transition-all cursor-pointer border border-slate-200"
                      >
                        <Unlock size={12} />
                        Mở khoá
                      </button>
                    ) : (
                      <button
                        onClick={() => {
                          onToggleLockCustomer(c.id);
                          alert(`Đã KHÓA TẠM THỜI tài khoản khách hàng: ${c.name} vì lý do vi phạm vi phạm đặt lịch!`);
                        }}
                        className="bg-rose-600 hover:bg-rose-700 text-white text-[10px] font-bold px-3.5 py-2 rounded-xl flex items-center justify-center gap-1 mx-auto transition-all cursor-pointer shadow-xs border border-rose-700"
                      >
                        <Lock size={12} />
                        Khóa tài khoản
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add new Customer Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <form
            onSubmit={handleAddSubmit}
            className="bg-white rounded-3xl border border-gray-100 max-w-sm w-full overflow-hidden shadow-2xl relative animate-in fade-in zoom-in-95 duration-200"
          >
            <div className="p-5 bg-indigo-600 text-white flex justify-between items-center">
              <h3 className="font-bold text-base flex items-center gap-2">
                <UserCheck size={18} />
                Thêm khách hàng mới
              </h3>
              <button
                type="button"
                onClick={() => setShowAddModal(false)}
                className="hover:scale-110 text-white/80 hover:text-white cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-400 uppercase">Họ và tên</label>
                <input
                  type="text"
                  required
                  className="w-full text-xs text-gray-800 border border-gray-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-indigo-500 font-medium font-sans"
                  placeholder="Ví dụ: Nguyễn Văn Hải"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-400 uppercase">Địa chỉ Email</label>
                <input
                  type="email"
                  required
                  className="w-full text-xs text-gray-800 border border-gray-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-indigo-500 font-mono font-medium"
                  placeholder="nhai@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-400 uppercase">Số điện thoại</label>
                <input
                  type="text"
                  required
                  className="w-full text-xs text-gray-800 border border-gray-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-indigo-500 font-mono font-medium"
                  placeholder="0912 345 678"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                />
              </div>

              <div className="border-t border-gray-100 pt-4 flex justify-end gap-3.5">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="text-xs bg-gray-100 text-gray-600 px-4 py-2.5 rounded-xl font-bold cursor-pointer"
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  className="text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl font-bold cursor-pointer shadow-xs"
                >
                  Tạo mới
                </button>
              </div>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
