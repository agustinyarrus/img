# img 1.0.0

La primera versión de img como proyecto propio. Antes vivía en navaja, la suite de herramientas de consola para Windows; el código es el que se probó ahí (más tres cambios de presentación, cada uno con su prueba: la cabecera dice la versión con su `v`; un error que no entra en la ventana se parte en palabras en vez de cortarse donde cae; y el encabezado de una tanda dice la extensión que se escribe, `.jpg`, donde decía `.jpeg`), ahora con su repo, su número de versión, su CI y su demo.

img es para cuando tenés una carpeta de `.webp` que ningún programa quiere abrir, un GIF animado del que necesitás los cuadros o fotos que tienen que ser `.jpg` para un formulario. Convierte en lote desde la consola, en paralelo, sin subir nada a ningún lado.

## Qué trae

**Convertir en lote.** `img *.webp` pasa cada `.webp` a `.png` al lado del original; `img fotos\ -r --to jpg -q 82` recorre una carpeta con sus subcarpetas. Lee webp (con y sin pérdida, con alfa), gif (estático y animado), png, jpg, bmp y tiff; escribe png, jpg, gif, bmp y tiff. Una barra viva mientras trabaja y una tarjeta al final con cuántas convirtió, el tamaño final y cuánto cambió el peso.

**El formato, por el contenido.** Un `.png` que en realidad es una WebP se convierte igual: img mira los primeros bytes, no la extensión.

**Colores de WebP idénticos a libwebp.** Las WebP con pérdida se pasan a RGB con la misma aritmética que libwebp, el decodificador de Chrome: BT.601 en rango limitado y el sobremuestreo de croma 9-3-3-1. Los colores salen idénticos al bit, no parecidos; la conversión estándar de Go los corría hasta 20 niveles.

**GIF animados bien compuestos.** `--frames` exporta cada cuadro completo, respetando el método de disposición del anterior, y no los recortes parciales que guarda el archivo.

**Alfa.** Se conserva hacia png y se aplana sobre `--background` hacia jpg y bmp (`#0b0b0f`, `blanco`, `negro`…).

**No pisa nada.** Nunca borra el original ni sobrescribe sin `--force`, y avisa cuando dos entradas caerían en la misma salida (`foto.webp` y `foto.gif` → `foto.png`). La escritura es atómica: un corte o un Ctrl+C no deja archivos a medias.

**Patrones propios.** Ni cmd ni PowerShell expanden comodines para un programa nativo: img entiende `*`, `?`, `[]` y `**` (sin distinguir mayúsculas, como Windows), ordena en orden natural (`pag2` antes que `pag10`) y, si un archivo no existe, sugiere el más parecido.

**Para scripts.** Si la salida no es una consola, texto plano sin un solo escape de color. Códigos de salida: `0` todo bien, `1` algunas fallaron, `2` línea de comandos inválida, `3` no se pudo hacer nada, `130` cancelado.

## Descargar

`img.exe` es el programa entero: Windows 10 u 11 de 64 bits (se probó en Windows 11), un solo archivo, sin instalador. Copialo a una carpeta del `PATH`. O, con Go:

```powershell
go install github.com/agustinyarrus/img@v1.0.0
```

Para comprobar la descarga, en la carpeta donde quedaron los dos archivos:

```powershell
(Get-FileHash .\img.exe -Algorithm SHA256).Hash -eq ((Get-Content .\SHA256SUMS) -split '\s+')[0]   # True
```

En Git Bash o WSL, `sha256sum -c SHA256SUMS`. El `.exe` es reproducible: la misma etiqueta con el mismo Go da los mismos bytes, así que cualquiera puede compilarla y comparar ([cómo](https://github.com/agustinyarrus/img/blob/v1.0.0/docs/RELEASE.md#5-el-exe-es-reproducible)).

## Cómo se verificó

- img no se contrasta consigo misma: Pillow, un decodificador independiente (libwebp para las WebP, libjpeg para los JPEG), compara píxel a píxel. 18 de 18 WebP con pérdida de estrés (de 1×1 a 333×201, ruido de color puro, con y sin alfa) idénticas al bit a libwebp; las imágenes de prueba convertidas, iguales al bit (el JPEG, a 1 nivel: dos decodificadores de JPEG no tienen por qué coincidir al bit).
- 57 pruebas de Go, todas corriendo: las de `imaging` leen imágenes de prueba generadas con ffmpeg.
- CI configurada para `windows-latest` con el Go mínimo del `go.mod`: formato, `go vet` (también para Linux), todas las pruebas sin salteadas, los dos oráculos y el `.exe` con su versión y su SHA256. Esta versión se verificó con la misma secuencia en un clon limpio, antes de publicarla.

El detalle, en [docs/VERIFICACION.md](https://github.com/agustinyarrus/img/blob/v1.0.0/docs/VERIFICACION.md); la arquitectura, en [docs/ARQUITECTURA.md](https://github.com/agustinyarrus/img/blob/v1.0.0/docs/ARQUITECTURA.md).

## Lo que falta

- **Escribir WebP.** No hay codificador en Go puro: img lee WebP pero no las escribe.
- **WebP animadas.** `golang.org/x/image/webp` solo lee imágenes estáticas; hace falta un lector del contenedor animado que componga los cuadros, como ya se hace con los GIF.
- **El GIF de salida.** Usa la paleta fija de Plan 9, así que un degradé suave pierde matices, y no reserva un transparente: hacia GIF la transparencia se pierde. Leer GIF, animados incluidos, no tiene ese problema.

La lista, en [docs/PENDIENTE.md](https://github.com/agustinyarrus/img/blob/v1.0.0/docs/PENDIENTE.md).
