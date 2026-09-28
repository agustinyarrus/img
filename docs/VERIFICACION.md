# Verificación

La regla: img se contrasta con algo **independiente**. Un decodificador que lee lo que escribió su propio codificador no prueba nada; Pillow (libwebp para las WebP, libjpeg para los JPEG, su propio lector para los GIF) sí.

## Tests de Go

```powershell
go test ./...
.\build.ps1 -Test     # go vet + go test y después compila
```

57 tests en `cli`, `fsx`, `textdist`, `tui`, `win/desk`, `imaging` e `img` (el encabezado dice la extensión que se escribe). Cinco de `imaging` leen imágenes reales generadas con ffmpeg (formato y dimensiones por contenido, los 8 cuadros de un GIF animado compuestos a tamaño completo, ida y vuelta por PNG y GIF). Buscan la carpeta de `$env:IMG_FIXTURES` o, si no está definida, `%TEMP%\img-fx`; si no existe, se saltean sin fallar. Para generarla:

```powershell
.\scripts\fixtures.ps1                    # necesita ffmpeg (winget install Gyan.FFmpeg)
.\scripts\fixtures.ps1 -Dir D:\fx\img     # en otra carpeta; después $env:IMG_FIXTURES = 'D:\fx\img'
```

Hay también un test de dependencias: `go list -deps` sobre `tui` y el exe no puede traer `net`, `net/netip` ni `os/exec`.

## Oráculos

Requisitos: Python 3 con `pip install -r internal/imaging/_oracle/requirements.txt` (numpy y Pillow, en las versiones con que se verificó).

### Píxel a píxel contra Pillow

```powershell
python internal\imaging\_oracle\pixel_check.py origen.webp convertida.png [--tolerancia N]
```

Compara la salida de img contra el origen decodificado por Pillow, en RGB y en alfa. Para las imágenes de prueba de `scripts\fixtures.ps1` hay un guion que hace todo:

```powershell
.\internal\imaging\_oracle\pixel_all.ps1 -Exe dist\img.exe [-Fx carpeta] [-Work carpeta]
```

Convierte a PNG la WebP sin pérdida, la WebP con pérdida, la WebP con alfa, el GIF estático, el animado, el BMP y el JPEG, y compara cada uno con su origen. Termina con un control: la salida de la WebP sin pérdida contra el origen *con* pérdida (el mismo degradé comprimido) tiene que dar diferencias; si no, el guion no estaría mirando nada.

| Origen | Resultado |
|---|---|
| WebP sin pérdida | diferencia 0 en RGB y alfa |
| WebP con alfa | diferencia 0 |
| GIF | diferencia 0 |
| WebP con pérdida | diferencia 0 |
| GIF animado (el primer cuadro), BMP | diferencia 0 |
| JPEG | a lo sumo 1 nivel: dos decodificadores de JPEG no tienen por qué coincidir al bit (la norma no fija el redondeo de la IDCT) |

### Estrés de las WebP con pérdida

```powershell
python internal\imaging\_oracle\webp_stress.py dist\img.exe <carpeta de trabajo>
```

Genera 18 casos con Pillow, los convierte con img y compara contra lo que decodifica libwebp:

- tamaños mínimos e impares, de 1×1 a 333×201, que es donde se complican los bordes del sobremuestreo;
- ruido de color puro, donde el croma cambia en cada píxel;
- los mismos casos con alfa;
- bloques de color de 320×240 y 161×99.

Resultado: 18 de 18 idénticos al bit.

**Lección:** las WebP con pérdida llegaron a diferir hasta 20 niveles en todos los píxeles. `x/image/webp` entrega YCbCr y la conversión de Go lo trataba como un JPEG: rango completo y el croma del píxel más cercano. VP8 usa BT.601 en rango limitado, y libwebp interpola el croma con un filtro 9-3-3-1. `webpcolor.go` replica esa aritmética.

### También se verificó

- el aplanado del alfa sobre un fondo (teal al 50 % sobre `#0b0b0f` da `(77, 112, 108)`, la cuenta exacta);
- los 8 cuadros de un GIF animado salen compuestos a tamaño completo;
- una tanda de 60 archivos en paralelo.

## En la CI

Cada push corre [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) en `windows-latest`, con el Go mínimo del `go.mod` (1.26.0):

1. `gofmt`, `go mod tidy -diff`, `go mod verify` y `go vet ./...`, también con `GOOS=linux`.
2. ffmpeg (el paquete de Chocolatey, el build "essentials" de gyan.dev, que trae libwebp) y las imágenes de prueba con `scripts\fixtures.ps1`.
3. `go test` con todas las pruebas, sin salteadas; [`.github/pruebas.ps1`](../.github/pruebas.ps1) deja en la página de la corrida cuántas pasaron y, si alguna se salteó, por qué.
4. `build.ps1`, y el `.exe` tiene que decir su versión y su commit (en una etiqueta, además, que la etiqueta y el código digan la misma versión).
5. Con ese `.exe`, los dos oráculos: `webp_stress.py` y `pixel_all.ps1`, con Python 3.12 y los paquetes de [`requirements.txt`](../internal/imaging/_oracle/requirements.txt).
6. `SHA256SUMS`, y el `.exe` con su hash queda como artefacto de la corrida.

La CI no corrió todavía en GitHub (el repo no se publicó). Se validó con [actionlint](https://github.com/rhysd/actionlint) y se simuló en la PC de desarrollo: un clon limpio, Go 1.26.0, cachés vacías, un Python 3.12 recién creado y los pasos `run:` del workflow con el mismo envoltorio de PowerShell que usa el runner. Todos en verde (el paso de Chocolatey no, que en la PC ya había ffmpeg).

## Corrida del 28/09/2026, ya como proyecto propio

Con el `img.exe` que compila este repo (1.0.0), en Windows 11 con Go 1.27.1, ffmpeg 9.0.2 y Python 3.12 con los paquetes de `requirements.txt`:

| Qué | Resultado |
|---|---|
| `gofmt -l .`, `go vet ./...` (Windows y Linux) | limpios |
| `go test ./...` con las imágenes de prueba | 57 de 57, ninguna salteada |
| `webp_stress.py` | 18 de 18 idénticos a libwebp |
| `pixel_all.ps1` sobre las imágenes de prueba | 7 de 7: seis iguales al bit, el JPEG a 1 nivel; el control con el origen equivocado da diferencias |
| la CI simulada con Go 1.26.0 | todos los pasos en verde |

Antes, cuando img vivía en la suite, `pixel_check.py` también se corrió a mano sobre una WebP sin pérdida de 131×97 con ruido, una WebP con alfa de 80×64 con ruido y un GIF de paleta, generados con Pillow: diferencia 0 en los tres.
