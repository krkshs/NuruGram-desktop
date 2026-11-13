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
        $localFile = Join-Path $Repo $fileName
        $expectedSize = (Get-Item -LiteralPath $localFile).Length
        $existing = $release.assets | Where-Object name -EQ $fileName
        if ($existing -and ($existing.state -ne 'uploaded' -or $existing.size -ne $expectedSize)) {
            Invoke-RestMethod -Method Delete -Uri ($api + '/releases/assets/' + $existing.id) -Headers $headers | Out-Null
            $existing = $null
        }
        if (!$existing) {
            $upload = ($release.upload_url -replace '\{\?name,label\}$','') + '?name=' + [Uri]::EscapeDataString($fileName)
            $responseFile = Join-Path $Repo ('.git/release-upload-' + $fileName + '.json')
            $curlConfig = 'header = "Authorization: Bearer ' + $credential.password + '"' + [Environment]::NewLine + 'header = "Content-Type: application/octet-stream"' + [Environment]::NewLine + 'header = "Expect:"'
            $curlConfig | & curl.exe --config - --http1.1 --fail-with-body --request POST --data-binary ('@' + $localFile) --url $upload --output $responseFile --silent --show-error --connect-timeout 30 --max-time 600
            if ($LASTEXITCODE -ne 0) { throw ('GitHub asset upload failed: curl exit ' + $LASTEXITCODE) }
            $asset = Get-Content -Raw -LiteralPath $responseFile | ConvertFrom-Json
            if ($asset.state -ne 'uploaded' -or $asset.size -ne $expectedSize) { throw 'GitHub returned an incomplete asset.' }
            if ($fileName -eq 'Telegram.exe' -and $asset.digest -and $asset.digest -ne ('sha256:' + $Hash.ToLowerInvariant())) { throw 'GitHub asset digest differs from the local client.' }
        }
    }
    return $release.html_url
}
