param([Parameter(Mandatory)][string]$OriginalExe)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$original = (Resolve-Path -LiteralPath $OriginalExe).Path
if ($original -eq (Join-Path $repo 'Telegram.exe')) { throw 'Choose an unmodified official Telegram.exe in a separate directory.' }
$tempDir = Join-Path $repo '.git\client-update'
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$tempExe = Join-Path $tempDir 'Telegram.exe'
& dotnet run --project (Join-Path $PSScriptRoot 'ClientSetup') -c Release -- $original (Join-Path $PSScriptRoot 'server-public.pem') $tempExe '31.77.17.214'
if ($LASTEXITCODE -ne 0) { throw 'Client preparation failed. The installed client was not changed.' }
$backupDir = Join-Path $repo '.git\client-backups'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backup = Join-Path $backupDir ('Telegram-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '.exe')
$exe = Join-Path $repo 'Telegram.exe'
try {
    [IO.File]::Move($exe,$backup)
} catch { throw 'Close this portable NuruGram client and run Update-Client.ps1 again; Telegram.exe is locked.' }
try {
    [IO.File]::Move($tempExe,$exe)
    [IO.File]::Copy(($tempExe + '.manifest.json'),($exe + '.manifest.json'),$true)
} catch {
    if (!(Test-Path -LiteralPath $exe)) { [IO.File]::Move($backup,$exe) }
    throw
}
$marker = Join-Path $repo 'externalupdater.d'
New-Item -ItemType Directory -Path $marker -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $marker 'nurugram'), ($exe.Replace('\','/') + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'Sync-Client.ps1')
Write-Host 'Installed and published the private client. Restart NuruGram to use the new executable.'
