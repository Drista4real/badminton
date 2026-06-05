import React, { useState, useEffect } from 'react';
import { 
  Save, 
  AlertCircle, 
  RefreshCw, 
  Zap, 
  History, 
  PlusCircle, 
  X, 
  RotateCcw, 
  CheckCircle,
  HelpCircle,
  ArrowRight
} from 'lucide-react';
import { PricingRule } from '../types';

interface PricingViewProps {
  pricingRules: PricingRule[];
  onUpdatePricing: (id: string, updated: Partial<PricingRule>) => void;
  onAddPricingRule?: (newRule: PricingRule) => void;
  onResetPricing?: () => void;
}

interface ChangeLog {
  id: string;
  timestamp: string;
  user: string;
  action: string;
  details: string;
}

export default function PricingView({ 
  pricingRules, 
  onUpdatePricing,
  onAddPricingRule,
  onResetPricing
}: PricingViewProps) {
  const [editedRules, setEditedRules] = useState<{ [id: string]: Partial<PricingRule> }>({});
  const [isSaving, setIsSaving] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [showAddGroupModal, setShowAddGroupModal] = useState(false);
  
  // Local change history log state stored in localStorage for persistent realism
  const [logs, setLogs] = useState<ChangeLog[]>([]);

  // Form states for adding custom hour group
  const [newDayType, setNewDayType] = useState<'T2 - T6' | 'T7 - CN'>('T2 - T6');
  const [newTimeSlot, setNewTimeSlot] = useState('');
  const [newFixedPrice, setNewFixedPrice] = useState(60000);
  const [newAppPrice, setNewAppPrice] = useState(70000);
  const [newWalkinPrice, setNewWalkinPrice] = useState(80000);
  const [addError, setAddError] = useState('');

  // Toast success notification
  const [toastMessage, setToastMessage] = useState('');

  useEffect(() => {
    // Seed initial realistic history log
    const storedLogs = localStorage.getItem('pricing_change_logs');
    if (storedLogs) {
      setLogs(JSON.parse(storedLogs));
    } else {
      const initialLogs: ChangeLog[] = [
        {
          id: 'log1',
          timestamp: '2026-06-04 08:30:12',
          user: 'Admin - Chủ sân',
          action: 'Tạo lập biểu giá',
          details: 'Thiết lập 8 khung giờ chuẩn đồng bộ hệ thống ProBadminton.'
        },
        {
          id: 'log2',
          timestamp: '2026-06-03 16:45:00',
          user: 'Admin - Chủ sân',
          action: 'Cấu hình khung giờ vàng',
          details: 'Cập nhật giá giờ cao điểm (16h - 22h) thêm 5.000đ để tối ưu doanh thu.'
        },
        {
          id: 'log3',
          timestamp: '2026-05-20 09:12:35',
          user: 'Admin - Chủ sân',
          action: 'Điểu chỉnh giá vãng lai',
          details: 'Tăng giá vãng lai khung 22h - 24h lên 85.000đ.'
        }
      ];
      localStorage.setItem('pricing_change_logs', JSON.stringify(initialLogs));
      setLogs(initialLogs);
    }
  }, []);

  const triggerToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage('');
    }, 4000);
  };

  const handlePriceChange = (id: string, field: 'fixedCustPrice' | 'appCustPrice' | 'walkinPrice', value: number) => {
    setEditedRules(prev => ({
      ...prev,
      [id]: {
        ...prev[id],
        [field]: value
      }
    }));
  };

  const handleSaveAll = () => {
    setIsSaving(true);
    // Simulate minor network sync delay
    setTimeout(() => {
      let changeSummary: string[] = [];

      Object.entries(editedRules).forEach(([id, rawFields]) => {
        const updatedFields = rawFields as Partial<PricingRule>;
        onUpdatePricing(id, updatedFields);
        const original = pricingRules.find(r => r.id === id) as PricingRule | undefined;
        if (original) {
          const changes: string[] = [];
          if (updatedFields.fixedCustPrice !== undefined) {
            changes.push(`Cố định: ${(original.fixedCustPrice || 0).toLocaleString()}đ ➔ ${(updatedFields.fixedCustPrice || 0).toLocaleString()}đ`);
          }
          if (updatedFields.appCustPrice !== undefined) {
            changes.push(`App: ${(original.appCustPrice || 0).toLocaleString()}đ ➔ ${(updatedFields.appCustPrice || 0).toLocaleString()}đ`);
          }
          if (updatedFields.walkinPrice !== undefined) {
            changes.push(`Vãng lai: ${(original.walkinPrice || 0).toLocaleString()}đ ➔ ${(updatedFields.walkinPrice || 0).toLocaleString()}đ`);
          }
          changeSummary.push(`Khung ${original.dayType} [${original.timeSlot}] (${changes.join(', ')})`);
        }
      });

      // Insert new log history item
      if (changeSummary.length > 0) {
        const now = new Date();
        const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
        const newLog: ChangeLog = {
          id: 'log_' + Date.now(),
          timestamp: dateStr,
          user: 'Admin - Chủ sân',
          action: 'Cập nhật bảng giá',
          details: changeSummary.join('; ')
        };
        const updatedLogs = [newLog, ...logs];
        setLogs(updatedLogs);
        localStorage.setItem('pricing_change_logs', JSON.stringify(updatedLogs));
      }

      setEditedRules({});
      setIsSaving(false);
      triggerToast('Đã lưu các thay đổi cấu hình bảng giá thành công!');
    }, 800);
  };

  const getRuleVal = (rule: PricingRule, field: 'fixedCustPrice' | 'appCustPrice' | 'walkinPrice'): number => {
    if (editedRules[rule.id] && editedRules[rule.id][field] !== undefined) {
      return editedRules[rule.id][field] as number;
    }
    return rule[field];
  };

  const handleResetToDefault = () => {
    if (window.confirm('Bạn có chắc chắn muốn khôi phục lại biểu giá chuẩn ban đầu như trong thiết kế mẫu không? Mọi thay đổi tuỳ biến hiện tại sẽ bị ghi đè.')) {
      if (onResetPricing) {
        onResetPricing();
        setEditedRules({});
        // Add log
        const now = new Date();
        const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
        const newLog: ChangeLog = {
          id: 'log_' + Date.now(),
          timestamp: dateStr,
          user: 'Admin - Chủ sân',
          action: 'Khôi phục mặc định',
          details: 'Thiết lập lại toàn bộ 8 biểu giá theo tiêu chuẩn thiết kế.'
        };
        const updatedLogs = [newLog, ...logs];
        setLogs(updatedLogs);
        localStorage.setItem('pricing_change_logs', JSON.stringify(updatedLogs));
        triggerToast('Bảng giá đã khôi phục về trạng thái thiết kế mẫu!');
        setShowHistoryModal(false);
      }
    }
  };

  const handleCreateGroup = () => {
    if (!newTimeSlot.trim()) {
      setAddError('Vui lòng nhập khung giờ hoạt động (Ví dụ: 12h - 15h)');
      return;
    }
    setAddError('');

    const newId = 'pr_' + Date.now();
    const newRule: PricingRule = {
      id: newId,
      dayType: newDayType,
      timeSlot: newTimeSlot,
      fixedCustPrice: newFixedPrice,
      appCustPrice: newAppPrice,
      walkinPrice: newWalkinPrice
    };

    if (onAddPricingRule) {
      onAddPricingRule(newRule);
    }

    // Add revision log
    const now = new Date();
    const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
    const newLog: ChangeLog = {
      id: 'log_' + Date.now(),
      timestamp: dateStr,
      user: 'Admin - Chủ sân',
      action: 'Thêm mới khung giờ đặc biệt',
      details: `Thêm khung [${newTimeSlot}] (${newDayType}) | Cố định: ${newFixedPrice.toLocaleString()}đ, App: ${newAppPrice.toLocaleString()}đ, Vãng lai: ${newWalkinPrice.toLocaleString()}đ`
    };
    const updatedLogs = [newLog, ...logs];
    setLogs(updatedLogs);
    localStorage.setItem('pricing_change_logs', JSON.stringify(updatedLogs));

    // Reset fields
    setNewTimeSlot('');
    setShowAddGroupModal(false);
    triggerToast(`Đã thêm thành công nhóm giờ đặc biệt ${newTimeSlot}!`);
  };

  const hasChanges = Object.keys(editedRules).length > 0;
  const lastUpdateStr = logs.length > 0 ? logs[0].timestamp : '12/10/2023';

  return (
    <div className="space-y-6 font-sans text-slate-800">
      
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
          className={`px-5 py-3 rounded-2xl text-xs font-bold flex items-center justify-center gap-2 shadow-sm transition-all focus:outline-hidden focus:ring-2 focus:ring-slate-350 cursor-pointer ${
            hasChanges && !isSaving
              ? 'bg-slate-800 hover:bg-slate-900 text-white hover:scale-[1.01] active:scale-[0.99]'
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

      {/* Redesigned Pricing Table Matrix from Screenshot */}
      <div className="bg-white rounded-[2rem] border border-slate-100 shadow-[0_4px_24px_-4px_rgba(15,23,42,0.03)] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/20">
                <th className="pl-10 pr-6 py-5 font-bold text-[#0F766E] uppercase tracking-wider text-[11px] w-48 select-none">
                  Thứ
                </th>
                <th className="px-8 py-5 font-bold text-[#0F766E] uppercase tracking-wider text-[11px] w-48 select-none">
                  Khung giờ
                </th>
                <th className="px-8 py-5 font-bold text-[#0F766E] uppercase tracking-wider text-[11px] text-center select-none">
                  Khách cố định
                </th>
                <th className="px-8 py-5 font-bold text-[#0F766E] uppercase tracking-wider text-[11px] text-center select-none">
                  Có tài khoản
                </th>
                <th className="px-8 py-5 font-bold text-[#0F766E] uppercase tracking-wider text-[11px] text-center select-none">
                  Vãng lai
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {pricingRules.map((rule, idx) => {
                const isFirstRowOfDay = idx === 0 || pricingRules[idx - 1].dayType !== rule.dayType;
                const rowSpanCount = pricingRules.filter(r => r.dayType === rule.dayType).length;
                const isGoldenHour = (rule.timeSlot || '').includes('16h - 22h');

                // Tag colors
                let badgeText = 'Ngày thường';
                let badgeStyle = 'bg-slate-100 text-slate-500';
                if (rule.dayType === 'T2 - T6') {
                  badgeText = 'Ngày thường';
                  badgeStyle = 'bg-teal-50 text-[#0D9488] font-semibold border border-teal-100/50';
                } else if (rule.dayType === 'T7 - CN') {
                  badgeText = 'Cuối tuần';
                  badgeStyle = 'bg-rose-50 text-rose-500 font-semibold border border-rose-100/50';
                }

                return (
                  <tr 
                    key={rule.id} 
                    className="hover:bg-slate-50/40 transition-colors"
                  >
                    {/* Spanned Day Range Cell with Clean badge */}
                    {isFirstRowOfDay && (
                      <td 
                        className="pl-10 pr-6 py-6 font-extrabold text-slate-900 align-middle w-48 border-r border-slate-50"
                        rowSpan={rowSpanCount}
                      >
                        <div className="flex flex-col gap-2 justify-center">
                          <p className="text-[17px] font-black tracking-tight text-slate-800">{rule.dayType}</p>
                          <span className={`text-[10px] px-2.5 py-1 rounded-full uppercase tracking-wide inline-block max-w-max text-center ${badgeStyle}`}>
                            {badgeText}
                          </span>
                        </div>
                      </td>
                    )}

                    {/* Time Slot column with Golden hour alert highlighting */}
                    <td className="px-8 py-6 font-semibold w-48">
                      <div className="flex items-center gap-1.5">
                        <span className={`text-[13px] ${isGoldenHour ? 'text-[#0D9488] font-extrabold' : 'text-slate-600'}`}>
                          {rule.timeSlot}
                        </span>
                        {isGoldenHour && (
                          <span className="text-teal-600 font-extrabold select-none shrink-0" title="Khung giờ vàng">⚡</span>
                        )}
                      </div>
                    </td>

                    {/* CONTRACT FIXED CUSTOMER PRICE COLUMN */}
                    <td className="px-8 py-5 text-center">
                      <PillPriceInput
                        value={getRuleVal(rule, 'fixedCustPrice')}
                        onChange={(newVal) => handlePriceChange(rule.id, 'fixedCustPrice', newVal)}
                        highlighted={isGoldenHour}
                      />
                    </td>

                    {/* APP CUSTOMER PRICE COLUMN */}
                    <td className="px-8 py-5 text-center">
                      <PillPriceInput
                        value={getRuleVal(rule, 'appCustPrice')}
                        onChange={(newVal) => handlePriceChange(rule.id, 'appCustPrice', newVal)}
                        highlighted={isGoldenHour}
                      />
                    </td>

                    {/* WALK-IN CUSTOMER PRICE COLUMN */}
                    <td className="px-8 py-5 text-center">
                      <PillPriceInput
                        value={getRuleVal(rule, 'walkinPrice')}
                        onChange={(newVal) => handlePriceChange(rule.id, 'walkinPrice', newVal)}
                        highlighted={isGoldenHour}
                      />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Floating alert notifier of unsaved changes */}
      {hasChanges && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 bg-slate-950 text-white py-4 px-6 rounded-2xl flex items-center justify-between gap-8 shadow-2xl border border-slate-850 animate-bounce-in w-full max-w-[620px]">
          <div className="flex items-center gap-3 text-[13px]">
            <AlertCircle size={18} className="text-amber-400 shrink-0" />
            <span>Có <b className="text-amber-300">{Object.keys(editedRules).length}</b> cấu hình giá thay đổi chưa được lưu lại.</span>
          </div>
          <button
            onClick={handleSaveAll}
            disabled={isSaving}
            className="bg-[#0D9488] hover:bg-teal-500 text-white font-bold text-xs px-5 py-2.5 rounded-xl transition-all cursor-pointer flex items-center gap-1.5 active:scale-95"
          >
            {isSaving ? <RefreshCw size={13} className="animate-spin" /> : null}
            <span>Lưu Ngay</span>
          </button>
        </div>
      )}

      {/* Redesigned bottom workspace cards matching the screenshot layout exactly */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
        
        {/* Card 1: Lịch sử thay đổi (Change logs) */}
        <div className="bg-[#F8FAFC]/50 p-6 rounded-[2rem] border border-slate-100 flex flex-col justify-between gap-5 relative hover:bg-slate-50/50 transition-colors">
          <div className="space-y-3">
            <div className="flex items-center gap-3 text-slate-700 font-bold">
              <div className="p-2.5 rounded-2xl bg-white border border-slate-100 flex items-center justify-center shrink-0">
                <History size={16} className="text-[#0D9488]" />
              </div>
              <span className="text-[13px] font-extrabold tracking-tight text-slate-800">Lịch sử thay đổi</span>
            </div>
            <p className="text-[12px] text-slate-500 leading-relaxed max-w-sm mt-1">
              Lần cập nhật cuối: <b className="font-bold text-slate-700">{lastUpdateStr}</b> bởi Admin.
            </p>
          </div>

          <button
            onClick={() => setShowHistoryModal(true)}
            className="text-[13px] font-bold text-[#0D9488] hover:text-teal-700 flex items-center gap-1.5 cursor-pointer max-w-max border-b border-transparent hover:border-teal-500 transition-colors pb-0.5"
          >
            <span>Xem chi tiết</span>
            <ArrowRight size={13} />
          </button>
        </div>

        {/* Card 2: Thêm nhóm giờ đặc biệt (Add hours) */}
        <div 
          onClick={() => setShowAddGroupModal(true)}
          className="bg-[#F8FAFC]/50 p-6 rounded-[2rem] border border-slate-200/60 border-dashed flex flex-col items-center justify-center gap-3 hover:bg-white hover:border-slate-350 transition-all cursor-pointer select-none group min-h-[140px]"
        >
          <div className="p-2.5 rounded-full bg-white border border-slate-100 shadow-2xs text-slate-400 group-hover:text-[#0D9488] group-hover:scale-110 transition-all shrink-0">
            <PlusCircle size={22} />
          </div>
          <span className="text-[13px] font-bold text-slate-650 group-hover:text-slate-800 transition-colors">
            Thêm nhóm giờ đặc biệt
          </span>
        </div>
      </div>

      {/* Explanatory Policy Helper Banner notes */}
      <div className="bg-amber-50/30 border border-amber-100/50 p-5 rounded-2rem flex items-start gap-3 mt-6">
        <HelpCircle size={16} className="text-amber-550 shrink-0 mt-0.5" />
        <div className="text-[11px] text-slate-500 space-y-1">
          <p className="font-bold text-slate-700 text-xs">💡 Quy tắc cấu hình bảng giá:</p>
          <p>• Hệ thống hỗ trợ nhập số và liên kết tự động tới mô-đun hoá đơn POS của lễ tân.</p>
          <p>• Khung giờ hoạt động chuẩn gồm 8 dòng (như ảnh hướng dẫn của ban quản trị), tự động phân hoá theo ngày thường / cuối tuần để tối ưu hoá hiệu suất đặt sân.</p>
        </div>
      </div>


      {/* Modal 1: HISTORY LOGS & HARD-RESET BACKUP */}
      {showHistoryModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-xs p-4 animate-fade-in">
          <div className="bg-white rounded-3xl w-full max-w-xl shadow-2xl border border-slate-100 overflow-hidden flex flex-col max-h-[85vh]">
            {/* Modal Header */}
            <div className="p-6 border-b border-slate-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <History className="text-[#0D9488]" size={18} />
                <h3 className="font-extrabold text-sm text-slate-950">Lịch sử cấu hình bảng giá</h3>
              </div>
              <button 
                onClick={() => setShowHistoryModal(false)}
                className="text-slate-400 hover:text-slate-700 rounded-full p-1.5 hover:bg-slate-100 cursor-pointer"
              >
                <X size={16} />
              </button>
            </div>

            {/* Modal Content */}
            <div className="p-6 overflow-y-auto flex-1 space-y-6">
              <div className="flex items-center justify-between bg-slate-50 p-4 rounded-2xl text-xs text-slate-600">
                <span>Nhấn nút bên để khôi phục lại biểu giá 8 khung giờ chuẩn mẫu.</span>
                <button
                  onClick={handleResetToDefault}
                  className="bg-red-50 hover:bg-red-100 text-red-650 font-bold px-3 py-1.5 rounded-xl border border-red-200/50 flex items-center gap-1.5 cursor-pointer text-[11px] transition-all"
                >
                  <RotateCcw size={12} />
                  <span>Khôi phục biểu gốc</span>
                </button>
              </div>

              {/* Logs Timeline */}
              <div className="space-y-5">
                <p className="text-xs font-bold text-slate-400 uppercase tracking-widest">Dòng thời gian hoạt động</p>
                <div className="relative border-l-2 border-slate-150 pl-5 ml-2 space-y-6">
                  {logs.map((log) => (
                    <div key={log.id} className="relative">
                      {/* Timeline Dot */}
                      <span className="absolute -left-[27px] top-1.5 bg-white border-2 border-teal-500 rounded-full w-2.5 h-2.5 z-10" />
                      
                      <div className="space-y-1">
                        <div className="flex items-center justify-between gap-2">
                          <span className="font-extrabold text-xs text-[#0D9488] bg-teal-50 px-2 py-0.5 rounded-md">
                            {log.action}
                          </span>
                          <span className="text-[10px] text-slate-400 font-mono">{log.timestamp}</span>
                        </div>
                        <p className="text-xs font-extrabold text-slate-700">{log.user}</p>
                        <p className="text-xs text-slate-500 whitespace-pre-wrap">{log.details}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="p-5 border-t border-slate-100 flex justify-end bg-slate-50/50">
              <button
                onClick={() => setShowHistoryModal(false)}
                className="bg-slate-800 hover:bg-slate-950 text-white font-bold text-xs px-5 py-2.5 rounded-xl cursor-pointer transition-all"
              >
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}


      {/* Modal 2: ADD NEW SPECIAL RATE ZONE */}
      {showAddGroupModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-xs p-4 animate-fade-in">
          <div className="bg-white rounded-3xl w-full max-w-md shadow-2xl border border-slate-100 overflow-hidden">
            {/* Header */}
            <div className="p-6 border-b border-slate-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <PlusCircle className="text-[#0D9488]" size={18} />
                <h3 className="font-extrabold text-sm text-slate-900">Thêm nhóm giờ đặc biệt</h3>
              </div>
              <button 
                onClick={() => setShowAddGroupModal(false)}
                className="text-slate-400 hover:text-slate-700 rounded-full p-1.5 hover:bg-slate-100 cursor-pointer"
              >
                <X size={16} />
              </button>
            </div>

            {/* Body */}
            <div className="p-6 space-y-4">
              
              {addError && (
                <div className="bg-red-50 text-red-650 border border-red-100 text-xs p-3.5 rounded-xl flex items-center gap-2">
                  <AlertCircle size={14} className="shrink-0" />
                  <span>{addError}</span>
                </div>
              )}

              {/* Day range select */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-600 block">Thời gian áp dụng (Thứ)</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setNewDayType('T2 - T6')}
                    className={`py-2 px-3 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                      newDayType === 'T2 - T6'
                        ? 'border-[#0D9488] bg-teal-50 text-[#0D9488]'
                        : 'border-slate-200 text-slate-600 bg-white hover:bg-slate-50'
                    }`}
                  >
                    Ngày thường (T2 - T6)
                  </button>
                  <button
                    type="button"
                    onClick={() => setNewDayType('T7 - CN')}
                    className={`py-2 px-3 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                      newDayType === 'T7 - CN'
                        ? 'border-[#0D9488] bg-teal-50 text-[#0D9488]'
                        : 'border-slate-200 text-slate-600 bg-white hover:bg-slate-50'
                    }`}
                  >
                    Cuối tuần (T7 - CN)
                  </button>
                </div>
              </div>

              {/* Custom Hours */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-600 block">Khung giờ hoạt động</label>
                <input
                  type="text"
                  placeholder="Ví dụ: 12h - 15h, 6h - 8h"
                  value={newTimeSlot}
                  onChange={(e) => setNewTimeSlot(e.target.value)}
                  className="w-full text-xs font-semibold text-slate-800 bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 outline-hidden focus:bg-white focus:border-slate-400 focus:ring-2 focus:ring-slate-100"
                />
              </div>

              {/* Price contract */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-600 block">Khách cố định (đ/Giờ)</label>
                <input
                  type="number"
                  step={5000}
                  value={newFixedPrice}
                  onChange={(e) => setNewFixedPrice(Math.max(0, parseInt(e.target.value) || 0))}
                  className="w-full text-xs font-bold text-slate-800 bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 outline-hidden focus:bg-white focus:border-slate-400"
                />
              </div>

              {/* Price app */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-600 block">Có tài khoản (đ/Giờ)</label>
                <input
                  type="number"
                  step={5000}
                  value={newAppPrice}
                  onChange={(e) => setNewAppPrice(Math.max(0, parseInt(e.target.value) || 0))}
                  className="w-full text-xs font-bold text-slate-800 bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 outline-hidden focus:bg-white focus:border-slate-400"
                />
              </div>

              {/* Price walkin */}
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-600 block">Vãng lai (đ/Giờ)</label>
                <input
                  type="number"
                  step={5000}
                  value={newWalkinPrice}
                  onChange={(e) => setNewWalkinPrice(Math.max(0, parseInt(e.target.value) || 0))}
                  className="w-full text-xs font-bold text-slate-800 bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 outline-hidden focus:bg-white focus:border-slate-400"
                />
              </div>
            </div>

            {/* Footer buttons */}
            <div className="p-5 border-t border-slate-100 flex items-center justify-end gap-3 bg-slate-50/50">
              <button
                type="button"
                onClick={() => setShowAddGroupModal(false)}
                className="bg-white border border-slate-200 text-slate-700 font-bold text-xs px-4 py-2.5 rounded-xl cursor-pointer hover:bg-slate-50"
              >
                Hủy bỏ
              </button>
              <button
                type="button"
                onClick={handleCreateGroup}
                className="bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-xs px-5 py-2.5 rounded-xl cursor-pointer transition-all active:scale-95 shadow-sm"
              >
                Thêm nhóm giờ
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}


/**
 * Sub-component for individual pricing field.
 * Alternates between beautiful formatted labels ('55.000đ') and plain inputs on focus.
 */
function PillPriceInput({ 
  value, 
  onChange, 
  highlighted 
}: { 
  value: number; 
  onChange: (val: number) => void; 
  highlighted: boolean; 
}) {
  const [isFocused, setIsFocused] = useState(false);
  const [tempValue, setTempValue] = useState('');

  const formatVND = (num: number): string => {
    return num.toLocaleString('vi-VN') + 'đ';
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
    const val = e.target.value.replace(/\D/g, ''); // only lock numeric digits
    setTempValue(val);
  };

  return (
    <div className="w-full max-w-[150px] mx-auto select-none">
      <input
        type="text"
        value={isFocused ? tempValue : formatVND(value)}
        onFocus={handleFocus}
        onBlur={handleBlur}
        onChange={handleChange}
        inputMode="numeric"
        pattern="[0-9]*"
        className={`w-full text-center font-bold text-[13px] rounded-full py-2 px-5 outline-hidden transition-all duration-150 border ${
          highlighted
            ? 'border-teal-500 text-teal-600 bg-teal-50/10 font-black shadow-[inset_0_1px_2px_rgba(13,148,136,0.05)] hover:bg-[#F0FDFA] focus:border-teal-600 focus:ring-2 focus:ring-teal-100/50'
            : 'border-slate-200/90 text-slate-700 bg-slate-50/45 hover:bg-slate-100/60 focus:bg-white focus:border-slate-400 focus:ring-2 focus:ring-slate-100/40'
        }`}
      />
    </div>
  );
}
