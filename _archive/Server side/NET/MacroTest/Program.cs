using System;
using System.Data;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using NPOI.SS.UserModel;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;

class Program
{
    static string? s_logPath;

    static void Log(string message)
    {
        Console.WriteLine(message);
        if (s_logPath != null)
        {
            try
            {
                // Ensure directory exists
                string? logDir = Path.GetDirectoryName(s_logPath);
                if (!string.IsNullOrEmpty(logDir) && !Directory.Exists(logDir))
                {
                    Directory.CreateDirectory(logDir);
                }
                // Use UTF-8 encoding and append with immediate flush for live updates
                using (var writer = new StreamWriter(s_logPath, append: true, encoding: System.Text.Encoding.UTF8))
                {
                    writer.WriteLine(message);
                    writer.Flush(); // Force immediate write to disk
                }
            }
            catch (Exception ex)
            {
                // Log error to console but don't fail the run
                Console.WriteLine($"[WARNING] Failed to write to log file: {ex.Message}");
            }
        }
    }

    static int Main(string[] args)
    {
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
        {
            Console.Error.WriteLine($"UNHANDLED: {e.ExceptionObject}");
            Console.Error.Flush();
        };

        int exitCode = 0;
        try
        {
            Console.WriteLine("Starting Module...");

            var config = LoadConfig();
            if (config == null)
            {
                exitCode = 12;
                return exitCode;
            }

            string baseDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location) ?? AppContext.BaseDirectory ?? ".";

            // Write effdate from Oracle to file (for .bat -> script: script reads this date for file movement).
            if (args.Length > 0 && string.Equals(args[0].Trim(), "--write-effdate", StringComparison.OrdinalIgnoreCase))
            {
                if (config.Oracle == null || string.IsNullOrWhiteSpace(config.Oracle.ConnectionString))
                {
                    Console.WriteLine("Oracle connection required for --write-effdate.");
                    return 1;
                }
                DateTime? eff = FetchEffdate(config.Oracle.ConnectionString);               if (!eff.HasValue)
                {
                    Console.WriteLine("Could not get effdate from Oracle (Business_Calendar).");
                    return 2;
                }
                string effdateFile = Path.Combine(baseDir, "effdate.txt");
                File.WriteAllText(effdateFile, eff.Value.ToString("yyyyMMdd", System.Globalization.CultureInfo.InvariantCulture));
                Console.WriteLine($"Effdate written: {eff.Value:yyyy-MM-dd} -> effdate.txt");
                return 0;
            }

            // Test mode: only run Holdings report (call proc, fill template, save). Usage: MacroTest.exe --test-holdings
            if (args.Length > 0 && string.Equals(args[0].Trim(), "--test-holdings", StringComparison.OrdinalIgnoreCase))
            {
                if (config.HoldingsReport == null)
                {
                    Console.WriteLine("HoldingsReport section missing in appsettings.json.");
                    return 1;
                }
                if (config.Oracle == null || string.IsNullOrWhiteSpace(config.Oracle.ConnectionString))
                {
                    Console.WriteLine("Oracle connection required for Holdings report. Configure Oracle in appsettings.json.");
                    return 1;
                }
                DateTime? effdate = FetchEffdate(config.Oracle.ConnectionString);
                if (!effdate.HasValue)
                {
                    Console.WriteLine("Could not get effdate from Oracle (Business_Calendar).");
                    return 2;
                }
                Console.WriteLine($"Test mode: Holdings report only. Effdate: {effdate.Value:yyyy-MM-dd}");
                return ExportHoldingsReport(config.Oracle.ConnectionString, effdate.Value, config.HoldingsReport, baseDir);
            }
            s_logPath = string.IsNullOrWhiteSpace(config.LogFiles.AppLog)
                ? Path.Combine(baseDir, "MacroTest.log")
                : Path.IsPathRooted(config.LogFiles.AppLog)
                    ? config.LogFiles.AppLog
                    : Path.Combine(baseDir, config.LogFiles.AppLog.Trim());

            // Ensure log file directory exists and create initial log entry
            try
            {
                string? logDir = Path.GetDirectoryName(s_logPath);
                if (!string.IsNullOrEmpty(logDir) && !Directory.Exists(logDir))
                {
                    Directory.CreateDirectory(logDir);
                }
                // Create/initialize log file with a header (UTF-8 encoding)
                File.WriteAllText(
                    s_logPath,
                    $"=== MacroTest Log Started at {DateTime.Now:yyyy-MM-dd HH:mm:ss} ==={Environment.NewLine}",
                    System.Text.Encoding.UTF8
                );
                Console.WriteLine($"Log file initialized: {s_logPath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[WARNING] Could not initialize log file at {s_logPath}: {ex.Message}");
                Console.WriteLine("Continuing without log file...");
                s_logPath = null; // Disable logging if we can't create the file
            }

            Log("----------");
            DateTime moduleStartTime = DateTime.Now;
            Log($"[{moduleStartTime:yyyy-MM-dd HH:mm:ss}] Starting Module...");
            Log($"Log file location: {s_logPath ?? "NOT AVAILABLE"}");
            Log("----------");

            string dionVbsPath = config.Scripts.DionDownloaderVbs;

            // Fetch effdate early from Oracle so we can decide whether to skip the DION Downloader
            DateTime? earlyEffDate = null;
            if (config.Oracle != null && !string.IsNullOrWhiteSpace(config.Oracle.ConnectionString))
            {
                Log("Fetching effective date from Oracle (pre-check for DION files)...");
                earlyEffDate = FetchEffdate(config.Oracle.ConnectionString);
                if (earlyEffDate.HasValue)
                    Log($"Effective date: {earlyEffDate.Value:yyyy-MM-dd}");
                else
                    Log("WARNING: Could not fetch effdate from Oracle - DION Downloader will run unconditionally.");
            }

            // Step 0: Run DionDownloader_latest.vbs — skipped if files are already ready for effdate
            if (earlyEffDate.HasValue && CheckDionFilesReady(earlyEffDate.Value, config))
            {
                Log($"All Dion files already present with correct size, date, and row counts for effdate {earlyEffDate.Value:yyyy-MM-dd}. Skipping DION Downloader.");
            }
            else
            {
                if (earlyEffDate.HasValue)
                    Log("Dion files not ready or not matching effdate - running DION Downloader...");
                else
                    Log("Running DION Downloader...");
                try
                {
                    var dionProcess = new Process();
                    dionProcess.StartInfo.FileName = "wscript.exe";
                    dionProcess.StartInfo.Arguments = $"\"{dionVbsPath}\"";
                    dionProcess.StartInfo.UseShellExecute = false;
                    dionProcess.StartInfo.CreateNoWindow = true;

                    dionProcess.Start();
                    dionProcess.WaitForExit();

                    if (dionProcess.ExitCode == 0)
                    {
                        Log("DionDownloader macro executed successfully.");
                    }
                    else
                    {
                        Log($"DionDownloader macro execution failed. Exit Code: {dionProcess.ExitCode}");
                        Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed with failure. Exit code: 10");
                        exitCode = 10;
                        return exitCode;
                    }
                }
                catch (Exception ex)
                {
                    Log("Error running DionDownloader macro:");
                    Log(ex.ToString());
                    Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed with error. Exit code: 11");
                    exitCode = 11;
                    return exitCode;
                }
            }

            string ps1Path = config.Scripts.PowerShellScript;
            string logPath = config.LogFiles.CopyLog;
            string vbsPath = config.Scripts.TestVbs;
            string filePath = config.OutputFiles.EtlDataXls;

            // Step 1: Run PowerShell script
            Log("Running BSE Downloader...");
            try
            {
            var psProcess = new Process();
            psProcess.StartInfo.FileName = "powershell.exe";
            psProcess.StartInfo.Arguments = $"-ExecutionPolicy Bypass -File \"{ps1Path}\"";
            psProcess.StartInfo.UseShellExecute = false;
            psProcess.StartInfo.RedirectStandardOutput = true;
            psProcess.StartInfo.RedirectStandardError = true;
            psProcess.StartInfo.CreateNoWindow = true;

            psProcess.Start();
            string psOutput = psProcess.StandardOutput.ReadToEnd();
            string psError = psProcess.StandardError.ReadToEnd();
            psProcess.WaitForExit();

            if (psProcess.ExitCode == 0)
            {
                Log("PowerShell script executed successfully.");
            }
            else
            {
                Log("PowerShell script execution failed.");
                Log($"Exit Code: {psProcess.ExitCode}");
                if (!string.IsNullOrWhiteSpace(psError))
                    Log("Error Output: " + psError);
                Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed with failure. Exit code: 1");
                exitCode = 1;
                return exitCode;
            }
            }
            catch (Exception ex)
            {
                Log("Error running PowerShell script:");
                Log(ex.ToString());
                Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed with error. Exit code: 2");
                exitCode = 2;
                return exitCode;
            }

            // Step 2: Fetch and show latest log data from copy_log.txt
            try
            {
            if (File.Exists(logPath))
            {
                string? lastLine = null;
                using (var fs = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (var sr = new StreamReader(fs))
                {
                    while (!sr.EndOfStream)
                        lastLine = sr.ReadLine();
                }

                if (!string.IsNullOrWhiteSpace(lastLine))
                {
                    Log("Latest copy_log.txt entry:");
                    Log(lastLine);
                }
                else
                {
                    Log("copy_log.txt exists but appears empty.");
                }
            }
            else
            {
                Log("copy_log.txt not found at path:");
                Log(logPath);
            }
            }
            catch (Exception ex)
            {
                Log("Error reading log file:");
                Log(ex.ToString());
            }

            // Step 3: Run VBS Macro
            Log("Running Macro...");
            try
            {
            var process = new Process();
            process.StartInfo.FileName = "wscript.exe";
            process.StartInfo.Arguments = $"\"{vbsPath}\"";
            process.StartInfo.UseShellExecute = false;
            process.StartInfo.CreateNoWindow = true;

            process.Start();
            process.WaitForExit();

            if (process.ExitCode == 0)
            {
                Log("Macro executed successfully.");

                try
                {
                    if (File.Exists(filePath))
                    {
                        var fileInfo = new FileInfo(filePath);
                        double sizeMb = fileInfo.Length / (1024.0 * 1024.0);
                        DateTime fileModifiedTime = fileInfo.LastWriteTime;
                        TimeSpan timeSinceModified = moduleStartTime - fileModifiedTime;
                        double minutesSinceModified = timeSinceModified.TotalMinutes;

                        Log("Output file information:");
                        Log($"  Name: {fileInfo.Name}");
                        Log($"  Size: {sizeMb:F2} MB");
                        Log($"  Last Modified: {fileModifiedTime:yyyy-MM-dd HH:mm:ss}");
                        Log($"  Full Path: {fileInfo.FullName}");
                        Log($"  Time since modification: {minutesSinceModified:F2} minutes");

                        // Check if file was modified within 7 minutes of module start
                        if (minutesSinceModified > 7)
                        {
                            Log($"  ⚠ ALERT: File modification time is {minutesSinceModified:F2} minutes old (expected within 7 minutes of module start).");
                            Log($"  Module started at: {moduleStartTime:yyyy-MM-dd HH:mm:ss}");
                            Log($"  File modified at: {fileModifiedTime:yyyy-MM-dd HH:mm:ss}");
                        }
                        else
                        {
                            Log($"  ✓ File modification time is recent (within 7 minutes).");
                        }
                    }
                    else
                    {
                        Log($"File does not exist: {filePath}");
                    }
                }
                catch (Exception fileEx)
                {
                    Log("Error checking output file:");
                    Log(fileEx.ToString());
                }

                // Step 3B: Read latest macro runtime log file
                try
                {
                    string? macroLogDir = config.OutputFiles.MacroLogDirectory;
                    if (!string.IsNullOrWhiteSpace(macroLogDir) && Directory.Exists(macroLogDir))
                    {
                        Log("Reading latest macro runtime log file...");
                        var latestLogFile = FindLatestMacroLogFile(macroLogDir);
                        if (latestLogFile != null)
                        {
                            Log($"Found latest macro log: {Path.GetFileName(latestLogFile)}");
                            Log($"  Full Path: {latestLogFile}");
                            Log($"  Last Modified: {File.GetLastWriteTime(latestLogFile):yyyy-MM-dd HH:mm:ss}");
                            // Log file found but content not displayed as requested
                        }
                        else
                        {
                            Log($"No macro log files found matching pattern 'log_*' in directory: {macroLogDir}");
                        }
                    }
                    else
                    {
                        Log($"Macro log directory not found or not configured: {macroLogDir ?? "null"}");
                    }
                }
                catch (Exception logEx)
                {
                    Log("Error reading macro runtime log file:");
                    Log(logEx.ToString());
                }

                // Step 4: Run Oracle stored procedures and validations
                if (config.Oracle != null && !string.IsNullOrWhiteSpace(config.Oracle.ConnectionString))
                {
                    Log("Running Oracle scripts and validations...");
                    int oracleResult = RunOracleScripts(config.Oracle.ConnectionString, config.Oracle.StepsFile, baseDir, config, earlyEffDate);
                    if (oracleResult != 0)
                    {
                        Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed with Oracle failure. Exit code: {oracleResult}");
                        exitCode = oracleResult;
                        return exitCode;
                    }

                    // Post completion: run finalfile.sql and export Holdings report
                    if (earlyEffDate.HasValue && config.HoldingsReport != null)
                    {
                        int holdingsResult = ExportHoldingsReport(config.Oracle!.ConnectionString, earlyEffDate.Value, config.HoldingsReport, baseDir);
                        if (holdingsResult != 0)
                        {
                            Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Holdings export failed. Exit code: {holdingsResult}");
                            exitCode = holdingsResult;
                            return exitCode;
                        }
                    }
                }
                else
                {
                    Log("Oracle configuration not found or empty. Skipping Oracle step.");
                }

                Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed successfully. Exit code: 0");
                exitCode = 0;
            }
            else
            {
                Log($"Macro execution failed. Exit Code: {process.ExitCode}");
                Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed with failure. Exit code: 1");
                exitCode = 1;
            }
            }
            catch (Exception ex)
            {
                Log("Error running macro:");
                Log(ex.ToString());
                Log($"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] Completed with error. Exit code: 2");
                exitCode = 2;
            }
        }
        catch (Exception outerEx)
        {
            Console.WriteLine($"Fatal error: {outerEx.Message}");
            Console.WriteLine(outerEx.ToString());
            exitCode = 99;
        }
        finally
        {
            if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("MacroTestNoPause")))
            {
                Console.WriteLine();
                Console.WriteLine("Press any key to exit...");
                Console.ReadKey();
            }
        }
        return exitCode;
    }

    /// <summary>Validates Dion Excel files: for each file, counts rows where date column = effdate and checks count is in [MinCount, MaxCount].</summary>
    static int ValidateDionExcelData(DateTime effdate, DionExcelValidationConfig[] validations)
    {
        const int exitCodeDionExcelValidation = 28;
        DateTime effdateDateOnly = effdate.Date;
        Log("Validating Dion Excel data (count of rows for effdate)...");

        foreach (var v in validations)
        {
            string dir = v.Directory;
            string prefix = v.FilePrefix;
            if (!Directory.Exists(dir))
            {
                Log($"ERROR: Dion Excel validation - directory does not exist: {dir}");
                return exitCodeDionExcelValidation;
            }

            var dirInfo = new DirectoryInfo(dir);
            var files = dirInfo.GetFiles(prefix + "*").OrderByDescending(f => f.LastWriteTime).ToArray();
            if (files.Length == 0)
            {
                Log($"ERROR: Dion Excel validation - no files found for '{prefix}*' in {dir}");
                return exitCodeDionExcelValidation;
            }

            string filePath = files[0].FullName;
            int? dateColumnIndex = ParseDateColumn(v.DateColumn);
            if (dateColumnIndex == null)
            {
                Log($"ERROR: Dion Excel validation - invalid DateColumn '{v.DateColumn}' for {prefix}");
                return exitCodeDionExcelValidation;
            }

            int count;
            try
            {
                count = CountRowsWithDateInExcel(filePath, dateColumnIndex.Value, effdateDateOnly);
            }
            catch (Exception ex)
            {
                Log($"ERROR: Dion Excel validation - failed to read {Path.GetFileName(filePath)}: {ex.Message}");
                Log(ex.ToString());
                return exitCodeDionExcelValidation;
            }

            Log($"  {prefix}: file={Path.GetFileName(filePath)}, rows with effdate ({effdateDateOnly:yyyy-MM-dd}) = {count} (expected {v.MinCount}-{v.MaxCount})");

            if (count < v.MinCount || count > v.MaxCount)
            {
                Log($"ERROR: Dion Excel validation FAILED for '{prefix}': count {count} is outside range [{v.MinCount}, {v.MaxCount}].");
                return exitCodeDionExcelValidation;
            }
            Log($"  ✓ {prefix} count OK.");
        }

        Log("All Dion Excel data validations passed.");
        return 0;
    }

    /// <summary>
    /// Extracts the date embedded in a Dion filename right after the prefix.
    /// Expected format: {prefix}{ddMMyyyy}{anything}.{ext}
    /// Example: DION_AVGVOL_19022026062301.xlsx  →  2026-02-19
    /// </summary>
    static DateTime? ParseDateFromFilename(string fileName, string prefix)
    {
        try
        {
            string nameNoExt = Path.GetFileNameWithoutExtension(fileName);
            if (!nameNoExt.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                return null;

            string after = nameNoExt.Substring(prefix.Length);
            if (after.Length < 8)
                return null;

            string datePart = after.Substring(0, 8); // ddMMyyyy
            if (DateTime.TryParseExact(datePart, "ddMMyyyy",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out DateTime result))
                return result;

            return null;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>Parse DateColumn as 0-based index: "A"->0, "B"->1, "AA"->26, or "1"/"2" as 1-based column index.</summary>
    static int? ParseDateColumn(string? dateColumn)
    {
        if (string.IsNullOrWhiteSpace(dateColumn)) return null;
        string s = dateColumn.Trim().ToUpperInvariant();
        if (s.Length == 0) return null;
        if (char.IsDigit(s[0]))
        {
            if (int.TryParse(s, out int oneBased) && oneBased >= 1)
                return oneBased - 1;
            return null;
        }
        int col = 0;
        foreach (char c in s)
        {
            if (c < 'A' || c > 'Z') return null;
            col = col * 26 + (c - 'A' + 1);
        }
        return col - 1;
    }

    /// <summary>Count rows in first sheet where the given column's value equals targetDate (date part).</summary>
    static int CountRowsWithDateInExcel(string filePath, int dateColumnIndex, DateTime targetDate)
    {
        using var stream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
        IWorkbook workbook = WorkbookFactory.Create(stream);
        ISheet sheet = workbook.GetSheetAt(0);
        int count = 0;
        for (int rowIndex = 0; rowIndex <= sheet.LastRowNum; rowIndex++)
        {
            IRow row = sheet.GetRow(rowIndex);
            if (row == null) continue;
            ICell cell = row.GetCell(dateColumnIndex);
            if (cell == null) continue;
            DateTime? cellDate = GetCellDate(cell);
            if (cellDate.HasValue && cellDate.Value.Date == targetDate)
                count++;
        }
        return count;
    }

    static DateTime? GetCellDate(ICell cell)
    {
        switch (cell.CellType)
        {
            case CellType.Numeric:
                if (DateUtil.IsCellDateFormatted(cell))
                    return cell.DateCellValue;
                // Excel stores dates as OADate number
                try
                {
                    double n = cell.NumericCellValue;
                    if (n >= 1 && n < 2958466) // rough valid date range
                        return DateTime.FromOADate(n);
                }
                catch { }
                break;
            case CellType.String:
                if (DateTime.TryParse(cell.StringCellValue, out var parsed))
                    return parsed;
                break;
            case CellType.Formula:
                try
                {
                    if (cell.CachedFormulaResultType == CellType.Numeric && DateUtil.IsCellDateFormatted(cell))
                        return cell.DateCellValue;
                    if (cell.CachedFormulaResultType == CellType.Numeric)
                    {
                        double n = cell.NumericCellValue;
                        if (n >= 1 && n < 2958466)
                            return DateTime.FromOADate(n);
                    }
                }
                catch { }
                break;
        }
        return null;
    }

    /// <summary>Opens a short-lived Oracle connection just to fetch effdate from Business_Calendar.</summary>
    static DateTime? FetchEffdate(string connectionString)
    {
        try
        {
            using var connection = new OracleConnection(connectionString);
            connection.Open();
            string sql = @"
                SELECT MIN(effective_date)
                FROM Business_Calendar
                WHERE dataload_status=0 and Businessday_flag=1
                AND effective_date > (SELECT MAX(effective_date) FROM business_calendar WHERE dataload_status=1)";
            using var cmd = new OracleCommand(sql, connection);
            var result = cmd.ExecuteScalar();
            if (result == null || result == DBNull.Value)
                return null;
            if (result is DateTime dt)
                return dt;
            if (DateTime.TryParse(result.ToString(), out var parsed))
                return parsed;
            return null;
        }
        catch (Exception ex)
        {
            Log($"WARNING: FetchEffdate failed: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Returns true if ALL Dion files are already present, within size range,
    /// last-modified on the same date as effdate, and (if configured) row counts for effdate are in range.
    /// Logs the reason for each failure so it is clear why the downloader is being triggered.
    /// </summary>
    static bool CheckDionFilesReady(DateTime effdate, AppConfig config)
    {
        bool allReady = true;

        // Size + file-date check
        foreach (var check in config.DionFileChecks)
        {
            if (!Directory.Exists(check.Directory))
            {
                Log($"  DION pre-check: directory not found: {check.Directory}");
                allReady = false;
                continue;
            }

            var files = new DirectoryInfo(check.Directory)
                .GetFiles(check.FilePrefix + "*")
                .OrderByDescending(f => f.LastWriteTime)
                .ToArray();

            if (files.Length == 0)
            {
                Log($"  DION pre-check: no file found for '{check.FilePrefix}*'");
                allReady = false;
                continue;
            }

            var latest = files[0];
            double sizeKb = latest.Length / 1024.0;

            if (sizeKb < check.MinKb || sizeKb > check.MaxKb)
            {
                Log($"  DION pre-check: '{latest.Name}' size {sizeKb:F1} KB outside range [{check.MinKb}-{check.MaxKb} KB]");
                allReady = false;
                continue;
            }

            DateTime? fileNameDate = ParseDateFromFilename(latest.Name, check.FilePrefix);
            if (fileNameDate == null)
            {
                Log($"  DION pre-check: '{latest.Name}' - could not parse date from filename (expected ddMMyyyy after prefix)");
                allReady = false;
                continue;
            }

            if (fileNameDate.Value.Date != effdate.Date)
            {
                Log($"  DION pre-check: '{latest.Name}' filename date {fileNameDate.Value:yyyy-MM-dd} != effdate {effdate:yyyy-MM-dd}");
                allReady = false;
                continue;
            }

            Log($"  DION pre-check: '{latest.Name}' size OK ({sizeKb:F1} KB), filename date matches effdate.");
        }

        if (!allReady)
            return false;

        // Row-count check (if DionExcelValidations configured)
        if (config.DionExcelValidations == null || config.DionExcelValidations.Length == 0)
            return true;

        foreach (var v in config.DionExcelValidations)
        {
            if (!Directory.Exists(v.Directory))
            {
                Log($"  DION pre-check (Excel): directory not found: {v.Directory}");
                return false;
            }

            var files = new DirectoryInfo(v.Directory)
                .GetFiles(v.FilePrefix + "*")
                .OrderByDescending(f => f.LastWriteTime)
                .ToArray();

            if (files.Length == 0)
            {
                Log($"  DION pre-check (Excel): no file found for '{v.FilePrefix}*'");
                return false;
            }

            int? colIdx = ParseDateColumn(v.DateColumn);
            if (colIdx == null)
            {
                Log($"  DION pre-check (Excel): invalid DateColumn '{v.DateColumn}' for '{v.FilePrefix}'");
                return false;
            }

            int count;
            try
            {
                count = CountRowsWithDateInExcel(files[0].FullName, colIdx.Value, effdate.Date);
            }
            catch (Exception ex)
            {
                Log($"  DION pre-check (Excel): failed to read '{files[0].Name}': {ex.Message}");
                return false;
            }

            if (count < v.MinCount || count > v.MaxCount)
            {
                Log($"  DION pre-check (Excel): '{files[0].Name}' has {count} rows for effdate (expected {v.MinCount}-{v.MaxCount})");
                return false;
            }

            Log($"  DION pre-check (Excel): '{files[0].Name}' row count {count} OK.");
        }

        return true;
    }

    static AppConfig? LoadConfig()
    {
        // Get the directory where the executable is located
        string baseDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location) ?? AppContext.BaseDirectory;
        string configPath = Path.Combine(baseDir, "appsettings.json");

        if (!File.Exists(configPath))
        {
            Console.WriteLine($"Configuration file not found: {configPath}");
            Console.WriteLine("Please ensure appsettings.json exists next to the executable.");
            return null;
        }

        try
        {
            string json = File.ReadAllText(configPath);
            var config = JsonSerializer.Deserialize<AppConfig>(json);
            if (config?.Scripts == null || config.LogFiles == null || config.OutputFiles == null || config.DionFileChecks == null)
            {
                Console.WriteLine("Invalid configuration: required sections (Scripts, LogFiles, OutputFiles, DionFileChecks) are missing or empty.");
                return null;
            }
            // Oracle config is optional - if missing, Oracle step will be skipped
            return config;
        }
        catch (JsonException ex)
        {
            Console.WriteLine("Invalid JSON in appsettings.json:");
            Console.WriteLine(ex.Message);
            return null;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error loading configuration:");
            Console.WriteLine(ex.ToString());
            return null;
        }
    }

    static int RunOracleScripts(string connectionString, string? stepsFile, string baseDir, AppConfig config, DateTime? earlyEffDate = null)
    {
        try
        {
            Log("Attempting to connect to Oracle database...");
            using var connection = new OracleConnection(connectionString);
            connection.Open();
            Log("✓ Oracle connection established successfully!");
            Log($"  Connection State: {connection.State}");
            Log($"  Server Version: {connection.ServerVersion}");

            // Use pre-fetched effdate if available, otherwise fetch it now
            DateTime? effDate = earlyEffDate;
            if (!effDate.HasValue)
            {
                Log("Fetching effective date (effdate)...");
                string effdateQuery = @"
                SELECT MIN(effective_date)
                FROM Business_Calendar
                WHERE dataload_status=0 and Businessday_flag=1
                AND effective_date > (SELECT MAX(effective_date) FROM business_calendar WHERE dataload_status=1)";

                using (var cmd = new OracleCommand(effdateQuery, connection))
                {
                    var result = cmd.ExecuteScalar();
                    if (result != null && result != DBNull.Value)
                    {
                        if (result is DateTime dt)
                            effDate = dt;
                        else if (DateTime.TryParse(result.ToString(), out var parsedDate))
                            effDate = parsedDate;
                    }
                }

                if (!effDate.HasValue)
                {
                    Log("ERROR: Could not retrieve effdate from business_calendar.");
                    return 22;
                }
                Log($"Retrieved effdate: {effDate.Value:yyyy-MM-dd}");
            }
            else
            {
                Log($"Using effective date (effdate): {effDate.Value:yyyy-MM-dd}");
            }

            // Step 2: Run UPDATE query for daily_process_stats
            Log("Updating daily_process_stats for ETL STAGE 1 and ETL STAGE 2...");
            string updateSql = @"
                UPDATE daily_process_stats 
                SET currdatadate=(SELECT currdatadate FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
                    lastdatadate=(SELECT lastdatadate FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
                    rundate=(SELECT rundate FROM daily_process_stats WHERE process_name = 'SRC DATA COLLATION'),
                    dataready=0,
                    status=NULL 
                WHERE process_name IN ('ETL STAGE 1','ETL STAGE 2')";

            using (var cmd = new OracleCommand(updateSql, connection))
            {
                int rowsAffected = cmd.ExecuteNonQuery();
                Log($"Updated {rowsAffected} row(s) in daily_process_stats.");
            }

            // Step 3+: Execute configured procedures & validations from file (runtime-driven)
            string resolvedStepsPath = ResolveConfigPath(baseDir, stepsFile, "oracle_steps.json");
            if (!File.Exists(resolvedStepsPath))
            {
                Log($"ERROR: Oracle steps file not found: {resolvedStepsPath}");
                return 25;
            }

            OracleStepsFile? stepsDoc;
            try
            {
                var json = File.ReadAllText(resolvedStepsPath);
                stepsDoc = JsonSerializer.Deserialize<OracleStepsFile>(json, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });
            }
            catch (Exception ex)
            {
                Log("ERROR: Failed to read/parse oracle steps file.");
                Log(ex.ToString());
                return 26;
            }

            if (stepsDoc?.Steps == null || stepsDoc.Steps.Length == 0)
            {
                Log($"ERROR: Oracle steps file has no steps: {resolvedStepsPath}");
                return 27;
            }

            // Track per-step and overall elapsed time
            var totalStepsElapsed = TimeSpan.Zero;

            foreach (var step in stepsDoc.Steps)
            {
                var stepStart = DateTime.Now;

                if (!string.IsNullOrWhiteSpace(step.Name))
                    Log($"--- ORACLE STEP: {step.Name} ---");

                if (!step.Enabled)
                {
                    Log("  SKIPPED (Enabled: false).");
                    continue;
                }

                if (!string.IsNullOrWhiteSpace(step.ProcedureBlock))
                {
                    Log($"Executing: {step.ProcedureBlock}");
                    using (var cmd = new OracleCommand(step.ProcedureBlock, connection))
                    {
                        cmd.CommandType = CommandType.Text;
                        int rowsAffected = cmd.ExecuteNonQuery();
                        // rowsAffected is -1 for PL/SQL blocks (BEGIN...END), >= 0 for DML
                        if (rowsAffected >= 0)
                            Log($"Executed successfully. Rows affected: {rowsAffected}");
                        else
                            Log("Procedure executed successfully.");
                    }
                }
                else
                {
                    Log("No procedure for this step (validation-only).");
                }

                if (step.Validations == null || step.Validations.Length == 0)
                {
                    Log("No validations configured for this step.");
                    continue;
                }

                foreach (var v in step.Validations)
                {
                    if (!string.IsNullOrWhiteSpace(v.Name))
                        Log($"Validation: {v.Name}");

                    if (string.IsNullOrWhiteSpace(v.Sql))
                    {
                        Log("  SKIP: Validation SQL is empty.");
                        continue;
                    }

                    object? scalar;
                    using (var cmd = new OracleCommand(v.Sql, connection))
                    {
                        cmd.CommandType = CommandType.Text;
                        if (v.Sql.Contains(":effdate", StringComparison.OrdinalIgnoreCase))
                        {
                            cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effDate.Value.Date;
                        }
                        scalar = cmd.ExecuteScalar();
                    }

                    string type = v.Type?.Trim() ?? string.Empty;
                    if (type.Equals("NonZeroCount", StringComparison.OrdinalIgnoreCase))
                    {
                        int c = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                        Log($"  Result: COUNT(*) = {c}");
                        if (c <= 0)
                        {
                            Log("  VALIDATION FAILED: count is 0 (expected > 0).");
                            return 23;
                        }
                        Log("  PASSED.");
                    }
                    else if (type.Equals("MustBeNull", StringComparison.OrdinalIgnoreCase))
                    {
                        bool isNull = (scalar == null || scalar == DBNull.Value);
                        Log($"  Result: {(isNull ? "NULL" : scalar?.ToString() ?? "NOT NULL")}");
                        if (!isNull)
                        {
                            Log("  VALIDATION FAILED: expected NULL.");
                            return 24;
                        }
                        Log("  PASSED.");
                    }
                    else
                    {
                        Log($"  Result: {(scalar == null || scalar == DBNull.Value ? "NULL" : scalar.ToString())}");
                        Log($"  NOTE: Unknown validation type '{v.Type}'. No pass/fail applied.");
                    }
                }

                var stepElapsed = DateTime.Now - stepStart;
                totalStepsElapsed += stepElapsed;
                Log($"Step elapsed time: {stepElapsed:c}");
            }

            Log($"Total elapsed time for all Oracle steps: {totalStepsElapsed:c}");
            Log("Oracle scripts completed successfully.");
            return 0;
        }
        catch (OracleException ex)
        {
            Log("✗ Oracle connection FAILED!");
            Log($"  Error Message: {ex.Message}");
            Log($"  Error Code: {ex.ErrorCode}");
            Log($"  Error Number: {ex.Number}");
            if (ex.InnerException != null)
                Log($"  Inner Exception: {ex.InnerException.Message}");
            Log($"  Full Details: {ex}");
            return 20; // Oracle-specific error code
        }
        catch (Exception ex)
        {
            Log("✗ Error running Oracle scripts:");
            Log($"  Error Type: {ex.GetType().Name}");
            Log($"  Error Message: {ex.Message}");
            if (ex.InnerException != null)
                Log($"  Inner Exception: {ex.InnerException.Message}");
            Log($"  Full Details: {ex}");
            return 21; // General Oracle error code
        }
    }

    static string? FindLatestMacroLogFile(string directory)
    {
        try
        {
            if (!Directory.Exists(directory))
                return null;

            var dirInfo = new DirectoryInfo(directory);
            // Find files matching pattern log_*
            var logFiles = dirInfo.GetFiles("log_*")
                .OrderByDescending(f => f.LastWriteTime)
                .ToArray();

            if (logFiles.Length == 0)
                return null;

            return logFiles[0].FullName;
        }
        catch (Exception ex)
        {
            Log($"Error finding latest macro log file in {directory}: {ex.Message}");
            return null;
        }
    }

    static string ResolveConfigPath(string baseDir, string? configuredPath, string defaultFileName)
    {
        if (string.IsNullOrWhiteSpace(configuredPath))
            return Path.Combine(baseDir, defaultFileName);
        return Path.IsPathRooted(configuredPath)
            ? configuredPath
            : Path.Combine(baseDir, configuredPath.Trim());
    }

    /// <summary>
    /// Runs finalfile.sql with :effdate, fills template with result, sets B3 to date, saves as Holdings_dd-MMM-yy.xls.
    /// </summary>
    static int ExportHoldingsReport(string connectionString, DateTime effdate, HoldingsReportConfig cfg, string baseDir)
    {
        const int exitCodeHoldingsExport = 29;
        string templatePath = Path.IsPathRooted(cfg.TemplatePath)
            ? cfg.TemplatePath
            : Path.Combine(baseDir, cfg.TemplatePath.Trim());
        if (!File.Exists(templatePath))
        {
            Log($"ERROR: Holdings report - template not found: {templatePath}");
            return exitCodeHoldingsExport;
        }

        string dateForFilename = effdate.ToString("dd-MMM-yy", CultureInfo.InvariantCulture);
        string outputFileName = $"Holdings_{dateForFilename}.xls";
        string outputDir = cfg.OutputDirectory.TrimEnd('\\', '/');
        string outputPath = Path.Combine(outputDir, outputFileName);

        try
        {
            Log("Calling FINAL_HOLDINGS_REPORT and building Holdings report...");
            DataTable dt;
            using (var connection = new OracleConnection(connectionString))
            {
                connection.Open();
                using var cmd = new OracleCommand("BEGIN FINAL_HOLDINGS_REPORT(:effdate, :out_cursor); END;", connection);
                cmd.BindByName = true;
                cmd.Parameters.Add("effdate", OracleDbType.Date).Value = effdate.Date;
                cmd.Parameters.Add("out_cursor", OracleDbType.RefCursor, ParameterDirection.Output);

                cmd.ExecuteNonQuery();

                var refCursor = (OracleRefCursor)cmd.Parameters["out_cursor"].Value!;
                using var reader = refCursor.GetDataReader();
                dt = new DataTable();
                dt.Load(reader);
            }

            if (dt.Rows.Count == 0)
                Log("WARNING: finalfile query returned no rows.");

            if (!Directory.Exists(outputDir))
                Directory.CreateDirectory(outputDir);

            int dataStartRowIndex = (cfg.DataStartRow ?? 5) - 1; // 1-based Excel row -> 0-based (template already has headers)

            using (var templateStream = new FileStream(templatePath, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                IWorkbook workbook = WorkbookFactory.Create(templateStream);
                ISheet sheet = workbook.GetSheetAt(0);

                // Date format for B3 and column A (dd-mmm-yy e.g. 20-Feb-26)
                short dateFormatIndex = workbook.GetCreationHelper().CreateDataFormat().GetFormat("dd-mmm-yy");
                ICellStyle dateStyle = workbook.CreateCellStyle();
                dateStyle.DataFormat = dateFormatIndex;

                // Set B3 to date (row index 2, column index 1) as Excel date
                IRow row3 = sheet.GetRow(2) ?? sheet.CreateRow(2);
                ICell cellB3 = row3.GetCell(1) ?? row3.CreateCell(1);
                cellB3.SetCellValue(effdate.Date);
                cellB3.CellStyle = dateStyle;

                // Write data only (no header row - template already has headers). Column A = date column, format as date.
                // At the same time, accumulate per-scheme weight sums in-memory so we can validate after the file is created.
                // Column indexes are 0-based: C = 2 (Scheme Name), M = 12 (Script Weight in Fund).
                var schemeWeights = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);

                for (int r = 0; r < dt.Rows.Count; r++)
                {
                    IRow dataRow = sheet.GetRow(dataStartRowIndex + r) ?? sheet.CreateRow(dataStartRowIndex + r);
                    for (int c = 0; c < dt.Columns.Count; c++)
                    {
                        ICell cell = dataRow.GetCell(c) ?? dataRow.CreateCell(c);
                        object val = dt.Rows[r][c];
                        if (val == null || val == DBNull.Value)
                            cell.SetCellValue(string.Empty);
                        else if (val is DateTime d)
                        {
                            cell.SetCellValue(d);
                            cell.CellStyle = dateStyle;
                        }
                        else if (val is decimal || val is double || val is int || val is long || val is float)
                            cell.SetCellValue(Convert.ToDouble(val));
                        else
                            cell.SetCellValue(val.ToString() ?? string.Empty);
                    }

                    // Accumulate per-scheme Script Weight in Fund (Column C / M in the output).
                    try
                    {
                        object schemeObj = dt.Rows[r].ItemArray.Length > 2 ? dt.Rows[r][2] : null;   // Scheme Name (Column C)
                        object weightObj = dt.Rows[r].ItemArray.Length > 12 ? dt.Rows[r][12] : null; // Script Weight in Fund (Column M)
                        if (schemeObj == null || schemeObj == DBNull.Value || weightObj == null || weightObj == DBNull.Value)
                            continue;

                        string scheme = schemeObj.ToString()?.Trim() ?? string.Empty;
                        if (string.IsNullOrEmpty(scheme))
                            continue;

                        double weight = Convert.ToDouble(weightObj, CultureInfo.InvariantCulture);
                        if (double.IsNaN(weight) || double.IsInfinity(weight))
                            continue;

                        if (schemeWeights.TryGetValue(scheme, out double existing))
                            schemeWeights[scheme] = existing + weight;
                        else
                            schemeWeights[scheme] = weight;
                    }
                    catch
                    {
                        // If any row cannot be parsed for validation, skip it – do not fail export.
                    }
                }

                // After populating the sheet, validate that for each scheme the total script weight is between 99.99 and 100.02.
                if (schemeWeights.Count > 0)
                {
                    var failedSchemes = schemeWeights
                        .Where(kvp => kvp.Value < 99.99 || kvp.Value > 100.02)
                        .OrderBy(kvp => kvp.Key)
                        .ToList();

                    if (failedSchemes.Count > 0)
                    {
                        Log("WARNING: Holdings validation – some schemes do not sum to ~100% (99.99–100.02).");
                        foreach (var kv in failedSchemes)
                        {
                            Log($"  Scheme '{kv.Key}' total Script Weight in Fund = {kv.Value:F6}");
                        }

                        Console.WriteLine();
                        Console.WriteLine("WARNING: One or more schemes in the Holdings file do not sum to ~100% (99.99–100.02).");
                        Console.WriteLine("Check MacroTest.log for details – the Holdings file was created anyway.");
                        Console.WriteLine();
                    }
                    else
                    {
                        Log("Holdings validation: all schemes have Script Weight in Fund between 99.99 and 100.02.");
                    }
                }

                using (var outStream = new FileStream(outputPath, FileMode.Create, FileAccess.Write))
                    workbook.Write(outStream);
            }

            Log($"Holdings report saved: {outputPath}");
            return 0;
        }
        catch (Exception ex)
        {
            Log($"ERROR: Holdings export failed: {ex.Message}");
            Log(ex.ToString());
            return exitCodeHoldingsExport;
        }
    }
}

// Config model: edit appsettings.json to change paths and settings
record AppConfig(
    ScriptsConfig Scripts,
    LogFilesConfig LogFiles,
    OutputFilesConfig OutputFiles,
    DionFileCheckConfig[] DionFileChecks,
    DionExcelValidationConfig[]? DionExcelValidations,
    OracleConfig? Oracle,
    HoldingsReportConfig? HoldingsReport
);

record ScriptsConfig(
    string DionDownloaderVbs,
    string PowerShellScript,
    string TestVbs
);

record LogFilesConfig(string CopyLog, string? AppLog);

record OutputFilesConfig(string EtlDataXls, string? MacroLogDirectory);

record DionFileCheckConfig(string Directory, string FilePrefix, double MinKb, double MaxKb);

/// <summary>Validates Dion Excel files: count of rows where date column = effdate must be between MinCount and MaxCount.</summary>
record DionExcelValidationConfig(string Directory, string FilePrefix, string DateColumn, int MinCount, int MaxCount);

record OracleConfig(string ConnectionString, string? StepsFile);

/// <summary>HeaderRow and DataStartRow are 1-based Excel row numbers (e.g. 4 = row 4). Defaults: 4 and 5.</summary>
record HoldingsReportConfig(string TemplatePath, string OutputDirectory, string FinalFileSql, int? HeaderRow = null, int? DataStartRow = null);

record OracleStepsFile(OracleStep[] Steps);

record OracleStep(string Name, string? ProcedureBlock, OracleValidation[] Validations, bool Enabled = true);

record OracleValidation(string Name, string Sql, string Type);
