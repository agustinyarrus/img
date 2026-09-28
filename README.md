# img

Convierte imágenes entre formatos, en lote, desde la consola de Windows. Un único `img.exe` portable escrito en Go puro: sin instalador, sin dependencias en tiempo de ejecución, sin nube. Las imágenes no salen de la máquina.

```powershell
img *.webp                           # cada .webp a .png, al lado del original
img fotos\ -r --to jpg -q 82         # una carpeta entera, con subcarpetas
img loader.gif --frames              # un gif animado → loader-001.png, loader-002.png…
img logo.webp --to jpg -b '#0b0b0f'  # aplanar la transparencia sobre un fondo oscuro
```

Convierte en paralelo, con una barra de progreso viva y una tarjeta de resumen al final (cuántas se convirtieron, el tamaño final y cuánto cambió el peso). Si la salida no es una consola, escribe texto plano sin un solo escape de color.

## Qué hace

- **Lee** webp (con y sin pérdida, con alfa), gif (estático y animado), png, jpg, bmp y tiff. **Escribe** png, jpg, gif, bmp y tiff (webp no tiene codificador en Go puro).
- **Reconoce el formato por el contenido**, no por la extensión: un `.png` que en realidad es webp se convierte igual.
- **Colores de WebP idénticos a libwebp.** Las webp con pérdida se pasan a RGB con la misma aritmética que libwebp (el decodificador de Chrome): BT.601 en rango limitado y el sobremuestreo de croma 9-3-3-1. Los colores salen idénticos al bit, no "parecidos".
- **GIF animados bien compuestos**: cada cuadro se reconstruye respetando el método de disposición del anterior, así `--frames` exporta cuadros completos y no los recortes parciales que guarda el archivo.
- **Alfa**: se conserva hacia png y se aplana sobre `--background` hacia jpg y bmp.
- **No pisa nada**: nunca borra el original ni sobrescribe sin `--force`, y detecta cuando dos entradas caerían en la misma salida (`foto.webp` y `foto.gif` → `foto.png`). La escritura es atómica: un corte o un Ctrl+C no deja archivos a medias.
- **Patrones propios**: ni cmd ni PowerShell expanden comodines para un exe nativo, así que img entiende `*`, `?`, `[]` y `**` (sin distinguir mayúsculas, como Windows) y ordena en orden natural (`pag2` antes que `pag10`). Si un archivo no existe, sugiere el más parecido.

## Instalación

Con [Go](https://go.dev/dl) 1.24 o más nuevo (el `go.mod` pide 1.26 y Go descarga sola esa versión la primera vez):

```powershell
go install github.com/agustinyarrus/img@latest
```

O desde el código, con la versión y el commit estampados en el exe:

```powershell
git clone https://github.com/agustinyarrus/img
cd img
.\build.ps1          # compila a dist\img.exe
.\build.ps1 -Test    # antes corre go vet y todos los tests
```

El único módulo externo es `golang.org/x/image` (webp, bmp y tiff); todo lo demás es la biblioteca estándar.

## Uso

`img --help` (salida real, sin colores):

```
  img  ·  convierte imágenes entre formatos, en lote                                         1.0.0

  uso
    img <archivos|carpetas|patrones…> [opciones]
    img *.webp                 cada .webp a .png, al lado del original
    img foto.gif --to jpg      un gif a jpg (primer cuadro)

  qué producir
        --to png|jpg|gif|bmp|tiff   formato de salida (png)
    -q, --quality N                 calidad JPEG 1–100 (90)
        --frames                    de un animado, exportar cada cuadro a un archivo
    -b, --background COLOR          fondo al aplanar transparencia hacia JPEG/BMP (blanco)
        --fast                      PNG con compresión rápida en vez de la máxima

  de dónde y a dónde
    -o, --out-dir DIR               carpeta de salida (por defecto, junto al original)
    -r, --recursive                 entrar en subcarpetas al pasar una carpeta
    -f, --force                     sobrescribir si el destino ya existe
    -j, --jobs N                    cuántas conversiones en paralelo (0 = una por CPU) (0)

  general
    -h, --help                      muestra esta ayuda
    -V, --version                   muestra la versión
        --no-color                  salida sin colores (también respeta NO_COLOR)
```

Flags al estilo GNU (`-q 82`, `--quality=82`, `-rf`, `--`); un flag mal escrito sugiere el más parecido ("¿quisiste decir --force?"). `--background` acepta `#rgb`, `#rrggbb`, `#rrggbbaa`, `blanco`, `negro` y `transparente`.

Códigos de salida: `0` todo bien · `1` algunas imágenes fallaron · `2` línea de comandos inválida · `3` no se pudo hacer nada · `130` cancelado con Ctrl+C.

## Cómo se verifica

img no se contrasta consigo misma sino con un decodificador independiente: Pillow (que usa libwebp, libjpeg y compañía), píxel a píxel.

| Origen | Oráculo | Resultado |
|---|---|---|
| WebP sin pérdida, WebP con alfa, GIF | `pixel_check.py` (Pillow) | diferencia 0 en RGB y alfa |
| WebP con pérdida | `webp_stress.py`: 18 casos de 1×1 a 333×201, ruido de color puro, con y sin alfa | 18 de 18 idénticos al bit a libwebp |

Además hay 54 tests de Go (`go test ./...`); cinco leen imágenes de prueba que genera `scripts\fixtures.ps1` con ffmpeg y, si no están, se saltean sin fallar. El detalle y cómo correr cada oráculo: [docs/VERIFICACION.md](docs/VERIFICACION.md).

## Cómo está hecho

```
main.go              el punto de entrada: abre la consola, llama a img.Main y sale con su código
internal/
  img/               la herramienta: flags, plan de salidas (colisiones), tanda y tarjeta final
  imaging/           decodificar (formato por contenido), componer GIF, color de WebP, codificar
    _oracle/         pixel_check.py y webp_stress.py, contra Pillow
  batch/             tareas en paralelo con barra viva y resultados en orden
  fsx/               patrones con **, orden natural, escritura atómica
  cli/               flags estilo GNU, ayuda, sugerencias por distancia de edición
  tui/               consola: paleta, progreso vivo, tarjetas, formato es-AR
  textdist/          distancia de Damerau–Levenshtein
  win/desk/          modo y tamaño de la consola por syscall
  version/           versión y commit, estampados por build.ps1
scripts/fixtures.ps1 imágenes de prueba para los tests
```

La arquitectura, las decisiones de diseño y los detalles de cada paquete: [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md). Lo que falta: [docs/PENDIENTE.md](docs/PENDIENTE.md).

## Origen

img nació dentro de navaja, una suite de herramientas de consola para Windows que compartían un núcleo (la consola, los flags, los patrones de archivos). Desde la 1.0.0 es un proyecto propio: se llevó ese núcleo y la historia de git de sus archivos.

## Licencia

[MIT](LICENSE).
