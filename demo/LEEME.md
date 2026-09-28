# La demo de img

`demo.gif` y `demo.webm` son una grabación de verdad, no un mockup: una terminal de 100×30 corre img
compilado desde este repo sobre una carpeta con doce imágenes de prueba. Lo que se ve es la salida
real de esa corrida: la barra mientras convierte, cada archivo cuando termina y la tarjeta al final.

| Momento | Qué se ve |
|---|---|
| 0 a 2,6 s | se escribe `img *.webp *.gif -o png`: todas las WebP y los GIF de la carpeta, a PNG en `png\` |
| 2,7 a 4,9 s | las doce conversiones en paralelo: la barra con el conteo, los archivos en curso debajo, y cada uno arriba cuando termina (en el orden en que terminan) |
| 5 s al final | la tarjeta: convertidas, tamaño final, cambio de peso y tiempo |

El peso sube: una WebP con pérdida ocupa mucho menos que el mismo dibujo en PNG sin pérdida, y la
tarjeta lo dice tal cual (`+473 %`). Los dos GIF bajan porque img guarda el primer cuadro (con
`--frames`, los guardaría todos).

## Qué hay acá

| Archivo | Para qué |
|---|---|
| `demo.tape` | el guion de [VHS](https://github.com/charmbracelet/vhs): arma la escena fuera de cámara, graba y la desarma |
| `preparar.ps1` | arma la escena (o la desarma con `-Limpiar`): compila img y genera las imágenes |
| `demo.gif` · `demo.webm` | la grabación: 8 s a 25 cuadros por segundo, 1078×644, 320 KB y 144 KB |
| `demo.png` | el último cuadro, con la tarjeta (para quien pide menos movimiento) |

## Las imágenes

Ninguna es una foto. `preparar.ps1` las genera con fuentes sintéticas de ffmpeg y parámetros fijos:
con la misma versión de ffmpeg salen iguales byte a byte en cada corrida.

| Archivos | Qué son |
|---|---|
| `fractal-01.webp` … `fractal-06.webp` | el conjunto de Mandelbrot acercándose (`mandelbrot`), 1600×900, WebP con pérdida |
| `degrade-01.webp` … `degrade-04.webp` | degradés con los cuatro colores de la paleta de img (`gradients`), 1920×1080 |
| `cargando.gif` | la señal de prueba animada de ffmpeg (`testsrc2`), 320×240, 24 cuadros |
| `automata.gif` | un autómata celular, la regla 110 (`cellauto`), 320×240, 24 cuadros |

El tamaño está elegido para que la conversión dure un par de segundos y la barra se vea: en la PC
donde se grabó, 16 hilos, img tardó 2,2 s.

## Regrabar con VHS

Hace falta Windows, PowerShell 7, Go y ffmpeg, y además:

```powershell
winget install --scope user charmbracelet.vhs tsl0922.ttyd Gyan.FFmpeg
```

**Ojo con la versión de VHS.** La 0.12.0 (la de winget al 28/9/2026) graba los cuadros pero no
genera ni el GIF ni el WebM, sin dar error: cancela el contexto de la grabación y se lo pasa a
ffmpeg. Está arreglado en la 0.12.1:

```powershell
go install github.com/charmbracelet/vhs@v0.12.1     # pide Go 1.26.7+; Go baja solo esa versión
```

VHS dibuja la terminal en un Chrome o Edge sin ventana: usa el que esté instalado, no baja
Chromium. Después, desde esta carpeta:

```powershell
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue     # si tu entorno lo define, la demo sale sin color
vhs demo.tape                                             # demo.gif y demo.webm
ffmpeg -y -sseof -0.5 -i demo.gif -frames:v 1 -vf "split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none" demo.png
```

Tarda medio minuto. Mirá siempre el resultado antes de publicarlo: cuadros sueltos con
`ffmpeg -ss 3.4 -i demo.gif -frames:v 1 cuadro.png`.

### Qué hace la escena, y por qué

- **Nada de tu máquina en pantalla.** Las imágenes son sintéticas y la carpeta es `X:\dev\galeria`,
  no tu ruta: `preparar.ps1` genera todo en `demo\.escena\dev\galeria` y monta `demo\.escena` como
  unidad con `subst` (la primera libre de X, Y, Z, W, V). img muestra los nombres tal como se los
  pasaron, relativos a la carpeta. `-Limpiar` desmonta la unidad y borra `.escena` (está en
  `.gitignore`).
- **img de este repo.** `preparar.ps1` lo compila sin commit estampado: en la cabecera dice
  `v1.0.0`, no `v1.0.0+abc1234`.
- **El prompt es `>` y nada más**, sin sugerencias del historial (serían las de quien graba), con
  los colores de la línea de comandos en la paleta de img. El tape los fija fuera de cámara.
- **La espera es la de verdad.** El tape no duerme un tiempo fijo después del Enter: espera a que la
  tarjeta diga `Tiempo` y recién ahí cuenta los 3 s de lectura.

### Estilo

El de las demás demos de la familia: fondo `#0b0b0f`, texto `#cdd6f4` y los acentos de
`internal/tui/color.go` como colores ANSI del tema; Cascadia Mono 16; 1078×644 px, que con 24 px de
margen dan 100×30. Tipeo de 80 a 90 ms por tecla. 25 cuadros por segundo: a 50, el navegador no
llega a capturar cada cuadro a tiempo y el video sale acelerado.

## Sin VHS

La misma sesión se puede grabar a mano: una terminal de 100×30 con fondo `#0b0b0f` y Cascadia Mono
(`wt --size 100,30 pwsh -NoProfile`), `Set-Location (.\preparar.ps1)` para armar la escena y
entrar, `img *.webp *.gif -o png` y un grabador de pantalla como
[ScreenToGif](https://www.screentogif.com). Al terminar, `.\preparar.ps1 -Limpiar` desde esta
carpeta.

## Desarmar a mano

Si una grabación se cortó y quedó la unidad `X:`:

```powershell
.\preparar.ps1 -Limpiar
```
