using backend_caulong.BackgroundWorkers;
using backend_caulong.Repositories;
using backend_caulong.Security;
using backend_caulong.Services;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Authentication;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
ValidateRequiredConfiguration(builder.Configuration);

var firebaseCredentialsPath = builder.Configuration["Firebase:CredentialsPath"];
if (!string.IsNullOrWhiteSpace(firebaseCredentialsPath))
{
    Environment.SetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", firebaseCredentialsPath);
}

builder.Services.AddSingleton(_ =>
{
    var projectId = builder.Configuration["Firebase:ProjectId"];
    if (string.IsNullOrWhiteSpace(projectId))
    {
        throw new InvalidOperationException("Missing required configuration: Firebase:ProjectId");
    }

    return FirestoreDb.Create(projectId);
});
builder.Services.AddSingleton(_ => GetOrCreateFirebaseApp(builder.Configuration));
builder.Services.AddSingleton(provider => FirebaseAuth.GetAuth(provider.GetRequiredService<FirebaseApp>()));
builder.Services
    .AddAuthentication(FirebaseAuthenticationHandler.SchemeName)
    .AddScheme<AuthenticationSchemeOptions, FirebaseAuthenticationHandler>(
        FirebaseAuthenticationHandler.SchemeName,
        _ => { });
builder.Services.AddAuthorization();
builder.Services.AddScoped<IBookingTransactionService, BookingTransactionService>();
builder.Services.AddScoped<IWalletService, WalletService>();
builder.Services.AddScoped<IRewardPointService, RewardPointService>();
builder.Services.AddScoped<IBookingNotificationService, BookingNotificationService>();
builder.Services.AddScoped<IFinancialNotificationService, FinancialNotificationService>();
builder.Services.AddScoped<ICancellationPolicyService, CancellationPolicyService>();
builder.Services.AddScoped<IBookingRepository, BookingRepository>();
builder.Services.AddScoped<ICourtRepository, CourtRepository>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<IWalletRepository, WalletRepository>();
builder.Services.AddHostedService<ExpiredOrderCleanupService>();
builder.Services.AddHostedService<FixedBookingCompletionService>();
builder.Services.AddHttpClient<IVietQrService, VietQrService>();
builder.Services.AddHttpClient<ISePayTransactionLookupService, SePayTransactionLookupService>();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterWeb", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});
builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Firebase ID token. Paste the token only; Swagger sends it as Bearer automatically.",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "Firebase ID token",
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer",
                },
            },
            Array.Empty<string>()
        },
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors("AllowFlutterWeb");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

static void ValidateRequiredConfiguration(IConfiguration configuration)
{
    var requiredKeys = new[]
    {
        "Firebase:ProjectId",
        "Firebase:CredentialsPath",
        "VietQr:ClientId",
        "VietQr:ApiKey",
        "VietQr:BankBin",
        "VietQr:AccountNo",
        "VietQr:AccountName",
        "Webhook:Secret",
    };

    var invalidKeys = requiredKeys
        .Where(key => IsMissingOrPlaceholder(configuration[key]))
        .ToArray();

    if (invalidKeys.Length > 0)
    {
        throw new InvalidOperationException(
            "Missing or placeholder security configuration: " + string.Join(", ", invalidKeys));
    }

    var credentialsPath = configuration["Firebase:CredentialsPath"]!;
    if (!File.Exists(credentialsPath))
    {
        throw new InvalidOperationException(
            $"Firebase credentials file was not found: {credentialsPath}");
    }
}

static FirebaseApp GetOrCreateFirebaseApp(IConfiguration configuration)
{
    try
    {
        var existingApp = FirebaseApp.DefaultInstance;
        if (existingApp is not null)
        {
            return existingApp;
        }
    }
    catch (InvalidOperationException)
    {
        // No default Firebase app has been created yet.
    }

    return FirebaseApp.Create(new AppOptions
    {
        Credential = CredentialFactory
            .FromFile<ServiceAccountCredential>(configuration["Firebase:CredentialsPath"]!)
            .ToGoogleCredential(),
        ProjectId = configuration["Firebase:ProjectId"],
    });
}

static bool IsMissingOrPlaceholder(string? value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return true;
    }

    var normalized = value.Trim().ToLowerInvariant();
    return normalized.Contains("your-")
        || normalized.Contains("placeholder")
        || normalized.Contains("change-me")
        || normalized.Contains("changeme")
        || normalized.Contains("todo")
        || normalized is "xxx" or "test" or "secret";
}
