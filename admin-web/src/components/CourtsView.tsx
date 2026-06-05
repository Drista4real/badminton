import React, { useState } from 'react';
import { PlusCircle, Edit3, Image, ToggleLeft, ToggleRight, Trash2, Check, X, ShieldAlert } from 'lucide-react';
import { Court } from '../types';

interface CourtsViewProps {
  courts: Court[];
  onToggleCourtActive: (id: string) => void;
  onAddCourt: (court: Court) => void;
  onUpdateCourt: (court: Court) => void;
}

export default function CourtsView({
  courts,
  onToggleCourtActive,
  onAddCourt,
  onUpdateCourt
}: CourtsViewProps) {
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingCourt, setEditingCourt] = useState<Court | null>(null);

  // Add / Edit form state
  const [name, setName] = useState('');
  const [type, setType] = useState<'Thảm PVC' | 'Sàn Gỗ' | 'Bê tông'>('Thảm PVC');
  const [price, setPrice] = useState(120000);
  const [image, setImage] = useState('');

  const handleOpenAdd = () => {
    setName('');
    setType('Thảm PVC');
    setPrice(120000);
    setImage('');
    setShowAddModal(true);
  };

  const handleAddSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || price <= 0) return;

    const id = String(courts.length + 1);
    const newCourt: Court = {
      id,
      name,
      type,
      pricePerHour: price,
      isActive: true,
      image: image || 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=500&auto=format&fit=crop&q=60'
    };

    onAddCourt(newCourt);
    setShowAddModal(false);
  };

  const handleOpenEdit = (c: Court) => {
    setEditingCourt(c);
    setName(c.name);
    setType(c.type);
    setPrice(c.pricePerHour);
    setImage(c.image);
  };

  const handleEditSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingCourt || !name || price <= 0) return;

    const updated: Court = {
      ...editingCourt,
      name,
      type,
      pricePerHour: price,
      image: image || editingCourt.image
    };

    onUpdateCourt(updated);
    setEditingCourt(null);
  };

  return (
    <div className="space-y-6">
      {/* Header section with add court */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Quản lý sân bãi</h1>
          <p className="text-sm text-gray-500">Xem danh mục sân chơi, chỉnh sửa biểu giá và thiết lập chế độ bảo dưỡng.</p>
        </div>

        <button
          onClick={handleOpenAdd}
          className="bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold px-4 py-2.5 rounded-xl flex items-center justify-center gap-1.5 shadow-xs transition-all cursor-pointer"
        >
          <PlusCircle size={16} />
          Thêm sân mới
        </button>
      </div>

      {/* Grid with visual Court Cards for aesthetic vibe */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
        {courts.map((court) => (
          <div
            key={court.id}
            className={`bg-white rounded-2xl border overflow-hidden shadow-xs transition-all flex flex-col justify-between ${
              court.isActive ? 'border-gray-100 hover:shadow-md' : 'border-dashed border-gray-300 opacity-60'
            }`}
          >
            {/* Image banner with status tag */}
            <div className="h-36 relative bg-slate-100">
              <img
                src={court.image}
                alt={court.name}
                className="w-full h-full object-cover"
                referrerPolicy="no-referrer"
              />
              <div className="absolute top-3 left-3 flex gap-2">
                <span className="text-[9px] font-bold tracking-widest text-slate-900 bg-white/95 backdrop-blur-xs px-2.5 py-1 rounded-md uppercase shadow-xs">
                  {court.type}
                </span>
                <span className={`text-[9px] font-bold tracking-widest text-white px-2.5 py-1 rounded-md uppercase shadow-xs ${
                  court.isActive ? 'bg-indigo-600' : 'bg-rose-600'
                }`}>
                  {court.isActive ? 'Hoạt động' : 'Bảo trì'}
                </span>
              </div>
            </div>

            {/* Core details */}
            <div className="p-4 space-y-3.5 flex-1 flex flex-col justify-between">
              <div>
                <h3 className="font-bold text-gray-900 text-sm">{court.name}</h3>
                <div className="text-indigo-600 font-extrabold font-mono text-sm mt-1">
                  {court.pricePerHour.toLocaleString('vi-VN')} VNĐ <span className="text-[10px] text-gray-400 font-normal">/ giờ chơi</span>
                </div>
              </div>

              {/* Action utilities and soft delete toggle */}
              <div className="flex items-center justify-between pt-3 border-t border-gray-100/60 mt-auto">
                {/* Soft delete toggle layout description */}
                <div className="flex items-center gap-1.5">
                  <span className="text-[10px] text-gray-400 font-bold uppercase">Bảo trì</span>
                  <button
                    onClick={() => {
                      onToggleCourtActive(court.id);
                      alert(`Đã ${court.isActive ? 'ĐÓNG SÂN VÀ CHUYỂN BẢO TRÌ' : 'KÍCH HOẠT hoạt động'} sân: ${court.name}`);
                    }}
                    className="focus:outline-hidden cursor-pointer"
                    title={court.isActive ? 'Chuyển sang trạng thái bảo trì (Xóa mềm)' : 'Kích hoạt lại sân chơi'}
                  >
                    {court.isActive ? (
                      <ToggleRight className="text-indigo-600" size={34} />
                    ) : (
                      <ToggleLeft className="text-gray-300" size={34} />
                    )}
                  </button>
                </div>

                <div className="flex gap-1">
                  <button
                    onClick={() => handleOpenEdit(court)}
                    className="p-1.5 rounded-lg text-gray-600 hover:text-indigo-600 hover:bg-slate-50 border border-transparent hover:border-indigo-100 cursor-pointer transition-all"
                    title="Chỉnh sửa thông tin sân"
                  >
                    <Edit3 size={15} />
                  </button>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Soft Delete Safeguard warning alert */}
      <div className="bg-amber-50 border border-amber-200/60 text-amber-800 p-4 rounded-2xl flex items-start gap-3.5">
        <ShieldAlert size={20} className="text-amber-600 shrink-0 mt-0.5" />
        <div className="text-xs space-y-1">
          <p className="font-bold uppercase tracking-wide text-amber-900">Tính năng "Xóa mềm" bảo trì sân chơi</p>
          <p className="leading-relaxed">
            Hệ thống <b>không sử dụng lệnh xóa cứng (DELETE)</b> để đảm bảo toàn vẹn dữ liệu thống kê doanh số.
            Khi dịch vụ sân bãi được tắt công tắc, sân đó ngay lập tức bị loại bỏ khỏi Grid của thu ngân tại quầy và App của người chơi.
          </p>
        </div>
      </div>

      {/* ADD COURT MODAL & EDIT COURT MODAL */}
      {(showAddModal || editingCourt) && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <form
            onSubmit={showAddModal ? handleAddSubmit : handleEditSubmit}
            className="bg-white rounded-3xl border border-gray-100 max-w-sm w-full overflow-hidden shadow-2xl relative animate-in fade-in zoom-in-95 duration-200"
          >
            <div className="p-5 bg-indigo-600 text-white flex justify-between items-center">
              <h3 className="font-bold text-base flex items-center gap-1.5 font-sans">
                <PlusCircle size={18} />
                {showAddModal ? 'Thêm Sân bãi mới' : `Sửa cấu hình: ${editingCourt?.name}`}
              </h3>
              <button
                type="button"
                onClick={() => { setShowAddModal(false); setEditingCourt(null); }}
                className="hover:scale-110 text-white/80 hover:text-white cursor-pointer"
              >
                <X size={18} />
              </button>
            </div>

            <div className="p-6 space-y-4 font-sans">
              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-400 uppercase">Tên sân bãi</label>
                <input
                  type="text"
                  required
                  className="w-full text-xs text-gray-800 border border-gray-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-indigo-500 font-bold"
                  placeholder="Ví dụ: Sân VIP 3, Sân 11..."
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-400 uppercase">Loại thảm chơi</label>
                <select
                  className="w-full text-xs text-gray-800 border border-gray-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-indigo-500 font-bold bg-white"
                  value={type}
                  onChange={(e) => setType(e.target.value as any)}
                >
                  <option value="Thảm PVC">Thảm PVC tiêu chuẩn</option>
                  <option value="Sàn Gỗ">Sàn Gỗ chống trượt</option>
                  <option value="Bê tông">Bê tông ngoài trời</option>
                </select>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-400 uppercase">Giá thuê mỗi giờ (VNĐ)</label>
                <input
                  type="number"
                  required
                  min={10000}
                  step={5000}
                  className="w-full text-xs text-gray-800 border border-gray-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-indigo-500 font-mono font-bold"
                  value={price}
                  onChange={(e) => setPrice(parseInt(e.target.value) || 0)}
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-gray-400 uppercase">Ảnh bìa sân (URL)</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    className="w-full text-xs text-slate-700 border border-gray-200 rounded-xl px-4 py-2.5 outline-hidden focus:border-indigo-500 font-mono whitespace-nowrap overflow-hidden text-ellipsis"
                    placeholder="Bỏ trống để dùng ảnh mặc định..."
                    value={image}
                    onChange={(e) => setImage(e.target.value)}
                  />
                  <div className="bg-slate-50 text-slate-400 p-2.5 rounded-xl border border-slate-200 shrink-0">
                    <Image size={16} />
                  </div>
                </div>
              </div>

              <div className="border-t border-gray-100 pt-4 flex justify-end gap-3.5">
                <button
                  type="button"
                  onClick={() => { setShowAddModal(false); setEditingCourt(null); }}
                  className="text-xs bg-gray-100 text-gray-600 px-4 py-2.5 rounded-xl font-bold cursor-pointer"
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  className="text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl font-bold cursor-pointer transition-all shadow-xs"
                >
                  {showAddModal ? 'Thêm vào hệ thống' : 'Lưu cập nhật'}
                </button>
              </div>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
