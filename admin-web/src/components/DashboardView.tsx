import React, { useMemo, useState } from 'react';
import { TrendingUp, Users, DollarSign, BookOpen, Clock, AlertCircle } from 'lucide-react';
import { Booking, Court, Customer } from '../types';

interface DashboardViewProps {
  selectedDateISO?: string;
  bookings: Booking[];
  courts: Court[];
  customers: Customer[];
  refundsCount: number;
}

export default function DashboardView({ selectedDateISO, bookings, courts, customers, refundsCount }: DashboardViewProps) {
  // Real calculations
  
  const fallbackDate = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`;
  const targetDate = selectedDateISO || fallbackDate;
  const todaysBookings = useMemo(() => bookings.filter(b => b.date === targetDate), [bookings, targetDate]);
  const activeCourtsCount = useMemo(() => courts.filter(c => c.isActive).length, [courts]);
  
  const confirmedAndCompleted = bookings.filter(b => b.status === 'Confirmed' || b.status === 'Completed');
  const realRevenue = confirmedAndCompleted.reduce((sum, b) => sum + (b.totalAmount || 0), 0);

  const confirmedAndCompletedToday = todaysBookings.filter(b => b.status === 'Confirmed' || b.status === 'Completed');
  const realRevenueToday = confirmedAndCompletedToday.reduce((sum, b) => sum + (b.totalAmount || 0), 0);
  
  const totalBookingsCount = bookings.length;

  // Parse time "HH:mm" to minutes
  const timeToMinutes = (time?: string) => {
    if (!time) return 0;
    const [h, m] = time.split(':').map(Number);
    return (h || 0) * 60 + (m || 0);
  };

  // Occupancy rate calculation
  // Assume operating hours from 05:00 to 24:00 (19 hours = 1140 minutes per active court)
  const totalOperatingMinutes = activeCourtsCount * 19 * 60; 
  const totalBookedMinutes = confirmedAndCompletedToday.reduce((sum, b) => {
    let duration = timeToMinutes(b.endTime) - timeToMinutes(b.startTime);
    // Handle overnight bookings or when endTime is "00:00" or next day
    if (duration <= -12 * 60) {
      // e.g. start at 23:00, end at 01:00 -> duration = -1320 + 1440 = 120
      duration += 24 * 60; 
    }
    // Prevent negative duration anomalies from flawed data entry
    if (duration < 0) duration = 0;
    return sum + duration;
  }, 0);
  
  const occupancyPercentage = totalOperatingMinutes > 0 
    ? Math.max(0, Math.round((totalBookedMinutes / totalOperatingMinutes) * 100)) 
    : 0;

  const occupancyRate = `${occupancyPercentage}%`;

  // Filter type for the Busy Hours chart: 'all' (entire database bookings) OR 'today' (selected day only)
  const [filterType, setFilterType] = useState<'today' | 'all'>('all');

  // Calculating hour distribution
  // We'll define bins matching the original UI peaks if possible, or just standard 3-hour bins
  const hourBins = useMemo(() => [
    { hour: '05:00', start: 5, end: 7 },
    { hour: '08:00', start: 8, end: 10 },
    { hour: '11:00', start: 11, end: 13 },
    { hour: '14:00', start: 14, end: 16 },
    { hour: '17:00', start: 17, end: 19 },
    { hour: '20:00', start: 20, end: 22 },
    { hour: '23:00', start: 23, end: 24 }
  ], []);

  const activeBookingsForChart = useMemo(() => {
    if (filterType === 'today') {
      return confirmedAndCompletedToday;
    } else {
      return confirmedAndCompleted;
    }
  }, [filterType, confirmedAndCompletedToday, confirmedAndCompleted]);

  const binCounts = useMemo(() => {
    return hourBins.map(bin => {
      let count = 0;
      activeBookingsForChart.forEach(b => {
        const hStr = b.startTime.split(':')[0];
        const h = parseInt(hStr, 10);
        if (h >= bin.start && h <= bin.end) {
          count += 1;
        }
      });
      return count;
    });
  }, [activeBookingsForChart, hourBins]);

  const maxCount = useMemo(() => Math.max(...binCounts, 1), [binCounts]); // avoid div by 0

  const hourData = useMemo(() => {
    return hourBins.map((bin, index) => {
      const count = binCounts[index];
      const isPeak = count === maxCount && count > 0;
      return {
        hour: bin.hour,
        count: count,
        fill: isPeak ? 'bg-gradient-to-t from-indigo-600 to-indigo-500 border border-indigo-400' : 
              count > maxCount * 0.7 ? 'bg-gradient-to-t from-indigo-500 to-indigo-400' : 
              count > maxCount * 0.4 ? 'bg-gradient-to-t from-indigo-400 to-indigo-300' :
              count > maxCount * 0.2 ? 'bg-gradient-to-t from-indigo-300 to-indigo-200' :
              count > 0 ? 'bg-indigo-100' : 'bg-gray-50 border border-gray-100/40',
        isPeak
      };
    });
  }, [hourBins, binCounts, maxCount]);

  const peakBin = useMemo(() => hourData.find(d => d.isPeak), [hourData]);
  const peakHours = peakBin ? `${peakBin.hour} - ${String(Number(peakBin.hour.split(':')[0]) + 3).padStart(2, '0')}:00` : "Chưa có";

  // Other statuses
  const fixedBookingsCount = todaysBookings.filter(b => (b.customerName || '').toLowerCase().includes('cố định')).length;

  return (
    <div className="space-y-6">
      {/* Header section with description */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Thống kê chi tiết</h1>
        <p className="text-sm text-gray-500">Quản lý và theo dõi thông tin tổng thể của hệ thống sân chơi.</p>
      </div>

      {/* Stats Cards Row */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-5">
        {/* Doanh thu Card */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-xs flex items-start justify-between">
          <div className="space-y-2">
            <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Doanh Thu</span>
            <div className="text-2xl font-bold text-gray-900 tracking-tight flex items-baseline gap-1">
              {realRevenue.toLocaleString('vi-VN')}đ
              <span className="text-xs text-indigo-500 font-medium font-mono">+{realRevenueToday.toLocaleString('vi-VN')}đ hôm nay</span>
            </div>
            <div className="flex items-center gap-1.5 pt-1 text-xs text-indigo-600 font-medium">
              <TrendingUp size={14} />
              <span>+12.5% so với tháng trước</span>
            </div>
          </div>
          <div className="bg-indigo-50 p-3 rounded-xl text-indigo-600">
            <DollarSign size={20} />
          </div>
        </div>

        {/* Tổng số Đơn Card */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-xs flex items-start justify-between">
          <div className="space-y-2">
            <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Số Đơn Đặt</span>
            <div className="text-2xl font-bold text-gray-900 tracking-tight flex items-baseline gap-1">
              {totalBookingsCount.toLocaleString('vi-VN')}
              <span className="text-xs text-indigo-500 font-medium">+{todaysBookings.length} hôm nay</span>
            </div>
            <div className="flex items-center gap-1.5 pt-1 text-xs text-indigo-600 font-medium font-sans">
              <TrendingUp size={14} />
              <span>+8.2% so với tháng trước</span>
            </div>
          </div>
          <div className="bg-slate-100 p-3 rounded-xl text-indigo-600">
            <BookOpen size={20} />
          </div>
        </div>

        {/* Tỷ lệ lấp đầy */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-xs flex items-start justify-between">
          <div className="space-y-2">
            <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tỷ lệ lấp đầy hôm nay</span>
            <div className="text-2xl font-bold text-gray-900 tracking-tight">{occupancyRate}</div>
            <p className="text-xs text-gray-400 font-medium">Dựa trên {activeCourtsCount} sân hoạt động</p>
          </div>
          <div className="bg-amber-50 p-3 rounded-xl text-amber-600">
            <Clock size={20} />
          </div>
        </div>

        {/* Đang chờ cọc/hoàn tiền */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-xs flex items-start justify-between">
          <div className="space-y-2">
            <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Yêu cầu hoàn tiền</span>
            <div className="text-2xl font-bold text-rose-600 tracking-tight">
              {refundsCount} <span className="text-xs text-gray-400 font-semibold">đang chờ duyệt</span>
            </div>
            <p className="text-xs text-rose-500 font-medium flex items-center gap-1">
              <AlertCircle size={12} />
              <span>Cần kế toán đối soát thủ công</span>
            </p>
          </div>
          <div className="bg-rose-50 p-3 rounded-xl text-rose-600 border border-rose-100">
            <AlertCircle size={20} />
          </div>
        </div>
      </div>

      {/* Peak hour Column Chart Block */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Chart */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-xs lg:col-span-2 space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-lg font-bold text-gray-900 tracking-tight">Khung giờ đông khách</h2>
              <p className="text-xs text-gray-500">Thống kê mật độ người chơi theo các mốc phục vụ trong ngày</p>
            </div>
            
            {/* Database & Today Toggle Filter */}
            <div className="flex bg-gray-100/80 p-0.5 rounded-xl border border-gray-200/50 self-start sm:self-center">
              <button
                type="button"
                onClick={() => setFilterType('today')}
                className={`text-xs px-3.5 py-1.5 rounded-lg font-medium transition-all duration-200 ${
                  filterType === 'today'
                    ? 'bg-white text-indigo-600 shadow-xs ring-1 ring-black/5'
                    : 'text-gray-500 hover:text-gray-900'
                }`}
              >
                Hôm nay
              </button>
              <button
                type="button"
                onClick={() => setFilterType('all')}
                className={`text-xs px-3.5 py-1.5 rounded-lg font-medium transition-all duration-200 ${
                  filterType === 'all'
                    ? 'bg-white text-indigo-600 shadow-xs ring-1 ring-black/5'
                    : 'text-gray-500 hover:text-gray-900'
                }`}
              >
                Tất cả (Database)
              </button>
            </div>
          </div>

          {/* Graphical Visualizer */}
          <div className="pt-4 pb-2">
            {/* The columns container */}
            <div className="h-64 flex items-end justify-between px-4 sm:px-8 border-b border-gray-100 relative">
              {/* grid helper lines */}
              <div className="absolute left-0 right-0 top-0 border-t border-dashed border-gray-100/80"></div>
              <div className="absolute left-0 right-0 top-1/3 border-t border-dashed border-gray-100/80"></div>
              <div className="absolute left-0 right-0 top-2/3 border-t border-dashed border-gray-100/80"></div>

              {hourData.map((d) => {
                const heightPercent = d.count > 0 ? `${(d.count / maxCount) * 85 + 15}%` : '8%';
                const isPeak = d.isPeak;
                return (
                  <div key={d.hour} className="flex flex-col justify-end items-center gap-2 group flex-1 z-1 relative h-full pb-1">
                    {/* Vertical line indicator */}
                    {isPeak && (
                      <div className="absolute top-0 bottom-0 left-1/2 -translate-x-1/2 w-0.5 bg-indigo-50/60 z-0 h-full border-dashed border-l-2 border-indigo-200" style={{ opacity: 0.6 }} />
                    )}
                    {/* Tooltip on hover */}
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity absolute -top-10 bg-gray-950 text-white text-[10px] px-2.5 py-1.5 rounded-lg shadow-md font-mono pointer-events-none z-20 transition-all duration-200 transform group-hover:scale-105">
                      {d.count} lượt đặt
                    </div>
                    {/* Bar */}
                    <div
                      style={{ height: heightPercent }}
                      className={`w-8 sm:w-12 rounded-t-lg transition-all duration-300 ${d.fill} hover:brightness-95 cursor-pointer relative flex justify-center shadow-xs z-10 w-full max-w-[48px]`}
                    >
                      {isPeak && (
                        <span className="absolute -top-7 text-[10px] text-indigo-700 bg-indigo-50 border border-indigo-200 px-2 py-0.5 rounded-full font-bold whitespace-nowrap z-20 shadow-xs">
                          🔥 CAO ĐIỂM
                        </span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Labels under chart */}
            <div className="flex items-center justify-between px-4 sm:px-8 pt-3 text-xs text-gray-400 font-mono">
              {hourData.map((d) => (
                <span
                  key={d.hour}
                  className={`w-8 sm:w-12 text-center text-xs ${d.isPeak ? 'text-indigo-600 font-bold' : ''}`}
                >
                  {d.hour}
                </span>
              ))}
            </div>
          </div>
        </div>

        {/* Right 1 Col: Quick Status Indicators & Live logs */}
        <div className="bg-white p-6 rounded-2xl border border-gray-100 shadow-xs space-y-5">
          <h2 className="text-base font-bold text-gray-900 tracking-tight">Trạng thái vận hành</h2>
          
          <div className="space-y-4">
            {/* Status 1 */}
            <div className="flex items-center justify-between p-3.5 bg-slate-50 rounded-xl">
              <div className="flex items-center gap-3">
                <span className="w-2.5 h-2.5 bg-emerald-500 rounded-full animate-pulse"></span>
                <span className="text-xs font-semibold text-gray-700">{activeCourtsCount} sân đang hoạt động</span>
              </div>
              <span className="text-[10px] font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md">Bình thường</span>
            </div>

            {/* Status 2 */}
            <div className="flex items-center justify-between p-3.5 bg-slate-50 rounded-xl">
              <div className="flex items-center gap-3">
                <span className="w-2.5 h-2.5 bg-indigo-500 rounded-full"></span>
                <span className="text-xs font-semibold text-gray-700">{fixedBookingsCount} Lịch cố định hôm nay</span>
              </div>
              <span className="text-[10px] font-bold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded-md">Đã khoá lịch</span>
            </div>

            {/* Status 3 */}
            <div className="flex items-center justify-between p-3.5 bg-slate-50 rounded-xl">
              <div className="flex items-center gap-3">
                <span className="w-2.5 h-2.5 bg-amber-500 rounded-full"></span>
                <span className="text-xs font-semibold text-gray-700">Giờ cao điểm tối</span>
              </div>
              <span className="text-[10px] font-bold text-ellipsis text-amber-700 bg-amber-50 px-2 py-0.5 rounded-md">
                {peakHours}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
