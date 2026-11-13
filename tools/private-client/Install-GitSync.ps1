$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sync = Join-Path $PSScriptRoot 'Sync-Client.ps1'
$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$taskName = 'NuruGram Desktop Git Sync'
$argsText = '-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $sync + '" -Watch'
$action = New-ScheduledTaskAction -Execute $pwsh -Argument $argsText -WorkingDirectory $repo
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Publish verified NuruGram client and tracked source changes to krkshs/NuruGram-desktop dev.' -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
$marker = Join-Path $repo 'externalupdater.d'
New-Item -ItemType Directory -Path $marker -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $marker 'nurugram'), ((Join-Path $repo 'Telegram.exe').Replace('\','/') + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Write-Host ('Installed ' + $taskName + '. Sync log: ' + (Join-Path $repo '.git\nurugram-sync.log'))
