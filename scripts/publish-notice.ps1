$ErrorActionPreference = 'Stop'
$meta = Get-Content release.json -Raw | ConvertFrom-Json
$repo = $env:CHANNEL_REPOSITORY
if (!$repo -or $repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Repositório inválido.' }
$releaseText = gh api ("repos/$repo/releases/tags/v" + $meta.version)
if ($LASTEXITCODE) { throw 'A Release ainda não está publicada.' }
$release = $releaseText | ConvertFrom-Json
if ($release.draft -or $release.prerelease) { throw 'O aviso exige uma versão estável publicada.' }
$asset = @($release.assets | Where-Object { $_.name -eq $meta.asset })
if ($asset.Count -ne 1) { throw 'O executável oficial não foi encontrado.' }
$published = @{
    version = $meta.version
    notes = $release.body
    downloadUrl = $asset[0].browser_download_url
    sha256 = $meta.sha256
    publishedAt = $release.published_at
}
$publishedJson = $published | ConvertTo-Json -Depth 6
$body = @{
    message = 'Atualizar aviso público para ' + $meta.version
    content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($publishedJson))
    branch = 'main'
}
$existingText = gh api ("repos/$repo/contents/published.json") 2>$null
if ($LASTEXITCODE -eq 0) { $body.sha = ($existingText | ConvertFrom-Json).sha }
$requestFile = Join-Path $env:RUNNER_TEMP 'elite-published-notice.json'
[IO.File]::WriteAllText($requestFile, ($body | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
gh api ("repos/$repo/contents/published.json") --method PUT --input $requestFile --silent
if ($LASTEXITCODE) { throw 'Não foi possível publicar o aviso de atualização.' }
Write-Output ('Aviso público atualizado para ' + $meta.version)
