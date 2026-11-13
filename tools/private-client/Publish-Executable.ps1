function Publish-Executable([string]$Repo, [string]$Hash, [object]$Manifest, [string]$Commit) {
    $env:GIT_TERMINAL_PROMPT = '0'
    $query = 'protocol=https' + [Environment]::NewLine + 'host=github.com' + [Environment]::NewLine + [Environment]::NewLine
    $credentialLines = $query | & git -c credential.interactive=false credential fill 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub HTTPS credential unavailable.' }
    $credential = @{}
    foreach ($line in $credentialLines) {
        $pair = $line -split '=',2
        if ($pair.Length -eq 2) { $credential[$pair[0]] = $pair[1] }
    }
    $headers = @{ Authorization=('Bearer ' + $credential.password); 'User-Agent'='NuruGram-GitSync'; Accept='application/vnd.github+json' }
    $api = 'https://api.github.com/repos/krkshs/NuruGram-desktop'
    $version = ($Manifest.Client -replace '^Official Telegram Desktop ','') -replace '[^0-9.]',''
    $tag = 'nurugram-' + $version + '-' + $Hash.Substring(0,12).ToLowerInvariant()
    try { $release = Invoke-RestMethod -Uri ($api + '/releases/tags/' + $tag) -Headers $headers }
    catch {
        if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
        $body = @{ tag_name=$tag; target_commitish=$Commit; name=('NuruGram Desktop ' + $version); body=('Windows portable private client for ' + $Manifest.Endpoint + '. SHA-256: ' + $Hash); draft=$false; prerelease=$false } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri ($api + '/releases') -Headers $headers -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    }
    foreach ($fileName in @('Telegram.exe','Telegram.exe.manifest.json')) {
        if (!($release.assets | Where-Object name -EQ $fileName)) {
            $upload = ($release.upload_url -replace '\{\?name,label\}$','') + '?name=' + [Uri]::EscapeDataString($fileName)
            Invoke-RestMethod -Method Post -Uri $upload -Headers $headers -ContentType 'application/octet-stream' -InFile (Join-Path $Repo $fileName) | Out-Null
        }
    }
    return $release.html_url
}
