# Pendiente

img está terminada y verificada ([VERIFICACION.md](VERIFICACION.md)). Lo que sigue son mejoras, en el orden en que conviene hacerlas.

## Formatos

- **WebP animadas**: `x/image/webp` solo lee imágenes estáticas. Hace falta un lector del contenedor RIFF animado (`ANIM`/`ANMF`) que componga los cuadros, igual que ya se hace con los GIF.
- **Escribir WebP**: no hay codificador en Go puro. Un WebP sin pérdida (VP8L) es la opción realista; el oráculo ya existe (Pillow lo decodifica).

- **Un GIF de salida mejor.** Hoy se cuantiza con la paleta fija de Plan 9 y sin un índice transparente: un degradé suave pierde matices y la transparencia se pierde. Una paleta armada para cada imagen (median cut u octree) y un índice reservado para el transparente lo arreglan; `pixel_check.py` ya sirve de oráculo (con tolerancia, porque cuantizar pierde).

## Distribución

- Hecho: la CI ([`ci.yml`](../.github/workflows/ci.yml)) corre en cada push todas las pruebas, con ffmpeg para las imágenes de prueba, y los dos oráculos de Pillow; la release 1.0.0 está lista para publicar ([RELEASE.md](RELEASE.md)).
- Falta: publicarla, y ver la primera corrida de la CI en GitHub (se simuló en la PC, no corrió en un runner de verdad).
