

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../payment/payment_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ---- Đặt sân lẻ ----
  DateTime _selectedDate = DateTime.now();
  double _startHour = 5;
  double _endHour = 24;
  final String _matType = 'PVC';
  final List<String> _courts = ['01','02','03','04','05','06','07','08','09','10'];
  final List<int> _hours = List.generate(19, (i) => i + 5);
  late List<List<int>> _grid;
  final Set<String> _selected = {};

  // ---- Đặt lịch cố định ----
  final List<String> _weekdays = ['T2','T3','T4','T5','T6','T7','CN'];
  final Set<String> _selectedWeekdays = {};
  double _fixedStart = 18;
  double _fixedEnd = 20;
  int _months = 3;
  final List<String> _availableCourts = [
    'Sân 01','Sân 02','Sân 03','Sân 04','Sân 05',
    'Sân 06','Sân 07','Sân 08','Sân 09','Sân 10'
  ];
  final Set<String> _selectedFixedCourts = {};
  bool _showSummary = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _initGrid();
  }

  void _initGrid() {
    _grid = List.generate(_courts.length, (c) {
      return List.generate(_hours.length, (h) {
        if (h < 2) return 3;
        if (c == 0 && (h == 4 || h == 5)) return 1;
        if (c == 1 && (h == 3 || h == 4)) return 2;
        if (c == 3 && (h == 7 || h == 8)) return 1;
        if (c == 4 && h == 5) return 2;
        if (c == 5 && (h == 9 || h == 10)) return 1;
        return 0;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatHour(double h) =>
      '${h.toInt().toString().padLeft(2, '0')}:00';

  Color _cellColor(int status, bool isSelected) {
    if (isSelected) return AppColors.primary;
    switch (status) {
      case 1: return const Color(0xFFEF5350);
      case 2: return const Color(0xFFFF9800);
      case 3: return const Color(0xFFBDBDBD);
      default: return const Color(0xFFF0FAF9);
    }
  }

  List<MapEntry<int, int>> get _selectedSlots => _selected.map((k) {
        final p = k.split('_');
        return MapEntry(int.parse(p[0]), int.parse(p[1]));
      }).toList();

  double _calcTotalPrice() {
    double total = 0;
    for (final s in _selectedSlots) {
      final h = _hours[s.value];
      if (h >= 5 && h < 9) total += 70000;
      else if (h >= 9 && h < 16) total += 60000;
      else if (h >= 16 && h < 22) total += 100000;
      else total += 70000;
    }
    return total;
  }

  double _calcFixedTotal() {
    final hours = _fixedEnd - _fixedStart;
    const weeksPerMonth = 4;
    return 100000 * hours * _selectedWeekdays.length *
        weeksPerMonth * _months *
        (_selectedFixedCourts.isEmpty ? 1 : _selectedFixedCourts.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildLeSan(), _buildCoDinh()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primary, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Đặt sân',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '🏸 Đặt sân lẻ'),
            Tab(text: '📅 Đặt lịch cố định'),
          ],
        ),
      ),
    );
  }

  // ==================== ĐẶT SÂN LẺ ====================
  Widget _buildLeSan() {
    final startIdx = (_startHour - 5).toInt().clamp(0, _hours.length - 1);
    final endIdx = (_endHour - 5).toInt().clamp(startIdx + 1, _hours.length);
    final visibleHours = _hours.sublist(startIdx, endIdx);

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: _filterDropdown(
                      icon: Icons.calendar_today_rounded,
                      label: '${_selectedDate.day.toString().padLeft(2,'0')}/${_selectedDate.month.toString().padLeft(2,'0')}/${_selectedDate.year}',
                      onTap: _pickDate,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _filterDropdown(
                      icon: Icons.access_time_rounded,
                      label: '${_formatHour(_startHour)} - ${_formatHour(_endHour)}',
                      onTap: _showTimeRangeSheet,
                    )),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    const Text('Thảm:', style: TextStyle(fontSize: 12, color: AppColors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_matType,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() { if (_startHour > 5) { _startHour--; _selected.clear(); } }),
                          child: const Icon(Icons.chevron_left_rounded, color: AppColors.primary, size: 28),
                        ),
                        Row(
                          children: [
                            _hourBadge(_formatHour(_startHour), AppColors.primary),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('—', style: TextStyle(color: AppColors.grey)),
                            ),
                            _hourBadge(_formatHour(_endHour), AppColors.secondary),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() { if (_endHour < 24) { _endHour++; _selected.clear(); } }),
                          child: const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 28),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(_startHour, _endHour),
                      min: 5, max: 24, divisions: 19,
                      activeColor: AppColors.primary,
                      inactiveColor: const Color(0xFFEEEEEE),
                      onChanged: (v) => setState(() {
                        _startHour = v.start; _endHour = v.end; _selected.clear();
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: visibleHours.map((h) => SizedBox(
                                width: 42,
                                child: Center(
                                  child: Text('${h.toString().padLeft(2,'0')}h',
                                      style: const TextStyle(
                                          fontSize: 9, color: AppColors.grey, fontWeight: FontWeight.w600)),
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 8),
                    ...List.generate(_courts.length, (c) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Center(
                                    child: Text(_courts[c],
                                        style: const TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.black)),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: List.generate(visibleHours.length, (hi) {
                                        final globalHi = startIdx + hi;
                                        final key = '${c}_$globalHi';
                                        final status = _grid[c][globalHi];
                                        final isSelected = _selected.contains(key);
                                        final canSelect = status == 0;
                                        return GestureDetector(
                                          onTap: canSelect ? () => setState(() {
                                            if (isSelected) _selected.remove(key);
                                            else _selected.add(key);
                                          }) : null,
                                          child: Container(
                                            width: 42, height: 34,
                                            margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _cellColor(status, isSelected),
                                              borderRadius: BorderRadius.circular(6),
                                              border: isSelected
                                                  ? Border.all(color: AppColors.primary, width: 1.5)
                                                  : status == 0 ? Border.all(color: Colors.grey.shade200) : null,
                                            ),
                                            child: status == 0 && !isSelected
                                                ? const Icon(Icons.star_border_rounded, size: 13, color: AppColors.grey)
                                                : null,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 40),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10, runSpacing: 6,
                  children: [
                    _legend(const Color(0xFFF0FAF9), 'Trống', border: true),
                    _legend(AppColors.primary, 'Đã chọn'),
                    _legend(const Color(0xFFEF5350), 'Đã đặt'),
                    _legend(const Color(0xFFFF9800), 'Cố định'),
                    _legend(const Color(0xFFBDBDBD), 'Quá khứ'),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
        if (_selected.isNotEmpty)
          Positioned(bottom: 0, left: 0, right: 0, child: _buildConfirmBar()),
      ],
    );
  }

  Widget _hourBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }

  Widget _filterDropdown({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.black),
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.grey),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label, {bool border = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border ? Border.all(color: Colors.grey.shade300) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.grey)),
      ],
    );
  }

  Widget _buildConfirmBar() {
    final total = _calcTotalPrice();
    final slots = _selectedSlots;
    final courtNums = slots.map((s) => _courts[s.key]).toSet().toList()..sort();
    final hoursList = slots.map((s) => _hours[s.value]).toList()..sort();
    final startH = hoursList.first;
    final endH = hoursList.last + 1;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sân ${courtNums.join(', ')}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.black)),
                  Text('$_matType  •  ${startH.toString().padLeft(2,'0')}:00 - ${endH.toString().padLeft(2,'0')}:00  •  ${slots.length}h',
                      style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                ],
              ),
              Text('${(total / 1000).toStringAsFixed(0)}.000đ',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Xác nhận đặt sân',
            onTap: () => _showConfirmSheet(courtNums.join(', '), startH, endH, total),
          ),
        ],
      ),
    );
  }

  void _showConfirmSheet(String court, int start, int end, double total) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sân $court',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.black)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Trống',
                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _confirmRow('Loại thảm', _matType),
            _confirmRow('Thời gian',
                '${start.toString().padLeft(2,'0')}:00 - ${end.toString().padLeft(2,'0')}:00  (${end - start}h)'),
            _confirmRow('Ngày đặt', '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
            _confirmRow('Loại đặt', 'Đơn giá'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền tạm tính',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.black)),
                Text('${(total / 1000).toStringAsFixed(0)}.000đ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Xác nhận →',
              onTap: () {
                Navigator.pop(context);
                Get.to(() => PaymentScreen(
                      courtName: 'Sân $court',
                      price: total,
                      date: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      time: '${start.toString().padLeft(2, '0')}:00 - ${end.toString().padLeft(2, '0')}:00',
                      isFixed: false,
                    ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.black)),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _selectedDate = picked; _selected.clear(); });
  }

  void _showTimeRangeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn khung giờ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              RangeSlider(
                values: RangeValues(_startHour, _endHour),
                min: 5, max: 24, divisions: 19,
                activeColor: AppColors.primary,
                labels: RangeLabels(_formatHour(_startHour), _formatHour(_endHour)),
                onChanged: (v) {
                  setS(() { _startHour = v.start; _endHour = v.end; });
                  setState(() { _startHour = v.start; _endHour = v.end; _selected.clear(); });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(_formatHour(_startHour),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const Text('—', style: TextStyle(color: AppColors.grey)),
                  Text(_formatHour(_endHour),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 16),
              CustomButton(text: 'Áp dụng', onTap: () => Navigator.pop(context)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ĐẶT LỊCH CỐ ĐỊNH ====================
  Widget _buildCoDinh() {
    final canShow = _selectedFixedCourts.isNotEmpty && _selectedWeekdays.isNotEmpty;
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: canShow ? 100 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Card cấu hình
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cấu hình lịch cố định',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.black)),
                    const SizedBox(height: 16),

                    // Chọn thứ
                    const Text('Chọn ngày trong tuần',
                        style: TextStyle(fontSize: 12, color: AppColors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _weekdays.map((day) {
                        final isSel = _selectedWeekdays.contains(day);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSel) _selectedWeekdays.remove(day);
                            else _selectedWeekdays.add(day);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary : const Color(0xFFF0FAF9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: isSel ? AppColors.primary : Colors.grey.shade200),
                            ),
                            child: isSel
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                : Center(
                                    child: Text(day,
                                        style: const TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.grey)),
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Khung giờ dạng đồng hồ
                    const Text('Khung giờ', style: TextStyle(fontSize: 12, color: AppColors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickFixedTime(isStart: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FAF9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(_formatHour(_fixedStart),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.black)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('—', style: TextStyle(fontSize: 20, color: Colors.grey.shade400)),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickFixedTime(isStart: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FAF9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(_formatHour(_fixedEnd),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.black)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kỳ hạn dropdown
                    const Text('Kỳ hạn đăng ký', style: TextStyle(fontSize: 12, color: AppColors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FAF9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButton<int>(
                        value: _months,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.black),
                        items: List.generate(12, (i) => i + 1).map((m) =>
                          DropdownMenuItem(value: m, child: Text('$m tháng'))).toList(),
                        onChanged: (v) => setState(() => _months = v!),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Danh sách sân trống
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Danh sách sân trống',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.black)),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_selectedFixedCourts.length == _availableCourts.length) {
                              _selectedFixedCourts.clear();
                            } else {
                              _selectedFixedCourts.addAll(_availableCourts);
                            }
                          }),
                          child: Text(
                            _selectedFixedCourts.length == _availableCourts.length
                                ? 'Bỏ chọn tất cả'
                                : 'Chọn tất cả',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._availableCourts.map((court) {
                      final isSel = _selectedFixedCourts.contains(court);
                      final price = ((_fixedEnd - _fixedStart) * 100).toInt();
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSel) _selectedFixedCourts.remove(court);
                          else _selectedFixedCourts.add(court);
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary.withOpacity(0.04) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSel ? AppColors.primary : Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/sancaulong.jpg',
                                  width: 60, height: 50,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(court,
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.black)),
                                    Text('PVC  •  ${_formatHour(_fixedStart)} - ${_formatHour(_fixedEnd)}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.grey)),
                                  ],
                                ),
                              ),
                              Text('$price.000đ/b',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              const SizedBox(width: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: isSel ? AppColors.primary : Colors.grey.shade300),
                                ),
                                child: isSel
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

              // ── Tóm tắt hợp đồng
              if (canShow) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      // Header tóm tắt
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tóm tắt hợp đồng',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.black)),
                            GestureDetector(
                              onTap: () => setState(() => _showSummary = !_showSummary),
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _showSummary ? Icons.close_rounded : Icons.expand_more_rounded,
                                  size: 16, color: AppColors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showSummary) ...[
                        const Divider(height: 20, indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              _summaryRow('Số ngày/tuần',
                                  '${_selectedWeekdays.length} ngày (${_selectedWeekdays.join(', ')})'),
                              _summaryRow('Thời gian',
                                  '${_formatHour(_fixedStart)} - ${_formatHour(_fixedEnd)} (${(_fixedEnd - _fixedStart).toInt()}h)'),
                              _summaryRow('Kỳ hạn',
                                  '$_months tháng (${_months * 4} tuần)'),
                              _summaryRow('Số sân đặt', '${_selectedFixedCourts.length} sân'),
                              _summaryRow('Tổng buổi',
                                  '${_selectedWeekdays.length * 4 * _months} buổi'),
                              _summaryRow('Đơn giá',
                                  '${((_fixedEnd - _fixedStart) * 100).toInt()}.000đ/buổi/sân'),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Tổng tiền tạm tính',
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.black)),
                                  Text(
                                    '${(_calcFixedTotal() / 1000).toStringAsFixed(0)}.000đ',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),

        // ── Bottom thanh toán
        if (canShow)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Tổng tiền tạm tính',
                            style: TextStyle(fontSize: 11, color: AppColors.grey)),
                        Text(
                          '${(_calcFixedTotal() / 1000).toStringAsFixed(0)}.000đ',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Thanh toán',
                      onTap: () {
                        final total = _calcFixedTotal();
                        final courtNames = _selectedFixedCourts.join(', ');
                        Get.to(() => PaymentScreen(
                              courtName: 'Sân $courtNames (Cố định)',
                              price: total,
                              date: 'Mỗi tuần (${_selectedWeekdays.join(', ')})',
                              time: '${_formatHour(_fixedStart)} - ${_formatHour(_fixedEnd)}',
                              isFixed: true,
                              fixedDuration: '$_months tháng',
                            ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.black)),
          ),
        ],
      ),
    );
  }

  void _pickFixedTime({required bool isStart}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          double tempHour = isStart ? _fixedStart : _fixedEnd;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isStart ? 'Giờ bắt đầu' : 'Giờ kết thúc',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Text(_formatHour(tempHour),
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 10),
                Slider(
                  value: tempHour,
                  min: 5, max: 24, divisions: 19,
                  activeColor: AppColors.primary,
                  inactiveColor: const Color(0xFFEEEEEE),
                  onChanged: (v) => setS(() => tempHour = v),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Áp dụng',
                  onTap: () {
                    setState(() {
                      if (isStart) {
                        _fixedStart = tempHour;
                        if (_fixedEnd <= _fixedStart) _fixedEnd = _fixedStart + 1;
                      } else {
                        _fixedEnd = tempHour;
                        if (_fixedStart >= _fixedEnd) _fixedStart = _fixedEnd - 1;
                      }
                    });
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}