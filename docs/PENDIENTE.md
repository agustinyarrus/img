# Pendiente

img está terminada y verificada ([VERIFICACION.md](VERIFICACION.md)). Lo que sigue son mejoras, en el orden en que conviene hacerlas.

## Formatos

- **WebP animadas**: `x/image/webp` solo lee imágenes estáticas. Hace falta un lector del contenedor RIFF animado (`ANIM`/`ANMF`) que componga los cuadros, igual que ya se hace con los GIF.
- **Escribir WebP**: no hay codificador en Go puro. Un WebP sin pérdida (VP8L) es la opción realista; el oráculo ya existe (Pillow lo decodifica).

## Distribución

- Releases en GitHub con el `img.exe` que genera `build.ps1` y su SHA256.
- Integración continua: `go vet` y `go test` en `windows-latest` con GitHub Actions. Los tests que necesitan fixtures se saltean solos; para correrlos habría que instalar ffmpeg en el runner y llamar a `scripts\fixtures.ps1` antes.
