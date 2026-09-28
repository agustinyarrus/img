# Arquitectura

## Principios

- **Go puro, sin CGO.** img compila a un único `.exe` estático. Las llamadas a Windows van por `syscall`, sin bindings de C, y el único módulo externo es `golang.org/x/image`.
- **Una responsabilidad por paquete.** La herramienta (`internal/img`) es solo su interfaz: flags, plan y presentación. Decodificar y codificar es `imaging`; la consola, los flags, los patrones de archivos y el trabajo en paralelo son paquetes aparte.
- **Validar en la frontera.** Los flags se interpretan y validan una sola vez al parsear (formato, calidad, color de fondo); adentro los valores ya son del tipo correcto.
- **Escritura atómica.** Toda salida va a un temporal en la misma carpeta y se renombra al final: un corte o un Ctrl+C nunca deja un archivo a medias ni pisa el anterior.
- **Salida visual que degrada.** Colores pastel sobre negro, progreso vivo y tarjeta de resumen en la consola; texto plano sin un solo escape cuando la salida es un pipe o un archivo.

## El recorrido de una corrida

1. `main.go` abre la consola (`tui.Open`), llama a `img.Main` con la versión y sale con el código que devuelve.
2. `cli` interpreta los argumentos; `--help`, `--version` y los errores de uso terminan ahí.
3. `fsx.Expand` resuelve los patrones y las carpetas (con `-r`, recursivo) y se queda con los nombres de imagen; lo que no existe se informa y no corta la tanda.
4. **Plan de salidas** (`construirTareas`): para cada entrada, su destino (misma carpeta u `--out-dir`, extensión nueva) y si procede. Se saltea, con motivo, si el destino es el mismo archivo, si ya existe sin `--force` o si otra entrada ya reclamó esa salida (la comparación no distingue mayúsculas, como NTFS).
5. `batch.Run` corre las conversiones en paralelo (una por CPU, o `--jobs`), con la barra viva.
6. La tarjeta final resume convertidas, salteadas, fallidas, el tamaño final y el cambio de peso; el código de salida sale de ahí.

## imaging

- **Formato por contenido**: se reconoce por los primeros bytes (magic numbers), no por la extensión.
- **WebP con pérdida**: `x/image/webp` entrega YCbCr 4:2:0 y `webpcolor.go` lo pasa a RGB con la aritmética de libwebp:
  - la conversión en punto fijo de BT.601 en rango limitado;
  - el sobremuestreo de croma 9-3-3-1 entre filas vecinas, con el mismo recorrido de filas de `EmitFancyRGB`.

  La salida coincide al bit con el decodificador de referencia. La conversión estándar de Go trataba esas imágenes como un JPEG (rango completo y el croma del píxel más cercano) y los colores salían corridos hasta 20 niveles.
- **Composición de GIF**: los cuadros suelen guardar solo el rectángulo que cambió. Se reconstruye cada cuadro completo aplicando el método de disposición del anterior: nada, restaurar al fondo (transparente) o restaurar al lienzo previo. Cuesta O(cuadros × píxeles).
- **Salida GIF**: paleta de 256 colores con dithering de Floyd–Steinberg.
- **Formatos opacos**: la transparencia se aplana sobre el fondo elegido (`--background`).
- **PNG**: compresión máxima por defecto; `--fast` cambia tamaño por velocidad.

## El núcleo de consola

### tui

- **Región viva**: el progreso se redibuja en el lugar a 20 cuadros por segundo y las líneas permanentes se imprimen por encima. Hay un orden de candados fijo para que no haya deadlock:
  - la función de dibujo corre sin el candado del terminal (puede tomar el del estado de la herramienta);
  - `Println` nunca llama a la función de dibujo: reusa el último cuadro.
- **Recorte seguro**: `ClipANSI` recorta una línea con escapes a N columnas visibles sin romper los colores. Las líneas vivas se cortan una columna antes del borde, para que el terminal no las parta y el conteo de líneas no se desfase.
- **Barra**: resolución de 1/8 de columna (bloques `▏▎▍▌▋▊▉█`) con degradé.
- **Tarjeta**: fondo apenas teñido, sin bordes.
- **Formato es-AR**: miles con punto, decimales con coma, bytes en unidades decimales.
- **Barra de tareas**: en Windows Terminal, el avance también se publica en el ícono y la pestaña (OSC 9;4).
- **Tabla**: columnas con mínimo, opcionales que se caen en orden si no entran y flexibles que ceden espacio por "llenado de agua". La disposición es una función pura, probada con 20.000 tablas al azar.

### cli

- Flags al estilo GNU: `-o x`, `--out=x`, `-abc`, `--no-x`, `--`.
- Binders tipados con validación: enteros acotados, enumerados, tamaños y tiempos.
- La ayuda se genera con el mismo lenguaje visual que el resto de la salida, al ancho real de la ventana.
- Un flag mal escrito sugiere el más parecido por distancia de Damerau–Levenshtein (`textdist`): programación dinámica en O(n·m) con tres filas rodantes, y la transposición de dos letras cuenta como un solo error.

### fsx

- Patrones con `*`, `?`, `[]` y `**`, resueltos segmento a segmento. En Windows no distinguen mayúsculas, igual que el sistema de archivos. Ni cmd ni PowerShell expanden comodines para un exe nativo: lo hace la herramienta.
- Orden natural: `pag2` antes que `pag10`, comparando tramos de dígitos por valor y sin límite de largo.
- Si un archivo no existe, sugiere el más parecido de la misma carpeta.
- `WriteAtomic` reintenta el renombre con espera exponencial (un antivirus o un visor pueden tener el destino abierto un instante). No hace fsync a propósito: protege contra cortes del programa sin pagar un `FlushFileBuffers` por archivo.

### batch

- Pool de workers para tareas independientes.
- Los resultados se guardan por índice, así el resumen es determinista aunque terminen desordenados.
- Los contadores son atómicos.
- Un pánico en una tarea se convierte en un fallo de esa tarea, sin tirar abajo la tanda.

### win/desk

- El modo y el tamaño de la consola (lo que usa `tui` para saber si hay consola y cuánto mide), por `syscall`.
- Solo carga `kernel32.dll`, que es una KnownDLL: Windows la toma siempre de System32. Con cualquier otra DLL nombrada sin ruta, `LoadLibrary` buscaría primero junto al exe, y un DLL plantado ahí ganaría.
- El envoltorio de las llamadas lleva `//go:uintptrescapes`: sin esa directiva, un búfer que viaja como `uintptr` puede quedar en la pila de la goroutine, y si la pila crece entre la conversión y la llamada, Windows escribe en la pila vieja.
- Es chico a propósito: nada de red ni de lanzar procesos. Un test (`internal/tui/deps_test.go`) comprueba con `go list -deps` que ni `tui` ni el exe cargan `net`, `net/netip` u `os/exec`.

### version

`Version` y `Commit` son variables que `build.ps1` pisa con `-ldflags -X`: `img --version` dice `1.0.0+abc1234`. Compilado con `go install`, dice `1.0.0`.
