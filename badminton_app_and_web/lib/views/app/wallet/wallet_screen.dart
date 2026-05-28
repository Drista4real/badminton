// ===============================
// FILE: lib/views/app/wallet/wallet_screen.dart
// ===============================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/app_colors.dart';
import '../../../widgets/custom_button.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final double _balance = 500000;
  final int _points = 1200;

  final List<Map<String, dynamic>> _transactions = [
    {
      'icon': Icons.add_circle_rounded,
      'color': Color(0xFF4CAF50),
      'title': '+100.000đ Hoàn tiền đơn hàng',
      'date': '16/05/2025',
      'status': 'Hoàn tiền',
      'statusColor': Color(0xFF4CAF50),
      'amount': '+100.000đ',
      'isPlus': true,
    },
    {
      'icon': Icons.remove_circle_rounded,
      'color': Color(0xFFFF9800),
      'title': '-50 Điểm đổi mã giảm giá',
      'date': '14/05/2025',
      'status': 'Thanh xong',
      'statusColor': Color(0xFF0B7D77),
      'amount': '-50 điểm',
      'isPlus': false,
    },
    {
      'icon': Icons.add_circle_rounded,
      'color': Color(0xFF4CAF50),
      'title': '+200.000đ Hoàn tiền đơn hàng',
      'date': '10/05/2025',
      'status': 'Hoàn tiền',
      'statusColor': Color(0xFF4CAF50),
      'amount': '+200.000đ',
      'isPlus': true,
    },
    {
      'icon': Icons.remove_circle_rounded,
      'color': Color(0xFFEF5350),
      'title': '-150.000đ Thanh toán đặt sân',
      'date': '08/05/2025',
      'status': 'Hoàn thành',
      'statusColor': Color(0xFF0B7D77),
      'amount': '-150.000đ',
      'isPlus': false,
    },
    {
      'icon': Icons.add_circle_rounded,
      'color': Color(0xFF4CAF50),
      'title': '+500 Điểm tích lũy đặt sân',
      'date': '05/05/2025',
      'status': 'Tích điểm',
      'statusColor': Color(0xFF9C27B0),
      'amount': '+500 điểm',
      'isPlus': true,
    },
  ];

  String _formatMoney(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}.000 đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 16),
                    _buildPointsCard(),
                    const SizedBox(height: 16),
                    _buildTransactionList(),
                    const SizedBox(height: 20),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const Expanded(
            child: Text('Ví của tôi',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history_rounded,
                  color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7D77), Color(0xFF0DBDB6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SỐ DƯ VÍ TIỀN',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              '${_balance.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}.đ',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tiền hoàn từ các đơn huỷ/hoàn ngập',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => _showRefundSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Yêu cầu hoàn tiền',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.stars_rounded,
                  color: Color(0xFFFF9800), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ĐIỂM TÍCH LŨY',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.grey,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_points.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text('Điểm',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.grey)),
                      ),
                    ],
                  ),
                  const Text(
                    'Dùng điểm tích lũy để giảm giá khi thanh toán',
                    style: TextStyle(fontSize: 10, color: AppColors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Đổi điểm',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF9800),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lịch sử giao dịch',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black)),
              GestureDetector(
                onTap: () {},
                child: const Text('Xem tất cả',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._transactions.map((t) => _buildTransactionItem(t)).toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (t['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(t['icon'] as IconData,
                color: t['color'] as Color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title'],
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(t['date'],
                    style: const TextStyle(fontSize: 10, color: AppColors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t['amount'],
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t['isPlus'] ? const Color(0xFF4CAF50) : AppColors.black),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (t['statusColor'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t['status'],
                  style: TextStyle(
                      fontSize: 9,
                      color: t['statusColor'] as Color,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRefundSheet() {
    final bankController = TextEditingController();
    final accountController = TextEditingController();
    final nameController = TextEditingController();
    String? selectedBank;
    final banks = [
      'Vietcombank', 'Techcombank', 'BIDV',
      'VPBank', 'MB Bank', 'ACB', 'Sacombank', 'TPBank'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.black),
                    ),
                    const SizedBox(width: 10),
                    const Text('Nhận tiền hoàn trả',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black)),
                  ],
                ),
                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Hình thức chuyển khoản áp dụng khi khách hàng hủy đơn và chọn lại tiền mặt.',
                          style: TextStyle(fontSize: 11, color: AppColors.grey, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Thông tin nhận tiền
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_rounded,
                              color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('Thông tin nhận tiền',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Tên ngân hàng
                      _refundLabel('Tên ngân hàng *'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButton<String>(
                          value: selectedBank,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Text('Chọn ngân hàng',
                              style: TextStyle(fontSize: 13, color: AppColors.grey)),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.primary),
                          items: banks.map((b) =>
                              DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (v) => setS(() => selectedBank = v),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Số tài khoản
                      _refundLabel('Số tài khoản *'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: accountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Nhập số tài khoản của bạn',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            suffixIcon: Icon(Icons.credit_card_rounded,
                                color: AppColors.grey, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tên chủ thẻ
                      _refundLabel('Tên chủ thẻ *'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'NHẬP TÊN CHỦ THẺ KHÔNG DẤU',
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 12, color: AppColors.grey),
                          const SizedBox(width: 4),
                          Text('Giao dịch bảo mật 256-bit',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Xác nhận hoàn tiền →',
                  onTap: () {
                    if (selectedBank == null ||
                        accountController.text.isEmpty ||
                        nameController.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng điền đầy đủ thông tin!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Yêu cầu hoàn tiền đã được gửi!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _refundLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.black));
  }
}