import React, { useState, useMemo } from 'react';
import { 
  CheckCircle, 
  AlertTriangle, 
  Search, 
  CornerDownRight, 
  User, 
  CreditCard, 
  Calendar, 
  Clock, 
  Check, 
  Coins, 
  Ban, 
  TrendingDown,
  Info
} from 'lucide-react';
import { RefundRequest, Booking } from '../types';

interface RefundsApprovalViewProps {
  refunds: RefundRequest[];
  bookings: Booking[];
  onApproveRefund: (id: string) => void;
}

export default function RefundsApprovalView({ refunds, bookings, onApproveRefund }: RefundsApprovalViewProps) {
  const [filterQuery, setFilterQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'pending' | 'all'>('pending');

  // Filter refunds based on selection and search
  const filteredRefunds = useMemo(() => {
    let list = refunds;
    if (activeTab === 'pending') {
      list = refunds.filter(r => r.status === 'Refund_Pending');
    }
    
    if (filterQuery.trim() !== '') {
      const q = filterQuery.toLowerCase();
      list = list.filter(r => 
        r.id.toLowerCase().includes(q) ||
        r.bookingId.toLowerCase().includes(q) ||
        r.customerName.toLowerCase().includes(q) ||
        r.bankName.toLowerCase().includes(q) ||
        r.accountNumber.toLowerCase().includes(q) ||
        r.accountHolder.toLowerCase().includes(q)
      );
    }
    return list;
  }, [refunds, activeTab, filterQuery]);

  // Calculations for dashboard indicators
  const totalPendingAmount = useMemo(() => {
    return refunds
      .filter(r => r.status === 'Refund_Pending')
      .reduce((sum, r) => sum + r.amount, 0);
  }, [refunds]);

  const pendingCount = useMemo(() => {
    return refunds.filter(r => r.status === 'Refund_Pending').length;
  }, [refunds]);

  const completedCount = useMemo(() => {
    return refunds.filter(r => r.status === 'Cancelled').length;
  }, [refunds]);

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Top Banner & Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-gray-900 font-sans">
            Màn hình Xét duyệt Hoàn tiền
          </h1>
          <p className="text-xs text-gray-500 mt-1 font-medium">
            Quản lý và phê duyệt các yêu cầu hoàn tiền đặt sân, cập nhật trạng thái giao dịch một cách minh bạch.
          </p>
        </div>

        {/* Small badge count */}
        <div className="flex items-center gap-2 bg-yellow-50 border border-yellow-200 text-yellow-800 px-3 py-1.5 rounded-xl text-xs font-semibold">
          <span className="w-2 h-2 rounded-full bg-yellow-500 animate-ping"></span>
          <span>Có {pendingCount} đơn đang chờ kế toán chuyển khoản thủ công</span>
        </div>
      </div>

      {/* Metric Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        <div id="stat-pending-refunds" className="bg-white p-5 border border-gray-100 rounded-2xl shadow-xs relative overflow-hidden">
          <div className="absolute right-4 top-4 w-9 h-9 rounded-xl bg-amber-50 flex items-center justify-center text-amber-500">
            <Coins size={18} />
          </div>
          <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">Tổng tiền chờ hoàn</span>
          <p className="text-2xl font-extrabold text-amber-600 font-mono mt-1.5">
            {totalPendingAmount.toLocaleString('vi-VN')}đ
          </p>
          <div className="text-[10px] text-gray-400 mt-1">
            Cần chuyển khoản thủ công cho khách hàng
          </div>
        </div>

        <div id="stat-pending-count" className="bg-white p-5 border border-gray-100 rounded-2xl shadow-xs relative overflow-hidden">
          <div className="absolute right-4 top-4 w-9 h-9 rounded-xl bg-rose-50 flex items-center justify-center text-rose-500">
            <AlertTriangle size={18} />
          </div>
          <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">Số đơn chờ duyệt</span>
          <p className="text-2xl font-extrabold text-rose-600 font-mono mt-1.5">
            {pendingCount} đơn
          </p>
          <div className="text-[10px] text-gray-400 mt-1">
            Đang ở trạng thái <code className="bg-amber-50 px-1 py-0.5 rounded text-amber-700 font-bold ml-1">Refund_Pending</code>
          </div>
        </div>

        <div id="stat-completed-refunds" className="bg-white p-5 border border-gray-100 rounded-2xl shadow-xs relative overflow-hidden">
          <div className="absolute right-4 top-4 w-9 h-9 rounded-xl bg-emerald-50 flex items-center justify-center text-emerald-500">
            <CheckCircle size={18} />
          </div>
          <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">Tổng số đã hoàn trả</span>
          <p className="text-2xl font-extrabold text-gray-900 font-mono mt-1.5">
            {completedCount} đơn
          </p>
          <div className="text-[10px] text-gray-400 mt-1">
            Đã chuyển khoản và đổi sang trạng thái <code className="bg-emerald-50 px-1 py-0.5 rounded text-emerald-700 font-bold ml-1">Cancelled</code>
          </div>
        </div>
      </div>

      {/* Procedure Guidelines */}
      <div className="bg-amber-50/70 border border-amber-200/40 text-amber-900 p-4 rounded-2xl flex items-start gap-3.5">
        <Info className="text-amber-600 shrink-0 mt-0.5" size={18} />
        <div className="text-xs space-y-1">
          <p className="font-extrabold uppercase tracking-wide">Quy trình xử lý hoàn tiền cho Kế toán:</p>
          <ul className="list-decimal pl-4 space-y-1 text-amber-800 leading-relaxed font-medium">
            <li>Sao chép số tài khoản & tên ngân hàng của khách trong bảng danh sách phía dưới.</li>
            <li>Thực hiện <b>chuyển khoản thủ công</b> từ thiết bị/ứng dụng ngân hàng của cơ sở.</li>
            <li>Bấm nút <b className="text-indigo-700">"Đã hoàn tiền"</b> dưới đây để hệ thống tự động cập nhật trạng thái đơn sang <span className="bg-slate-200 px-1 py-0.2 rounded font-normal text-slate-800">Cancelled</span> và ghi nhận giao dịch thành công.</li>
          </ul>
        </div>
      </div>

      {/* Main Table Area */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-xs overflow-hidden">
        {/* Controls header */}
        <div className="p-4 sm:p-5 border-b border-gray-100 flex flex-col sm:flex-row items-center justify-between gap-4">
          {/* Sub tabs filtering */}
          <div className="flex bg-slate-100 p-0.5 rounded-xl border border-slate-200/40 shrink-0">
            <button
              onClick={() => setActiveTab('pending')}
              className={`px-4 py-2 rounded-lg text-xs font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                activeTab === 'pending'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-gray-500 hover:text-slate-900'
              }`}
            >
              <span>Chờ hoàn tiền</span>
              {pendingCount > 0 && (
                <span className="px-1.5 py-0.5 rounded-full bg-red-500 text-white text-[9px] font-mono font-black animate-pulse">
                  {pendingCount}
                </span>
              )}
            </button>
            <button
              onClick={() => setActiveTab('all')}
              className={`px-4 py-2 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                activeTab === 'all'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-gray-500 hover:text-slate-900'
              }`}
            >
              Tất cả lịch sử hoàn tiền
            </button>
          </div>

          {/* Search box */}
          <div className="relative w-full sm:max-w-xs">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={14} />
            <input
              type="text"
              placeholder="Tìm kiếm khách hàng, ngân hàng..."
              value={filterQuery}
              onChange={(e) => setFilterQuery(e.target.value)}
              className="w-full text-xs pl-9 pr-4 py-2 rounded-xl bg-slate-50 border border-slate-200 placeholder-gray-400 focus:outline-none focus:border-indigo-500 focus:bg-white transition-all font-medium"
            />
          </div>
        </div>

        {/* Records list */}
        {filteredRefunds.length === 0 ? (
          <div className="p-16 text-center text-slate-400 space-y-4">
            <div className="w-16 h-16 rounded-full bg-indigo-50 flex items-center justify-center text-indigo-500 mx-auto">
              <CheckCircle size={32} />
            </div>
            <div className="max-w-md mx-auto space-y-1">
              <p className="font-bold text-gray-800 text-sm">Danh sách sạch hoàn toàn!</p>
              <p className="text-xs text-gray-500">
                {activeTab === 'pending' 
                  ? 'Hiện thời không có bất kỳ lệnh hoàn tiền nào đang ở trạng thái chờ duyệt.' 
                  : 'Không tìm thấy kết quả giao dịch hoàn tiền nào khớp với bộ lọc tìm kiếm.'}
              </p>
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="bg-slate-50 text-gray-400 font-extrabold uppercase tracking-wider border-b border-gray-100">
                  <th className="px-6 py-4">Mã Refund / Đơn Đặt</th>
                  <th className="px-6 py-4">Sân Bãi & Thời Gian</th>
                  <th className="px-6 py-4">Khách Hàng</th>
                  <th className="px-6 py-4">Thông Tin Nhận Tiền</th>
                  <th className="px-6 py-4 text-right">Số Tiền Hoàn</th>
                  <th className="px-6 py-4 text-center">Trạng Thái</th>
                  <th className="px-6 py-4 text-center">Xác Nhận</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 font-medium text-gray-600">
                {filteredRefunds.map((ref) => {
                  const isPending = ref.status === 'Refund_Pending';
                  
                  return (
                    <tr key={ref.id} className="hover:bg-slate-50/40 transition-colors">
                      {/* ID info */}
                      <td className="px-6 py-4">
                        <div className="space-y-0.5">
                          <span className="font-bold text-slate-900 font-mono text-xs block">
                            {ref.id}
                          </span>
                          <div className="flex items-center gap-1 text-[10px] text-gray-400">
                            <CornerDownRight size={10} className="text-gray-300" />
                            <span>Mã lịch đặt: <b className="font-mono text-gray-600 font-bold">{ref.bookingId}</b></span>
                          </div>
                        </div>
                      </td>

                      {/* Court & Slot */}
                      <td className="px-6 py-4">
                        <div className="space-y-1">
                          <span className="font-bold text-gray-800 block text-xs">
                            {ref.courtName}
                          </span>
                          <div className="flex items-center gap-1.5 text-[10px] text-gray-500 font-medium whitespace-nowrap">
                            <span className="flex items-center gap-1">
                              <Calendar size={11} className="text-gray-400" />
                              {ref.date}
                            </span>
                            <span className="flex items-center gap-1 border-l border-gray-200 pl-1.5">
                              <Clock size={11} className="text-gray-400" />
                              {ref.timeSlot}
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* Customer Name */}
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <div className="w-7 h-7 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center font-bold text-[10px]">
                            {ref.customerName.charAt(0)}
                          </div>
                          <div>
                            <span className="font-semibold text-gray-900 block text-xs">
                              {ref.customerName}
                            </span>
                            <span className="text-[10px] text-gray-400 block font-mono">
                              Khách đặt qua app
                            </span>
                          </div>
                        </div>
                      </td>

                      {/* Banking Details */}
                      <td className="px-6 py-4">
                        <div className="space-y-1">
                          <div className="flex items-center gap-1.5">
                            <span className="bg-indigo-50 border border-indigo-100 text-indigo-700 font-sans font-extrabold text-[10px] px-2 py-0.5 rounded-md shadow-2xs">
                              {ref.bankName}
                            </span>
                            <span className="text-slate-800 font-mono font-bold text-xs">
                              {ref.accountNumber}
                            </span>
                          </div>
                          <p className="text-[10px] text-gray-400 uppercase font-black tracking-wider flex items-center gap-1">
                            <User size={10} className="text-gray-300" />
                            Chủ thẻ: {ref.accountHolder}
                          </p>
                        </div>
                      </td>

                      {/* Money Amount */}
                      <td className="px-6 py-4 text-right">
                        <div className="space-y-0.5">
                          <span className="font-bold font-mono text-sm text-red-600">
                            -{ref.amount.toLocaleString('vi-VN')}đ
                          </span>
                          <span className="text-[9px] text-gray-400 uppercase font-bold block">
                            Đã cọc 100%
                          </span>
                        </div>
                      </td>

                      {/* Status Badging */}
                      <td className="px-6 py-2 text-center">
                        {isPending ? (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold bg-amber-50 border border-amber-200 text-amber-700 animate-pulse">
                            <span className="w-1.5 h-1.5 rounded-full bg-amber-500"></span>
                            Chờ hoàn tiền
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold bg-emerald-50 border border-emerald-100 text-emerald-800">
                            <Check size={11} className="text-emerald-600" />
                            Đã hoàn (Cancelled)
                          </span>
                        )}
                      </td>

                      {/* Action Button */}
                      <td className="px-6 py-4 text-center">
                        {isPending ? (
                          <button
                            onClick={() => onApproveRefund(ref.id)}
                            className="bg-indigo-600 hover:bg-indigo-700 text-white font-extrabold text-[10px] px-3 py-2 rounded-xl inline-flex items-center gap-1.5 transition-all shadow-xs shrink-0 cursor-pointer border border-indigo-700"
                          >
                            <CheckCircle size={12} />
                            Đã hoàn tiền
                          </button>
                        ) : (
                          <span className="text-gray-400 text-[10px] font-semibold italic">
                            Đã đối soát xong
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
