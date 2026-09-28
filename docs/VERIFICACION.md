# Verificación

La regla: img se contrasta con algo **independiente**. Un decodificador que lee lo que escribió su propio codificador no prueba nada; Pillow (libwebp, libjpeg, giflib…) sí.

## Tests de Go

```powershell
go test ./...
.\build.ps1 -Test     # go vet + go test y después compila
```

54 tests en `cli`, `fsx`, `textdist`, `tui`, `win/desk` e `imaging`. Cinco de `imaging` leen imágenes reales generadas con ffmpeg (formato y dimensiones por contenido, los 8 cuadros de un GIF animado compuestos a tamaño completo, ida y vuelta por PNG y GIF). Buscan la carpeta de `$env:IMG_FIXTURES` o, si no está definida, `%TEMP%\img-fx`; si no existe, se saltean sin fallar. Para generarla:

```powershell
.\scripts\fixtures.ps1                    # necesita ffmpeg (winget install Gyan.FFmpeg)
.\scripts\fixtures.ps1 -Dir D:\fx\img     # en otra carpeta; después $env:IMG_FIXTURES = 'D:\fx\img'
```

Hay también un test de dependencias: `go list -deps` sobre `tui` y el exe no puede traer `net`, `net/netip` ni `os/exec`.

## Oráculos

Requisitos: Python 3 con `pip install pillow numpy`.

### Píxel a píxel contra Pillow

```powershell
python internal\imaging\_oracle\pixel_check.py origen.webp convertida.png [--tolerancia N]
```

Compara la salida de img contra el origen decodificado por Pillow, en RGB y en alfa.

| Origen | Resultado |
|---|---|
| WebP sin pérdida | diferencia 0 en RGB y alfa |
| WebP con alfa | diferencia 0 |
| GIF | diferencia 0 |
| WebP con pérdida | diferencia 0 |

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

## Corrida del 28/09/2026, ya como proyecto propio

Con el `dist\img.exe` que compila este repo (1.0.0), en Windows 11 con Go 1.26.4:

| Qué | Resultado |
|---|---|
| `gofmt -l .`, `go vet ./...` | limpios |
| `go test ./...` | 54 tests: 49 pasan, 5 se saltean (la máquina no tenía ffmpeg para generar los fixtures) |
| `webp_stress.py` | 18 de 18 idénticos a libwebp |
| `pixel_check.py` sobre una WebP sin pérdida de 131×97 con ruido, una WebP con alfa de 80×64 con ruido y un GIF de paleta, generados con Pillow | diferencia 0 en los tres |
