$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$port = 4173
$url = "http://localhost:$port"

$needsBuild = $false
if (-not (Test-Path "dist\index.html")) {
    $needsBuild = $true
} else {
    $distTime = (Get-Item "dist\index.html").LastWriteTimeUtc
    $sources = Get-ChildItem -Path "src", "index.html", "vite.config.js", "public" -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $sources) {
        if ($f.LastWriteTimeUtc -gt $distTime) { $needsBuild = $true; break }
    }
}

if ($needsBuild) {
    Write-Host "Building app..."
    npm run build | Out-Null
}

$running = $false
try {
    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect("127.0.0.1", $port)
    $running = $true
    $client.Close()
} catch { }

if (-not $running) {
    Write-Host "Starting server..."
    Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c", "npm run preview -- --port $port --strictPort >nul 2>&1" `
        -WorkingDirectory $root `
        -WindowStyle Hidden

    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $client.Connect("127.0.0.1", $port)
            $running = $true
            $client.Close()
            break
        } catch { }
    }
}

if (-not $running) {
    msg * "Margin failed to start. Run 'npm run build; npm run preview' in the project folder for details."
    exit 1
}

$edgeCandidates = @(
    "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
$browser = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($browser) {
    Start-Process -FilePath $browser -ArgumentList "--app=$url"
} else {
    Start-Process $url
}
