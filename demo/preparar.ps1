<#
.SYNOPSIS
  Arma (o desarma con -Limpiar) la escena de la demo de img: una carpeta con
  doce imágenes de prueba (WebP y GIF animados) y el img.exe de este repo.

.DESCRIPTION
  1. Compila img desde este repo a demo\.escena\bin\img.exe con la versión
     limpia (sin commit estampado): en la cabecera dice v1.0.0.
  2. Genera con ffmpeg, en demo\.escena\dev\galeria, las imágenes de la
     demo. Ninguna es una foto: son sintéticas, con parámetros fijos, y con
     la misma versión de ffmpeg salen iguales byte a byte en cada corrida.
       fractal-01..06.webp  el conjunto de Mandelbrot, acercándose, 1600x900
       degrade-01..04.webp  degradés con los cuatro colores de la paleta, 1920x1080
       cargando.gif         la señal de prueba de ffmpeg (testsrc2), animada
       automata.gif         un autómata celular (regla 110), animado
  3. Monta demo\.escena como una unidad con subst (la primera libre de X, Y,
     Z, W, V): en pantalla la carpeta es X:\dev\galeria y no la ruta real de
     quien graba.

  Imprime la carpeta de la galería. -Limpiar desmonta la unidad y borra
  demo\.escena (está en .gitignore).

  Requisitos: Go y ffmpeg (winget install Gyan.FFmpeg).

.EXAMPLE
  .\preparar.ps1            # arma la escena y dice dónde quedó
  .\preparar.ps1 -Limpiar   # la desarma
#>
[CmdletBinding()]
param(
    [switch] $Limpiar
)
$ErrorActionPreference = 'Stop'

$demo    = $PSScriptRoot
$repo    = Split-Path $demo -Parent
$escena  = Join-Path $demo '.escena'
$unidadF = Join-Path $escena 'unidad.txt'

function Stop-Escena {
    if (Test-Path -LiteralPath $unidadF) {
        $u = (Get-Content -LiteralPath $unidadF -Raw).Trim()
        if ($u) { subst.exe "${u}:" /d 2>$null | Out-Null }
    }
    if (Test-Path -LiteralPath $escena) { Remove-Item -LiteralPath $escena -Recurse -Force }
}

if ($Limpiar) {
    Stop-Escena
    Write-Host 'escena desarmada'
    exit 0
}

# Una escena vieja (una grabación cortada) se desarma antes.
Stop-Escena

foreach ($cmd in 'go', 'ffmpeg') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { Write-Host "falta $cmd en el PATH"; exit 1 }
}

# 1. img de este repo, con la versión limpia (sin +commit).
$bin = Join-Path $escena 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
Push-Location $repo
$cgoAntes = $env:CGO_ENABLED
try {
    $env:CGO_ENABLED = '0'
    go build -trimpath -ldflags '-s -w' -o (Join-Path $bin 'img.exe') .
    if ($LASTEXITCODE -ne 0) { throw 'no compiló img' }
} finally {
    $env:CGO_ENABLED = $cgoAntes
    Pop-Location
}

# 2. Las imágenes.
$galeria = Join-Path $escena 'dev\galeria'
New-Item -ItemType Directory -Path $galeria -Force | Out-Null
$paleta = 'split[a][b];[a]palettegen[p];[b][p]paletteuse'
$trabajos = @(
    @('-f', 'lavfi', '-i', 'mandelbrot=s=1600x900:rate=2:maxiter=1500:end_scale=0.02:end_pts=6', '-frames:v', '6', '-c:v', 'libwebp', '-q:v', '82', 'fractal-%02d.webp'),
    @('-f', 'lavfi', '-i', 'gradients=s=1920x1080:c0=0x8fd6cc:c1=0xc4b5fd:c2=0xf3b9d2:c3=0xeedfb8:n=4:x0=0:y0=0:x1=1919:y1=1079:seed=11:rate=1:speed=0.08', '-frames:v', '4', '-c:v', 'libwebp', '-q:v', '82', 'degrade-%02d.webp'),
    @('-f', 'lavfi', '-t', '2', '-i', 'testsrc2=s=320x240:rate=12', '-vf', $paleta, 'cargando.gif'),
    @('-f', 'lavfi', '-t', '2', '-i', 'cellauto=s=320x240:rate=12:rule=110:seed=2026', '-vf', $paleta, 'automata.gif')
)
Push-Location $galeria
try {
    foreach ($t in $trabajos) {
        ffmpeg -y -loglevel error @t
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg falló generando $($t[-1])" }
    }
} finally { Pop-Location }

# 3. La unidad.
$libres = 'X', 'Y', 'Z', 'W', 'V' | Where-Object { -not (Test-Path "${_}:\") }
if (-not $libres) { throw 'no hay una unidad libre entre X, Y, Z, W y V para montar la escena' }
$u = @($libres)[0]
subst.exe "${u}:" $escena
if ($LASTEXITCODE -ne 0) { throw "subst ${u}: no anduvo" }
Set-Content -LiteralPath $unidadF -Value $u -Encoding ascii
"${u}:\dev\galeria"
