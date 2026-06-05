import React, { useState } from 'react';
import { 
  Save, 
  RefreshCw, 
  CheckCircle,
  HelpCircle
} from 'lucide-react';
import { Court } from '../types';

interface PricingViewProps {
  courts: Court[];
  onUpdateCourt: (updatedCourt: Court) => void;
}

const TABS = [
  { id: 'T2 - T6', label: 'T2 - T6', dbKey: 'weekday' },
  { id: 'T7 - CN', label: 'T7 - CN', dbKey: 'weekend' },
];

const WEEKDAY_TIME_SLOTS = [
  { id: '05:00 - 09:00', label: '05:00 - 09:00', dbKey: 'morning' },
  { id: '09:00 - 16:00', label: '09:00 - 16:00', dbKey: 'base' },
  { id: '16:00 - 22:00', label: '16:00 - 22:00', dbKey: 'peak' },
  { id: '22:00 - 24:00', label: '22:00 - 24:00', dbKey: 'late' },
];

const WEEKEND_TIME_SLOTS = [
  { id: '05:00 - 16:00', label: '05:00 - 16:00', dbKey: 'base' },
  { id: '16:00 - 22:00', label: '16:00 - 22:00', dbKey: 'peak' },
  { id: '22:00 - 24:00', label: '22:00 - 24:00', dbKey: 'late' },
];

export default function PricingView({ 
  courts, 
  onUpdateCourt
}: PricingViewProps) {
  const [activeDayTab, setActiveDayTab] = useState('T2 - T6');
  const [activeTimeTab, setActiveTimeTab] = useState('05:00 - 09:00');
  
  const timeSlots = activeDayTab === 'T2 - T6' ? WEEKDAY_TIME_SLOTS : WEEKEND_TIME_SLOTS;

  React.useEffect(() => {
    if (!timeSlots.find(t => t.id === activeTimeTab)) {
      setActiveTimeTab(timeSlots[0].id);
    }
  }, [activeDayTab, timeSlots, activeTimeTab]);
  
  // Store local dirty state for unsaved edits mapping courtId -> key -> value
  // key format: "weekday.morning.fixed"
  const [editedPrices, setEditedPrices] = useState<{ [courtId: string]: { [key: string]: number } }>({});
  const [isSaving, setIsSaving] = useState(false);
  const [toastMessage, setToastMessage] = useState('');

  const triggerToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage('');
    }, 4000);
  };

  const getDbDayKey = () => TABS.find(t => t.id === activeDayTab)?.dbKey || 'weekday';
  const getDbTimeKey = () => timeSlots.find(t => t.id === activeTimeTab)?.dbKey || 'morning';

  const getExactDbKey = (dayType: string, timeSlot: string, custType: string): string => {
    if (timeSlot === 'late') {
      return `late.${custType}`;
    }
    return `${dayType}.${timeSlot}.${custType}`;
  };

  // Robust getter to parse flat or nested Firebase objects
  const getPrice = (court: Court, dayType: string, timeSlot: string, custType: string): number => {
    const exactKey = getExactDbKey(dayType, timeSlot, custType);

    // 1. Check local unsaved edits first
    if (editedPrices[court.id] && editedPrices[court.id][exactKey] !== undefined) {
      return editedPrices[court.id][exactKey];
    }

    const hp = court.hourlyPrices || {};

    // 2. Try exact flat key (e.g. "weekday.morning.fixed")
    if (hp[exactKey] !== undefined) return hp[exactKey];
    
    // Default price mappings based on sensible fallbacks if empty
    if (timeSlot === 'base') return 45000;
    if (timeSlot === 'morning') return 55000;
    if (timeSlot === 'peak') return 90000;
    if (timeSlot === 'late') return 60000;

    return 60000;
  };

  const handlePriceChange = (courtId: string, dayType: string, timeSlot: string, custType: string, value: number) => {
    const exactKey = getExactDbKey(dayType, timeSlot, custType);
    
    setEditedPrices(prev => {
      const courtEdits = prev[courtId] || {};
      return {
        ...prev,
        [courtId]: {
          ...courtEdits,
          [exactKey]: value
        }
      };
    });
  };

  const handleSaveAll = async () => {
    setIsSaving(true);
    
    // We update each court individually
    const promises = Object.keys(editedPrices).map(async (courtId) => {
      const court = courts.find(c => c.id === courtId);
      if (!court) return;

      const currentHourlyPrices = court.hourlyPrices || {};
      const newHourlyPrices = { ...currentHourlyPrices };
      
      const editsForCourt = editedPrices[courtId];
      
      // Merge flat keys
      Object.keys(editsForCourt).forEach(flatKey => {
        // Just store them precisely as flat keys string to match their database's structure easily
        newHourlyPrices[flatKey] = editsForCourt[flatKey];
      });

      const updatedCourt = {
        ...court,
        hourlyPrices: newHourlyPrices
      };

      // Call parent update
      await onUpdateCourt(updatedCourt);
    });

    try {
      await Promise.all(promises);
      setEditedPrices({});
      triggerToast('Lưu bảng giá thành công!');
    } catch (error) {
      console.error(error);
      triggerToast('Đã xảy ra lỗi khi lưu bảng giá!');
    } finally {
      setIsSaving(false);
    }
  };

  const hasChanges = Object.keys(editedPrices).length > 0;

  return (
    <div className="space-y-6 font-sans text-slate-800 pb-20">
      
      {/* Toast Alert Success notification */}
      {toastMessage && (
        <div className="fixed top-5 right-5 z-50 bg-[#0D9488] text-white py-3.5 px-6 rounded-2xl shadow-xl border border-teal-500/30 flex items-center gap-3 animate-slide-in text-xs font-semibold">
          <CheckCircle size={18} className="text-teal-100 shrink-0" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Header section with top button */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold text-slate-900 tracking-tight">Cấu hình bảng giá</h1>
          <p className="text-sm text-slate-500 mt-1">
            Thiết lập linh hoạt phí thuê sân dựa trên đối tượng khách hàng và múi giờ cao điểm.
          </p>
        </div>

        <button
          onClick={handleSaveAll}
          disabled={!hasChanges || isSaving}
          className={`px-5 py-3 rounded-2xl text-sm font-bold flex items-center justify-center gap-2 shadow-sm transition-all focus:outline-hidden focus:ring-2 cursor-pointer ${
            hasChanges && !isSaving
              ? 'bg-[#0D9488] hover:bg-teal-700 text-white hover:scale-[1.01] active:scale-[0.99]'
              : 'bg-slate-200 text-slate-400 cursor-not-allowed'
          }`}
        >
          {isSaving ? (
            <RefreshCw size={14} className="animate-spin" />
          ) : (
            <Save size={14} className="opacity-90" />
          )}
          <span>Lưu bảng giá</span>
        </button>
      </div>

      <div className="bg-white rounded-3xl shadow-sm border border-slate-100 p-6 flex flex-col gap-6">
        
        {/* Navigation Tabs aligned with the screenshot */}
        <div className="flex flex-col gap-5">
          {/* Day Tabs */}
          <div className="flex items-center gap-6 border-b border-slate-200/60 pb-2">
            <h2 className="text-xl font-bold text-slate-900">Bảng giá sân</h2>
            
            <div className="flex gap-2">
              {TABS.map(tab => (
                <button
                  key={tab.id}
                  onClick={() => setActiveDayTab(tab.id)}
                  className={`px-4 py-1.5 text-sm font-bold rounded-lg transition-all cursor-pointer ${
                    activeDayTab === tab.id 
                    ? 'bg-[#007067] text-white shadow-sm'
                    : 'text-slate-500 hover:text-slate-800 hover:bg-slate-100 bg-transparent'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>

          {/* Time Slot Tabs */}
          <div className="flex flex-wrap gap-2">
            {timeSlots.map(t => (
              <button
                key={t.id}
                onClick={() => setActiveTimeTab(t.id)}
                className={`px-4 py-2 text-sm font-bold transition-all cursor-pointer border rounded-md ${
                  activeTimeTab === t.id
                  ? 'bg-[#007067] text-white border-[#007067]'
                  : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
                }`}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Pricing Matrix Table exactly like screenshot */}
        <div className="overflow-x-auto rounded-lg border border-slate-200 shadow-sm mt-2">
          <table className="w-full text-left border-collapse min-w-[700px]">
            <thead>
              <tr className="bg-[#118B7A] text-white">
                <th className="pl-6 pr-4 py-4 font-bold tracking-wider text-sm w-48">
                  Sân
                </th>
                <th className="px-6 py-4 font-bold text-center tracking-wider text-sm border-l border-white/20">
                  Cố định
                </th>
                <th className="px-6 py-4 font-bold text-center tracking-wider text-sm border-l border-white/20">
                  Tài khoản
                </th>
                <th className="px-6 py-4 font-bold text-center tracking-wider text-sm border-l border-white/20">
                  Vãng lai
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700 bg-white">
              {courts.filter(c => c.isActive).map((court) => {
                const dayKey = getDbDayKey();
                const timeKey = getDbTimeKey();
                
                return (
                  <tr key={court.id} className="hover:bg-slate-50/50 transition-colors">
                    {/* Court Info Col */}
                    <td className="pl-6 pr-4 py-5 w-64 border-r border-slate-100">
                      <div className="flex flex-col gap-1.5">
                        <p className="text-[14px] font-semibold text-slate-800">{court.name}</p>
                        <span className="text-[10px] w-max px-2 py-0.5 rounded bg-[#EAF0F0] text-[#007067] font-semibold tracking-wide">
                          {court.code || court.id.toUpperCase()} - {court.type}
                        </span>
                      </div>
                    </td>

                    {/* Fixed Price */}
                    <td className="px-6 py-5 align-middle text-center border-r border-slate-100">
                      <PillPriceInput
                        value={getPrice(court, dayKey, timeKey, 'fixed')}
                        onChange={(newVal) => handlePriceChange(court.id, dayKey, timeKey, 'fixed', newVal)}
                      />
                    </td>

                    {/* Account Price */}
                    <td className="px-6 py-5 align-middle text-center border-r border-slate-100">
                      <PillPriceInput
                        value={getPrice(court, dayKey, timeKey, 'account')}
                        onChange={(newVal) => handlePriceChange(court.id, dayKey, timeKey, 'account', newVal)}
                        defaultColor="text-[#0D9488]"
                      />
                    </td>

                    {/* Walkin/Guest Price */}
                    <td className="px-6 py-5 align-middle text-center">
                      <PillPriceInput
                        value={getPrice(court, dayKey, timeKey, 'guest')}
                        onChange={(newVal) => handlePriceChange(court.id, dayKey, timeKey, 'guest', newVal)}
                        defaultColor="text-orange-600"
                      />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {hasChanges && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 bg-slate-900 text-white py-3.5 px-6 rounded-2xl flex items-center justify-between gap-6 shadow-2xl w-full max-w-[450px]">
          <span className="text-sm font-semibold">Có thay đổi chưa được lưu.</span>
          <button
            onClick={handleSaveAll}
            disabled={isSaving}
            className="bg-[#0D9488] hover:bg-teal-600 text-white font-bold text-xs px-5 py-2.5 rounded-xl transition-all cursor-pointer flex items-center gap-1.5 active:scale-95"
          >
            {isSaving ? <RefreshCw size={13} className="animate-spin" /> : null}
            <span>Lưu cập nhật</span>
          </button>
        </div>
      )}

      {/* Explanatory Policy Helper Banner notes */}
      <div className="bg-amber-50 border border-amber-100 p-5 rounded-2xl flex items-start gap-3 mt-6">
        <HelpCircle size={16} className="text-amber-500 shrink-0 mt-0.5" />
        <div className="text-[12px] text-amber-800 flex flex-col gap-2">
          <p className="font-bold text-amber-900 text-xs">💡 Lưu ý thiết lập giá</p>
          <p>• Bảng giá đã được tự động ánh xạ với <b>từng sân cụ thể</b> trên Database (court.hourlyPrices).</p>
          <p>• Nhấn trực tiếp vào mức giá để cập nhật giá trị mới. Chú ý: Các thay đổi sẽ có hiệu lực ngay sau khi bạn nhấn <b>Lưu bảng giá</b>.</p>
        </div>
      </div>
    </div>
  );
}

// Sub-component for inline editing of prices
function PillPriceInput({ 
  value, 
  onChange,
  defaultColor = "text-emerald-600"
}: { 
  value: number; 
  onChange: (val: number) => void;
  defaultColor?: string;
}) {
  const [isFocused, setIsFocused] = useState(false);
  const [tempValue, setTempValue] = useState('');

  const formatVND = (num: number): string => {
    // This perfectly mimics the screenshot where prices are displayed like 55.000 VNĐ
    // (We separate the VNĐ label below the input)
    return num.toLocaleString('vi-VN');
  };

  const handleFocus = () => {
    setIsFocused(true);
    setTempValue(value === 0 ? '' : value.toString());
  };

  const handleBlur = () => {
    setIsFocused(false);
    const parsed = parseInt(tempValue, 10);
    if (!isNaN(parsed)) {
      onChange(parsed);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value.replace(/\D/g, ''); 
    setTempValue(val);
  };

  return (
    <div className="flex flex-col items-center justify-center">
      <input
        type="text"
        value={isFocused ? tempValue : formatVND(value)}
        onFocus={handleFocus}
        onBlur={handleBlur}
        onChange={handleChange}
        inputMode="numeric"
        className={`w-28 text-center font-bold text-[15px] leading-none py-1.5 px-2 bg-transparent focus:text-slate-900 border-b-2 focus:border-teal-500 focus:bg-slate-50 outline-hidden transition-all rounded-t-sm ${isFocused ? 'border-teal-500' : 'border-transparent ' + defaultColor}`}
      />
      {!isFocused && <span className="text-[10px] text-slate-400 font-bold uppercase mt-1 tracking-wider">VNĐ</span>}
    </div>
  );
}
