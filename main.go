// img convierte imágenes entre formatos en lote (webp/gif/jpg/bmp/tiff → png…).
package main

import (
	"os"

	"github.com/agustinyarrus/img/internal/img"
	"github.com/agustinyarrus/img/internal/tui"
	"github.com/agustinyarrus/img/internal/version"
)

func main() {
	t := tui.Open()
	defer t.Close()
	os.Exit(img.Main(t, version.String(), os.Args[1:]))
}
