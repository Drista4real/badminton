using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;

const string defaultTestEmail = "qa.test@badminton.local";
const string defaultTestPassword = "Test@123456";
const string testDisplayName = "QA Test User";
const double weekdayMorningFixed = 55000;
const double weekdayMorningAccount = 70000;
const double weekdayMorningGuest = 80000;
const double weekdayBaseFixed = 45000;
const double weekdayBaseAccount = 60000;
const double weekdayBaseGuest = 70000;
const double weekdayPeakFixed = 90000;
const double weekdayPeakAccount = 100000;
const double weekdayPeakGuest = 110000;
const double lateFixed = 60000;
const double lateAccount = 70000;
const double lateGuest = 70000;
const double weekendBaseFixed = 90000;
const double weekendBaseAccount = 100000;
const double weekendBaseGuest = 110000;
const double weekendPeakFixed = 90000;
const double weekendPeakAccount = 100000;
const double weekendPeakGuest = 110000;
const int courtCount = 10;

var projectId = ReadOption(args, "--project-id")
    ?? Environment.GetEnvironmentVariable("FIREBASE_PROJECT_ID")
    ?? Environment.GetEnvironmentVariable("GOOGLE_CLOUD_PROJECT");
var credentialsPath = ReadOption(args, "--credentials")
    ?? Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
var testEmail = ReadOption(args, "--test-email") ?? defaultTestEmail;
var testPassword = ReadOption(args, "--test-password") ?? defaultTestPassword;

if (string.IsNullOrWhiteSpace(projectId))
{
    throw new InvalidOperationException(
        "Missing Firebase project id. Pass --project-id or set FIREBASE_PROJECT_ID.");
}

if (string.IsNullOrWhiteSpace(credentialsPath) || !File.Exists(credentialsPath))
{
    throw new InvalidOperationException(
        "Missing Firebase service account. Pass --credentials or set GOOGLE_APPLICATION_CREDENTIALS.");
}

Environment.SetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", credentialsPath);

var credential = CredentialFactory
    .FromFile<ServiceAccountCredential>(credentialsPath)
    .ToGoogleCredential();
var app = FirebaseApp.Create(new AppOptions
{
    Credential = credential,
    ProjectId = projectId,
});

var firestore = FirestoreDb.Create(projectId);
var auth = FirebaseAuth.GetAuth(app);

var testUser = await UpsertTestAuthUserAsync(auth, testEmail, testPassword);
await SeedCourtsAsync(firestore);
await SeedTestUserDocumentAsync(firestore, testUser);

Console.WriteLine("Firestore seed completed.");
Console.WriteLine($"Project: {projectId}");
Console.WriteLine($"Courts: {courtCount} documents upserted in collection 'courts'.");
Console.WriteLine($"Test user: {testEmail}");
Console.WriteLine($"Password: {testPassword}");
Console.WriteLine($"User document: users/{testUser.Uid}");

static async Task<UserRecord> UpsertTestAuthUserAsync(
    FirebaseAuth auth,
    string email,
    string password)
{
    try
    {
        var existingUser = await auth.GetUserByEmailAsync(email);
        await auth.UpdateUserAsync(new UserRecordArgs
        {
            Uid = existingUser.Uid,
            Email = email,
            Password = password,
            DisplayName = testDisplayName,
            EmailVerified = true,
            Disabled = false,
        });

        return await auth.GetUserAsync(existingUser.Uid);
    }
    catch (FirebaseAuthException exception) when (exception.AuthErrorCode == AuthErrorCode.UserNotFound)
    {
        return await auth.CreateUserAsync(new UserRecordArgs
        {
            Email = email,
            Password = password,
            DisplayName = testDisplayName,
            EmailVerified = true,
            Disabled = false,
        });
    }
}

static async Task SeedCourtsAsync(FirestoreDb firestore)
{
    var batch = firestore.StartBatch();
    var courts = firestore.Collection("courts");

    for (var index = 1; index <= courtCount; index++)
    {
        var id = $"court-{index:00}";
        var data = new Dictionary<string, object?>
        {
            ["id"] = id,
            ["name"] = $"Sân số {index}",
            ["code"] = $"COURT-{index:00}",
            ["surfaceType"] = "Sân tiêu chuẩn",
            ["status"] = "active",
            ["isActive"] = true,
            ["isMaintenance"] = false,
            ["hourlyRate"] = weekdayBaseAccount,
            ["pricePerHour"] = weekdayBaseAccount,
            ["basePrice"] = weekdayBaseAccount,
            ["peakPrice"] = weekdayPeakAccount,
            ["fixedSchedulePrice"] = weekdayBaseFixed,
            ["hourlyPrices"] = new Dictionary<string, object>
            {
                ["weekday.morning.fixed"] = weekdayMorningFixed,
                ["weekday.morning.account"] = weekdayMorningAccount,
                ["weekday.morning.guest"] = weekdayMorningGuest,
                ["weekday.base.fixed"] = weekdayBaseFixed,
                ["weekday.base.account"] = weekdayBaseAccount,
                ["weekday.base.guest"] = weekdayBaseGuest,
                ["weekday.peak.fixed"] = weekdayPeakFixed,
                ["weekday.peak.account"] = weekdayPeakAccount,
                ["weekday.peak.guest"] = weekdayPeakGuest,
                ["late.fixed"] = lateFixed,
                ["late.account"] = lateAccount,
                ["late.guest"] = lateGuest,
                ["weekend.base.fixed"] = weekendBaseFixed,
                ["weekend.base.account"] = weekendBaseAccount,
                ["weekend.base.guest"] = weekendBaseGuest,
                ["weekend.peak.fixed"] = weekendPeakFixed,
                ["weekend.peak.account"] = weekendPeakAccount,
                ["weekend.peak.guest"] = weekendPeakGuest,
                ["weekday.fixed"] = weekdayBaseFixed,
                ["weekday.account"] = weekdayBaseAccount,
                ["weekday.guest"] = weekdayBaseGuest,
                ["weekday.base"] = weekdayBaseAccount,
                ["weekday.peak"] = weekdayPeakAccount,
                ["weekend.fixed"] = weekendBaseFixed,
                ["weekend.account"] = weekendBaseAccount,
                ["weekend.guest"] = weekendBaseGuest,
                ["weekend.base"] = weekendBaseAccount,
                ["weekend.peak"] = weekendPeakAccount,
                ["fixed"] = weekdayBaseFixed,
            },
            ["imageUrl"] = null,
            ["images"] = Array.Empty<string>(),
            ["description"] = "Sân cầu lông tiêu chuẩn, mặt sân đồng nhất, phù hợp đặt sân theo giờ.",
            ["createdAt"] = FieldValue.ServerTimestamp,
            ["updatedAt"] = FieldValue.ServerTimestamp,
        };

        batch.Set(courts.Document(id), data, SetOptions.MergeAll);
    }

    await batch.CommitAsync();
}

static async Task SeedTestUserDocumentAsync(FirestoreDb firestore, UserRecord user)
{
    var data = new Dictionary<string, object?>
    {
        ["id"] = user.Uid,
        ["email"] = user.Email,
        ["phoneNumber"] = user.PhoneNumber,
        ["fullName"] = user.DisplayName ?? testDisplayName,
        ["avatarUrl"] = user.PhotoUrl,
        ["walletBalance"] = 500000,
        ["points"] = 15,
        ["loyaltyPoints"] = 15,
        ["rewardPoints"] = 15,
        ["isActive"] = true,
        ["emailVerified"] = true,
        ["updatedAt"] = FieldValue.ServerTimestamp,
        ["createdAt"] = FieldValue.ServerTimestamp,
    };

    await firestore
        .Collection("users")
        .Document(user.Uid)
        .SetAsync(data, SetOptions.MergeAll);
}

static string? ReadOption(IReadOnlyList<string> args, string name)
{
    for (var index = 0; index < args.Count - 1; index++)
    {
        if (string.Equals(args[index], name, StringComparison.OrdinalIgnoreCase))
        {
            return args[index + 1];
        }
    }

    return null;
}
