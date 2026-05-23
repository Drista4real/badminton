// ===============================
// FILE: lib/views/app/booking/booking_screen.dart
// ===============================

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../widgets/custom_button.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Ngày & tháng
  DateTime _selectedDate = DateTime.now();

  // Khung giờ slider
  double _startHour = 5;
  double _endHour = 24;

  // Loại thảm
  final String _matType = 'PVC';

  // Grid: 10 sân x 17 giờ (5h->21h)
  final List<String> _courts = [
    '01','02','03','04','05','06','07','08','09','10'
  ];
  final List<int> _hours = List.generate(19, (i) => i + 5); // 5h -> 23h
  late List<List<int>> _grid; // status: 0=trống,1=đã đặt,2=cố định,3=quá khứ,4=chờ xếp

  final Set<String> _selected = {}; // "courtIdx_hourIdx"

  // ---- Cố định ----
  final List<String> _weekdays = ['T2','T3','T4','T5','T6','T7','CN'];
  final Set<String> _selectedWeekdays = {};
  double _fixedStart = 18;
  double _fixedEnd = 20;
  int _months = 3;
  final List<String> _availableCourts = ['Sân 01','Sân 02','Sân 03','Sân 04','Sân 05','Sân 06','Sân 07','Sân 08','Sân 09','Sân 10'];
  final Set<String> _selectedFixedCourts = {};

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
        if (h < 2) return 3; // quá khứ
        if (c == 0 && (h == 4 || h == 5)) return 1; // đã đặt
        if (c == 1 && (h == 3 || h == 4)) return 2; // cố định
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
    double pricePerHour = 100000;
    final hours = _fixedEnd - _fixedStart;
    const weeksPerMonth = 4;
    return pricePerHour * hours * _selectedWeekdays.length *
        weeksPerMonth * _months * (_selectedFixedCourts.isEmpty ? 1 : _selectedFixedCourts.length);
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
                children: [
                  _buildLeSan(),
                  _buildCoDinh(),
                ],
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bộ lọc ngày + khung giờ
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

              // Thảm
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    const Text('Thảm:',
                        style: TextStyle(fontSize: 12, color: AppColors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_matType,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              // Slider khung giờ
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_startHour > 5) { _startHour--; _selected.clear(); }
                          }),
                          child: const Icon(Icons.chevron_left_rounded,
                              color: AppColors.primary, size: 28),
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
                          onTap: () => setState(() {
                            if (_endHour < 24) { _endHour++; _selected.clear(); }
                          }),
                          child: const Icon(Icons.chevron_right_rounded,
                              color: AppColors.primary, size: 28),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(_startHour, _endHour),
                      min: 5, max: 24, divisions: 19,
                      activeColor: AppColors.primary,
                      inactiveColor: const Color(0xFFEEEEEE),
                      onChanged: (v) => setState(() {
                        _startHour = v.start;
                        _endHour = v.end;
                        _selected.clear();
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Grid sân
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    // Header giờ
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
                                  child: Text(
                                    '${h.toString().padLeft(2,'0')}h',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.grey,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 8),

                    // Rows sân
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
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.black)),
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
                                          onTap: canSelect
                                              ? () => setState(() {
                                                    if (isSelected) {
                                                      _selected.remove(key);
                                                    } else {
                                                      _selected.add(key);
                                                    }
                                                  })
                                              : null,
                                          child: Container(
                                            width: 42,
                                            height: 34,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _cellColor(status, isSelected),
                                              borderRadius: BorderRadius.circular(6),
                                              border: isSelected
                                                  ? Border.all(
                                                      color: AppColors.primary,
                                                      width: 1.5)
                                                  : status == 0
                                                      ? Border.all(
                                                          color: Colors.grey.shade200)
                                                      : null,
                                            ),
                                            child: status == 0 && !isSelected
                                                ? const Icon(Icons.star_border_rounded,
                                                    size: 13, color: AppColors.grey)
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

              // Chú thích
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

        // Bottom confirm bar
        if (_selected.isNotEmpty)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildConfirmBar(),
          ),
      ],
    );
  }

  Widget _hourBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }

  Widget _filterDropdown({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black),
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: AppColors.grey),
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
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sân ${courtNums.join(', ')}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black),
                  ),
                  Text(
                    '$_matType  •  ${startH.toString().padLeft(2,'0')}:00 - ${endH.toString().padLeft(2,'0')}:00  •  ${slots.length}h',
                    style: const TextStyle(fontSize: 11, color: AppColors.grey),
                  ),
                ],
              ),
              Text(
                '${(total / 1000).toStringAsFixed(0)}.000đ',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Xác nhận đặt sân',
            onTap: () => _showConfirmSheet(
                courtNums.join(', '), startH, endH, total),
          ),
        ],
      ),
    );
  }

  void _showConfirmSheet(String court, int start, int end, double total) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sân $court',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Trống',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _confirmRow('Loại thảm', _matType),
            _confirmRow('Thời gian',
                '${start.toString().padLeft(2,'0')}:00 - ${end.toString().padLeft(2,'0')}:00  (${end - start}h)'),
            _confirmRow('Ngày đặt',
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
            _confirmRow('Loại đặt', 'Đơn giá'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền tạm tính',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black)),
                Text(
                  '${(total / 1000).toStringAsFixed(0)}.000đ',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Xác nhận →',
              onTap: () => Navigator.pop(context),
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
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black)),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn khung giờ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const Text('—', style: TextStyle(color: AppColors.grey)),
                  Text(_formatHour(_endHour),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.secondary)),
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
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chọn thứ
              _sectionCard(
                title: 'Chọn ngày trong tuần',
                icon: Icons.date_range_rounded,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _weekdays.map((day) {
                    final isSelected = _selectedWeekdays.contains(day);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) _selectedWeekdays.remove(day);
                        else _selectedWeekdays.add(day);
                      }),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(day,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : AppColors.grey)),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 4, height: 4,
                              decoration: const BoxDecoration(
                                  color: AppColors.primary, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Khung giờ
              _sectionCard(
                title: 'Khung giờ',
                icon: Icons.access_time_rounded,
                child: Row(
                  children: [
                    Expanded(
                      child: _timePickerBox(
                        label: 'Bắt đầu',
                        hour: _fixedStart,
                        onMinus: () => setState(() {
                          if (_fixedStart > 5) _fixedStart--;
                        }),
                        onPlus: () => setState(() {
                          if (_fixedStart < _fixedEnd - 1) _fixedStart++;
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          const Icon(Icons.arrow_forward_rounded,
                              color: AppColors.grey, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            '${(_fixedEnd - _fixedStart).toInt()}h',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _timePickerBox(
                        label: 'Kết thúc',
                        hour: _fixedEnd,
                        onMinus: () => setState(() {
                          if (_fixedEnd > _fixedStart + 1) _fixedEnd--;
                        }),
                        onPlus: () => setState(() {
                          if (_fixedEnd < 24) _fixedEnd++;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Kỳ hạn
              _sectionCard(
                title: 'Kỳ hạn đăng ký',
                icon: Icons.event_repeat_rounded,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _circleBtn(Icons.remove_rounded, () {
                          setState(() { if (_months > 1) _months--; });
                        }, active: _months > 1),
                        const SizedBox(width: 24),
                        Column(
                          children: [
                            Text('$_months',
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                            const Text('tháng',
                                style: TextStyle(fontSize: 12, color: AppColors.grey)),
                          ],
                        ),
                        const SizedBox(width: 24),
                        _circleBtn(Icons.add_rounded, () {
                          setState(() { if (_months < 12) _months++; });
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick select
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [1, 2, 3, 6, 12].map((m) {
                        final isSel = _months == m;
                        return GestureDetector(
                          onTap: () => setState(() => _months = m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$m tháng',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSel ? Colors.white : AppColors.primary)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Danh sách sân trống
              _sectionCard(
                title: 'Danh sách sân trống',
                icon: Icons.sports_tennis_rounded,
                child: Column(
                  children: _availableCourts.map((court) {
                    final isSelected = _selectedFixedCourts.contains(court);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) _selectedFixedCourts.remove(court);
                        else _selectedFixedCourts.add(court);
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sports_tennis_rounded,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(court,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.black)),
                                  Text('PVC  •  ${_formatHour(_fixedStart)} - ${_formatHour(_fixedEnd)}',
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.grey)),
                                ],
                              ),
                            ),
                            Text(
                              '${((_fixedEnd - _fixedStart) * 100).toInt()}.000đ/b',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Tóm tắt hợp đồng
              if (_selectedFixedCourts.isNotEmpty && _selectedWeekdays.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildFixedSummary(),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),

        // Bottom thanh toán
        if (_selectedFixedCourts.isNotEmpty && _selectedWeekdays.isNotEmpty)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                      children: [
                        const Text('Tổng tiền tạm tính',
                            style: TextStyle(fontSize: 11, color: AppColors.grey)),
                        Text(
                          '${(_calcFixedTotal() / 1000).toStringAsFixed(0)}.000đ',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Thanh toán',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFixedSummary() {
    final hours = _fixedEnd - _fixedStart;
    final weeksPerMonth = 4;
    final totalSessions = _selectedWeekdays.length * weeksPerMonth * _months;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.07),
            AppColors.secondary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tóm tắt hợp đồng',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black)),
          const Divider(height: 14),
          _confirmRow('Số ngày/tuần', '${_selectedWeekdays.length} ngày (${_selectedWeekdays.join(', ')})'),
          _confirmRow('Thời gian', '${_formatHour(_fixedStart)} - ${_formatHour(_fixedEnd)} (${hours.toInt()}h)'),
          _confirmRow('Kỳ hạn', '$_months tháng (${_months * 4} tuần)'),
          _confirmRow('Số sân đặt', '${_selectedFixedCourts.length} sân'),
          _confirmRow('Tổng buổi', '$totalSessions buổi'),
          _confirmRow('Đơn giá', '${(hours * 100).toInt()}.000đ/buổi/sân'),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng tiền tạm tính',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black)),
              Text(
                '${(_calcFixedTotal() / 1000).toStringAsFixed(0)}.000đ',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timePickerBox({
    required String label,
    required double hour,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.grey)),
          const SizedBox(height: 6),
          Text(_formatHour(hour),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onMinus,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.remove_rounded,
                      size: 14, color: AppColors.grey),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onPlus,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool active = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.1)
              : const Color(0xFFF0F0F0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: active ? AppColors.primary : AppColors.grey, size: 20),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}