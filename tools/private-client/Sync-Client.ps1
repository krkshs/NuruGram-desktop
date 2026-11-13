param([switch]$Watch, [int]$PollSeconds = 60)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$env:GIT_TERMINAL_PROMPT = '0'
$log = Join-Path $repo '.git\nurugram-sync.log'
. (Join-Path $PSScriptRoot 'Publish-Executable.ps1')
$releaseState = Join-Path $repo '.git\nurugram-release.json'
$mutexId = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($repo))).Substring(0,16)
$mutex = [Threading.Mutex]::new($false, ('Local\NuruGramGitSync-' + $mutexId))
function Invoke-Git {
    param([string[]]$GitArgs)
    $result = & git -C $repo -c credential.interactive=false @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join [Environment]::NewLine) }
    return $result
}
function Write-SyncLog([string]$Message) {
    ('{0:u} {1}' -f [DateTime]::UtcNow,$Message) | Add-Content -LiteralPath $log -Encoding utf8
}
function Publish-Client {
    if (!(Test-Path -LiteralPath (Join-Path $repo 'Telegram.exe'))) { throw 'Telegram.exe is missing.' }
    if ((Invoke-Git -GitArgs @('remote','get-url','origin')) -ne 'https://github.com/krkshs/NuruGram-desktop.git') { throw 'Unexpected Git remote.' }
    $branch = (Invoke-Git -GitArgs @('branch','--show-current')) -join ''
    if ($branch -ne 'dev') { throw 'Automatic publishing is only enabled on dev.' }
    $staged = Invoke-Git -GitArgs @('diff','--cached','--name-only')
    if ($staged) { Write-SyncLog 'Skipped: the Git index contains manually staged changes.'; return }
    $changes = Invoke-Git -GitArgs @('diff','--name-only','HEAD')
    $ahead = [int]((Invoke-Git -GitArgs @('rev-list','--count','origin/dev..HEAD')) -join '')
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $repo 'Telegram.exe.manifest.json') | ConvertFrom-Json
    $hash = (Get-FileHash -LiteralPath (Join-Path $repo 'Telegram.exe') -Algorithm SHA256).Hash
    if ($manifest.Endpoint -ne '31.77.17.214:443' -or $manifest.PatchedSha256 -ne $hash) {
        throw 'Client/manifest mismatch. Install the new version with Update-Client.ps1 first.'
    }
    $publishedHash = if (Test-Path -LiteralPath $releaseState) { (Get-Content -Raw -LiteralPath $releaseState | ConvertFrom-Json).Hash } else { '' }
    if (!$changes -and $ahead -eq 0 -and $publishedHash -eq $hash) { return }
    Invoke-Git -GitArgs @('fetch','origin','dev') | Out-Null
    & git -C $repo merge-base --is-ancestor origin/dev HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Remote dev has new commits. Integrate them locally before automatic publishing.' }
    if ($changes) {
        Invoke-Git -GitArgs @('add','--update','--','.') | Out-Null
        Invoke-Git -GitArgs @('commit','-m','Update NuruGram Desktop client.') | Out-Null
    }
    Invoke-Git -GitArgs @('push','origin','HEAD:dev') | Out-Null
    if ($publishedHash -ne $hash) {
        $commit = (Invoke-Git -GitArgs @('rev-parse','HEAD')) -join ''
        $url = Publish-Executable -Repo $repo -Hash $hash -Manifest $manifest -Commit $commit
        @{Hash=$hash; Url=$url} | ConvertTo-Json | Set-Content -LiteralPath $releaseState -Encoding utf8
        Write-SyncLog ('Published executable: ' + $url)
    }
    Write-SyncLog ('Published ' + ((Invoke-Git -GitArgs @('rev-parse','--short','HEAD')) -join ''))
}
try {
    if (!$mutex.WaitOne(0)) { exit 0 }
    do {
        try {
            if ($Watch) {
                $before = (Invoke-Git -GitArgs @('diff','--stat','HEAD')) -join [Environment]::NewLine
                $exe = Get-Item -LiteralPath (Join-Path $repo 'Telegram.exe')
                $stamp = $exe.LastWriteTimeUtc
                Start-Sleep -Seconds 15
                $after = (Invoke-Git -GitArgs @('diff','--stat','HEAD')) -join [Environment]::NewLine
                $newStamp = (Get-Item -LiteralPath $exe.FullName).LastWriteTimeUtc
                if ($before -ne $after -or $stamp -ne $newStamp) { continue }
            }
            Publish-Client
        } catch {
            Write-SyncLog $_.Exception.Message
            if (!$Watch) { throw }
        }
        if ($Watch) { Start-Sleep -Seconds $PollSeconds }
    } while ($Watch)
} finally {
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Dispose()
}
