import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/wallet_transaction_model.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/payment_repository.dart';
import '../../routes/app_routes.dart';
import '../../utils/currency_format.dart';

class PaymentController extends GetxController {
  PaymentController({
    required PaymentRepository paymentRepository,
    required AuthRepository authRepository,
  }) : _paymentRepository = paymentRepository,
       _authRepository = authRepository;

  static const paymentWindowSeconds = 600;
  static const paymentReconcileInterval = Duration(seconds: 5);

  final PaymentRepository _paymentRepository;
  final AuthRepository _authRepository;

  final isLoading = false.obs;
  final isCancelling = false.obs;
  final errorMessage = ''.obs;
  final qrUrl = ''.obs;
  final paymentContent = ''.obs;
  final secondsRemaining = paymentWindowSeconds.obs;
  final walletBalance = 0.0.obs;
  final availableWalletBalance = 0.0.obs;
  final rewardPoints = 0.obs;
  final useWallet = false.obs;
  final useRewardPoints = false.obs;
  final originalAmount = 0.0.obs;
  final payableAmount = 0.0.obs;
  final walletDiscount = 0.0.obs;
  final pointDiscount = 0.0.obs;
  final pointsSpent = 0.obs;
  final isPaymentPrepared = false.obs;

  Timer? _timer;
  StreamSubscription<PaymentOrderStatus>? _orderSub;
  StreamSubscription<WalletSummary>? _walletSub;
  bool _completed = false;
  bool _isReconcilingPayment = false;
  bool _warnedMissingPollingConfig = false;
  DateTime? _lastReconcileAt;

  String? _orderId;
  String _courtName = '';
  String _date = '';
  String _time = '';
  List<String> _bookingIds = const <String>[];

  String get formattedCountdown {
    final minutes = (secondsRemaining.value ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining.value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedOriginalAmount =>
      CurrencyFormat.vnd(originalAmount.value);

  String get formattedPayableAmount => CurrencyFormat.vnd(payableAmount.value);

  String get formattedWalletBalance =>
      CurrencyFormat.vnd(availableWalletBalance.value);

  String get formattedRewardPoints => CurrencyFormat.number(rewardPoints.value);

  String get formattedWalletDiscount =>
      CurrencyFormat.vnd(walletDiscount.value);

  String get formattedPointDiscount => CurrencyFormat.vnd(pointDiscount.value);

  bool get canChangeBenefitOptions =>
      !isPaymentPrepared.value && !isLoading.value;

  Future<void> startPayment({
    required String orderId,
    required double amount,
    required String courtName,
    required String date,
    required String time,
    required bool isFixed,
    String? fixedDuration,
    List<String> bookingIds = const <String>[],
  }) async {
    if (orderId.trim().isEmpty) {
      errorMessage.value = 'Thiếu mã đơn hàng thanh toán.';
      Get.snackbar(
        'Không thể thanh toán',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back<void>();
      return;
    }

    _resetPaymentSession();
    _orderId = orderId.trim();
    originalAmount.value = amount;
    payableAmount.value = amount;
    walletDiscount.value = 0;
    pointDiscount.value = 0;
    pointsSpent.value = 0;
    useWallet.value = false;
    useRewardPoints.value = false;
    isPaymentPrepared.value = false;
    qrUrl.value = '';
    errorMessage.value = '';
    _courtName = courtName;
    _date = date;
    _time = time;
    _bookingIds = bookingIds;
    _completed = false;
    _isReconcilingPayment = false;
    _warnedMissingPollingConfig = false;
    _lastReconcileAt = null;

    secondsRemaining.value = paymentWindowSeconds;
    paymentContent.value = _orderId!;

    _listenWalletSummary();
    _listenOrderStatus(_orderId!);
  }

  void toggleUseWallet(bool? value) {
    if (!canChangeBenefitOptions) return;
    useWallet.value = value == true;
  }

  void toggleUseRewardPoints(bool? value) {
    if (!canChangeBenefitOptions) return;
    useRewardPoints.value = value == true;
    if (useRewardPoints.value && rewardPoints.value < 100) {
      Get.snackbar(
        'Chưa đủ điểm',
        'Bạn cần tối thiểu 100 điểm để dùng điểm tích lũy.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> preparePayment() async {
    final orderId = _orderId;
    if (orderId == null ||
        orderId.isEmpty ||
        isLoading.value ||
        isPaymentPrepared.value) {
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = useWallet.value || useRewardPoints.value
          ? await _paymentRepository.applyAppPaymentBenefits(
              userId: _requireCurrentUserId(),
              orderId: orderId,
              originalAmount: originalAmount.value,
              useWallet: useWallet.value,
              usePoints: useRewardPoints.value,
              bookingIds: _bookingIds,
            )
          : PaymentBenefitResult(
              originalAmount: originalAmount.value,
              payableAmount: originalAmount.value,
              walletDiscount: 0,
              pointDiscount: 0,
              pointsSpent: 0,
              isFullyPaid: false,
            );

      originalAmount.value = result.originalAmount;
      payableAmount.value = result.payableAmount;
      walletDiscount.value = result.walletDiscount;
      pointDiscount.value = result.pointDiscount;
      pointsSpent.value = result.pointsSpent;
      isPaymentPrepared.value = true;

      if (result.isFullyPaid) {
        _completePayment(orderId);
        return;
      }
    } on PaymentRepositoryException catch (error) {
      errorMessage.value = error.message;
      Get.snackbar(
        'Không thể áp dụng thanh toán',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    } catch (_) {
      errorMessage.value = 'Không thể áp dụng ví/điểm. Vui lòng thử lại.';
      return;
    } finally {
      isLoading.value = false;
    }

    await generateQr(orderId: orderId);
    _maybeReconcilePaymentStatus(force: true);
  }

  Future<void> generateQr({required String orderId}) async {
    if (isLoading.value) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final result = await _paymentRepository.generatePaymentQr(
        orderId: orderId,
      );
      qrUrl.value = result.qrUrl;
      paymentContent.value = result.paymentContent;
      _startTimeoutCountdown();
    } on PaymentRepositoryException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Không thể kết nối backend thanh toán.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> retryGenerateQr() async {
    final orderId = _orderId;
    if (orderId == null) return;
    if (!isPaymentPrepared.value) {
      await preparePayment();
      return;
    }
    await generateQr(orderId: orderId);
  }

  Future<void> cancelPaymentAndGoHome() async {
    if (_completed || isCancelling.value) return;

    isCancelling.value = true;
    try {
      final orderId = _orderId;
      if (orderId != null && orderId.isNotEmpty) {
        await _paymentRepository.cancelPendingOrder(
          userId: _requireCurrentUserId(),
          orderId: orderId,
          bookingIds: _bookingIds,
        );
      }
    } catch (_) {
      // Navigation should not be blocked if cancellation cannot be written.
    } finally {
      isCancelling.value = false;
      _resetPaymentSession();
      Get.offAllNamed(AppRoutes.home);
    }
  }

  void _listenWalletSummary() {
    final userId = _requireCurrentUserId();
    _walletSub?.cancel();
    _walletSub = _paymentRepository
        .watchWalletSummary(userId)
        .listen(
          (summary) {
            walletBalance.value = summary.balance;
            availableWalletBalance.value = summary.availableBalance;
            rewardPoints.value = summary.points;
          },
          onError: (_) {
            errorMessage.value = 'Không tải được số dư ví.';
          },
        );
  }

  void _listenOrderStatus(String orderId) {
    _orderSub?.cancel();
    _orderSub = _paymentRepository
        .watchOrderStatus(orderId)
        .listen(
          (status) {
            if (_completed || !status.isPaid) return;
            _completePayment(orderId);
          },
          onError: (_) {
            errorMessage.value = 'Không thể lắng nghe trạng thái thanh toán.';
          },
        );
  }

  void _startTimeoutCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_completed) {
        timer.cancel();
        return;
      }

      if (secondsRemaining.value <= 0) {
        timer.cancel();
        if (!_completed) {
          cancelPaymentAndGoHome();
        }
        return;
      }

      _maybeReconcilePaymentStatus();
      secondsRemaining.value--;
    });
  }

  void _maybeReconcilePaymentStatus({bool force = false}) {
    final orderId = _orderId;
    if (_completed ||
        orderId == null ||
        orderId.isEmpty ||
        !isPaymentPrepared.value ||
        payableAmount.value <= 0 ||
        _isReconcilingPayment ||
        isLoading.value) {
      return;
    }

    final now = DateTime.now();
    final lastReconcileAt = _lastReconcileAt;
    if (!force &&
        lastReconcileAt != null &&
        now.difference(lastReconcileAt) < paymentReconcileInterval) {
      return;
    }

    _lastReconcileAt = now;
    _reconcilePaymentStatus(orderId);
  }

  Future<void> _reconcilePaymentStatus(String orderId) async {
    if (_isReconcilingPayment || _completed) return;

    _isReconcilingPayment = true;
    try {
      final result = await _paymentRepository.reconcilePayment(
        orderId: orderId,
      );

      if (result.isPaid && !_completed) {
        _completePayment(orderId);
        return;
      }

      if (!result.pollingConfigured && !_warnedMissingPollingConfig) {
        _warnedMissingPollingConfig = true;
      }
    } on PaymentRepositoryException {
      // Firestore listener and the next polling tick will keep the payment screen alive.
    } finally {
      _isReconcilingPayment = false;
    }
  }

  void _completePayment(String orderId) {
    if (_completed) return;

    _completed = true;
    final successArguments = {
      'courtName': _courtName,
      'price': originalAmount.value,
      'date': _date,
      'time': _time,
      'bookingCode': orderId,
    };

    _resetPaymentSession(preserveCompleted: true);
    Get.offNamed(AppRoutes.paymentSuccess, arguments: successArguments);
  }

  String _requireCurrentUserId() {
    final user = _authRepository.currentUser;
    if (user == null || user.uid.isEmpty || user.isAnonymous) {
      Get.offAllNamed(AppRoutes.login);
      throw StateError('Authenticated user is required.');
    }

    return user.uid;
  }

  @override
  void onClose() {
    _resetPaymentSession();
    super.onClose();
  }

  void _resetPaymentSession({bool preserveCompleted = false}) {
    _timer?.cancel();
    _timer = null;
    _orderSub?.cancel();
    _orderSub = null;
    _walletSub?.cancel();
    _walletSub = null;

    _completed = preserveCompleted && _completed;
    _isReconcilingPayment = false;
    _warnedMissingPollingConfig = false;
    _lastReconcileAt = null;

    _orderId = null;
    _courtName = '';
    _date = '';
    _time = '';
    _bookingIds = const <String>[];

    isLoading.value = false;
    isCancelling.value = false;
    errorMessage.value = '';
    qrUrl.value = '';
    paymentContent.value = '';
    secondsRemaining.value = paymentWindowSeconds;
    walletBalance.value = 0;
    availableWalletBalance.value = 0;
    rewardPoints.value = 0;
    useWallet.value = false;
    useRewardPoints.value = false;
    originalAmount.value = 0;
    payableAmount.value = 0;
    walletDiscount.value = 0;
    pointDiscount.value = 0;
    pointsSpent.value = 0;
    isPaymentPrepared.value = false;
  }
}
