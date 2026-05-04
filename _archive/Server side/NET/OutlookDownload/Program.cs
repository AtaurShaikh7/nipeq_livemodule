using System.Globalization;
using System.Text.Json;
using Microsoft.Playwright;

// Log file next to config so we have a trace even if console closes
string? LogPath(string? configPath) => configPath != null ? Path.Combine(Path.GetDirectoryName(configPath) ?? ".", "OutlookDownload.log") : null;
void Log(string message, string? configPath)
{
    Console.WriteLine(message);
    try { if (LogPath(configPath) is { } p) File.AppendAllText(p, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + message + Environment.NewLine); } catch { }
}
void Flush() { try { Console.Out?.Flush(); } catch { } }

string? configPath = null;
bool saveLogin = false;
foreach (var arg in args)
{
    if (string.Equals(arg, "--save-login", StringComparison.OrdinalIgnoreCase))
        saveLogin = true;
    else if (arg.StartsWith("--config:", StringComparison.OrdinalIgnoreCase))
        configPath = arg.Substring("--config:".Length).Trim();
    else if (arg == "--config" && args.Length > Array.IndexOf(args, arg) + 1)
        configPath = args[Array.IndexOf(args, arg) + 1];
}

string baseDir = AppContext.BaseDirectory ?? Path.GetDirectoryName(Environment.ProcessPath) ?? ".";
if (string.IsNullOrEmpty(configPath))
    configPath = Path.Combine(baseDir, "appsettings.json");

if (!File.Exists(configPath))
{
    Log("Config not found: " + configPath, configPath);
    Log("Usage: OutlookDownload.exe [--save-login] [--config:path]", configPath);
    Flush();
    return 1;
}

Log("Config: " + configPath, configPath);
Flush();
var config = await LoadConfig(configPath);
if (config == null) { Log("LoadConfig failed.", configPath); Flush(); return 2; }

string statePath = config.StorageStatePath;
if (!Path.IsPathRooted(statePath))
    statePath = Path.Combine(Path.GetDirectoryName(configPath) ?? baseDir, statePath);

if (saveLogin)
{
    Log("Save-login mode: browser will open. Log in to Outlook, then press Enter here to save session.", configPath);
    Flush();
    return await SaveLoginAsync(config.WebUrl, statePath);
}

string effdatePath = Path.Combine(Path.GetDirectoryName(configPath) ?? baseDir, "effdate.txt");
if (!File.Exists(effdatePath))
{
    Log("effdate.txt not found: " + effdatePath, configPath);
    Flush();
    return 3;
}

string effdate = File.ReadAllText(effdatePath).Trim();
if (string.IsNullOrEmpty(effdate) || effdate.Length < 8)
{
    Log("Invalid effdate in effdate.txt.", configPath);
    Flush();
    return 4;
}

// Allow running without saved state if Email + Password are in config (auto-login).
bool canAutoLogin = !string.IsNullOrWhiteSpace(config.Email) && !string.IsNullOrWhiteSpace(config.Password);
if (!File.Exists(statePath) && !canAutoLogin)
{
    Log("Saved login not found: " + statePath, configPath);
    Log("Add Outlook.Email and Outlook.Password in appsettings.json for auto-login, or run once with --save-login.", configPath);
    Flush();
    return 5;
}

if (!Directory.Exists(config.SourceFolder))
{
    Log("Source (download) folder does not exist: " + config.SourceFolder, configPath);
    Flush();
    return 6;
}

Log("Effdate: " + effdate + ", Download folder: " + config.SourceFolder, configPath);
string[] searchTerms = GetSearchTermsFromEffdate(effdate);
Log("Search terms: " + string.Join(" | ", searchTerms), configPath);
Flush();

int exitCode;
try
{
    exitCode = await DownloadAttachmentsAsync(config, statePath, config.SourceFolder, searchTerms);
}
catch (Exception ex)
{
    Log("Unhandled error: " + ex.Message, configPath);
    Log(ex.StackTrace ?? "", configPath);
    Flush();
    throw;
}
Log("OutlookDownload exiting with code " + exitCode, configPath);
Flush();
return exitCode;

static async Task<int> SaveLoginAsync(string webUrl, string statePath)
{
    using var playwright = await Playwright.CreateAsync();
    var browser = await playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions { Headless = false });
    var context = await browser.NewContextAsync(new BrowserNewContextOptions { IgnoreHTTPSErrors = true });
    var page = await context.NewPageAsync();
    try
    {
        await page.GotoAsync(webUrl, new PageGotoOptions { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 60000 });
        Console.WriteLine("Log in in the browser if needed. When inbox is visible, press Enter in this window.");
        await Task.Run(() => Console.ReadLine());
        await context.StorageStateAsync(new BrowserContextStorageStateOptions { Path = statePath });
        Console.WriteLine("Session saved to: " + statePath);
        return 0;
    }
    finally
    {
        await browser.CloseAsync();
    }
}

/// <summary>
/// Build search term from effdate (yyyyMMdd from Oracle). The subject line is fully derived from effdate:
///   FA-RLMF_RLMF_VALUEFY_{ddMMyy}.zip - {dd-MMM-yyyy}
/// </summary>
static string[] GetSearchTermsFromEffdate(string effdate)
{
    if (effdate.Length >= 8 &&
        DateTime.TryParseExact(effdate, "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var dt))
    {
        var inv = CultureInfo.InvariantCulture;
        string dashDate = dt.ToString("dd-MMM-yyyy", inv);
        string dd = dt.ToString("dd", inv);
        string MM = dt.ToString("MM", inv);
        string yy = dt.ToString("yy", inv);
        string ddMMyy = dd + MM + yy;
        return new[] { $"FA-RLMF_RLMF_VALUEFY_{ddMMyy}.zip - {dashDate}" };
    }
    return new[] { effdate };
}

const int DownloadTimeoutMs = 60000;
const int DownloadRetries = 3;
const int RetryDelayMs = 2000;

static async Task<System.Net.CookieContainer> BuildCookieContainerAsync(IBrowserContext context, Uri uri)
{
    var cookies = await context.CookiesAsync(new[] { uri.ToString() });
    var jar = new System.Net.CookieContainer();
    foreach (var c in cookies)
    {
        string domain = string.IsNullOrEmpty(c.Domain) ? uri.Host : c.Domain;
        jar.Add(new System.Net.Cookie(c.Name, c.Value, c.Path ?? "/", domain));
    }
    return jar;
}

static async Task<bool> DownloadViaHttpClientAsync(
    IResponse response,
    IBrowserContext context,
    string downloadFolder,
    string desiredFileName,
    Action<string> LogLocal)
{
    try
    {
        var url = new Uri(response.Url);
        LogLocal("  Using HttpClient to download: " + url);

        var handler = new System.Net.Http.HttpClientHandler
        {
            CookieContainer = await BuildCookieContainerAsync(context, url),
            AutomaticDecompression = System.Net.DecompressionMethods.All
        };

        using var client = new System.Net.Http.HttpClient(handler);
        using var httpResponse = await client.GetAsync(url, System.Net.Http.HttpCompletionOption.ResponseHeadersRead);
        httpResponse.EnsureSuccessStatusCode();

        Directory.CreateDirectory(downloadFolder);
        var targetPath = Path.Combine(downloadFolder, desiredFileName);
        await using (var fs = File.Create(targetPath))
        await using (var content = await httpResponse.Content.ReadAsStreamAsync())
        {
            await content.CopyToAsync(fs);
        }

        LogLocal("  Downloaded via HttpClient: " + targetPath);
        return true;
    }
    catch (Exception ex)
    {
        LogLocal("  HttpClient download failed: " + ex.Message);
        return false;
    }
}

static async Task<(bool found, string? file)> WaitForNewZipAsync(string folder, DateTime clickStart, Action<string> LogLocal)
{
    try
    {
        if (!Directory.Exists(folder))
        {
            LogLocal("  Download folder does not exist: " + folder);
            return (false, null);
        }
        int attempts = Math.Max(5, DownloadTimeoutMs / 1000);
        DateTime threshold = clickStart.AddMilliseconds(-500);
        string? lastReported = null;
        for (int i = 0; i < attempts; i++)
        {
            var zips = Directory.GetFiles(folder, "*.zip");
            if (zips.Length > 0)
            {
                var latest = zips
                    .Select(p => new FileInfo(p))
                    .OrderByDescending(fi => fi.LastWriteTime)
                    .First();
                if (latest.LastWriteTime >= threshold)
                {
                    if (lastReported != latest.FullName)
                    {
                        LogLocal("  Detected new/updated zip: " + latest.FullName);
                        lastReported = latest.FullName;
                    }
                    return (true, latest.FullName);
                }
            }
            await Task.Delay(1000);
        }
        LogLocal("  No new zip file detected in folder within timeout.");
        return (false, null);
    }
    catch (Exception ex)
    {
        LogLocal("  WaitForNewZipAsync error: " + ex.Message);
        return (false, null);
    }
}

static async Task<int> DownloadAttachmentsAsync(AppConfig config, string statePath, string downloadFolder, string[] searchTerms)
{
    string? logPath = Path.Combine(Path.GetDirectoryName(statePath) ?? ".", "OutlookDownload.log");
    void LogLocal(string msg) { Console.WriteLine(msg); try { File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + msg + Environment.NewLine); } catch { } Console.Out?.Flush(); }

    LogLocal("OutlookDownload.log path: " + logPath);
    LogLocal("Download folder: " + downloadFolder);
    LogLocal("Launching browser...");
    using var playwright = await Playwright.CreateAsync();
    var browser = await playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions { Headless = false });

    BrowserNewContextOptions contextOptions = new BrowserNewContextOptions { IgnoreHTTPSErrors = true };
    if (File.Exists(statePath))
        contextOptions.StorageStatePath = statePath;

    var context = await browser.NewContextAsync(contextOptions);
    var page = await context.NewPageAsync();
    int totalDownloaded = 0;
    bool anyDownloaded = false;
    var seenSubjects = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

    try
    {
        LogLocal("Navigating to " + config.WebUrl);
        await page.GotoAsync(config.WebUrl, new PageGotoOptions
        {
            WaitUntil = WaitUntilState.DOMContentLoaded,
            Timeout = 90000
        });
        try
        {
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle, new PageWaitForLoadStateOptions { Timeout = 30000 });
        }
        catch { }
        await Task.Delay(3000);

        // 1) If already authenticated (mailbox UI visible), skip login entirely.
        if (!await IsAuthenticatedAsync(page))
        {
            // 2) Not clearly authenticated. If we have credentials, run full login + verification flow.
            if (!string.IsNullOrWhiteSpace(config.Email) && !string.IsNullOrWhiteSpace(config.Password))
            {
                LogLocal("Not authenticated; logging in with config credentials...");
                bool loginOk = await LoginWithCredentialsAsync(page, context, config.WebUrl, config.Email!, config.Password!, statePath, LogLocal);
                if (!loginOk)
                {
                    LogLocal("Auto-login failed.");
                    return 12;
                }
                await Task.Delay(2000);
            }
            else
            {
                // 3) No credentials in config; caller must prepare a valid storage state.
                LogLocal("Not authenticated and Outlook.Email/Password not configured.");
                return 5;
            }
        }

        LogLocal("Looking for search box...");
        var search = page.GetByPlaceholder("Search", new PageGetByPlaceholderOptions { Exact = false })
            .Or(page.Locator("input[aria-label*='Search'], input[placeholder*='Search']")).First;
        await search.WaitForAsync(new LocatorWaitForOptions { Timeout = 10000 });

        foreach (string term in searchTerms)
        {
            LogLocal("Searching: \"" + term + "\"");
            await search.FillAsync(term);
            await search.PressAsync("Enter");
            await Task.Delay(4000);

            string subjectToken = term.Split(" - ")[0].Trim();
            // Use the subject token as desired download filename (Outlook may serve GUID names)
            string desiredFileName = subjectToken.EndsWith(".zip", StringComparison.OrdinalIgnoreCase)
                ? subjectToken
                : subjectToken + ".zip";
            var mailLinks = page
                .Locator("[role='listbox'] [role='option'], [role='grid'] [role='row'], [data-convid], a[href*='mail']")
                .Filter(new LocatorFilterOptions { HasText = subjectToken });
            int count = await mailLinks.CountAsync();
            LogLocal("Mail list (subject token) count: " + count);
            if (count == 0)
            {
                mailLinks = page.Locator("[role='listbox'] [role='option'], [role='grid'] [role='row'], [data-convid], a[href*='mail']")
                    .Filter(new LocatorFilterOptions { HasNotText = "Search" });
                count = await mailLinks.CountAsync();
                LogLocal("Mail list (listbox/grid) count: " + count);
            }
            if (count == 0)
            {
                mailLinks = page.GetByRole(AriaRole.Link).Filter(new LocatorFilterOptions { HasText = "VALUEFY" });
                count = await mailLinks.CountAsync();
                LogLocal("Mail links (HasText VALUEFY) count: " + count);
            }
            if (count == 0)
            {
                mailLinks = page.GetByRole(AriaRole.Link).Filter(new LocatorFilterOptions { HasText = term });
                count = await mailLinks.CountAsync();
                LogLocal("Mail links (HasText term) count: " + count);
            }

            for (int i = 0; i < Math.Min(count, 10); i++)
            {
                try
                {
                    var item = mailLinks.Nth(i);
                    string? subject = await item.TextContentAsync();
                    LogLocal("  Item " + i + " text: " + (subject?.Trim().Length > 80 ? subject.Trim().Substring(0, 80) + "..." : subject ?? "(null)"));
                    if (!string.IsNullOrWhiteSpace(subject) && seenSubjects.Contains(subject.Trim()))
                        continue;
                    if (!string.IsNullOrWhiteSpace(subject))
                        seenSubjects.Add(subject.Trim());

                    LogLocal("  Clicking item " + i);
                    await item.ClickAsync(new LocatorClickOptions { Timeout = 8000 });
                    await Task.Delay(2500);
                    await page.Keyboard.PressAsync("Enter");
                    await Task.Delay(1500);

                    // Primary path: click zip attachment tile and intercept attachment response, then download via HttpClient.
                    if (!anyDownloaded)
                    {
                        for (int attempt = 1; attempt <= DownloadRetries && !anyDownloaded; attempt++)
                        {
                            try
                            {
                                LogLocal("  Attempt " + attempt + "/" + DownloadRetries + ": clicking zip attachment tile...");
                                var zipTile = page.Locator(
                                    "[title$='.zip'], [aria-label$='.zip'], " +
                                    "[title*='.zip '], [aria-label*='.zip '], " +
                                    "[title*='RLMF_RLMF_VALUEFY'], [aria-label*='RLMF_RLMF_VALUEFY']"
                                ).First;
                                if (await zipTile.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 5000 }))
                                {
                                    var response = await page.RunAndWaitForResponseAsync(
                                        async () => await zipTile.ClickAsync(new LocatorClickOptions { Timeout = 8000 }),
                                        resp =>
                                        {
                                            if (!resp.Ok) return false;
                                            if (!resp.Headers.TryGetValue("content-disposition", out var cd)) return false;
                                            return cd.Contains("attachment", StringComparison.OrdinalIgnoreCase);
                                        },
                                        new PageRunAndWaitForResponseOptions { Timeout = DownloadTimeoutMs }
                                    );

                                    if (await DownloadViaHttpClientAsync(response, context, downloadFolder, desiredFileName, LogLocal))
                                    {
                                        totalDownloaded++;
                                        anyDownloaded = true;
                                        break;
                                    }
                                }
                                LogLocal("  Zip attachment tile not visible.");
                            }
                            catch (Exception ex)
                            {
                                LogLocal("  Zip tile attempt " + attempt + " failed: " + ex.Message);
                                if (attempt < DownloadRetries)
                                    await Task.Delay(RetryDelayMs);
                            }
                        }
                    }

                    var attachLinks = page.Locator(
                        "button:has-text('Download'), " +
                        "[aria-label*='Download attachment'], " +
                        "[aria-label*='Download'], [title*='Download'], " +
                        "a[href*='attachment'], a[href*='Attachment'], " +
                        "button[aria-label*='attachment'], [name*='attachment']"
                    );
                    int ac = await attachLinks.CountAsync();
                    LogLocal("  Attachment links found: " + ac);
                    for (int j = 0; j < ac && !anyDownloaded; j++)
                    {
                        for (int attempt = 1; attempt <= DownloadRetries; attempt++)
                        {
                            try
                            {
                                var response = await page.RunAndWaitForResponseAsync(
                                    async () => await attachLinks.Nth(j).ClickAsync(new LocatorClickOptions { Timeout = 5000 }),
                                    resp =>
                                    {
                                        if (!resp.Ok) return false;
                                        if (!resp.Headers.TryGetValue("content-disposition", out var cd)) return false;
                                        return cd.Contains("attachment", StringComparison.OrdinalIgnoreCase);
                                    },
                                    new PageRunAndWaitForResponseOptions { Timeout = DownloadTimeoutMs }
                                );

                                if (await DownloadViaHttpClientAsync(response, context, downloadFolder, desiredFileName, LogLocal))
                                {
                                    totalDownloaded++;
                                    anyDownloaded = true;
                                    break;
                                }
                            }
                            catch (Exception ex)
                            {
                                LogLocal("    Attachment click attempt " + attempt + " failed: " + ex.Message);
                                if (attempt < DownloadRetries) await Task.Delay(RetryDelayMs);
                            }
                        }
                        await Task.Delay(500);
                    }

                    if (!anyDownloaded)
                    {
                        try
                        {
                            LogLocal("  Trying attachment-card fallback...");
                            var zipCard = page.Locator(
                                "button:has-text('.zip'), [title*='.zip'], [aria-label*='.zip'], " +
                                "[aria-label*='RLMF_RLMF_VALUEFY'], [title*='RLMF_RLMF_VALUEFY']"
                            ).First;
                            if (await zipCard.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 3000 }))
                            {
                                await zipCard.ClickAsync(new LocatorClickOptions { Timeout = 5000 });
                                await Task.Delay(1000);
                            }
                            var menuDownload = page.GetByRole(AriaRole.Menuitem, new PageGetByRoleOptions { Name = "Download", Exact = false }).First;
                            if (await menuDownload.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 3000 }))
                            {
                                var response = await page.RunAndWaitForResponseAsync(
                                    async () => await menuDownload.ClickAsync(new LocatorClickOptions { Timeout = 5000 }),
                                    resp =>
                                    {
                                        if (!resp.Ok) return false;
                                        if (!resp.Headers.TryGetValue("content-disposition", out var cd)) return false;
                                        return cd.Contains("attachment", StringComparison.OrdinalIgnoreCase);
                                    },
                                    new PageRunAndWaitForResponseOptions { Timeout = DownloadTimeoutMs }
                                );

                                if (await DownloadViaHttpClientAsync(response, context, downloadFolder, desiredFileName, LogLocal))
                                {
                                    totalDownloaded++;
                                    anyDownloaded = true;
                                }
                            }
                        }
                        catch (Exception ex) { LogLocal("  Fallback failed: " + ex.Message); }
                    }

                    if (anyDownloaded)
                    {
                        LogLocal("At least one attachment downloaded; stopping.");
                        break;
                    }
                }
                catch (Exception ex)
                {
                    LogLocal("  Row processing failed: " + ex.Message);
                }
            }

            if (anyDownloaded)
                break;
        }

        LogLocal("Attachments downloaded: " + totalDownloaded);
        if (totalDownloaded == 0)
        {
            LogLocal("No attachments were downloaded for the matched mail.");
            return 11;
        }
        return 0;
    }
    catch (Exception ex)
    {
        LogLocal("Error: " + ex.Message);
        LogLocal(ex.StackTrace ?? "");
        return 10;
    }
    finally
    {
        await browser.CloseAsync();
    }
}

static async Task<bool> IsLoginPageAsync(IPage page)
{
    try
    {
        var emailInput = page.Locator("input[type='email'], input[name='loginfmt'], input[aria-label*='email'], input[placeholder*='email']").First;
        if (await emailInput.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 2000 }))
            return true;
    }
    catch { }
    try
    {
        if (page.Url.Contains("login.", StringComparison.OrdinalIgnoreCase) || page.Url.Contains("login.live.com", StringComparison.OrdinalIgnoreCase))
            return true;
    }
    catch { }
    return false;
}

/// <summary>
/// Auto-login with email/password. First checks if user is already authenticated (inbox visible) and skips login in that case.
/// Handles verification / account prompts by clicking "Choose different account" and re-selecting the target email.
/// </summary>
static async Task<bool> LoginWithCredentialsAsync(IPage page, IBrowserContext context, string webUrl, string email, string password, string statePath, Action<string> LogLocal)
{
    try
    {
        // If already authenticated (mailbox visible), just save state and return.
        if (await IsAuthenticatedAsync(page))
        {
            LogLocal("Already authenticated; saving session without re-login.");
            await context.StorageStateAsync(new BrowserContextStorageStateOptions { Path = statePath });
            return true;
        }

        // Email step
        var emailInput = page.Locator("input[type='email'], input[name='loginfmt']").First;
        await emailInput.WaitForAsync(new LocatorWaitForOptions { Timeout = 10000 });
        await emailInput.FillAsync(email);
        await page.Locator("input[type='submit'], button[type='submit']").First.ClickAsync(new LocatorClickOptions { Timeout = 5000 });
        await Task.Delay(3000);

        // Password step (or verification / choose different account)
        for (int round = 0; round < 5; round++)
        {
            // If "Choose different account" or "account not verified" type prompt appears, click it and reselect account.
            var chooseDiff = page.GetByRole(AriaRole.Link).Filter(new LocatorFilterOptions { HasText = "Choose different account" }).First;
            if (await chooseDiff.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 2000 }))
            {
                LogLocal("Verification/account prompt: clicking 'Choose different account'.");
                await chooseDiff.ClickAsync(new LocatorClickOptions { Timeout = 5000 });
                await Task.Delay(2000);
                var accountOption = page.Locator("[role='listbox'] [role='option'], [data-convid], a").Filter(new LocatorFilterOptions { HasText = email }).First;
                if (await accountOption.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 5000 }))
                {
                    await accountOption.ClickAsync(new LocatorClickOptions { Timeout = 5000 });
                    await Task.Delay(3000);
                }
                continue;
            }

            var passwordInput = page.Locator("input[type='password'], input[name='passwd']").First;
            if (await passwordInput.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 3000 }))
            {
                await passwordInput.FillAsync(password);
                await page.Locator("input[type='submit'], button[type='submit']").First.ClickAsync(new LocatorClickOptions { Timeout = 5000 });
                await Task.Delay(5000);
                continue;
            }

            // Check if we're on inbox (mail list or search visible)
            if (await IsAuthenticatedAsync(page))
            {
                LogLocal("Inbox reached; saving session.");
                await context.StorageStateAsync(new BrowserContextStorageStateOptions { Path = statePath });
                return true;
            }

            await Task.Delay(2000);
        }

        // Final check for inbox
        if (await IsAuthenticatedAsync(page))
        {
            await context.StorageStateAsync(new BrowserContextStorageStateOptions { Path = statePath });
            return true;
        }
        return false;
    }
    catch (Exception ex)
    {
        LogLocal("LoginWithCredentials error: " + ex.Message);
        return false;
    }
}

/// <summary>
/// Detects whether the current page looks like an authenticated Outlook mailbox
/// (search box and/or message list visible).
/// </summary>
static async Task<bool> IsAuthenticatedAsync(IPage page)
{
    try
    {
        var searchBox = page.GetByPlaceholder("Search", new PageGetByPlaceholderOptions { Exact = false })
            .Or(page.Locator("input[aria-label*='Search'], input[placeholder*='Search']"))
            .First;
        if (await searchBox.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 2000 }))
            return true;
    }
    catch { }

    try
    {
        var messageList = page.Locator("[role='listbox'] [role='option'], [role='grid'] [role='row'], [data-convid]").First;
        if (await messageList.IsVisibleAsync(new LocatorIsVisibleOptions { Timeout = 2000 }))
            return true;
    }
    catch { }

    return false;
}

static async Task<AppConfig?> LoadConfig(string configPath)
{
    try
    {
        string json = await File.ReadAllTextAsync(configPath);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        string sourceFolder = "";
        string webUrl = "https://outlook.office.com/mail/inbox";
        string storageStatePath = "outlook-playwright-state.json";
        string? email = null;
        string? password = null;

        if (root.TryGetProperty("FinalMovement", out var fm))
        {
            if (fm.TryGetProperty("SourceFolder", out var sf))
                sourceFolder = sf.GetString() ?? "";
        }
        if (root.TryGetProperty("Outlook", out var ol))
        {
            if (ol.TryGetProperty("WebUrl", out var wu)) webUrl = wu.GetString() ?? webUrl;
            if (ol.TryGetProperty("StorageStatePath", out var ss)) storageStatePath = ss.GetString() ?? storageStatePath;
            if (ol.TryGetProperty("Email", out var em)) email = em.GetString();
            if (ol.TryGetProperty("Password", out var pw)) password = pw.GetString();
        }

        if (string.IsNullOrEmpty(sourceFolder))
        {
            Console.WriteLine("FinalMovement.SourceFolder not found in config.");
            return null;
        }
        return new AppConfig(sourceFolder, webUrl, storageStatePath, email ?? "", password ?? "");
    }
    catch (Exception ex)
    {
        Console.WriteLine("Config read error: " + ex.Message);
        return null;
    }
}

internal record AppConfig(string SourceFolder, string WebUrl, string StorageStatePath, string Email, string Password);
