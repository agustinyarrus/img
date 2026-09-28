<#
.SYNOPSIS
  Genera las imágenes de prueba de img (las que leen los tests de internal/imaging).

.DESCRIPTION
  Los tests de internal/imaging leen la carpeta de $env:IMG_FIXTURES o, si no
  está definida, %TEMP%\img-fx. Si no existe, esos tests se saltean sin fallar;
  este script la llena con ffmpeg:
    base.png       degradé de 320x200, el origen de casi todo lo demás
    lossless.webp  webp sin pérdida        lossy.webp  webp con pérdida (q 80)
    alpha.png      teal al 50 % de alfa     alpha.webp  lo mismo en webp
    static.gif     gif de un cuadro         anim.gif    gif animado de 8 cuadros
    q.jpg, b.bmp   jpg y bmp del mismo origen

  Requisito: ffmpeg (winget install Gyan.FFmpeg).

.EXAMPLE
  .\scriptsixtures.ps1                  # a %TEMP%\img-fx
  .\scriptsixtures.ps1 -Dir D:x\img   # a otra carpeta; los tests la leen con:
  $env:IMG_FIXTURES = 'D:x\img'; go test ./internal/imaging/
#>
[CmdletBinding()]
param([string] $Dir)
$ErrorActionPreference = 'Stop'

$e = [char]27
function Ok([string] $s) { Write-Host "  $e[38;2;181;223;168m✓$e[0m $s" }
function Fail([string] $s) { Write-Host "  $e[38;2;242;167;184m✗$e[0m $s"; exit 1 }

if (-not $Dir) {
    $Dir = if ($env:IMG_FIXTURES) { $env:IMG_FIXTURES } else { Join-Path ([IO.Path]::GetTempPath()) 'img-fx' }
}
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { Fail 'falta ffmpeg (winget install Gyan.FFmpeg)' }

New-Item -ItemType Directory -Force $Dir | Out-Null
Push-Location $Dir
try {
    $jobs = @(
        @('-f', 'lavfi', '-i', 'gradients=s=320x200:c0=0x8fd6cc:c1=0xc4b5fd:d=1', '-frames:v', '1', 'base.png'),
        @('-i', 'base.png', '-c:v', 'libwebp', '-lossless', '1', 'lossless.webp'),
        @('-i', 'base.png', '-c:v', 'libwebp', '-q:v', '80', 'lossy.webp'),
        @('-f', 'lavfi', '-i', 'color=c=0x8fd6cc@0.5:s=160x120,format=rgba', '-frames:v', '1', 'alpha.png'),
        @('-i', 'alpha.png', '-c:v', 'libwebp', '-lossless', '1', 'alpha.webp'),
        @('-i', 'base.png', '-frames:v', '1', 'static.gif'),
        @('-f', 'lavfi', '-i', 'testsrc=s=120x120:d=1:r=8', 'anim.gif'),
        @('-i', 'base.png', 'q.jpg'),
        @('-i', 'base.png', 'b.bmp')
    )
    foreach ($j in $jobs) {
        ffmpeg -y -loglevel error @j
        if ($LASTEXITCODE -ne 0) { Fail "ffmpeg falló generando $($j[-1])" }
    }
} finally { Pop-Location }
Ok "imágenes en $Dir ($((Get-ChildItem $Dir).Count) archivos)"
if ($Dir -ne (Join-Path ([IO.Path]::GetTempPath()) 'img-fx') -and $env:IMG_FIXTURES -ne $Dir) {
    Write-Host "  para los tests: `$env:IMG_FIXTURES = '$Dir'"
}
