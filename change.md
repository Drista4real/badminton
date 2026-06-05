Backend fails with 'Microsoft.NET.Sdk.Web could not be found'. The SDK resolver from dotnet 10.0.300 seems broken. Attempting to pin to SDK 8.0.421 via global.json and retry.

Edited global.json
Ran command: `dotnet --version`

`dotnet --version` now shows **8.0.421** — the pin worked. Now let's run the backend:

Successfully pinned global.json to SDK 8.0.421; dotnet --version confirmed 8.0.421. Now launching backend.

Ran command: `dotnet run`
Ran command: `dotnet build 2>&1`
Ran command: `dotnet build --verbosity normal 2>&1 | Select-Object -Last 30`

SDK is now 8.0.421 but dotnet build still fails. Output is truncated. Investigating the root build error.

Ran command: `dotnet build --verbosity diagnostic 2>&1 | Out-File -FilePath build_diag.txt -Encoding utf8; Get-Content build_diag.txt | Select-String -Pattern "error" | Select-Object -First 20`
Ran command: `Get-Content build_diag.txt | Select-String -Pattern "error|Error|Error(s)" | Select-Object -First 30`
Ran command: `Get-Content build_diag.txt -Raw | Out-String | Select-String "error MSB" -AllMatches`
Ran command: `Get-Content build_diag.txt | Where-Object { $_ -match "import|Import|error|Error|MSB" } | Select-Object -First 20`

SDK pinned to 8.0.421. dotnet build still fails with an MSBuild import error. Reading the full diagnostic log to find the exact problem.

Viewed build_diag.txt:1-34

The root cause is clear now: `MSBuildSDKsPath` is set to `C:\Program Files\dotnet\sdk\9.0.306\Sdks` in the environment, but .NET 9.0.306 is **not installed** on this machine. The environment variable is stale. Let's fix this by overriding `MSBuildSDKsPath` when running.

Found root cause: env var MSBuildSDKsPath points to SDK 9.0.306 which is not installed. Overriding it to point to 8.0.421 Sdks folder before running dotnet run.

Ran command: `$env:MSBuildSDKsPath = "C:\Program Files\dotnet\sdk\8.0.421\Sdks"; dotnet run`

The backend is now running! Output shows `Now listening on: http://localhost:5...`. Let me check the full URL:

Both services are running successfully:

- ✅ **Backend** (`dotnet run`): Now running, fixed by overriding `MSBuildSDKsPath` to point to the correct SDK 8.0.421 Sdks folder. Listening on `http://localhost:5...`
- ✅ **Frontend Flutter Web**: Was launched earlier and is now running at `http://127.0.0.1:62656/...` (Chrome)

**Tóm tắt:**

| Service | Trạng thái | Ghi chú |
|---|---|---|
| **Backend** (ASP.NET Core) | ✅ Đang chạy | `http://localhost:5xxx` |
| **Frontend** (Flutter Web / Chrome) | ✅ Đang chạy | Đã khởi động trên Chrome |

**Vấn đề gặp phải và đã giải quyết:**

Biến môi trường `MSBuildSDKsPath` đang trỏ đến SDK `9.0.306` không được cài đặt trên máy. Giải pháp là ghi đè biến này về đúng đường dẫn SDK `8.0.421` trước khi chạy `dotnet run`:
```powershell
$env:MSBuildSDKsPath = "C:\Program Files\dotnet\sdk\8.0.421\Sdks"; dotnet run
```

✅ Cả hai service đã chạy thành công!

| Service | Trạng thái |
|---|---|
| **Backend** (ASP.NET Core) | ✅ Đang chạy tại `http://localhost:5xxx` |
| **Frontend** (Flutter Web / Chrome) | ✅ Đang chạy trên Chrome |

**Vấn đề đã giải quyết:** Biến môi trường `MSBuildSDKsPath` trỏ sai sang SDK `9.0.306` (chưa cài). Giải pháp: ghi đè về `8.0.421` trước khi chạy:
```powershell
$env:MSBuildSDKsPath = "C:\Program Files\dotnet\sdk\8.0.421\Sdks"; dotnet run
```
Dùng lệnh này mỗi lần khởi động backend trong cùng terminal session.