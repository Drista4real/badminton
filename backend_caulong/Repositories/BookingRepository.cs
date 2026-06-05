using backend_caulong.Models;
using backend_caulong.Services;
using Google.Cloud.Firestore;

namespace backend_caulong.Repositories;

public sealed class BookingRepository : IBookingRepository
{
    private const int FixedAbsenceMonthlyLimit = 2;
    private const double VndPerRewardPoint = 10000d;
    private static readonly TimeZoneInfo BusinessTimeZone = ResolveBusinessTimeZone();

    private readonly FirestoreDb _firestoreDb;
    private readonly IConfiguration _configuration;
    private readonly ICancellationPolicyService _cancellationPolicyService;

    public BookingRepository(
        FirestoreDb firestoreDb,
        IConfiguration configuration,
        ICancellationPolicyService cancellationPolicyService)
    {
        _firestoreDb = firestoreDb;
        _configuration = configuration;
        _cancellationPolicyService = cancellationPolicyService;
    }

    public async Task<IReadOnlyList<BookingDocument>> GetActiveBookingsAsync(
        CancellationToken cancellationToken = default)
    {
        var snapshot = await _firestoreDb
            .Collection("bookings")
            .WhereIn("status", new[]
            {
                BookingStatuses.Pending,
                BookingStatuses.Confirmed,
                BookingStatuses.Completed,
            })
            .GetSnapshotAsync(cancellationToken);

        var bookings = snapshot.Documents
            .Select(TryConvertToBookingDocument)
            .OfType<BookingDocument>()
            .ToArray();

        var orderStatuses = await GetOrderStatusesByIdAsync(bookings, cancellationToken);

        return bookings
            .Where(booking => ShouldReturnActiveBooking(booking, orderStatuses))
            .ToArray();
    }

    public async Task<BookingWriteResult> CreateBookingAsync(
        CreateBookingWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var bookingDate = ToUtcDateTimestamp(request.Date);
        var ordersRef = _firestoreDb.Collection("orders").Document();
        var bookingRef = _firestoreDb.Collection("bookings").Document();
        var bookingIds = new[] { bookingRef.Id };
        var slotLocks = BuildSlotLocks(
            request.CourtId,
            [new SlotLockBooking(request.Date, bookingRef.Id)],
            request.StartTime,
            request.EndTime);
        double totalPrice = 0;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var nowUtc = DateTime.UtcNow;
            await EnsureUserCanBookAsync(
                transaction,
                request.UserId,
                nowUtc,
                cancellationToken);

            var courtSnapshot = await transaction.GetSnapshotAsync(
                _firestoreDb.Collection("courts").Document(request.CourtId),
                cancellationToken);
            await EnsureProtectedCourtCanBeBookedAsync(
                transaction,
                courtSnapshot,
                request.UserId,
                cancellationToken);

            totalPrice = CalculateBookingTotalPrice(
                courtSnapshot,
                request.CourtId,
                [request.Date],
                request.StartTime,
                request.EndTime,
                ResolveOneTimePriceCustomerType(request.UserId));

            var existingBookingsSnapshot = await transaction.GetSnapshotAsync(
                BuildBlockingBookingsQuery(
                    request.CourtId,
                    bookingDate,
                    request.BlockingStatuses),
                cancellationToken);

            var existingBookings = existingBookingsSnapshot.Documents
                .Where(document => document.Exists)
                .Select(document => document.ConvertTo<BookingDocument>())
                .ToArray();
            var existingOrderStatuses = await GetOrderStatusesByIdAsync(
                transaction,
                existingBookings,
                cancellationToken);

            var hasOverlap = existingBookings
                .Where(existing => ShouldReturnActiveBooking(existing, existingOrderStatuses))
                .Any(existing =>
                    request.StartTime < existing.EndTime &&
                    existing.StartTime < request.EndTime);

            if (hasOverlap)
            {
                throw new BookingWriteConflictException(
                    request.CourtId,
                    request.Date,
                    request.StartTime,
                    request.EndTime);
            }

            await EnsureSlotLocksAvailableAsync(transaction, slotLocks, cancellationToken);

            var now = Timestamp.FromDateTime(nowUtc);

            transaction.Set(ordersRef, new OrderDocument
            {
                UserId = request.UserId,
                TotalPrice = totalPrice,
                Status = OrderStatuses.Pending,
                BookingIds = bookingIds,
                PaymentContent = PaymentReference.BuildPaymentContent(_configuration, ordersRef.Id),
                CreatedAt = now,
                UpdatedAt = now,
            });

            transaction.Set(bookingRef, new BookingDocument
            {
                OrderId = ordersRef.Id,
                UserId = request.UserId,
                CourtId = request.CourtId,
                BookingType = BookingTypes.OneTime,
                Date = bookingDate,
                StartTime = request.StartTime,
                EndTime = request.EndTime,
                Status = BookingStatuses.Pending,
                CreatedAt = now,
                UpdatedAt = now,
            });

            SetSlotLocks(
                transaction,
                slotLocks,
                ordersRef.Id,
                request.UserId,
                BookingStatuses.Pending,
                now);
        }, cancellationToken: cancellationToken);

        return new BookingWriteResult(ordersRef.Id, bookingIds, totalPrice);
    }

    public async Task<BookingWriteResult> CreateFixedBookingAsync(
        CreateFixedBookingWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var bookingDates = request.BookingDates
            .Select(date => new FixedBookingWriteDate(date, ToUtcDateTimestamp(date)))
            .ToArray();

        var ordersRef = _firestoreDb.Collection("orders").Document();
        var bookingRefs = bookingDates
            .Select(_ => _firestoreDb.Collection("bookings").Document())
            .ToArray();
        var bookingIds = bookingRefs.Select(reference => reference.Id).ToArray();
        var slotLocks = BuildSlotLocks(
            request.CourtId,
            bookingDates.Select((bookingDate, index) => new SlotLockBooking(
                bookingDate.Date,
                bookingRefs[index].Id)),
            request.StartTime,
            request.EndTime);
        double totalPrice = 0;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var nowUtc = DateTime.UtcNow;
            await EnsureUserCanBookAsync(
                transaction,
                request.UserId,
                nowUtc,
                cancellationToken);

            var courtSnapshot = await transaction.GetSnapshotAsync(
                _firestoreDb.Collection("courts").Document(request.CourtId),
                cancellationToken);
            await EnsureProtectedCourtCanBeBookedAsync(
                transaction,
                courtSnapshot,
                request.UserId,
                cancellationToken);

            totalPrice = CalculateBookingTotalPrice(
                courtSnapshot,
                request.CourtId,
                bookingDates.Select(bookingDate => bookingDate.Date),
                request.StartTime,
                request.EndTime,
                BookingPriceCustomerType.Fixed);

            var requestedDates = bookingDates
                .Select(bookingDate => bookingDate.Date)
                .ToHashSet();
            var existingBookings = await GetBlockingBookingsForDatesAsync(
                transaction,
                request.CourtId,
                bookingDates,
                request.BlockingStatuses,
                cancellationToken);
            var existingOrderStatuses = await GetOrderStatusesByIdAsync(
                transaction,
                existingBookings,
                cancellationToken);

            var conflictingBooking = existingBookings
                .Where(existing => ShouldReturnActiveBooking(existing, existingOrderStatuses))
                .Where(existing => requestedDates.Contains(ToUtcDateOnly(existing.Date)))
                .Where(existing =>
                    request.StartTime < existing.EndTime &&
                    existing.StartTime < request.EndTime)
                .OrderBy(existing => ToUtcDateOnly(existing.Date))
                .ThenBy(existing => existing.StartTime)
                .FirstOrDefault();

            if (conflictingBooking is not null)
            {
                throw new BookingWriteConflictException(
                    request.CourtId,
                    ToUtcDateOnly(conflictingBooking.Date),
                    request.StartTime,
                    request.EndTime);
            }

            await EnsureSlotLocksAvailableAsync(transaction, slotLocks, cancellationToken);

            var now = Timestamp.FromDateTime(nowUtc);

            transaction.Set(ordersRef, new OrderDocument
            {
                UserId = request.UserId,
                TotalPrice = totalPrice,
                Status = OrderStatuses.Pending,
                BookingIds = bookingIds,
                PaymentContent = PaymentReference.BuildPaymentContent(_configuration, ordersRef.Id),
                CreatedAt = now,
                UpdatedAt = now,
            });

            var fixedStartDate = ToUtcDateTimestamp(request.FixedStartDate);
            var fixedEndDate = ToUtcDateTimestamp(request.FixedEndDate);

            for (var index = 0; index < bookingDates.Length; index++)
            {
                transaction.Set(bookingRefs[index], new BookingDocument
                {
                    OrderId = ordersRef.Id,
                    UserId = request.UserId,
                    CourtId = request.CourtId,
                    BookingType = BookingTypes.Fixed,
                    Date = bookingDates[index].Timestamp,
                    StartTime = request.StartTime,
                    EndTime = request.EndTime,
                    Status = BookingStatuses.Pending,
                    FixedWeekdays = request.FixedWeekdays,
                    FixedDurationMonths = request.FixedDurationMonths,
                    FixedStartDate = fixedStartDate,
                    FixedEndDate = fixedEndDate,
                    CreatedAt = now,
                    UpdatedAt = now,
                });
            }

            SetSlotLocks(
                transaction,
                slotLocks,
                ordersRef.Id,
                request.UserId,
                BookingStatuses.Pending,
                now);
        }, cancellationToken: cancellationToken);

        return new BookingWriteResult(ordersRef.Id, bookingIds, totalPrice);
    }

    public async Task<RenewFixedBookingWriteResult> RenewFixedBookingAsync(
        RenewFixedBookingWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var oldOrderRef = _firestoreDb.Collection("orders").Document(request.OldOrderId.Trim());
        var newOrderRef = _firestoreDb.Collection("orders").Document();
        RenewFixedBookingWriteResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var oldOrderSnapshot = await transaction.GetSnapshotAsync(oldOrderRef, cancellationToken);
            if (!oldOrderSnapshot.Exists)
            {
                throw new InvalidOperationException($"Order '{request.OldOrderId}' was not found.");
            }

            var oldOrderUserId = GetString(oldOrderSnapshot, "userId");
            if (string.IsNullOrWhiteSpace(oldOrderUserId))
            {
                throw new InvalidOperationException($"Order '{request.OldOrderId}' does not contain userId.");
            }

            if (!string.Equals(oldOrderUserId, request.UserId, StringComparison.Ordinal))
            {
                throw new OrderForbiddenException(request.OldOrderId);
            }

            var nowUtc = DateTime.UtcNow;
            await EnsureUserCanBookAsync(
                transaction,
                oldOrderUserId,
                nowUtc,
                cancellationToken);

            var oldBookingSnapshots = await GetOrderBookingSnapshotsAsync(
                transaction,
                oldOrderSnapshot,
                cancellationToken);

            var fixedBookings = oldBookingSnapshots
                .Where(snapshot => snapshot.Exists)
                .Select(snapshot => snapshot.ConvertTo<BookingDocument>())
                .Where(booking =>
                    string.Equals(booking.BookingType, BookingTypes.Fixed, StringComparison.OrdinalIgnoreCase) ||
                    booking.FixedDurationMonths is not null ||
                    booking.FixedWeekdays.Count > 0)
                .OrderBy(booking => ToUtcDateOnly(booking.Date))
                .ToArray();

            if (fixedBookings.Length == 0)
            {
                throw new InvalidOperationException($"Order '{request.OldOrderId}' does not contain fixed booking metadata.");
            }

            var template = fixedBookings[0];
            var durationMonths = request.DurationMonths ?? template.FixedDurationMonths ?? 1;
            if (durationMonths is not (1 or 3 or 6))
            {
                throw new ArgumentException("durationMonths must be one of: 1, 3, 6.", nameof(request));
            }

            var fixedWeekdays = template.FixedWeekdays.Count > 0
                ? template.FixedWeekdays.Distinct().OrderBy(day => day).ToArray()
                : fixedBookings
                    .Select(booking => ToApiDayOfWeek(ToUtcDateOnly(booking.Date).DayOfWeek))
                    .Distinct()
                    .OrderBy(day => day)
                    .ToArray();

            var oldEndDate = fixedBookings
                .Select(booking => booking.FixedEndDate is null
                    ? ToUtcDateOnly(booking.Date)
                    : ToUtcDateOnly(booking.FixedEndDate))
                .Max();
            var nextContractDate = oldEndDate.AddDays(1);
            var todayUtc = DateOnly.FromDateTime(DateTime.UtcNow);
            var fixedStartDate = nextContractDate.DayNumber < todayUtc.DayNumber
                ? todayUtc
                : nextContractDate;
            var fixedEndDate = fixedStartDate.AddMonths(durationMonths).AddDays(-1);
            var bookingDates = BuildFixedBookingDates(fixedStartDate, durationMonths, fixedWeekdays)
                .Select(date => new FixedBookingWriteDate(date, ToUtcDateTimestamp(date)))
                .ToArray();

            if (bookingDates.Length == 0)
            {
                throw new InvalidOperationException("No renewal booking dates were generated.");
            }

            var courtSnapshot = await transaction.GetSnapshotAsync(
                _firestoreDb.Collection("courts").Document(template.CourtId),
                cancellationToken);
            await EnsureProtectedCourtCanBeBookedAsync(
                transaction,
                courtSnapshot,
                oldOrderUserId,
                cancellationToken);

            var totalPrice = CalculateBookingTotalPrice(
                courtSnapshot,
                template.CourtId,
                bookingDates.Select(bookingDate => bookingDate.Date),
                template.StartTime,
                template.EndTime,
                BookingPriceCustomerType.Fixed);

            var requestedDates = bookingDates.Select(bookingDate => bookingDate.Date).ToHashSet();
            var existingBookings = await GetBlockingBookingsForDatesAsync(
                transaction,
                template.CourtId,
                bookingDates,
                request.BlockingStatuses,
                cancellationToken);
            var existingOrderStatuses = await GetOrderStatusesByIdAsync(
                transaction,
                existingBookings,
                cancellationToken);

            var conflictingBooking = existingBookings
                .Where(existing => ShouldReturnActiveBooking(existing, existingOrderStatuses))
                .Where(existing => requestedDates.Contains(ToUtcDateOnly(existing.Date)))
                .Where(existing =>
                    template.StartTime < existing.EndTime &&
                    existing.StartTime < template.EndTime)
                .OrderBy(existing => ToUtcDateOnly(existing.Date))
                .ThenBy(existing => existing.StartTime)
                .FirstOrDefault();

            if (conflictingBooking is not null)
            {
                throw new BookingWriteConflictException(
                    template.CourtId,
                    ToUtcDateOnly(conflictingBooking.Date),
                    template.StartTime,
                    template.EndTime);
            }

            var now = Timestamp.FromDateTime(nowUtc);
            var bookingRefs = bookingDates
                .Select(_ => _firestoreDb.Collection("bookings").Document())
                .ToArray();
            var bookingIds = bookingRefs.Select(reference => reference.Id).ToArray();
            var slotLocks = BuildSlotLocks(
                template.CourtId,
                bookingDates.Select((bookingDate, index) => new SlotLockBooking(
                    bookingDate.Date,
                    bookingRefs[index].Id)),
                template.StartTime,
                template.EndTime);
            await EnsureSlotLocksAvailableAsync(transaction, slotLocks, cancellationToken);

            var userId = oldOrderUserId;

            transaction.Set(newOrderRef, new OrderDocument
            {
                UserId = userId,
                TotalPrice = totalPrice,
                Status = OrderStatuses.Pending,
                BookingIds = bookingIds,
                PaymentContent = PaymentReference.BuildPaymentContent(_configuration, newOrderRef.Id),
                RenewedFromOrderId = request.OldOrderId.Trim(),
                CreatedAt = now,
                UpdatedAt = now,
            });

            var fixedStartTimestamp = ToUtcDateTimestamp(fixedStartDate);
            var fixedEndTimestamp = ToUtcDateTimestamp(fixedEndDate);
            for (var index = 0; index < bookingDates.Length; index++)
            {
                transaction.Set(bookingRefs[index], new BookingDocument
                {
                    OrderId = newOrderRef.Id,
                    UserId = userId,
                    CourtId = template.CourtId,
                    BookingType = BookingTypes.Fixed,
                    Date = bookingDates[index].Timestamp,
                    StartTime = template.StartTime,
                    EndTime = template.EndTime,
                    Status = BookingStatuses.Pending,
                    FixedWeekdays = fixedWeekdays,
                    FixedDurationMonths = durationMonths,
                    FixedStartDate = fixedStartTimestamp,
                    FixedEndDate = fixedEndTimestamp,
                    CreatedAt = now,
                    UpdatedAt = now,
                });
            }

            SetSlotLocks(
                transaction,
                slotLocks,
                newOrderRef.Id,
                userId,
                BookingStatuses.Pending,
                now);

            result = new RenewFixedBookingWriteResult(
                newOrderRef.Id,
                bookingIds,
                totalPrice,
                fixedStartDate,
                fixedEndDate,
                durationMonths);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not renew fixed booking.");
    }

    public async Task<CancelBookingWriteResult> CancelOrderAsync(
        CancelBookingWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var trimmedOrderId = request.OrderId.Trim();
        var trimmedUserId = request.UserId.Trim();
        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);
        CancelBookingWriteResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new OrderNotFoundException(trimmedOrderId);
            }

            var orderUserId = GetString(orderSnapshot, "userId");
            if (!string.Equals(orderUserId, trimmedUserId, StringComparison.Ordinal))
            {
                throw new OrderForbiddenException(trimmedOrderId);
            }

            var currentStatus = GetString(orderSnapshot, "status");
            var bookingSnapshots = await GetOrderBookingSnapshotsAsync(
                transaction,
                orderSnapshot,
                cancellationToken);
            var bookingIds = bookingSnapshots
                .Where(snapshot => snapshot.Exists)
                .Select(snapshot => snapshot.Reference.Id)
                .ToArray();
            var slotLockRefs = BuildSlotLockRefs(bookingSnapshots);

            if (string.Equals(currentStatus, OrderStatuses.Cancelled, StringComparison.OrdinalIgnoreCase))
            {
                foreach (var slotLockRef in slotLockRefs)
                {
                    transaction.Delete(slotLockRef);
                }

                result = new CancelBookingWriteResult(trimmedOrderId, bookingIds);
                return;
            }

            if (!CanUserCancelOrder(currentStatus))
            {
                throw new CancelBookingWriteNotAllowedException(trimmedOrderId, currentStatus);
            }

            var nowUtc = DateTime.UtcNow;
            var now = Timestamp.FromDateTime(nowUtc);
            await _cancellationPolicyService.ApplyCancellationAsync(
                transaction,
                new CancellationPolicyRequest(
                    trimmedUserId,
                    bookingSnapshots,
                    nowUtc,
                    now),
                cancellationToken);

            transaction.Set(orderRef, new Dictionary<string, object>
            {
                ["status"] = OrderStatuses.Cancelled,
                ["orderStatus"] = OrderStatuses.Cancelled,
                ["paymentStatus"] = "cancelled",
                ["cancelledReason"] = "user_cancelled",
                ["cancelledAt"] = now,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);

            foreach (var bookingSnapshot in bookingSnapshots.Where(snapshot => snapshot.Exists))
            {
                transaction.Set(bookingSnapshot.Reference, new Dictionary<string, object>
                {
                    ["status"] = BookingStatuses.Cancelled,
                    ["orderStatus"] = OrderStatuses.Cancelled,
                    ["paymentStatus"] = "cancelled",
                    ["cancelledReason"] = "user_cancelled",
                    ["cancelledAt"] = now,
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);
            }

            foreach (var slotLockRef in slotLockRefs)
            {
                transaction.Delete(slotLockRef);
            }

            result = new CancelBookingWriteResult(trimmedOrderId, bookingIds);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not cancel booking order.");
    }

    public async Task<ReportFixedAbsenceWriteResult> ReportFixedAbsenceAsync(
        ReportFixedAbsenceWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var trimmedUserId = request.UserId.Trim();
        var trimmedBookingId = request.BookingId.Trim();
        var bookingRef = _firestoreDb.Collection("bookings").Document(trimmedBookingId);
        ReportFixedAbsenceWriteResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var bookingSnapshot = await transaction.GetSnapshotAsync(bookingRef, cancellationToken);
            if (!bookingSnapshot.Exists)
            {
                throw new OrderNotFoundException(trimmedBookingId);
            }

            var booking = bookingSnapshot.ConvertTo<BookingDocument>();
            if (!string.Equals(booking.UserId, trimmedUserId, StringComparison.Ordinal))
            {
                throw new OrderForbiddenException(trimmedBookingId);
            }

            if (!string.Equals(booking.BookingType, BookingTypes.Fixed, StringComparison.OrdinalIgnoreCase))
            {
                throw new FixedAbsenceWriteNotAllowedException("Chỉ lịch cố định mới được báo nghỉ từng buổi.");
            }

            if (string.Equals(booking.Status, BookingStatuses.CancelledByUserFixed, StringComparison.OrdinalIgnoreCase))
            {
                var existingRefundAmount = GetDouble(bookingSnapshot, "refundedAmount");
                result = new ReportFixedAbsenceWriteResult(
                    trimmedBookingId,
                    booking.OrderId,
                    existingRefundAmount,
                    GetInt(bookingSnapshot, "absenceCountThisMonth"),
                    Refunded: false);
                return;
            }

            if (!string.Equals(booking.Status, BookingStatuses.Confirmed, StringComparison.OrdinalIgnoreCase))
            {
                throw new FixedAbsenceWriteNotAllowedException("Buổi này không ở trạng thái đã xác nhận nên không thể báo nghỉ.");
            }

            var nowUtc = DateTime.UtcNow;
            var sessionStartUtc = GetBookingSessionUtc(booking, booking.StartTime);
            if (sessionStartUtc - nowUtc <= TimeSpan.FromHours(24))
            {
                throw new FixedAbsenceWriteNotAllowedException("Bạn chỉ có thể báo nghỉ trước giờ chơi ít nhất 24 giờ.");
            }

            var absenceMonth = ToBusinessMonth(booking.Date);
            var monthlyAbsenceQuery = _firestoreDb
                .Collection("bookings")
                .WhereEqualTo("userId", trimmedUserId)
                .WhereEqualTo("bookingType", BookingTypes.Fixed)
                .WhereEqualTo("absenceMonth", absenceMonth)
                .WhereEqualTo("status", BookingStatuses.CancelledByUserFixed);
            var monthlyAbsenceSnapshot = await transaction.GetSnapshotAsync(monthlyAbsenceQuery, cancellationToken);
            var currentMonthlyCount = monthlyAbsenceSnapshot.Documents.Count(document => document.Exists);
            if (currentMonthlyCount >= FixedAbsenceMonthlyLimit)
            {
                throw new MonthlyFixedAbsenceLimitExceededException();
            }

            var orderRef = _firestoreDb.Collection("orders").Document(booking.OrderId);
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new OrderNotFoundException(booking.OrderId);
            }

            var orderBookings = await GetOrderBookingSnapshotsAsync(
                transaction,
                orderSnapshot,
                cancellationToken);
            var refundAmount = CalculatePerBookingMoneyAmount(orderSnapshot, orderBookings);
            if (refundAmount <= 0)
            {
                throw new FixedAbsenceWriteNotAllowedException("Không xác định được số tiền hoàn của buổi này.");
            }

            var now = Timestamp.FromDateTime(nowUtc);
            var refundTransactionRef = _firestoreDb
                .Collection("walletTransactions")
                .Document($"refund_fixed_absence_{SanitizeDocumentId(trimmedBookingId)}");
            var refundTransactionSnapshot = await transaction.GetSnapshotAsync(refundTransactionRef, cancellationToken);
            var refundAlreadyExists = refundTransactionSnapshot.Exists;

            if (!refundAlreadyExists)
            {
                CreditWallet(
                    transaction,
                    trimmedUserId,
                    refundAmount,
                    refundTransactionRef,
                    sourceOrderId: booking.OrderId,
                    provider: "fixed_absence",
                    description: "Hoàn tiền báo nghỉ buổi cố định",
                    now,
                    cancellationToken);
            }

            transaction.Set(bookingRef, new Dictionary<string, object>
            {
                ["status"] = BookingStatuses.CancelledByUserFixed,
                ["orderStatus"] = OrderStatuses.Confirmed,
                ["paymentStatus"] = "refunded_to_wallet",
                ["cancelledReason"] = "fixed_absence",
                ["absenceMonth"] = absenceMonth,
                ["absenceCountThisMonth"] = currentMonthlyCount + 1,
                ["refundedAmount"] = refundAmount,
                ["refundMethod"] = "wallet",
                ["cancelledAt"] = now,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);

            DeleteBookingSlotLocks(transaction, new[] { bookingSnapshot });

            result = new ReportFixedAbsenceWriteResult(
                trimmedBookingId,
                booking.OrderId,
                refundAmount,
                currentMonthlyCount + 1,
                Refunded: !refundAlreadyExists);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not report fixed absence.");
    }

    public async Task<CancelOrderWithRefundWriteResult> CancelOrderWithRefundAsync(
        CancelOrderWithRefundWriteRequest request,
        CancellationToken cancellationToken = default)
    {
        var trimmedUserId = request.UserId.Trim();
        var trimmedOrderId = request.OrderId.Trim();
        var refundMethod = NormalizeRefundMethod(request.RefundMethod);
        var orderRef = _firestoreDb.Collection("orders").Document(trimmedOrderId);
        CancelOrderWithRefundWriteResult? result = null;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                throw new OrderNotFoundException(trimmedOrderId);
            }

            var orderUserId = GetString(orderSnapshot, "userId");
            if (!string.Equals(orderUserId, trimmedUserId, StringComparison.Ordinal))
            {
                throw new OrderForbiddenException(trimmedOrderId);
            }

            var status = GetString(orderSnapshot, "status");
            if (!string.Equals(status, OrderStatuses.Confirmed, StringComparison.OrdinalIgnoreCase))
            {
                throw new CancelBookingWriteNotAllowedException(trimmedOrderId, status);
            }

            if (refundMethod == "bank"
                && (string.IsNullOrWhiteSpace(request.BankName)
                    || string.IsNullOrWhiteSpace(request.BankAccountNumber)
                    || string.IsNullOrWhiteSpace(request.BankAccountName)))
            {
                throw new ArgumentException("Thông tin ngân hàng là bắt buộc khi chọn hoàn tiền chuyển khoản.");
            }

            var paidAt = GetTimestamp(orderSnapshot, "paidAt")
                ?? GetTimestamp(orderSnapshot, "confirmedAt")
                ?? throw new FixedAbsenceWriteNotAllowedException("Đơn chưa có thời điểm thanh toán hợp lệ.");
            var elapsed = DateTime.UtcNow - paidAt.ToDateTime();
            var refundRate = elapsed <= TimeSpan.FromHours(5) ? 0.5d : 0.25d;
            var paidMoneyAmount = CalculatePaidMoneyAmount(orderSnapshot);
            var refundAmount = NormalizeMoney(paidMoneyAmount * refundRate);
            if (refundAmount <= 0)
            {
                throw new FixedAbsenceWriteNotAllowedException("Không xác định được số tiền hoàn của đơn này.");
            }

            var bookingSnapshots = await GetOrderBookingSnapshotsAsync(
                transaction,
                orderSnapshot,
                cancellationToken);
            var bookingIds = bookingSnapshots
                .Where(snapshot => snapshot.Exists)
                .Select(snapshot => snapshot.Reference.Id)
                .ToArray();
            var now = Timestamp.FromDateTime(DateTime.UtcNow);
            var nextStatus = refundMethod == "wallet"
                ? OrderStatuses.Cancelled
                : OrderStatuses.RefundPending;
            var nextBookingStatus = refundMethod == "wallet"
                ? BookingStatuses.Cancelled
                : BookingStatuses.RefundPending;
            var paymentStatus = refundMethod == "wallet"
                ? "refunded_to_wallet"
                : "refund_pending";

            DocumentReference? refundTransactionRef = null;
            DocumentSnapshot? refundTransactionSnapshot = null;
            if (refundMethod == "wallet")
            {
                refundTransactionRef = _firestoreDb
                    .Collection("walletTransactions")
                    .Document($"refund_cancel_order_{SanitizeDocumentId(trimmedOrderId)}");
                refundTransactionSnapshot = await transaction.GetSnapshotAsync(refundTransactionRef, cancellationToken);
            }

            transaction.Set(orderRef, new Dictionary<string, object>
            {
                ["status"] = nextStatus,
                ["orderStatus"] = nextStatus,
                ["paymentStatus"] = paymentStatus,
                ["cancelledReason"] = "user_cancelled",
                ["refundMethod"] = refundMethod,
                ["refundRate"] = refundRate,
                ["refundAmount"] = refundAmount,
                ["refundStatus"] = refundMethod == "wallet" ? "completed" : "pending",
                ["refundRequestedAt"] = now,
                ["cancelledAt"] = now,
                ["updatedAt"] = now,
                ["bankName"] = request.BankName?.Trim() ?? string.Empty,
                ["bankAccountNumber"] = request.BankAccountNumber?.Trim() ?? string.Empty,
                ["bankAccountName"] = request.BankAccountName?.Trim() ?? string.Empty,
            }, SetOptions.MergeAll);

            foreach (var bookingSnapshot in bookingSnapshots.Where(snapshot => snapshot.Exists))
            {
                transaction.Set(bookingSnapshot.Reference, new Dictionary<string, object>
                {
                    ["status"] = nextBookingStatus,
                    ["orderStatus"] = nextStatus,
                    ["paymentStatus"] = paymentStatus,
                    ["cancelledReason"] = "user_cancelled",
                    ["refundMethod"] = refundMethod,
                    ["refundAmount"] = refundAmount,
                    ["refundStatus"] = refundMethod == "wallet" ? "completed" : "pending",
                    ["cancelledAt"] = now,
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);
            }

            DeleteBookingSlotLocks(transaction, bookingSnapshots);

            var refundedToWallet = false;
            if (refundMethod == "wallet")
            {
                if (refundTransactionRef is not null && refundTransactionSnapshot?.Exists != true)
                {
                    CreditWallet(
                        transaction,
                        trimmedUserId,
                        refundAmount,
                        refundTransactionRef,
                        sourceOrderId: trimmedOrderId,
                        provider: "booking_cancellation",
                        description: "Hoàn tiền do hủy sân",
                        now,
                        cancellationToken);
                    refundedToWallet = true;
                }
            }

            result = new CancelOrderWithRefundWriteResult(
                trimmedOrderId,
                bookingIds,
                nextStatus,
                refundMethod,
                refundAmount,
                refundRate,
                refundedToWallet);
        }, cancellationToken: cancellationToken);

        return result ?? throw new InvalidOperationException("Could not cancel order with refund.");
    }

    public async Task<int> CompleteDueFixedBookingsAsync(
        DateTime nowUtc,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var normalizedNowUtc = nowUtc.Kind == DateTimeKind.Utc
            ? nowUtc
            : DateTime.SpecifyKind(nowUtc, DateTimeKind.Utc);
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(normalizedNowUtc, BusinessTimeZone));
        var dueDate = ToUtcDateTimestamp(today);
        var snapshot = await _firestoreDb
            .Collection("bookings")
            .WhereEqualTo("bookingType", BookingTypes.Fixed)
            .WhereEqualTo("status", BookingStatuses.Confirmed)
            .WhereLessThanOrEqualTo("date", dueDate)
            .Limit(pageSize)
            .GetSnapshotAsync(cancellationToken);

        var completedCount = 0;
        foreach (var document in snapshot.Documents.Where(document => document.Exists))
        {
            var booking = document.ConvertTo<BookingDocument>();
            if (GetBookingSessionUtc(booking, booking.EndTime) > normalizedNowUtc)
            {
                continue;
            }

            if (await CompleteFixedBookingIfDueAsync(document.Reference.Id, normalizedNowUtc, cancellationToken))
            {
                completedCount++;
            }
        }

        return completedCount;
    }

    private async Task<bool> CompleteFixedBookingIfDueAsync(
        string bookingId,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var bookingRef = _firestoreDb.Collection("bookings").Document(bookingId.Trim());
        var completed = false;

        await _firestoreDb.RunTransactionAsync(async transaction =>
        {
            var bookingSnapshot = await transaction.GetSnapshotAsync(bookingRef, cancellationToken);
            if (!bookingSnapshot.Exists)
            {
                return;
            }

            var booking = bookingSnapshot.ConvertTo<BookingDocument>();
            if (!string.Equals(booking.Status, BookingStatuses.Confirmed, StringComparison.OrdinalIgnoreCase)
                || !string.Equals(booking.BookingType, BookingTypes.Fixed, StringComparison.OrdinalIgnoreCase)
                || GetBookingSessionUtc(booking, booking.EndTime) > nowUtc)
            {
                return;
            }

            var orderRef = _firestoreDb.Collection("orders").Document(booking.OrderId);
            var orderSnapshot = await transaction.GetSnapshotAsync(orderRef, cancellationToken);
            if (!orderSnapshot.Exists)
            {
                return;
            }

            var orderBookings = await GetOrderBookingSnapshotsAsync(
                transaction,
                orderSnapshot,
                cancellationToken);
            var sessionAmount = CalculatePerBookingMoneyAmount(orderSnapshot, orderBookings);
            var points = Math.Max(0, (int)Math.Floor(sessionAmount / VndPerRewardPoint));
            var now = Timestamp.FromDateTime(nowUtc);

            if (points > 0 && !GetBool(bookingSnapshot, "rewardPointsGranted"))
            {
                var userRef = _firestoreDb.Collection("users").Document(booking.UserId);
                transaction.Set(userRef, new Dictionary<string, object>
                {
                    ["points"] = FieldValue.Increment(points),
                    ["loyaltyPoints"] = FieldValue.Increment(points),
                    ["rewardPoints"] = FieldValue.Increment(points),
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);
            }

            transaction.Set(bookingRef, new Dictionary<string, object>
            {
                ["status"] = BookingStatuses.Completed,
                ["orderStatus"] = OrderStatuses.Confirmed,
                ["completedAt"] = now,
                ["rewardPoints"] = points,
                ["rewardPointsGranted"] = true,
                ["rewardPointsGrantedAt"] = now,
                ["updatedAt"] = now,
            }, SetOptions.MergeAll);

            if (!HasOpenSiblingBooking(orderBookings, bookingRef.Id))
            {
                transaction.Set(orderRef, new Dictionary<string, object>
                {
                    ["status"] = OrderStatuses.Completed,
                    ["orderStatus"] = OrderStatuses.Completed,
                    ["completedAt"] = now,
                    ["updatedAt"] = now,
                }, SetOptions.MergeAll);
            }

            completed = true;
        }, cancellationToken: cancellationToken);

        return completed;
    }

    private Query BuildBlockingBookingsQuery(
        string courtId,
        Timestamp date,
        IReadOnlyCollection<string> blockingStatuses)
    {
        return _firestoreDb
            .Collection("bookings")
            .WhereEqualTo("courtId", courtId)
            .WhereEqualTo("date", date)
            .WhereIn("status", blockingStatuses);
    }

    private async Task<IReadOnlyList<BookingDocument>> GetBlockingBookingsForDatesAsync(
        Transaction transaction,
        string courtId,
        IReadOnlyCollection<FixedBookingWriteDate> bookingDates,
        IReadOnlyCollection<string> blockingStatuses,
        CancellationToken cancellationToken)
    {
        var blockingStatusSet = blockingStatuses.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var results = new List<BookingDocument>();

        foreach (var bookingDate in bookingDates.DistinctBy(bookingDate => bookingDate.Date))
        {
            var snapshot = await transaction.GetSnapshotAsync(
                BuildCourtDateBookingsQuery(courtId, bookingDate.Timestamp),
                cancellationToken);

            results.AddRange(snapshot.Documents
                .Select(TryConvertToBookingDocument)
                .OfType<BookingDocument>()
                .Where(booking => blockingStatusSet.Contains(booking.Status)));
        }

        return results;
    }

    private Query BuildCourtDateBookingsQuery(string courtId, Timestamp date)
    {
        return _firestoreDb
            .Collection("bookings")
            .WhereEqualTo("courtId", courtId)
            .WhereEqualTo("date", date);
    }

    private static BookingDocument? TryConvertToBookingDocument(DocumentSnapshot document)
    {
        if (!document.Exists)
        {
            return null;
        }

        try
        {
            return document.ConvertTo<BookingDocument>();
        }
        catch
        {
            return null;
        }
    }

    private async Task<IReadOnlyDictionary<string, string>> GetOrderStatusesByIdAsync(
        IReadOnlyList<BookingDocument> bookings,
        CancellationToken cancellationToken)
    {
        var orderIds = bookings
            .Select(booking => booking.OrderId)
            .Where(orderId => !string.IsNullOrWhiteSpace(orderId))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        if (orderIds.Length == 0)
        {
            return new Dictionary<string, string>(StringComparer.Ordinal);
        }

        var statuses = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var orderId in orderIds)
        {
            var orderSnapshot = await _firestoreDb
                .Collection("orders")
                .Document(orderId)
                .GetSnapshotAsync(cancellationToken);
            if (!orderSnapshot.Exists)
            {
                continue;
            }

            statuses[orderId] = GetString(orderSnapshot, "status");
        }

        return statuses;
    }

    private async Task<IReadOnlyDictionary<string, string>> GetOrderStatusesByIdAsync(
        Transaction transaction,
        IReadOnlyList<BookingDocument> bookings,
        CancellationToken cancellationToken)
    {
        var orderIds = bookings
            .Select(booking => booking.OrderId)
            .Where(orderId => !string.IsNullOrWhiteSpace(orderId))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        if (orderIds.Length == 0)
        {
            return new Dictionary<string, string>(StringComparer.Ordinal);
        }

        var statuses = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var orderId in orderIds)
        {
            var orderSnapshot = await transaction.GetSnapshotAsync(
                _firestoreDb.Collection("orders").Document(orderId),
                cancellationToken);
            if (!orderSnapshot.Exists)
            {
                continue;
            }

            statuses[orderId] = GetString(orderSnapshot, "status");
        }

        return statuses;
    }

    private static bool ShouldReturnActiveBooking(
        BookingDocument booking,
        IReadOnlyDictionary<string, string> orderStatuses)
    {
        if (string.IsNullOrWhiteSpace(booking.OrderId))
        {
            return true;
        }

        return !orderStatuses.TryGetValue(booking.OrderId, out var orderStatus)
            || !string.Equals(orderStatus, OrderStatuses.Cancelled, StringComparison.OrdinalIgnoreCase);
    }

    private Query BuildBlockingBookingsQuery(
        string courtId,
        Timestamp startDate,
        Timestamp endDate,
        IReadOnlyCollection<string> blockingStatuses)
    {
        return _firestoreDb
            .Collection("bookings")
            .WhereEqualTo("courtId", courtId)
            .WhereGreaterThanOrEqualTo("date", startDate)
            .WhereLessThanOrEqualTo("date", endDate)
            .WhereIn("status", blockingStatuses);
    }

    private async Task EnsureUserCanBookAsync(
        Transaction transaction,
        string userId,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var userSnapshot = await transaction.GetSnapshotAsync(
            _firestoreDb.Collection("users").Document(userId),
            cancellationToken);
        if (!userSnapshot.Exists)
        {
            return;
        }

        var disabledUntil = GetTimestamp(userSnapshot, "bookingDisabledUntil");
        if (disabledUntil is null)
        {
            return;
        }

        var disabledUntilUtc = disabledUntil.Value.ToDateTime();
        if (disabledUntilUtc > nowUtc)
        {
            throw new BookingSuspendedWriteException(userId, disabledUntilUtc);
        }
    }

    private async Task EnsureProtectedCourtCanBeBookedAsync(
        Transaction transaction,
        DocumentSnapshot courtSnapshot,
        string userId,
        CancellationToken cancellationToken)
    {
        if (!IsCourtProtected(courtSnapshot))
        {
            return;
        }

        var hasPaidOrder = await UserHasPaidOrderAsync(
            transaction,
            userId,
            cancellationToken);
        if (!hasPaidOrder)
        {
            throw new ProtectedCourtWriteException(courtSnapshot.Reference.Id);
        }
    }

    private async Task<bool> UserHasPaidOrderAsync(
        Transaction transaction,
        string userId,
        CancellationToken cancellationToken)
    {
        return await UserHasOrderWithStatusAsync(
                transaction,
                userId,
                OrderStatuses.Confirmed,
                cancellationToken)
            || await UserHasOrderWithStatusAsync(
                transaction,
                userId,
                OrderStatuses.Completed,
                cancellationToken);
    }

    private async Task<bool> UserHasOrderWithStatusAsync(
        Transaction transaction,
        string userId,
        string status,
        CancellationToken cancellationToken)
    {
        var ordersSnapshot = await transaction.GetSnapshotAsync(
            _firestoreDb
                .Collection("orders")
                .WhereEqualTo("userId", userId)
                .WhereEqualTo("status", status)
                .Limit(1),
            cancellationToken);

        return ordersSnapshot.Documents.Any(document => document.Exists);
    }

    private static bool IsCourtProtected(DocumentSnapshot courtSnapshot)
    {
        return courtSnapshot.Exists && GetBool(courtSnapshot, "isProtected");
    }

    private static bool CanUserCancelOrder(string status)
    {
        return string.Equals(status, OrderStatuses.Pending, StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, OrderStatuses.Confirmed, StringComparison.OrdinalIgnoreCase);
    }

    private static string NormalizeRefundMethod(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        return normalized switch
        {
            "wallet" => "wallet",
            "bank" => "bank",
            _ => throw new ArgumentException("refundMethod must be wallet or bank."),
        };
    }

    private void CreditWallet(
        Transaction transaction,
        string userId,
        double amount,
        DocumentReference walletTransactionRef,
        string sourceOrderId,
        string provider,
        string description,
        Timestamp now,
        CancellationToken cancellationToken)
    {
        _ = cancellationToken;
        var normalizedAmount = NormalizeMoney(amount);
        var userRef = _firestoreDb.Collection("users").Document(userId.Trim());
        transaction.Set(userRef, new Dictionary<string, object>
        {
            ["walletBalance"] = FieldValue.Increment(normalizedAmount),
            ["availableBalance"] = FieldValue.Increment(normalizedAmount),
            ["updatedAt"] = now,
        }, SetOptions.MergeAll);

        transaction.Set(walletTransactionRef, new WalletTransactionDocument
        {
            UserId = userId.Trim(),
            Amount = normalizedAmount,
            Type = WalletTransactionTypes.Refund,
            Status = WalletTransactionStatuses.Completed,
            SourceOrderId = sourceOrderId,
            Provider = provider,
            Description = description,
            CreatedAt = now,
        });
    }

    private static double CalculatePerBookingMoneyAmount(
        DocumentSnapshot orderSnapshot,
        IReadOnlyList<DocumentSnapshot> bookingSnapshots)
    {
        var paidMoney = CalculatePaidMoneyAmount(orderSnapshot);
        var billableBookingCount = bookingSnapshots.Count(snapshot => snapshot.Exists);

        if (billableBookingCount <= 0)
        {
            billableBookingCount = Math.Max(1, bookingSnapshots.Count(snapshot => snapshot.Exists));
        }

        return NormalizeMoney(paidMoney / billableBookingCount);
    }

    private static double CalculatePaidMoneyAmount(DocumentSnapshot orderSnapshot)
    {
        var paidAmount = NormalizeMoney(GetDouble(orderSnapshot, "paidAmount"));
        var walletDiscount = NormalizeMoney(GetDouble(orderSnapshot, "appWalletDiscount"));
        var totalPrice = NormalizeMoney(GetDouble(orderSnapshot, "totalPrice"));
        var originalTotal = NormalizeMoney(GetDouble(orderSnapshot, "originalTotalPrice"));

        if (paidAmount > 0)
        {
            return paidAmount;
        }

        if (originalTotal > 0 && totalPrice <= 0)
        {
            return Math.Max(0d, originalTotal - NormalizeMoney(GetDouble(orderSnapshot, "appPointDiscount")));
        }

        return Math.Max(0d, totalPrice + walletDiscount);
    }

    private static bool HasOpenSiblingBooking(
        IReadOnlyList<DocumentSnapshot> orderBookings,
        string completedBookingId)
    {
        return orderBookings.Any(snapshot =>
            snapshot.Exists
            && !string.Equals(snapshot.Reference.Id, completedBookingId, StringComparison.Ordinal)
            && IsOpenBookingStatus(GetString(snapshot, "status")));
    }

    private static bool IsOpenBookingStatus(string status)
    {
        return string.Equals(status, BookingStatuses.Pending, StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, BookingStatuses.Confirmed, StringComparison.OrdinalIgnoreCase);
    }

    private static DateTime GetBookingSessionUtc(BookingDocument booking, int minutesFromMidnight)
    {
        var date = ToUtcDateOnly(booking.Date);
        var localDateTime = new DateTime(
            date.Year,
            date.Month,
            date.Day,
            minutesFromMidnight / 60,
            minutesFromMidnight % 60,
            0,
            DateTimeKind.Unspecified);
        return TimeZoneInfo.ConvertTimeToUtc(localDateTime, BusinessTimeZone);
    }

    private static string ToBusinessMonth(Timestamp bookingDate)
    {
        var localDate = TimeZoneInfo.ConvertTimeFromUtc(bookingDate.ToDateTime(), BusinessTimeZone);
        return localDate.ToString("yyyy-MM");
    }

    private static TimeZoneInfo ResolveBusinessTimeZone()
    {
        foreach (var timeZoneId in new[] { "SE Asia Standard Time", "Asia/Ho_Chi_Minh" })
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        return TimeZoneInfo.Utc;
    }

    private static double NormalizeMoney(double value)
    {
        return Math.Round(value, 0, MidpointRounding.AwayFromZero);
    }

    private static Timestamp ToUtcDateTimestamp(DateOnly date)
    {
        var normalized = new DateTime(date.Year, date.Month, date.Day, 0, 0, 0, DateTimeKind.Utc);
        return Timestamp.FromDateTime(normalized);
    }

    private static DateOnly ToUtcDateOnly(Timestamp timestamp)
    {
        return DateOnly.FromDateTime(timestamp.ToDateTime());
    }

    private static DateOnly ToUtcDateOnly(Timestamp? timestamp)
    {
        return timestamp is null
            ? default
            : ToUtcDateOnly(timestamp.Value);
    }

    private IReadOnlyList<BookingSlotLockWrite> BuildSlotLocks(
        string courtId,
        IEnumerable<SlotLockBooking> bookings,
        int startTime,
        int endTime)
    {
        return bookings
            .SelectMany(booking => EnumerateSlotStarts(startTime, endTime)
                .Select(slotStart => new BookingSlotLockWrite(
                    _firestoreDb.Collection("bookingSlotLocks").Document(
                        BuildSlotLockId(courtId, booking.Date, slotStart)),
                    courtId,
                    booking.Date,
                    slotStart,
                    slotStart + 30,
                    booking.BookingId)))
            .ToArray();
    }

    private async Task EnsureSlotLocksAvailableAsync(
        Transaction transaction,
        IReadOnlyList<BookingSlotLockWrite> slotLocks,
        CancellationToken cancellationToken)
    {
        var staleSlotLockRefs = new List<DocumentReference>();
        foreach (var slotLock in slotLocks)
        {
            var snapshot = await transaction.GetSnapshotAsync(slotLock.Reference, cancellationToken);
            if (snapshot.Exists)
            {
                if (await IsCancelledSlotLockAsync(transaction, snapshot, cancellationToken))
                {
                    staleSlotLockRefs.Add(slotLock.Reference);
                    continue;
                }

                throw new BookingWriteConflictException(
                    slotLock.CourtId,
                    slotLock.Date,
                    slotLock.StartTime,
                    slotLock.EndTime);
            }
        }

        foreach (var staleSlotLockRef in staleSlotLockRefs)
        {
            transaction.Delete(staleSlotLockRef);
        }
    }

    private async Task<bool> IsCancelledSlotLockAsync(
        Transaction transaction,
        DocumentSnapshot slotLockSnapshot,
        CancellationToken cancellationToken)
    {
        var orderId = GetString(slotLockSnapshot, "orderId");
        if (string.IsNullOrWhiteSpace(orderId))
        {
            return false;
        }

        var orderSnapshot = await transaction.GetSnapshotAsync(
            _firestoreDb.Collection("orders").Document(orderId),
            cancellationToken);
        return orderSnapshot.Exists
            && string.Equals(GetString(orderSnapshot, "status"), OrderStatuses.Cancelled, StringComparison.OrdinalIgnoreCase);
    }

    private static void SetSlotLocks(
        Transaction transaction,
        IReadOnlyList<BookingSlotLockWrite> slotLocks,
        string orderId,
        string userId,
        string status,
        Timestamp now)
    {
        foreach (var slotLock in slotLocks)
        {
            transaction.Set(slotLock.Reference, new Dictionary<string, object>
            {
                ["courtId"] = slotLock.CourtId,
                ["date"] = ToUtcDateTimestamp(slotLock.Date),
                ["startTime"] = slotLock.StartTime,
                ["endTime"] = slotLock.EndTime,
                ["orderId"] = orderId,
                ["bookingId"] = slotLock.BookingId,
                ["userId"] = userId,
                ["status"] = status,
                ["createdAt"] = now,
                ["updatedAt"] = now,
            });
        }
    }

    private IReadOnlyList<DocumentReference> BuildSlotLockRefs(IEnumerable<DocumentSnapshot> bookingSnapshots)
    {
        return bookingSnapshots
            .Where(snapshot => snapshot.Exists)
            .Select(snapshot => snapshot.ConvertTo<BookingDocument>())
            .SelectMany(booking => EnumerateSlotStarts(booking.StartTime, booking.EndTime)
                .Select(slotStart => _firestoreDb
                    .Collection("bookingSlotLocks")
                    .Document(BuildSlotLockId(booking.CourtId, ToUtcDateOnly(booking.Date), slotStart))))
            .DistinctBy(reference => reference.Path)
            .ToArray();
    }

    private void DeleteBookingSlotLocks(
        Transaction transaction,
        IEnumerable<DocumentSnapshot> bookingSnapshots)
    {
        foreach (var slotLockRef in BuildSlotLockRefs(bookingSnapshots))
        {
            transaction.Delete(slotLockRef);
        }
    }

    private static IEnumerable<int> EnumerateSlotStarts(int startTime, int endTime)
    {
        for (var slotStart = startTime; slotStart < endTime; slotStart += 30)
        {
            yield return slotStart;
        }
    }

    private static string BuildSlotLockId(string courtId, DateOnly date, int slotStart)
    {
        return $"{SanitizeDocumentId(courtId)}_{date:yyyyMMdd}_{slotStart:0000}";
    }

    private static string SanitizeDocumentId(string value)
    {
        var chars = value
            .Trim()
            .Select(ch => char.IsLetterOrDigit(ch) || ch is '-' or '_' ? ch : '_')
            .ToArray();

        return new string(chars);
    }

    private async Task<IReadOnlyList<DocumentSnapshot>> GetOrderBookingSnapshotsAsync(
        Transaction transaction,
        DocumentSnapshot orderSnapshot,
        CancellationToken cancellationToken)
    {
        var bookingIds = GetBookingIds(orderSnapshot);
        if (bookingIds.Count > 0)
        {
            var snapshots = new List<DocumentSnapshot>(bookingIds.Count);
            foreach (var bookingId in bookingIds)
            {
                var bookingRef = _firestoreDb.Collection("bookings").Document(bookingId);
                snapshots.Add(await transaction.GetSnapshotAsync(bookingRef, cancellationToken));
            }

            return snapshots;
        }

        var bookingsQuery = _firestoreDb
            .Collection("bookings")
            .WhereEqualTo("orderId", orderSnapshot.Reference.Id);

        var querySnapshot = await transaction.GetSnapshotAsync(bookingsQuery, cancellationToken);
        return querySnapshot.Documents;
    }

    private static IReadOnlyList<string> GetBookingIds(DocumentSnapshot orderSnapshot)
    {
        if (!orderSnapshot.ContainsField("bookingIds"))
        {
            return Array.Empty<string>();
        }

        return orderSnapshot.GetValue<IReadOnlyList<string>>("bookingIds")
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
    }

    private static IEnumerable<DateOnly> BuildFixedBookingDates(
        DateOnly startDate,
        int months,
        IReadOnlyCollection<int> requestedDaysOfWeek)
    {
        var daysOfWeek = requestedDaysOfWeek.Select(ToDayOfWeek).ToHashSet();
        var exclusiveEndDate = startDate.AddMonths(months);

        for (var date = startDate; date.DayNumber < exclusiveEndDate.DayNumber; date = date.AddDays(1))
        {
            if (daysOfWeek.Contains(date.DayOfWeek))
            {
                yield return date;
            }
        }
    }

    private static DayOfWeek ToDayOfWeek(int dayOfWeek)
    {
        return dayOfWeek switch
        {
            1 => DayOfWeek.Sunday,
            2 => DayOfWeek.Monday,
            3 => DayOfWeek.Tuesday,
            4 => DayOfWeek.Wednesday,
            5 => DayOfWeek.Thursday,
            6 => DayOfWeek.Friday,
            7 => DayOfWeek.Saturday,
            _ => throw new ArgumentException("daysOfWeek values must be from 1 to 7."),
        };
    }

    private static int ToApiDayOfWeek(DayOfWeek dayOfWeek)
    {
        return dayOfWeek switch
        {
            DayOfWeek.Sunday => 1,
            DayOfWeek.Monday => 2,
            DayOfWeek.Tuesday => 3,
            DayOfWeek.Wednesday => 4,
            DayOfWeek.Thursday => 5,
            DayOfWeek.Friday => 6,
            DayOfWeek.Saturday => 7,
            _ => throw new ArgumentOutOfRangeException(nameof(dayOfWeek)),
        };
    }

    private static double CalculateBookingTotalPrice(
        DocumentSnapshot courtSnapshot,
        string courtId,
        IEnumerable<DateOnly> bookingDates,
        int startTime,
        int endTime,
        BookingPriceCustomerType customerType)
    {
        var hourlyPrices = GetCourtHourlyPrices(courtSnapshot, courtId);
        var totalPrice = bookingDates.Sum(date => CalculateBookingDatePrice(
            hourlyPrices,
            courtId,
            date,
            startTime,
            endTime,
            customerType));

        if (totalPrice <= 0)
        {
            throw new InvalidOperationException("Calculated totalPrice must be greater than zero.");
        }

        return Math.Round(totalPrice, 0, MidpointRounding.AwayFromZero);
    }

    private static double CalculateBookingDatePrice(
        IReadOnlyDictionary<string, double> hourlyPrices,
        string courtId,
        DateOnly date,
        int startTime,
        int endTime,
        BookingPriceCustomerType customerType)
    {
        var coveredMinutes = 0;
        var totalPrice = 0d;

        foreach (var priceBand in GetPriceBands(date))
        {
            var overlapStart = Math.Max(startTime, priceBand.StartMinute);
            var overlapEnd = Math.Min(endTime, priceBand.EndMinute);
            if (overlapStart >= overlapEnd)
            {
                continue;
            }

            var minutes = overlapEnd - overlapStart;
            var hourlyRate = GetHourlyPrice(
                hourlyPrices,
                courtId,
                priceBand.PriceKeyPrefix,
                customerType);

            totalPrice += hourlyRate * minutes / 60d;
            coveredMinutes += minutes;
        }

        var requestedMinutes = endTime - startTime;
        if (coveredMinutes != requestedMinutes)
        {
            throw new InvalidOperationException(
                $"Court '{courtId}' does not contain a price rule for the full requested time range {FormatMinutes(startTime)}-{FormatMinutes(endTime)}.");
        }

        return totalPrice;
    }

    private static IReadOnlyList<PriceBand> GetPriceBands(DateOnly date)
    {
        return date.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday
            ? WeekendPriceBands
            : WeekdayPriceBands;
    }

    private static double GetHourlyPrice(
        IReadOnlyDictionary<string, double> hourlyPrices,
        string courtId,
        string priceKeyPrefix,
        BookingPriceCustomerType customerType)
    {
        var key = $"{priceKeyPrefix}.{ToPriceCustomerKey(customerType)}";
        if (!hourlyPrices.TryGetValue(key, out var hourlyRate) || hourlyRate <= 0)
        {
            throw new InvalidOperationException(
                $"Court '{courtId}' does not contain a valid hourlyPrices['{key}'] value.");
        }

        return hourlyRate;
    }

    private static IReadOnlyDictionary<string, double> GetCourtHourlyPrices(
        DocumentSnapshot courtSnapshot,
        string courtId)
    {
        if (!courtSnapshot.Exists)
        {
            throw new InvalidOperationException($"Court '{courtId}' was not found.");
        }

        if (!courtSnapshot.ContainsField("hourlyPrices"))
        {
            throw new InvalidOperationException($"Court '{courtId}' does not contain hourlyPrices.");
        }

        var rawHourlyPrices = courtSnapshot.GetValue<Dictionary<string, object>>("hourlyPrices");
        var hourlyPrices = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
        foreach (var (key, value) in rawHourlyPrices)
        {
            if (TryGetDouble(value, out var price))
            {
                hourlyPrices[key] = price;
            }
        }

        if (hourlyPrices.Count == 0)
        {
            throw new InvalidOperationException($"Court '{courtId}' does not contain valid hourlyPrices.");
        }

        return hourlyPrices;
    }

    private static BookingPriceCustomerType ResolveOneTimePriceCustomerType(string userId)
    {
        return string.IsNullOrWhiteSpace(userId)
            ? BookingPriceCustomerType.Guest
            : BookingPriceCustomerType.Account;
    }

    private static string ToPriceCustomerKey(BookingPriceCustomerType customerType)
    {
        return customerType switch
        {
            BookingPriceCustomerType.Guest => "guest",
            BookingPriceCustomerType.Account => "account",
            BookingPriceCustomerType.Fixed => "fixed",
            _ => throw new ArgumentOutOfRangeException(nameof(customerType)),
        };
    }

    private static bool TryGetDouble(object? value, out double result)
    {
        switch (value)
        {
            case double doubleValue:
                result = doubleValue;
                return true;
            case long longValue:
                result = longValue;
                return true;
            case int intValue:
                result = intValue;
                return true;
            default:
                result = 0;
                return false;
        }
    }

    private static string FormatMinutes(int minutes)
    {
        return $"{minutes / 60:00}:{minutes % 60:00}";
    }

    private static string GetString(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return string.Empty;
        }

        var value = snapshot.GetValue<object>(field);
        return value?.ToString() ?? string.Empty;
    }

    private static bool GetBool(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return false;
        }

        var value = snapshot.GetValue<object>(field);
        return value is bool boolValue && boolValue;
    }

    private static int GetInt(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return 0;
        }

        var value = snapshot.GetValue<object>(field);
        return value switch
        {
            int intValue => intValue,
            long longValue => (int)longValue,
            double doubleValue => (int)doubleValue,
            _ => 0,
        };
    }

    private static double GetDouble(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return 0;
        }

        var value = snapshot.GetValue<object>(field);
        return value switch
        {
            double doubleValue => doubleValue,
            long longValue => longValue,
            int intValue => intValue,
            _ => 0,
        };
    }

    private static Timestamp? GetTimestamp(DocumentSnapshot snapshot, string field)
    {
        if (!snapshot.Exists || !snapshot.ContainsField(field))
        {
            return null;
        }

        return snapshot.GetValue<object>(field) is Timestamp timestamp
            ? timestamp
            : null;
    }

    private sealed record FixedBookingWriteDate(
        DateOnly Date,
        Timestamp Timestamp);

    private sealed record PriceBand(
        int StartMinute,
        int EndMinute,
        string PriceKeyPrefix);

    private sealed record SlotLockBooking(
        DateOnly Date,
        string BookingId);

    private sealed record BookingSlotLockWrite(
        DocumentReference Reference,
        string CourtId,
        DateOnly Date,
        int StartTime,
        int EndTime,
        string BookingId);

    private enum BookingPriceCustomerType
    {
        Guest,
        Account,
        Fixed,
    }

    private static readonly PriceBand[] WeekdayPriceBands =
    [
        new(5 * 60, 9 * 60, "weekday.morning"),
        new(9 * 60, 16 * 60, "weekday.base"),
        new(16 * 60, 22 * 60, "weekday.peak"),
        new(22 * 60, 24 * 60, "late"),
    ];

    private static readonly PriceBand[] WeekendPriceBands =
    [
        new(5 * 60, 16 * 60, "weekend.base"),
        new(16 * 60, 22 * 60, "weekend.peak"),
        new(22 * 60, 24 * 60, "late"),
    ];
}
