# OutlookDownload

Uses **Playwright** to download email attachments from **Outlook on the web** (Inbox). Used in the RunFinalMovement flow: after effdate is fetched, this app finds Inbox emails whose **subject contains the effdate** (8-digit date) and downloads all attachments to the same folder used by file movement (`FinalMovement.SourceFolder` in appsettings).

## One-time setup

1. **Build** the project (e.g. from Visual Studio or `dotnet build`).
2. **Install Playwright browsers** (required once per machine):
   ```powershell
   cd "d:\Ataur\Project_NipEQ\Server side\NET\OutlookDownload"
   pwsh bin\Debug\net9.0\playwright.ps1 install
   ```
   Or from the project directory after build:
   ```powershell
   dotnet run -- playwright install
   ```
   (If `playwright.ps1` is not in the output folder, run: `pwsh node_modules/playwright/cli.js install` from a folder that has Playwright CLI, or use the [Playwright .NET install instructions](https://playwright.dev/dotnet/docs/intro#installation).)

3. **Save your Outlook login** (once, or when session expires):
   ```powershell
   OutlookDownload.exe --save-login --config:"path\to\MacroTest\appsettings.json"
   ```
   A browser opens. Log in at **https://outlook.cloud.microsoft.com/mail/** with your account. When the Inbox is visible, switch back to the console and **press Enter**. Your session is saved to `outlook-playwright-state.json` (in the same folder as the config). **Do not put your password in config or code** — only the saved browser context is used for automation. Add `outlook-playwright-state.json` to .gitignore.

## Config (appsettings.json)

Already added under **Outlook**:

- **WebUrl**: `https://outlook.office.com/mail/inbox` (or `https://outlook.live.com/mail/0/inbox` for personal).
- **StorageStatePath**: `outlook-playwright-state.json` (relative to config file directory).

**SourceFolder** comes from **FinalMovement.SourceFolder** — attachments are downloaded there so the next step (FinalMovement.ps1) can move them.

## How the wrapper uses it

1. Get effdate (MacroTest.exe --write-effdate) → writes `effdate.txt`.
2. **OutlookDownload.exe** — reads `effdate.txt`, opens Outlook with saved session, searches Inbox for the effdate string, opens each matching email, downloads all attachments to SourceFolder.
3. File movement (FinalMovement.ps1).
4. Full pipeline (MacroTest.exe).

The wrapper looks for `OutlookDownload.exe` in the MacroTest folder first, then in `..\OutlookDownload\bin\Debug\net9.0\`. To have it in MacroTest, build OutlookDownload and copy the contents of `OutlookDownload\bin\Debug\net9.0\` (including all DLLs and the `playwright.ps1` script) into the MacroTest folder, or add a post-build copy in your build process.

## Usage

- **Save login**: `OutlookDownload.exe --save-login [--config:path]`
- **Download** (used by wrapper): `OutlookDownload.exe [--config:path]`  
  Expects `effdate.txt` and `outlook-playwright-state.json` next to the config file (or in the folder of the config path).

If Outlook Web UI changes, the in-code selectors (search box, mail list, attachment links) may need to be updated.
