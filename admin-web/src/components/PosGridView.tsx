import React, { useState, useEffect } from 'react';
import { 
  Calendar, Check, X, ShieldAlert, Award, User, Phone, FileText, 
  Coins, CreditCard, ChevronLeft, ChevronRight, CheckCircle2, RefreshCw, AlertTriangle,
  Plus, Minus, Search
} from 'lucide-react';
import { Booking, Court, Customer, PricingRule } from '../types';

interface PosGridViewProps {
  selectedDateISO: string;
  courts: Court[];
  bookings: Booking[];
  customers: Customer[];
  pricingRules: PricingRule[];
  onAddBooking: (booking: Booking) => void;
  onUpdateBookingStatus: (id: string, newStatus: Booking['status'], updates?: any) => void;
}

// Generating slots in 30-min intervals from 05:00 to 23:30
const STANDARDIZED_TIME_SLOTS = [
  '05:00', '05:30', '06:00', '06:30', '07:00', '07:30', '08:00', '08:30',
  '09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '12:00', '12:30',
  '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
  '17:00', '17:30', '18:00', '18:30', '19:00', '19:30', '20:00', '20:30',
  '21:00', '21:30', '22:00', '22:30', '23:00', '23:30'
];

export default function PosGridView({
  selectedDateISO,
  courts,
  bookings,
  customers,
  pricingRules = [],
  onAddBooking,
  onUpdateBookingStatus
}: PosGridViewProps) {
  const TIME_SLOTS = STANDARDIZED_TIME_SLOTS;
  // Booking Selection State
  const [selectedSlots, setSelectedSlots] = useState<{ [courtId: string]: string[] }>({});
  const [showBookingModal, setShowBookingModal] = useState<boolean>(false);
  
  // Mouse Drag Select State
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [dragCourtId, setDragCourtId] = useState<string | null>(null);
  const [dragStartSlot, setDragStartSlot] = useState<string | null>(null);

  // Form input states for the modal
  const [modalCourtId, setModalCourtId] = useState<string>('');
  const [modalDate, setModalDate] = useState<string>('');
  const [modalStartTime, setModalStartTime] = useState<string>('');
  const [modalDuration, setModalDuration] = useState<number>(1.5);

  // Slot details popup
  const [activeDetailBooking, setActiveDetailBooking] = useState<Booking | null>(null);

  // Quick Booking Flow states
  const [bookingStep, setBookingStep] = useState<1 | 2>(1); // 1: Select/Edit info, 2: QR Display
  const [customerType, setCustomerType] = useState<'App' | 'Walkin'>('App');
  const [searchCustQuery, setSearchCustQuery] = useState('');
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
  const [walkinName, setWalkinName] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'vietqr' | null>(null);
  const [qrTimer, setQrTimer] = useState(600); // 10 minutes count down

  // QR Timer Countdown effect
  useEffect(() => {
    let interval: any = null;
    if (showBookingModal && bookingStep === 2 && paymentMethod === 'vietqr' && qrTimer > 0) {
      interval = setInterval(() => {
        setQrTimer((prev) => prev - 1);
      }, 1000);
    } else {
      clearInterval(interval);
    }
    return () => clearInterval(interval);
  }, [showBookingModal, bookingStep, paymentMethod, qrTimer]);

  // Drag-and-drop mouse select handlers
  const handleMouseDown = (courtId: string, time: string, isPast: boolean, hasBooking: boolean) => {
    if (isPast || hasBooking) return;
    setIsDragging(true);
    setDragCourtId(courtId);
    setDragStartSlot(time);
    setSelectedSlots(prev => ({
      ...prev,
      [courtId]: [time]
    }));
  };

  const handleMouseEnter = (courtId: string, time: string, isPast: boolean, hasBooking: boolean) => {
    if (!isDragging || dragCourtId !== courtId || !dragStartSlot || isPast || hasBooking) return;
    
    const startIdx = TIME_SLOTS.indexOf(dragStartSlot);
    const currentIdx = TIME_SLOTS.indexOf(time);
    const minIdx = Math.min(startIdx, currentIdx);
    const maxIdx = Math.max(startIdx, currentIdx);
    
    const clickedRange = TIME_SLOTS.slice(minIdx, maxIdx + 1);
    
    // Concurrency Check: Overlap prevention
    const overlaps = clickedRange.some(t => findBookingForSlot(courtId, t) !== undefined);
    if (!overlaps) {
      setSelectedSlots(prev => ({
        ...prev,
        [courtId]: clickedRange
      }));
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
    setDragStartSlot(null);
  };

  // Click slot ranges (fallback & manual edit)
  const handleSlotClick = (courtId: string, time: string) => {
    // If active booking overlaps, open detail popup instead
    const activeBooking = findBookingForSlot(courtId, time);
    if (activeBooking) {
      setActiveDetailBooking(activeBooking);
      return;
    }

    // Past booking prevention - Compare dates only to ensure reliable booking on the same day
    const todayStr = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`;
    if (selectedDateISO < todayStr) {
      alert('Không thể đặt sân trong quá khứ!');
      return;
    }

    const currentCourtSlots = selectedSlots[courtId] || [];
    if (currentCourtSlots.includes(time)) {
      // Toggle/Deselect
      const newRange = currentCourtSlots.filter(t => t !== time);
      setSelectedSlots(prev => ({
        ...prev,
        [courtId]: newRange
      }));
    } else if (currentCourtSlots.length === 0) {
      setSelectedSlots(prev => ({
        ...prev,
        [courtId]: [time]
      }));
    } else {
      // Grow slot selection range contiguously from earliest to clicked
      const allTimes = [...currentCourtSlots, time];
      const indices = allTimes.map(s => TIME_SLOTS.indexOf(s));
      const minIdx = Math.min(...indices);
      const maxIdx = Math.max(...indices);
      
      const clickedRange = TIME_SLOTS.slice(minIdx, maxIdx + 1);
      
      // Concurrency Check/Overlap prevention before highlighting range
      const overlaps = clickedRange.some(t => findBookingForSlot(courtId, t) !== undefined);
      if (overlaps) {
        alert('Khung giờ được chọn có chứa mốc thời gian đã được đặt!');
        setSelectedSlots(prev => ({
          ...prev,
          [courtId]: [time]
        }));
      } else {
        setSelectedSlots(prev => ({
          ...prev,
          [courtId]: clickedRange
        }));
      }
    }
  };

  const findBookingForSlot = (courtId: string, time: string): Booking | undefined => {
    return bookings.find(b => {
      if (b.courtId !== courtId || b.date !== selectedDateISO) return false;
      const bStartIdx = TIME_SLOTS.indexOf(b.startTime);
      const bEndIdx = b.endTime === '24:00' ? TIME_SLOTS.length : TIME_SLOTS.indexOf(b.endTime);
      const curIdx = TIME_SLOTS.indexOf(time);
      return curIdx >= bStartIdx && curIdx < bEndIdx && b.status !== 'Cancelled' && b.status !== 'No-show';
    });
  };

  // Helper to determine weekday vs weekend
  const getDayType = (dateStr: string): 'T2 - T6' | 'T7 - CN' => {
    const d = new Date(dateStr);
    const day = d.getDay(); // 0: Sunday, 6: Saturday
    if (day === 0 || day === 6) {
      return 'T7 - CN';
    }
    return 'T2 - T6';
  };

  // Dynamic price mapping hourly slots based on court.hourlyPrices from database
  const getPriceForHourSlot = (court: Court, dateStr: string, hourNum: number, custType: 'App' | 'Walkin'): number => {
    const isWeekend = getDayType(dateStr) === 'T7 - CN';
    const dayKey = isWeekend ? 'weekend' : 'weekday';
    
    let timeKey = 'base';
    if (isWeekend) {
      if (hourNum >= 5 && hourNum < 16) timeKey = 'base';
      else if (hourNum >= 16 && hourNum < 22) timeKey = 'peak';
      else timeKey = 'late';
    } else {
      if (hourNum >= 5 && hourNum < 9) timeKey = 'morning';
      else if (hourNum >= 9 && hourNum < 16) timeKey = 'base';
      else if (hourNum >= 16 && hourNum < 22) timeKey = 'peak';
      else timeKey = 'late';
    }
    
    // In POS we only have 'App' and 'Walkin'. But pricing distinguishes account, guest, fixed.
    const custKey = custType === 'App' ? 'account' : 'guest';

    let exactKey = `${dayKey}.${timeKey}.${custKey}`;
    if (timeKey === 'late') {
        exactKey = `late.${custKey}`;
    }

    const hp = court?.hourlyPrices || {};

    if (hp[exactKey] !== undefined) return hp[exactKey];

    // Baseline fallback if rule is not found in database rules yet (matches PricingView.tsx exactly)
    if (timeKey === 'base') return 45000;
    if (timeKey === 'morning') return 55000;
    if (timeKey === 'peak') return 90000;
    if (timeKey === 'late') return 60000;

    return 60000;
  };

  // Standard pricing calculator with high resolution time slices
  const calculateBookingPrice = (courtId: string, dateStr: string, startTime: string, duration: number, custType: 'App' | 'Walkin'): number => {
    const court = courts.find(c => c.id === courtId);
    if (!court) return 0;
    
    const startIdx = TIME_SLOTS.indexOf(startTime);
    if (startIdx === -1) return court.pricePerHour * duration;
    
    const numSlots = Math.round(duration / 0.5);
    let total = 0;
    
    for (let i = 0; i < numSlots; i++) {
      const idx = startIdx + i;
      if (idx < TIME_SLOTS.length) {
        const slotTime = TIME_SLOTS[idx];
        const hour = parseInt(slotTime.split(':')[0], 10);
        const isHalfHour = slotTime.split(':')[1] === '30';
        const hourNum = hour + (isHalfHour ? 0.5 : 0);
        
        const basePrice = getPriceForHourSlot(court, dateStr, hourNum, custType);
        total += basePrice * 0.5;
      } else {
        total += (court.pricePerHour * 0.5);
      }
    }
    
    return Math.round(total);
  };

  const selectedCourtIds = Object.keys(selectedSlots).filter(id => selectedSlots[id] && selectedSlots[id].length > 0);

  const calculateTotalMultiBookingPrice = () => {
    let grandTotal = 0;
    selectedCourtIds.forEach(courtId => {
      const slots = [...(selectedSlots[courtId] || [])].sort((a, b) => TIME_SLOTS.indexOf(a) - TIME_SLOTS.indexOf(b));
      if (slots.length > 0) {
        const start = slots[0];
        const duration = slots.length * 0.5;
        grandTotal += calculateBookingPrice(courtId, selectedDateISO, start, duration, customerType);
      }
    });
    return grandTotal;
  };

  const startBookingFlow = () => {
    const activeCourtIds = Object.keys(selectedSlots).filter(id => selectedSlots[id] && selectedSlots[id].length > 0);
    if (activeCourtIds.length === 0) return;
    
    if (activeCourtIds.length === 1) {
      const courtId = activeCourtIds[0];
      const slots = [...(selectedSlots[courtId] || [])].sort((a, b) => TIME_SLOTS.indexOf(a) - TIME_SLOTS.indexOf(b));
      const startSlot = slots[0];
      const countSlots = slots.length;
      const durVal = countSlots * 0.5;

      // Populating modal fields with pre-filled selections
      setModalCourtId(courtId);
      setModalDate(selectedDateISO);
      setModalStartTime(startSlot || TIME_SLOTS[0]);
      setModalDuration(durVal);
    } else {
      setModalCourtId('');
      setModalDate(selectedDateISO);
      setModalStartTime('');
      setModalDuration(0);
    }

    setBookingStep(1);
    setSearchCustQuery('');
    setSelectedCustomer(null);
    setWalkinName('');
    setPaymentMethod(null);
    setQrTimer(600);
    setShowBookingModal(true);
  };

  const handleConfirmBooking = () => {
    const courtIdsToBook = selectedCourtIds.length > 0 ? selectedCourtIds : [modalCourtId];
    if (courtIdsToBook.length === 0 || (selectedCourtIds.length === 0 && !modalCourtId)) return;

    courtIdsToBook.forEach((courtId, idx) => {
      let startSlot = '';
      let endSlot = '';
      let duration = 0.5;

      if (selectedCourtIds.length > 0) {
        const slots = [...(selectedSlots[courtId] || [])].sort((a, b) => TIME_SLOTS.indexOf(a) - TIME_SLOTS.indexOf(b));
        if (slots.length < 1) return;
        startSlot = slots[0];
        duration = slots.length * 0.5;
        
        const startIdx = TIME_SLOTS.indexOf(startSlot);
        endSlot = TIME_SLOTS[startIdx + slots.length] || '24:00';
      } else {
        startSlot = modalStartTime;
        duration = modalDuration;
        const startIdx = TIME_SLOTS.indexOf(modalStartTime);
        const numSlots = Math.round(modalDuration / 0.5);
        const endIdx = startIdx + numSlots;
        endSlot = TIME_SLOTS[endIdx] || '24:00';
      }

      const id = `BK${Math.floor(100 + Math.random() * 900) + idx}`;
      const cost = calculateBookingPrice(courtId, selectedDateISO, startSlot, duration, customerType);

      const newBooking: Booking = {
        id,
        courtId: courtId,
        date: selectedDateISO,
        startTime: startSlot,
        endTime: endSlot,
        status: 'Completed', // completely settled instantly
        customerType,
        customerName: customerType === 'App' && selectedCustomer ? selectedCustomer.name : (walkinName || 'Khách vãng lai'),
        customerPhone: customerType === 'App' && selectedCustomer ? selectedCustomer.phone : '0934567XXX',
        customerEmail: customerType === 'App' && selectedCustomer ? selectedCustomer.email : undefined,
        customerId: customerType === 'App' && selectedCustomer ? selectedCustomer.id : undefined,
        totalAmount: cost,
        createdAt: new Date().toISOString()
      };

      onAddBooking(newBooking);
    });

    setShowBookingModal(false);
    setSelectedSlots({});
  };

  // Masking helpers
  const maskPhone = (phone?: string) => {
    if (!phone) return 'Ẩn SĐT';
    if (phone.length <= 4) return phone;
    return phone.slice(0, 4) + ' XXX XXX';
  };

  const maskEmail = (email?: string) => {
    if (!email) return '';
    const parts = email.split('@');
    if (parts.length < 2) return email;
    return parts[0].slice(0, 2) + '***@' + parts[1];
  };

  // Filtered customer autocomplete
  const filteredCustomers = customers.filter(c => 
    c.name.toLowerCase().includes(searchCustQuery.toLowerCase()) || 
    c.phone.includes(searchCustQuery) ||
    c.email.toLowerCase().includes(searchCustQuery.toLowerCase())
  );

  return (
    <div className="space-y-6">
      {/* Grid Top Controls */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Sân Cầu Lông Quốc Tế</h1>
          <p className="text-sm text-gray-500">Giám sát và đặt lịch quầy cập nhật thời gian thực.</p>
        </div>

        {/* Legend Panel */}
        <div className="flex flex-wrap items-center gap-4 bg-white px-4 py-2 border border-slate-200 rounded-xl text-xs shadow-xs font-semibold text-slate-600">
          <div className="flex items-center gap-1.5">
            <span className="w-3.5 h-3.5 bg-slate-100 border border-slate-300 rounded-md"></span>
            <span>Trống</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-3.5 h-3.5 bg-rose-500 rounded-md"></span>
            <span>Đã đặt lẻ</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-3.5 h-3.5 bg-amber-400 rounded-md"></span>
            <span>Chờ cọc</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-3.5 h-3.5 bg-indigo-500 rounded-md"></span>
            <span>Cố định</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-3.5 h-3.5 bg-indigo-600 ring-4 ring-indigo-100 rounded-md"></span>
            <span>Đang Chọn</span>
          </div>
        </div>
      </div>

      {/* POS Grid Core */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-xs overflow-hidden">
        {/* Table horizontal scrolling container */}
        <div className="overflow-x-auto select-none">
          <table className="w-full border-collapse text-left min-w-[1200px]">
            <thead>
              <tr className="bg-slate-50 border-b border-gray-100 divide-x divide-gray-100 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <th className="px-4 py-3 sticky.left-0 bg-slate-50 z-2 w-32 border-r border-gray-100">Sân \ Giờ</th>
                {TIME_SLOTS.map(t => (
                  <th key={t} className="px-2 py-3 text-center w-20 font-mono">
                    {t}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody 
              onMouseUp={handleMouseUp}
              onMouseLeave={handleMouseUp}
              className="divide-y divide-gray-100 text-sm"
            >
              {courts.filter(c => c.isActive).map(court => {
                return (
                  <tr key={court.id} className="hover:bg-slate-50/50 transition-all divide-x divide-gray-100">
                    {/* Court label */}
                    <td className="px-4 py-4 font-bold text-gray-800 sticky left-0 bg-white shadow-xs z-2">
                      <div className="flex flex-col">
                        <span>{court.name}</span>
                        <span className="text-[10px] text-gray-400 font-medium">{court.type}</span>
                      </div>
                    </td>

                    {/* Timeline grid slots */}
                    {TIME_SLOTS.map(time => {
                      const b = findBookingForSlot(court.id, time);
                      const isSelected = !!selectedSlots[court.id]?.includes(time);
                      
                      const [y, M, d] = selectedDateISO.split('-').map(Number);
                      const [ch, cm] = time.split(':').map(Number);
                      const slotDateTime = new Date(y, M - 1, d, ch, cm, 0);
                      const isPast = slotDateTime.getTime() < Date.now();

                      let cellClass = "bg-white text-slate-300 hover:bg-indigo-50/70 hover:text-indigo-600 transition-all cursor-pointer";
                      let displayedText = "";
                      let spanStyle = {};

                      if (b) {
                        cellClass = "transition-all cursor-pointer select-none text-white text-center text-xs font-semibold shadow-xs ";
                        if (b.status === 'Pending') {
                          cellClass += "bg-amber-400 text-amber-950 rounded-xs";
                        } else if ((b.customerName || '').includes('Cố định')) {
                          cellClass += "bg-indigo-500 text-indigo-50 rounded-xs";
                        } else {
                          cellClass += "bg-rose-500 text-rose-50 rounded-xs";
                        }
                        
                        // Display booking name ONLY inside its start slot to keep clean
                        if (b.startTime === time) {
                          displayedText = b.customerName;
                        }
                      } else if (isSelected) {
                        cellClass = "bg-indigo-600 text-white rounded-xs ring-4 ring-indigo-200 shadow-sm text-center text-xs font-bold ring-offset-1 z-10 scale-[1.02] border-x border-indigo-700";
                        displayedText = "✓ ĐANG CHỌN";
                      } else if (isPast) {
                        cellClass = "bg-slate-50 text-slate-400 cursor-not-allowed border-dashed opacity-50 relative";
                        displayedText = "ĐÃ QUA";
                      }

                      return (
                        <td
                          key={time}
                          onMouseDown={() => {
                            if (isPast && !b) return;
                            if (b) {
                              setActiveDetailBooking(b);
                            } else {
                              handleMouseDown(court.id, time, isPast, !!b);
                            }
                          }}
                          onMouseEnter={() => {
                            if (isPast || b) return;
                            handleMouseEnter(court.id, time, isPast, !!b);
                          }}
                          onClick={() => {
                            if (isPast && !b) return;
                            if (b) {
                              setActiveDetailBooking(b);
                            } else {
                              handleSlotClick(court.id, time);
                            }
                          }}
                          className={`px-1 py-3 text-center font-mono border-dashed h-16 min-w-20 relative text-[10px] ${cellClass}`}
                          title={b ? `${b.customerName} (${b.startTime} - ${b.endTime}) - Click xem chi tiết` : isPast ? `Thời gian đã trôi qua (${time})` : `Sân trống, nhấp giữ và kéo để chọn nhanh nhiều ca liên tiếp`}
                        >
                          <div className="truncate max-w-[100px] mx-auto select-none leading-tight font-sans">
                            {displayedText}
                          </div>
                          {isPast && (
                            <div className="absolute inset-0 bg-slate-400/20 pointer-events-none rounded-xs" />
                          )}
                          {b && b.startTime === time && (
                            <span className="absolute bottom-1 right-1 text-[8px] font-mono text-white/70 block px-1 bg-black/25 rounded-xs leading-none">
                              {b.startTime}-{b.endTime}
                            </span>
                          )}
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Booking float floating active alert */}
      {selectedCourtIds.length > 0 && (
        <div className="bg-slate-900 text-white p-4 rounded-2xl flex flex-col md:flex-row items-center justify-between gap-4 shadow-xl fixed bottom-6 left-6 right-6 md:left-auto md:right-8 md:w-[500px] z-[45] border border-slate-800 duration-200">
          <div className="space-y-1 w-full text-left">
            <p className="text-sm font-bold flex items-center gap-2">
              <span className="w-2.5 h-2.5 bg-indigo-500 rounded-full animate-ping"></span>
              Đã khoá giờ trên {selectedCourtIds.length} sân
            </p>
            <div className="text-xs text-slate-300 max-h-24 overflow-y-auto space-y-0.5">
              {selectedCourtIds.map(courtId => {
                const court = courts.find(c => c.id === courtId);
                const slots = [...(selectedSlots[courtId] || [])].sort((a, b) => TIME_SLOTS.indexOf(a) - TIME_SLOTS.indexOf(b));
                if (slots.length === 0) return null;
                const start = slots[0];
                const end = TIME_SLOTS[TIME_SLOTS.indexOf(start) + slots.length] || '24:00';
                const durMin = slots.length * 30;
                return (
                  <p key={courtId} className="font-sans text-[11px] leading-tight">
                    • <b>{court?.name}</b>: {start} ➜ {end} ({durMin} phút)
                  </p>
                );
              })}
            </div>
          </div>
          <div className="flex items-center gap-2 w-full md:w-auto shrink-0 select-none">
            <button 
              onClick={() => { setSelectedSlots({}); }}
              className="flex-1 md:flex-none uppercase text-xs font-semibold bg-slate-800 hover:bg-slate-700 px-3 py-2 rounded-xl transition-all cursor-pointer h-9 shrink-0"
            >
              Hủy
            </button>
            <button 
              onClick={startBookingFlow}
              className="flex-1 md:flex-none uppercase text-xs font-bold bg-[#005C53] hover:bg-teal-700 text-white px-5 py-2 rounded-xl shadow-md transition-all cursor-pointer h-9 shrink-0"
            >
              Đặt sân
            </button>
          </div>
        </div>
      )}

      {/* SLOT DETAIL PREVIEW POPOVER MODAL (EXCEPTION OVERRIDES FLOW) */}
      {activeDetailBooking && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl border border-gray-100 max-w-md w-full overflow-hidden shadow-2xl relative animate-in fade-in zoom-in-95 duration-200">
            {/* Modal Header */}
            <div className={`p-5 text-white flex items-center justify-between ${
              activeDetailBooking.status === 'Pending' ? 'bg-amber-700' :
              (activeDetailBooking.customerName || '').includes('Cố định') ? 'bg-indigo-600' : 'bg-red-600'
            }`}>
              <div className="space-y-1">
                <span className="text-[10px] tracking-wider uppercase bg-white/20 text-white px-2 py-0.5 rounded-md font-bold">
                  {activeDetailBooking.customerType === 'App' ? 'Khách App định danh' : 'Khách vãng lai'}
                </span>
                <h3 className="text-lg font-bold">Thông tin đặt sân: {activeDetailBooking.id}</h3>
              </div>
              <button 
                onClick={() => setActiveDetailBooking(null)}
                className="hover:scale-110 text-white bg-white/20 hover:bg-white/35 transition-all w-8 h-8 rounded-full flex items-center justify-center cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>

            {/* Modal Content */}
            <div className="p-6 space-y-5">
              <div className="space-y-3.5">
                {/* Court Name & Time block */}
                <div className="flex items-start gap-3 p-3 bg-slate-50 rounded-xl border border-slate-100">
                  <div className="text-slate-600 bg-white p-2.5 rounded-lg border border-slate-100">
                    <Calendar size={18} />
                  </div>
                  <div className="text-xs text-gray-700">
                    <p className="font-bold text-gray-900 text-sm">
                      {courts.find(c => c.id === activeDetailBooking.courtId)?.name || 'Sân cầu lông'}
                    </p>
                    <p className="font-mono mt-0.5">Khung giờ: {activeDetailBooking.startTime} - {activeDetailBooking.endTime}</p>
                    <p className="text-[10px] text-gray-400">Ngày chơi: {activeDetailBooking.date}</p>
                  </div>
                </div>

                {/* Customer Info (Masked Sensitive Details) */}
                <div className="space-y-3">
                  <h4 className="text-xs font-bold text-gray-400 uppercase tracking-widest">Khách hàng</h4>
                  <div className="grid grid-cols-2 gap-4 text-xs font-medium text-gray-600">
                    <div>
                      <p className="text-gray-400 text-[10px] uppercase">Tên khách</p>
                      <p className="text-gray-900 font-bold">{activeDetailBooking.customerName}</p>
                    </div>
                    <div>
                      <p className="text-gray-400 text-[10px] uppercase">Số điện thoại</p>
                      <p className="text-gray-900 font-mono font-bold">
                        {maskPhone(activeDetailBooking.customerPhone)}
                      </p>
                    </div>
                    {activeDetailBooking.customerEmail && (
                      <div className="col-span-2 border-t border-gray-100 pt-2">
                        <p className="text-gray-400 text-[10px] uppercase">Email liên kết</p>
                        <p className="text-gray-900 font-mono text-[11px] font-bold">
                          {maskEmail(activeDetailBooking.customerEmail)}
                        </p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Pricing / Payment block */}
                <div className="border-t border-gray-100 pt-3 flex items-center justify-between text-xs">
                  <div>
                    <p className="text-gray-400">Trạng thái thanh toán</p>
                    <span className={`inline-block text-[10px] font-bold px-2 py-0.5 rounded-sm mt-1 uppercase ${
                      activeDetailBooking.status === 'Completed' ? 'bg-emerald-50 text-emerald-700 border border-emerald-100' :
                      activeDetailBooking.status === 'Pending' ? 'bg-amber-50 text-amber-700 border border-amber-100 animate-pulse' :
                      'bg-rose-50 text-rose-700 border border-rose-100'
                    }`}>
                      {activeDetailBooking.status === 'Completed' ? 'Đã Thanh Toán Toàn Bộ' : 
                       activeDetailBooking.status === 'Pending' ? 'Chờ Đóng Cọc Giữ Sân' : 'Đã Đặt/Đã Cọc'}
                    </span>
                  </div>
                  <div className="text-right">
                    <p className="text-gray-400">Số tiền cần thu</p>
                    <p className="text-lg font-extrabold text-emerald-600 font-mono">
                      {activeDetailBooking.totalAmount.toLocaleString('vi-VN')} VNĐ
                    </p>
                  </div>
                </div>
              </div>

              {/* MANUAL OVERRIDES (HIỂN THỊ XỬ LÝ NGOẠI LỆ) */}
              <div className="border-t border-rose-100 bg-rose-50/50 -mx-6 -mb-6 p-6 space-y-3.5">
                <div className="flex items-center gap-2 text-rose-700">
                  <ShieldAlert size={16} />
                  <span className="text-xs font-extrabold uppercase tracking-wider">Xử lý Ngoại lệ (Manual Override)</span>
                </div>
                <p className="text-xs text-rose-600 leading-relaxed">
                  Cấp quyền cho nhân viên trực ca can thiệp thủ công vào luồng tự động khi hỗ trợ sân trực tiếp (Khách về sớm, vắng mặt không lý do).
                </p>

                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={() => {
                      onUpdateBookingStatus(activeDetailBooking.id, 'No-show', { cancelledReason: 'no_show', paymentStatus: 'cancelled' });
                      setActiveDetailBooking(null);
                      alert('Cập nhật trạng thái thành công: Vắng mặt (No-show). Không cộng tích điểm.');
                    }}
                    className="col-span-1 bg-amber-600 hover:bg-amber-700 text-white font-bold text-xs py-2.5 px-4 rounded-xl flex items-center justify-center gap-1.5 shadow-xs transition-all cursor-pointer"
                  >
                    <AlertTriangle size={14} />
                    Vắng mặt (No-show)
                  </button>

                  <button
                    onClick={() => {
                      onUpdateBookingStatus(activeDetailBooking.id, 'Cancelled', { cancelledReason: 'user_cancelled', paymentStatus: 'cancelled' });
                      setActiveDetailBooking(null);
                      alert('Đã hủy đơn thành công. Trạng thái giải phóng sân bãi.');
                    }}
                    className="col-span-1 bg-rose-600 hover:bg-rose-700 text-white font-bold text-xs py-2.5 px-4 rounded-xl flex items-center justify-center gap-1.5 shadow-xs transition-all cursor-pointer"
                  >
                    <X size={14} />
                    Nhấp hủy đơn
                  </button>

                  <button
                    onClick={() => {
                      const currentEndTimeStr = activeDetailBooking.endTime;
                      let newEndTime = currentEndTimeStr;
                      const now = new Date();
                      const h = now.getHours();
                      const m = now.getMinutes();
                      let roundedMins = (m <= 30) ? h * 60 + 30 : (h + 1) * 60;
                      
                      const origParts = currentEndTimeStr.split(':').map(Number);
                      const origMins = origParts[0] * 60 + origParts[1];
                      if (roundedMins < origMins) {
                         const newH = Math.floor(roundedMins / 60);
                         const newM = roundedMins % 60;
                         newEndTime = `${newH.toString().padStart(2, '0')}:${newM.toString().padStart(2, '0')}`;
                      }

                      onUpdateBookingStatus(activeDetailBooking.id, 'Completed', { endTime: newEndTime });
                      setActiveDetailBooking(null);
                      alert(`Đã đánh dấu hoàn tất. Khách về sớm, thành công giải phóng sân từ ${newEndTime}.`);
                    }}
                    className="col-span-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs py-2.5 px-4 rounded-xl flex items-center justify-center gap-1.5 shadow-sm transition-all cursor-pointer"
                  >
                    <CheckCircle2 size={14} />
                    Đánh dấu Hoàn tất (Khách về sớm)
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* QUICK WORKFLOW BOOKING DIALOG (POPUP MODAL COMPLIANT WITH SCREEN 5 & 6) */}
      {showBookingModal && (() => {
        const isMultiCourt = selectedCourtIds.length > 1;
        
        // Single court variables
        let totalBookingAmount = 0;
        let effectiveUnitPrice = 0;
        let modalCourtObj = null;

        if (isMultiCourt) {
          totalBookingAmount = calculateTotalMultiBookingPrice();
        } else {
          // If 1 court (or fallback to modal states)
          const targetCourtId = selectedCourtIds[0] || modalCourtId;
          totalBookingAmount = calculateBookingPrice(targetCourtId, modalDate, modalStartTime, modalDuration, customerType);
          modalCourtObj = courts.find(c => c.id === targetCourtId);
          const [startH, startM] = (modalStartTime || '05:00').split(':').map(Number);
          const hourNumForUnit = startH + (startM === 30 ? 0.5 : 0);
          const slotHourlyRateBase = getPriceForHourSlot(modalCourtObj, modalDate, hourNumForUnit, customerType);
          effectiveUnitPrice = slotHourlyRateBase;
        }

        return (
          <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-in fade-in duration-200">
            <div className="bg-white rounded-[24px] max-w-[460px] w-full overflow-hidden shadow-2xl border border-slate-100 flex flex-col relative animate-in slide-in-from-bottom-4 duration-300">
              
              {/* Modal Header */}
              <div className="px-6 py-4.5 flex items-center justify-between border-b border-slate-100">
                <h3 className="text-[17px] font-extrabold text-slate-900 tracking-tight">Đặt sân nhanh</h3>
                <button 
                  onClick={() => setShowBookingModal(false)}
                  className="hover:bg-slate-100 w-8 h-8 rounded-full flex items-center justify-center text-slate-400 hover:text-slate-600 cursor-pointer transition-colors"
                >
                  <X size={18} />
                </button>
              </div>

              {/* Step 1: Form & Configuration */}
              {bookingStep === 1 && (
                <div className="p-6 space-y-5">
                  
                  {/* Segment Switcher Pills */}
                  <div className="flex bg-[#EAF0F0]/80 p-1 rounded-xl border border-slate-100/50">
                    <button
                      type="button"
                      onClick={() => { setCustomerType('App'); setSelectedCustomer(null); }}
                      className={`flex-1 py-2 text-center text-xs font-bold rounded-lg cursor-pointer transition-all flex items-center justify-center gap-1.5 ${
                        customerType === 'App'
                          ? 'bg-white text-[#005C53] shadow-sm font-black'
                          : 'text-slate-500 hover:text-slate-800'
                      }`}
                    >
                      <Award size={13.5} />
                      Khách có App
                    </button>
                    <button
                      type="button"
                      onClick={() => { setCustomerType('Walkin'); setSelectedCustomer(null); }}
                      className={`flex-1 py-2 text-center text-xs font-bold rounded-lg cursor-pointer transition-all flex items-center justify-center gap-1.5 ${
                        customerType === 'Walkin'
                          ? 'bg-white text-[#005C53] shadow-sm font-black'
                          : 'text-slate-500 hover:text-slate-800'
                      }`}
                    >
                      <User size={13.5} />
                      Khách vãng lai
                    </button>
                  </div>

                  {/* Customer Selection Input form matches screenshots */}
                  {customerType === 'App' ? (
                    <div className="space-y-1.5">
                      <label className="text-[11px] font-bold text-slate-500 block">
                        Tìm khách hàng (SĐT/Tên)
                      </label>
                      <div className="relative">
                        <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-[#005C53]">
                          <Search className="w-4 h-4" />
                        </span>
                        <input
                          type="text"
                          placeholder="Nhập số điện thoại hoặc tên..."
                          className="w-full text-xs text-slate-800 bg-white border border-slate-200 rounded-xl pl-10 pr-4 py-2.5 outline-hidden focus:border-[#005C53] transition-all font-medium h-[41px]"
                          value={searchCustQuery}
                          onChange={(e) => setSearchCustQuery(e.target.value)}
                        />
                      </div>

                      {/* Autocomplete autocomplete matching search */}
                      {searchCustQuery && (
                        <div className="max-h-28 overflow-y-auto divide-y divide-slate-100 border border-slate-150 rounded-xl bg-white shadow-lg animate-in fade-in slide-in-from-top-1 duration-150">
                          {filteredCustomers.length === 0 ? (
                            <p className="p-3 text-[11px] text-center text-slate-400">Không tìm thấy khách hàng nào</p>
                          ) : (
                            filteredCustomers.slice(0, 4).map((c) => (
                              <div
                                key={c.id}
                                onClick={() => { setSelectedCustomer(c); setSearchCustQuery(c.name); }}
                                className={`p-2 px-3.5 flex items-center justify-between text-xs cursor-pointer hover:bg-slate-50 ${
                                  selectedCustomer?.id === c.id ? 'bg-teal-50/40 font-semibold text-[#005C53]' : ''
                                }`}
                              >
                                <div>
                                  <p className="text-slate-900 font-bold">{c.name}</p>
                                  <p className="text-[10px] text-slate-450 font-mono">{c.phone} | {c.email}</p>
                                </div>
                                <span className="text-[9px] bg-teal-50 text-[#005C53] px-2 py-0.5 rounded font-mono font-bold border border-teal-105/30 animate-pulse">
                                  ★ VIP
                                </span>
                              </div>
                            ))
                          )}
                        </div>
                      )}

                      {selectedCustomer && (
                        <div className="bg-teal-50/40 border border-teal-100/60 p-2.5 rounded-xl flex items-center justify-between animate-in fade-in duration-200">
                          <div className="text-xs">
                            <p className="font-extrabold text-[#005C53]">Đã liên kết khách hàng:</p>
                            <p className="text-slate-700 font-bold">{selectedCustomer.name} - {selectedCustomer.phone}</p>
                          </div>
                          <Check className="text-white bg-[#005C53] rounded-full p-0.5" size={16} />
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="space-y-1.5">
                      <label className="text-[11px] font-bold text-slate-500 block">
                        Tên khách hàng
                      </label>
                      <input
                        type="text"
                        className="w-full text-xs text-slate-800 bg-white border border-slate-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-[#005C53] transition-all font-semibold h-[41px]"
                        placeholder="Nhập tên gợi nhớ..."
                        value={walkinName}
                        onChange={(e) => setWalkinName(e.target.value)}
                      />
                    </div>
                  )}

                  {/* 2x2 Grid Form or Multi-Court List based on count */}
                  {!isMultiCourt ? (
                    <div className="grid grid-cols-2 gap-4">
                      {/* Court Selector Dropdown */}
                      <div className="space-y-1">
                        <label className="text-[11px] font-bold text-slate-500 block">
                          Sân
                        </label>
                        <select
                          value={modalCourtId}
                          onChange={(e) => setModalCourtId(e.target.value)}
                          className="w-full text-xs text-slate-800 bg-white border border-slate-200 rounded-xl px-3.5 py-2.5 outline-hidden focus:border-[#005C53] transition-all font-bold cursor-pointer h-[41px]"
                        >
                          {courts.filter(c => c.isActive).map(c => (
                            <option key={c.id} value={c.id}>
                              {c.name} - {c.type === 'Thảm PVC' ? 'VIP' : (c.type === 'Sàn Gỗ' ? 'VIP' : 'Thường')}
                            </option>
                          ))}
                        </select>
                      </div>

                      {/* Date picker */}
                      <div className="space-y-1">
                        <label className="text-[11px] font-bold text-slate-500 block">
                          Ngày
                        </label>
                        <input
                          type="date"
                          value={modalDate}
                          onChange={(e) => setModalDate(e.target.value)}
                          className="w-full text-xs text-slate-850 bg-white border border-slate-200 rounded-xl px-3.5 py-2.5 outline-hidden focus:border-[#005C53] transition-all font-bold font-mono cursor-pointer h-[41px]"
                        />
                      </div>

                      {/* Start hour picker dropdown */}
                      <div className="space-y-1">
                        <label className="text-[11px] font-bold text-slate-500 block">
                          Giờ bắt đầu
                        </label>
                        <select
                          value={modalStartTime}
                          onChange={(e) => setModalStartTime(e.target.value)}
                          className="w-full text-xs text-slate-850 bg-white border border-slate-200 rounded-xl px-3.5 py-2.5 outline-hidden focus:border-[#005C53] transition-all font-bold font-mono cursor-pointer h-[41px]"
                        >
                          {TIME_SLOTS.map(t => (
                            <option key={t} value={t}>{t}</option>
                          ))}
                        </select>
                      </div>

                      {/* Stepper Selector for Play Duration */}
                      <div className="space-y-1">
                        <label className="text-[11px] font-bold text-slate-500 block">
                          Thời lượng
                        </label>
                        <div className="flex items-center justify-between border border-slate-200 bg-white rounded-xl px-2.5 py-1.5 h-[41px]">
                          <button
                            type="button"
                            onClick={() => setModalDuration(p => Math.max(0.5, p - 0.5))}
                            className="w-7 h-7 rounded-full border border-slate-200 hover:bg-slate-50 flex items-center justify-center text-slate-500 hover:text-slate-700 transition-colors cursor-pointer select-none font-bold"
                          >
                            <Minus size={11} />
                          </button>
                          <span className="text-xs font-bold text-slate-800 font-sans mx-2 select-none shrink-0">
                            {modalDuration} giờ
                          </span>
                          <button
                            type="button"
                            onClick={() => setModalDuration(p => Math.min(5.0, p + 0.5))}
                            className="w-7 h-7 rounded-full border border-slate-200 hover:bg-slate-50 flex items-center justify-center text-slate-500 hover:text-slate-700 transition-colors cursor-pointer select-none font-bold"
                          >
                            <Plus size={11} />
                          </button>
                        </div>
                      </div>
                    </div>
                  ) : (
                    /* Multi-court list with pricing breakdown */
                    <div className="space-y-2">
                      <label className="text-[11px] font-bold text-slate-500 block">
                        Danh sách sân & thời gian đặt chơi
                      </label>
                      <div className="space-y-2 max-h-40 overflow-y-auto border border-slate-150 rounded-2xl p-3 bg-slate-50/70">
                        {selectedCourtIds.map(courtId => {
                          const court = courts.find(c => c.id === courtId);
                          const slots = [...(selectedSlots[courtId] || [])].sort((a, b) => TIME_SLOTS.indexOf(a) - TIME_SLOTS.indexOf(b));
                          if (slots.length === 0) return null;
                          const start = slots[0];
                          const duration = slots.length * 0.5;
                          const end = TIME_SLOTS[TIME_SLOTS.indexOf(start) + slots.length] || '24:00';
                          const price = calculateBookingPrice(courtId, selectedDateISO, start, duration, customerType);
                          return (
                            <div key={courtId} className="flex justify-between items-center text-xs bg-white p-2.5 rounded-xl border border-slate-100 shadow-2xs">
                              <div>
                                <p className="font-extrabold text-[#005C53]">{court?.name}</p>
                                <p className="font-mono text-[10px] text-slate-500 font-semibold">{start} ➜ {end} ({duration} giờ)</p>
                              </div>
                              <span className="font-mono font-black text-slate-800">{price.toLocaleString('vi-VN')} đ</span>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}

                  {/* Summary checkout panel matches screenshots */}
                  <div className="bg-[#F3F7F6] border border-teal-100/50 py-4.5 px-5.5 rounded-2xl flex items-center justify-between">
                    <div>
                      {!isMultiCourt ? (
                        <span className="text-xs font-semibold text-slate-500 block">
                          Đơn giá: {effectiveUnitPrice.toLocaleString('vi-VN')} đ/giờ
                        </span>
                      ) : (
                        <span className="text-xs font-semibold text-[#005C53] block font-bold">
                          Đặt sân tích hợp ({selectedCourtIds.length} sân)
                        </span>
                      )}
                    </div>
                    <div className="text-right">
                      <p className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Tổng tiền</p>
                      <span className="text-[22px] font-black text-[#005C53] block leading-none mt-1">
                        {totalBookingAmount.toLocaleString('vi-VN')} đ
                      </span>
                    </div>
                  </div>

                  {/* Action row side-by-side with appropriate icons */}
                  <div className="border-t border-slate-100 pt-5 flex items-center gap-4 bg-white">
                    <button
                      type="button"
                      disabled={customerType === 'App' && !selectedCustomer || customerType === 'Walkin' && !walkinName}
                      onClick={() => {
                        setPaymentMethod('cash');
                        handleConfirmBooking();
                        alert(`Đặt sân thành công! Thanh toán bằng Tiền mặt: ${totalBookingAmount.toLocaleString('vi-VN')} đ`);
                      }}
                      className="flex-1 border-2 border-[#005C53] text-[#005C53] hover:bg-teal-50/20 font-bold text-xs py-3 px-4 rounded-full flex items-center justify-center gap-2 cursor-pointer transition-all disabled:opacity-30 disabled:cursor-not-allowed selection:bg-transparent h-[45px]"
                    >
                      <Coins size={15} />
                      Thu tiền mặt
                    </button>

                    <button
                      type="button"
                      disabled={customerType === 'App' && !selectedCustomer || customerType === 'Walkin' && !walkinName}
                      onClick={() => {
                        setPaymentMethod('vietqr');
                        setQrTimer(600);
                        setBookingStep(2);
                      }}
                      className="flex-1 bg-[#005C53] hover:bg-[#00473F] text-white font-bold text-xs py-3 px-4 rounded-full flex items-center justify-center gap-2 cursor-pointer shadow-md shadow-[#005C53]/15 transition-all disabled:opacity-30 disabled:cursor-not-allowed h-[45px]"
                    >
                      <CreditCard size={15} />
                      Xác nhận & In QR
                    </button>
                  </div>

                </div>
              )}

              {/* Step 2: VIETQR GENERATOR & REAL-TIME WEBHOCK PAYMENT INTERACTION */}
              {bookingStep === 2 && (
                <div className="p-6 space-y-6">
                  
                  {/* QR Display Area */}
                  <div className="bg-[#F8FAFC] border border-slate-100 p-5 rounded-3xl space-y-4 text-center">
                    <p className="text-[10px] font-black text-[#005C53] bg-teal-50/50 max-w-fit mx-auto px-2.5 py-1 rounded-full uppercase tracking-wider border border-teal-100/30">
                      Cổng QR VietQR thanh toán nhanh
                    </p>
                    
                    {/* Dynamic QR mockup */}
                    <div className="bg-white p-3.5 border border-slate-150 rounded-2xl max-w-[180px] mx-auto shadow-xs select-none">
                      <div className="aspect-square bg-slate-900 rounded-lg flex flex-col items-center justify-center text-white relative p-1.5">
                        <div className="grid grid-cols-5 gap-1.5 w-full h-full p-2.5 opacity-90 bg-slate-900">
                          {Array.from({ length: 25 }).map((_, i) => (
                            <div key={i} className={`rounded-[3px] ${
                              (i % 3 === 0 || i % 7 === 0 || i < 5 || i % 5 === 0) ? 'bg-white' : 'bg-slate-800'
                            }`} />
                          ))}
                        </div>
                        <div className="absolute inset-x-0 bottom-2 bg-[#005C53] text-[8px] tracking-wider font-extrabold uppercase py-0.5 text-center px-1 rounded-sm mx-2">
                          PROBAD {Math.floor(1000 + Math.random() * 9000)}
                        </div>
                      </div>
                    </div>

                    {/* MB Bank transfer accounts */}
                    <div className="text-xs font-semibold text-slate-700 space-y-1.5">
                      <p>Hệ thống: <b className="text-slate-900 font-bold">MB Bank (Ngân Hàng Quân Đội)</b></p>
                      <p>Số tài khoản: <b className="text-slate-900 font-mono font-bold">1133557799</b></p>
                      <p>Chủ tài khoản: <b className="text-slate-900 font-bold uppercase">PRO BADMINTON CAU GIAY</b></p>
                      <p className="text-sm border-t border-slate-100 pt-2 text-[#005C53] font-extrabold">
                        Phải thanh toán: <b>{totalBookingAmount.toLocaleString('vi-VN')} VNĐ</b>
                      </p>
                      <div className="bg-amber-50/60 text-amber-800 border border-amber-100/40 px-3 py-1.5 rounded-lg inline-block text-center mt-1">
                        Nội dung quét dán: <b className="font-mono text-sm uppercase text-slate-850 font-black">DATSAN {modalStartTime ? modalStartTime.replace(':', '') : 'MULTI'}</b>
                      </div>
                    </div>

                    {/* Interactive Bank Simulator Webhook */}
                    <div className="border-t border-slate-200/50 pt-3 text-xs flex flex-col items-center justify-center gap-2">
                      <p className="text-slate-400 font-medium">
                        Mã giao dịch sẽ tự động hết hạn sau: {' '}
                        <b className="font-mono text-[#005C53] font-black">
                          {Math.floor(qrTimer / 60)}:{String(qrTimer % 60).padStart(2, '0')}
                        </b>
                      </p>

                      <button
                        type="button"
                        onClick={handleConfirmBooking}
                        className="bg-[#005C53] hover:bg-[#00473F] text-white font-extrabold text-[10px] px-4 py-2.5 rounded-xl flex items-center justify-center gap-2.5 cursor-pointer shadow-md active:scale-95 transition-all mt-1 uppercase tracking-wide tracking-wider"
                      >
                        <RefreshCw size={11} className="animate-spin" />
                        Giả lập quét QR (Webhook thành công)
                      </button>
                    </div>
                  </div>

                  {/* Back button */}
                  <div className="border-t border-slate-100 pt-4 flex justify-start bg-white">
                    <button
                      type="button"
                      onClick={() => { setBookingStep(1); setPaymentMethod(null); }}
                      className="flex items-center gap-1.5 text-xs bg-slate-100 text-slate-700 px-4 py-2.5 rounded-xl font-bold cursor-pointer hover:bg-slate-200 transition-all font-sans"
                    >
                      <ChevronLeft size={15} /> Quay lại quầy đặt sân
                    </button>
                  </div>

                </div>
              )}

            </div>
          </div>
        );
      })()}
    </div>
  );
}
