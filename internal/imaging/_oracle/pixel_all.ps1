<#
.SYNOPSIS
  Las imágenes de prueba, convertidas por img y comparadas píxel a píxel con
  lo que decodifica Pillow (libwebp, giflib, libjpeg).

.DESCRIPTION
  Convierte a PNG, con el img.exe que se le pasa, los fixtures de
  scripts\fixtures.ps1 y compara cada salida con su origen usando
  pixel_check.py. Todo sin pérdida tiene que dar diferencia 0; la WebP con
  pérdida también (img replica la aritmética de libwebp). El JPEG se compara
  con tolerancia 1: dos decodificadores de JPEG no tienen por qué coincidir al
  bit (la norma no fija el redondeo de la IDCT). Al final, un control: la
  salida de la WebP sin pérdida contra el origen con pérdida tiene que dar
  diferencias; si no, el guion no estaría mirando nada.

  Requisitos: los fixtures (.\scripts\fixtures.ps1, con ffmpeg) y Python 3 con
  pip install -r internal/imaging/_oracle/requirements.txt.

.EXAMPLE
  .\scripts\fixtures.ps1 -Dir D:\fx\img
  .\build.ps1
  .\internal\imaging\_oracle\pixel_all.ps1 -Exe .\dist\img.exe -Fx D:\fx\img
#>
#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Exe,
    [string] $Fx = $(if ($env:IMG_FIXTURES) { $env:IMG_FIXTURES } else { Join-Path ([IO.Path]::GetTempPath()) 'img-fx' }),
    [string] $Work = (Join-Path ([IO.Path]::GetTempPath()) 'img-pixel')
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
$check = Join-Path $PSScriptRoot 'pixel_check.py'
$Exe = (Resolve-Path $Exe).Path
if (-not (Test-Path (Join-Path $Fx 'base.png'))) { throw "no hay fixtures en $($Fx): correr antes .\scripts\fixtures.ps1" }

$casos = [ordered]@{ # origen → tolerancia
    'lossless.webp' = 0
    'lossy.webp'    = 0
    'alpha.webp'    = 0
    'static.gif'    = 0
    'anim.gif'      = 0
    'b.bmp'         = 0
    'q.jpg'         = 1
}
if (Test-Path $Work) { Remove-Item -Recurse -Force $Work }
New-Item -ItemType Directory -Force $Work | Out-Null
$origenes = @($casos.Keys | ForEach-Object { Join-Path $Fx $_ })
& $Exe @origenes --out-dir $Work --no-color | Out-Null
if ($LASTEXITCODE -ne 0) { throw "img salió con $LASTEXITCODE" }

function Comparar([string] $origen, [int] $tolerancia, [string] $de = $origen) {
    $salida = Join-Path $Work ([IO.Path]::GetFileNameWithoutExtension($de) + '.png')
    $r = python $check (Join-Path $Fx $origen) $salida --tolerancia $tolerancia 2>&1
    [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Texto = (@($r) -join ' ').Trim() }
}

$ok = 0
foreach ($k in $casos.Keys) {
    $r = Comparar $k $casos[$k]
    if ($r.Ok) { $ok++ }
    Write-Host ("  {0,-14} {1}" -f $k, $r.Texto)
}
# El control: la conversión de la WebP sin pérdida contra el origen CON
# pérdida (el mismo degradé, comprimido) tiene que dar diferencias.
$control = Comparar 'lossy.webp' 0 'lossless.webp'
if (-not $control.Ok) { Write-Host '  ✓ control: contra otro origen da diferencias, como tiene que ser' }
else { Write-Host '  ✗ control: contra otro origen dio igual; el guion no está comparando' }

Write-Host ''
Write-Host "  $ok de $($casos.Count) conversiones como las decodifica Pillow (al bit; el JPEG, a 1 nivel)"
if ($ok -ne $casos.Count -or $control.Ok) { exit 1 }
exit 0
