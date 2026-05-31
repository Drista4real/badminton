// ===============================
// FILE: lib/views/app/profile/map_screen.dart
// ===============================

import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedTransport = 0; // 0: Ô tô, 1: Xe máy, 2: Đi bộ

  final List<Map<String, dynamic>> _transportModes = [
    {'icon': Icons.directions_car_rounded, 'label': 'Ô tô', 'time': '25 phút', 'distance': '3.2 km'},
    {'icon': Icons.two_wheeler_rounded, 'label': 'Xe máy', 'time': '12 phút', 'distance': '2.5 km'},
    {'icon': Icons.directions_walk_rounded, 'label': 'Đi bộ', 'time': '38 phút', 'distance': '2.1 km'},
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _transportModes[_selectedTransport];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 16),
          ),
        ),
        title: const Text(
          'Tìm đường',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Location info
          _buildLocationInfo(),

          // Map placeholder
          Expanded(child: _buildMapPlaceholder()),

          // Transport selector + info
          _buildBottomPanel(selected),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.my_location_rounded,
            iconColor: AppColors.primary,
            label: 'Vị trí hiện tại',
            value: 'Vị trí của bạn',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Column(
              children: List.generate(3, (_) => Container(
                width: 2,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(1),
                ),
              )),
            ),
          ),
          _buildLocationRow(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFEF5350),
            label: 'Sân cầu lông ShuttleGo',
            value: 'R0WV+7M Tầng Nhơm Phú, Hồ Chí Minh, Việt Nam',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 11, color: AppColors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder() {
    return Stack(
      children: [
        // Simulated map background
        Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFE8F4F3),
          child: CustomPaint(
            painter: _MapPainter(),
          ),
        ),

        // Route line overlay
        Center(
          child: CustomPaint(
            size: const Size(double.infinity, 300),
            painter: _RoutePainter(),
          ),
        ),

        // Start marker
        Positioned(
          top: 80,
          left: MediaQuery.of(context).size.width * 0.35,
          child: _buildMarker(
            color: AppColors.primary,
            icon: Icons.my_location_rounded,
            label: 'Vị trí bạn',
          ),
        ),

        // End marker
        Positioned(
          bottom: 100,
          right: MediaQuery.of(context).size.width * 0.25,
          child: _buildMarker(
            color: const Color(0xFFEF5350),
            icon: Icons.sports_tennis_rounded,
            label: 'ShuttleGo',
          ),
        ),

        // Map attribution
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '© OpenStreetMap',
              style: TextStyle(fontSize: 9, color: AppColors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarker({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        Container(
          width: 2,
          height: 10,
          color: color,
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(Map<String, dynamic> selected) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Transport mode selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_transportModes.length, (i) {
              final mode = _transportModes[i];
              final isSelected = _selectedTransport == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedTransport = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : const Color(0xFFF0FAF9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFDDEEED),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mode['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Time and distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip(
                label: 'THỜI GIAN DỰ KIẾN',
                value: selected['time'] as String,
                icon: Icons.access_time_rounded,
              ),
              Container(width: 1, height: 50, color: const Color(0xFFEEEEEE)),
              _buildInfoChip(
                label: 'KHOẢNG CÁCH',
                value: selected['distance'] as String,
                icon: Icons.straighten_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Navigate button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text(
                'BẮT ĐẦU DẪN ĐƯỜNG TỪNG CHẶNG',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.split(' ')[0],
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                value.split(' ')[1],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Custom painter for map grid lines
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCE8E6)
      ..strokeWidth = 1;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw some "road" lines
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.3),
      Offset(size.width * 0.9, size.height * 0.3),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.8, size.height * 0.6),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.3, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, 0),
      Offset(size.width * 0.75, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for route
class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.35, 80);
    path.cubicTo(
      size.width * 0.35, 150,
      size.width * 0.6, 150,
      size.width * 0.6, 220,
    );
    path.cubicTo(
      size.width * 0.6, 260,
      size.width * 0.7, 260,
      size.width * 0.72, 300,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
