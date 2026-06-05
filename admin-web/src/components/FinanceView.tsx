import React, { useState, useMemo } from 'react';
import { CreditCard, ArrowLeftRight, CheckCircle, TrendingUp, Download, Receipt, Users, Clock, AlertTriangle } from 'lucide-react';
import { RefundRequest, Booking } from '../types';

interface FinanceViewProps {
  refunds: RefundRequest[];
  bookings: Booking[];
  onApproveRefund: (id: string) => void;
}

export default function FinanceView({ refunds, bookings, onApproveRefund }: FinanceViewProps) {
  const [activeFinanceTab, setActiveFinanceTab] = useState<'reports' | 'refunds'>('reports');
  const [reportRange, setReportRange] = useState<'week' | 'month' | 'year'>('month');

  // Real statistics derived from database
  const currentStats = useMemo(() => {
    const completedBookings = bookings.filter((b) => b.status === 'Completed' || b.status === 'Confirmed');
    
    const totalRevenue = completedBookings.reduce((sum, b) => sum + (b.totalAmount || 0), 0);
    const walkinRevenue = completedBookings.filter(b => b.customerType === 'Walkin' || (b.customerName || '').includes('Cố định')).reduce((sum, b) => sum + (b.totalAmount || 0), 0);
    const appRevenue = completedBookings.filter(b => b.customerType === 'App' && !(b.customerName || '').includes('Cố định')).reduce((sum, b) => sum + (b.totalAmount || 0), 0);
    
    // Refunds amounts could be negative or positive in DB, so we use absolute value for summation
    const totalRefunds = refunds.reduce((sum, r) => sum + Math.abs(r.amount), 0);
    
    const profit = totalRevenue - totalRefunds;
    const margin = totalRevenue > 0 ? ((profit / totalRevenue) * 100).toFixed(1) + '%' : '0%';
    
    return {
      revenue: totalRevenue,
      walkinRevenue,
      appRevenue,
      refunds: totalRefunds,
      profit: profit,
      margin: margin,
      orders: bookings.length
    };
  }, [bookings, refunds]);

  // Dynamic calculation of completed and confirmed bookings
  const completedBookings = useMemo(() => {
    return bookings.filter((b) => b.status === 'Completed' || b.status === 'Confirmed');
  }, [bookings]);

  // Real database dynamic trends based on report range
  const activeTrends = useMemo(() => {
    if (reportRange === 'week') {
      const bins = [
        { label: 'T2', dayNum: 1, value: 0 },
        { label: 'T3', dayNum: 2, value: 0 },
        { label: 'T4', dayNum: 3, value: 0 },
        { label: 'T5', dayNum: 4, value: 0 },
        { label: 'T6', dayNum: 5, value: 0 },
        { label: 'T7', dayNum: 6, value: 0 },
        { label: 'CN', dayNum: 0, value: 0 },
      ];
      completedBookings.forEach((b) => {
        // Parse the booking date and extract day of week (0 to 6)
        const d = new Date(b.date);
        const day = d.getDay();
        const bin = bins.find((x) => x.dayNum === day);
        if (bin) {
          bin.value += b.totalAmount || 0;
        }
      });
      return bins;
    } else if (reportRange === 'month') {
      const bins = [
        { label: 'Tuần 1', start: 1, end: 7, value: 0 },
        { label: 'Tuần 2', start: 8, end: 14, value: 0 },
        { label: 'Tuần 3', start: 15, end: 21, value: 0 },
        { label: 'Tuần 4', start: 22, end: 31, value: 0 },
      ];
      completedBookings.forEach((b) => {
        const d = new Date(b.date);
        const mDay = d.getDate();
        const bin = bins.find((x) => mDay >= x.start && mDay <= x.end);
        if (bin) {
          bin.value += b.totalAmount || 0;
        }
      });
      return bins;
    } else {
      const bins = [
        { label: 'Quý 1', startMonth: 0, endMonth: 2, value: 0 },
        { label: 'Quý 2', startMonth: 3, endMonth: 5, value: 0 },
        { label: 'Quý 3', startMonth: 6, endMonth: 8, value: 0 },
        { label: 'Quý 4', startMonth: 9, endMonth: 11, value: 0 },
      ];
      completedBookings.forEach((b) => {
        const d = new Date(b.date);
        const m = d.getMonth();
        const bin = bins.find((x) => m >= x.startMonth && m <= x.endMonth);
        if (bin) {
          bin.value += b.totalAmount || 0;
        }
      });
      return bins;
    }
  }, [completedBookings, reportRange]);

  const maxVal = useMemo(() => {
    return Math.max(...activeTrends.map(x => x.value), 1);
  }, [activeTrends]);

  return (
    <div className="space-y-6">
      {/* Sub menu tabs */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-gray-100 pb-2">
        <div className="flex gap-4">
          <button
            onClick={() => setActiveFinanceTab('reports')}
            className={`text-sm font-bold pb-2 cursor-pointer transition-all ${
              activeFinanceTab === 'reports'
                ? 'text-indigo-600 border-b-2 border-indigo-500'
                : 'text-gray-400 hover:text-gray-600'
            }`}
          >
            Báo cáo tài chính (Revenue & Margins)
          </button>
          <button
            onClick={() => setActiveFinanceTab('refunds')}
            className={`text-sm font-bold pb-2 relative cursor-pointer transition-all ${
              activeFinanceTab === 'refunds'
                ? 'text-indigo-600 border-b-2 border-indigo-500'
                : 'text-gray-400 hover:text-gray-600'
            }`}
          >
            Xét duyệt hoàn tiền {refunds.filter(r => r.status === 'Refund_Pending').length > 0 && (
              <span className="absolute -top-1 -right-3.5 w-4 h-4 rounded-full bg-rose-500 text-[9px] font-mono text-white flex items-center justify-center font-bold animate-pulse">
                {refunds.filter(r => r.status === 'Refund_Pending').length}
              </span>
            )}
          </button>
        </div>

        {activeFinanceTab === 'reports' && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-gray-400 font-bold uppercase mr-1">Lọc chu kỳ:</span>
            <div className="flex bg-gray-100 rounded-lg p-0.5 font-sans">
              {(['week', 'month', 'year'] as const).map((r) => (
                <button
                  key={r}
                  onClick={() => setReportRange(r)}
                  className={`px-3 py-1 rounded text-[10px] font-extrabold uppercase transition-all cursor-pointer ${
                    reportRange === r ? 'bg-indigo-600 text-white shadow-xs' : 'text-gray-500 hover:text-gray-900'
                  }`}
                >
                  {r === 'week' ? 'Tuần' : r === 'month' ? 'Tháng' : 'Năm'}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* RENDER TAB 1: REPORTS */}
      {activeFinanceTab === 'reports' && (
        <div className="space-y-6 animate-in fade-in duration-250">
          {/* Summary stats */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-5">
            {/* Revenue card */}
            <div className="bg-white p-5 border border-gray-100 rounded-2xl shadow-xs">
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">Thống kê Doanh thu</span>
              <p className="text-2xl font-extrabold text-gray-900 font-mono mt-1.5">
                {currentStats.revenue.toLocaleString('vi-VN')}đ
              </p>
              <div className="text-[10px] text-indigo-600 pt-1 flex items-center gap-1 font-bold">
                <TrendingUp size={12} />
                <span>+12.5% so với chu kỳ trước</span>
              </div>
            </div>

            {/* Total refunds card */}
            <div className="bg-white p-5 border border-gray-100 rounded-2xl shadow-xs">
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">Tiền Hoàn (Refunds)</span>
              <p className="text-2xl font-extrabold text-rose-600 font-mono mt-1.5">
                {currentStats.refunds.toLocaleString('vi-VN')}đ
              </p>
              <p className="text-[10px] text-gray-400 pt-1">Đã khấu trừ trực tiếp cho đơn huỷ</p>
            </div>

            {/* Profits margins card */}
            <div className="bg-white p-5 border border-gray-100 rounded-2xl shadow-xs">
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">Thực Thu (Net Profit)</span>
              <p className="text-2xl font-extrabold text-indigo-600 font-mono mt-1.5">
                {currentStats.profit.toLocaleString('vi-VN')}đ
              </p>
              <p className="text-[10px] text-gray-400 pt-1">Tỷ lệ biên lợi nhuận ròng: <b>{currentStats.margin}</b></p>
            </div>

            {/* Ticket orders count */}
            <div className="bg-white p-5 border border-gray-100 rounded-2xl shadow-xs">
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">Tổng Số Đơn Đã Xác Nhận</span>
              <p className="text-2xl font-extrabold text-indigo-600 font-mono mt-1.5">
                {currentStats.orders.toLocaleString('vi-VN')} đơn
              </p>
              <p className="text-[10px] text-gray-400 pt-1">Trung bình {currentStats.orders > 0 ? Math.round(currentStats.revenue / currentStats.orders).toLocaleString('vi-VN') : 0}đ / đơn</p>
            </div>
          </div>

          {/* SVG Visual trend line */}
          <div className="bg-white p-6 border border-gray-100 rounded-2xl shadow-xs space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-bold text-gray-800 uppercase tracking-widest">Biến động thực thu trong chu kỳ</h3>
                <p className="text-[10px] text-gray-400 font-medium">Biểu đồ so sánh và tăng trưởng ròng</p>
              </div>
              <button className="text-[10px] font-bold bg-slate-100 text-gray-700 px-3 py-1.5 rounded-lg hover:bg-slate-200 transition-all flex items-center gap-1.5 cursor-pointer">
                <Download size={13} /> Export PDF
              </button>
            </div>

            {/* Simple responsive visual chart bars */}
            <div className="h-64 flex items-end justify-between px-4 sm:px-8 border-b border-gray-100/80 relative pt-8 font-sans">
              {/* grid helper lines */}
              <div className="absolute left-0 right-0 top-0 border-t border-dashed border-gray-100/80"></div>
              <div className="absolute left-0 right-0 top-1/3 border-t border-dashed border-gray-100/80"></div>
              <div className="absolute left-0 right-0 top-2/3 border-t border-dashed border-gray-100/80"></div>

              {activeTrends.map((t) => {
                const isPeak = t.value === maxVal && t.value > 0;
                const heightPercent = t.value > 0 ? `${(t.value / maxVal) * 85 + 15}%` : '8%';
                
                // Emerald (green) premium financial gradient mapping for revenue
                const barFill = isPeak
                  ? 'bg-gradient-to-t from-emerald-600 to-emerald-500 border border-emerald-400/40 shadow-xs'
                  : t.value > maxVal * 0.7
                  ? 'bg-gradient-to-t from-emerald-500 to-emerald-400 border border-emerald-300/30'
                  : t.value > maxVal * 0.4
                  ? 'bg-gradient-to-t from-emerald-400 to-emerald-300'
                  : t.value > maxVal * 0.2
                  ? 'bg-gradient-to-t from-emerald-300 to-emerald-200'
                  : t.value > 0
                  ? 'bg-emerald-100'
                  : 'bg-gray-50 border border-gray-100/40';

                return (
                  <div key={t.label} className="flex flex-col justify-end items-center gap-2 group flex-1 z-1 relative h-full pb-1 cursor-pointer">
                    {/* Vertical line indicator */}
                    {isPeak && (
                      <div className="absolute top-0 bottom-0 left-1/2 -translate-x-1/2 w-0.5 bg-emerald-50/60 z-0 h-full border-dashed border-l-2 border-emerald-200/50" style={{ opacity: 0.6 }} />
                    )}
                    {/* Tooltip on hover */}
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity absolute -top-10 bg-gray-950 text-white text-[10px] px-2.5 py-1.5 rounded-lg shadow-md font-mono pointer-events-none z-20 transition-all duration-200 transform group-hover:scale-105">
                      {t.value.toLocaleString('vi-VN')} VNĐ
                    </div>
                    {/* Bar */}
                    <div
                      style={{ height: heightPercent }}
                      className={`w-8 sm:w-16 rounded-t-lg transition-all duration-300 hover:brightness-95 cursor-pointer relative flex justify-center shadow-xs z-10 w-full max-w-[64px] ${barFill}`}
                    >
                      {isPeak && (
                        <span className="absolute -top-7 text-[10px] text-emerald-700 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full font-bold whitespace-nowrap z-20 shadow-xs">
                          📈 CAO NHẤT
                        </span>
                      )}
                    </div>
                    <span className={`text-[10px] text-gray-400 font-semibold mt-1 ${isPeak ? 'text-emerald-600 font-bold' : ''}`}>{t.label}</span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Financial details table */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-xs overflow-hidden">
            <div className="p-4 border-b border-gray-100 font-bold text-gray-800 text-sm">
              Sổ Cái Giao Dịch Chi Tiết
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="bg-slate-50 border-b border-gray-100 text-gray-400 font-bold uppercase tracking-wider">
                    <th className="px-6 py-4">Hạng mục chi thu</th>
                    <th className="px-6 py-4">Phương thức</th>
                    <th className="px-6 py-4 font-mono">Doanh thu tạm tính</th>
                    <th className="px-6 py-4 font-mono">Tiền cọc hoàn trả</th>
                    <th className="px-6 py-4 font-mono text-right">Lợi Nhuận Thực</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 font-medium text-gray-600">
                  <tr className="hover:bg-slate-50/50">
                    <td className="px-6 py-4 font-bold text-gray-800">Đặt lịch thu ngân tại quầy (Staff)</td>
                    <td className="px-6 py-4">Thu Tiền Mặt / In QR</td>
                    <td className="px-6 py-4 font-mono">{currentStats.walkinRevenue.toLocaleString('vi-VN')} VNĐ</td>
                    <td className="px-6 py-4 font-mono">---</td>
                    <td className="px-6 py-4 font-mono text-right text-indigo-600 font-bold">+{currentStats.walkinRevenue.toLocaleString('vi-VN')} VNĐ</td>
                  </tr>
                  <tr className="hover:bg-slate-50/50">
                    <td className="px-6 py-4 font-bold text-gray-800">Khách lẻ đặt trực tuyến qua App Mobile</td>
                    <td className="px-6 py-4">VietQR MB Bank BankHub</td>
                    <td className="px-6 py-4 font-mono">{currentStats.appRevenue.toLocaleString('vi-VN')} VNĐ</td>
                    <td className="px-6 py-4 font-mono">---</td>
                    <td className="px-6 py-4 font-mono text-right text-indigo-600 font-bold">+{currentStats.appRevenue.toLocaleString('vi-VN')} VNĐ</td>
                  </tr>
                  <tr className="hover:bg-slate-50/50">
                    <td className="px-6 py-4 font-bold text-gray-800">Hủy sân bãi / Báo nghỉ (Khách vãng lai & App)</td>
                    <td className="px-6 py-4">Chuyển khoản thủ công</td>
                    <td className="px-6 py-4 font-mono">---</td>
                    <td className="px-6 py-4 font-mono text-rose-500">{(currentStats.refunds).toLocaleString('vi-VN')} VNĐ</td>
                    <td className="px-6 py-4 font-mono text-right text-rose-600 font-bold">-{(currentStats.refunds).toLocaleString('vi-VN')} VNĐ</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* RENDER TAB 2: REFUND APPROVALS */}
      {activeFinanceTab === 'refunds' && (
        <div className="space-y-6 animate-in fade-in duration-250">
          <div className="bg-amber-50 border border-amber-200/50 text-amber-900 p-4 rounded-2xl flex items-start gap-3.5">
            <AlertTriangle className="text-amber-600 shrink-0 mt-0.5" size={20} />
            <div className="text-xs space-y-1">
              <p className="font-bold uppercase tracking-wider">Hạ tầng ngân hàng và Quy trình đối soát</p>
              <p className="leading-relaxed text-amber-800">
                Khi người chơi yêu cầu hủy đơn qua chuyển khoản ngân hàng, hệ thống đưa đơn sang trạng thái <b>Refund_Pending (Chờ hoàn)</b>.
                Bộ phận Kế toán thực hiện chuyển khoản thủ công bằng tài khoản của cơ sở, sau đó bấm nút <b>"Đã hoàn tiền"</b> để cập nhật dữ liệu Cancelled và thông báo khách hàng.
              </p>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-gray-100 shadow-xs overflow-hidden">
            {refunds.filter(r => r.status === 'Refund_Pending').length === 0 ? (
              <div className="p-12 text-center text-slate-400 space-y-3">
                <CheckCircle className="text-indigo-500 mx-auto" size={42} />
                <div>
                  <p className="font-bold text-gray-800">Sạch danh sách chờ duyệt!</p>
                  <p className="text-xs">Tất cả các lệnh hoàn tiền đã được kế toán cơ sở đối soát.</p>
                </div>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-slate-50 border-b border-gray-100 text-gray-400 font-bold uppercase tracking-widest pl-4">
                      <th className="px-6 py-4">Đơn đặt / Sân</th>
                      <th className="px-6 py-4">Tên Khách hàng</th>
                      <th className="px-6 py-4">Thông tin ngân hàng</th>
                      <th className="px-6 py-4 font-mono text-center">Số tiền hoàn</th>
                      <th className="px-6 py-4 text-center">Hành động của Kế toán</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {refunds.filter(r => r.status === 'Refund_Pending').map((ref) => (
                      <tr key={ref.id} className="hover:bg-slate-50/40 transition-all">
                        {/* Court info */}
                        <td className="px-6 py-4">
                          <div className="space-y-1">
                            <span className="font-bold text-gray-800 block text-xs">{ref.bookingId}</span>
                            <span className="text-[10px] text-gray-400 font-medium block">
                              {ref.courtName} ({ref.timeSlot})
                            </span>
                            <span className="text-[9px] font-semibold text-slate-400 font-mono block">
                              Chơi ngày: {ref.date}
                            </span>
                          </div>
                        </td>

                        {/* Customer */}
                        <td className="px-6 py-4 font-semibold text-gray-900">
                          {ref.customerName}
                        </td>

                        {/* Bank particulars */}
                        <td className="px-6 py-4 space-y-1">
                          <div className="flex items-center gap-1">
                            <span className="bg-indigo-50 text-indigo-700 text-[10px] font-bold px-1.5 py-0.5 rounded-sm">
                              {ref.bankName}
                            </span>
                            <b className="text-slate-900 font-mono text-xs">{ref.accountNumber}</b>
                          </div>
                          <p className="text-[10px] text-gray-400 uppercase font-semibold">
                            Chủ thẻ: {ref.accountHolder}
                          </p>
                        </td>

                        {/* Amount */}
                        <td className="px-6 py-4 text-center font-bold font-mono text-sm text-rose-600">
                          {ref.amount.toLocaleString('vi-VN')}đ
                        </td>

                        {/* Actions */}
                        <td className="px-6 py-4 text-center">
                          <button
                            onClick={() => {
                              onApproveRefund(ref.id);
                              alert(`Kế toán xác nhận: Đơn hoàn tiền ${ref.id} trị giá ${ref.amount.toLocaleString('vi-VN')}đ đã được chuyển khoản và cập nhật thành công!`);
                            }}
                            className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-[10px] px-3.5 py-2 rounded-xl flex items-center justify-center gap-1.5 mx-auto transition-all shadow-xs shrink-0 cursor-pointer border border-indigo-700"
                          >
                            <CheckCircle size={12} />
                            Đã hoàn tiền
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
