package img

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/agustinyarrus/img/internal/imaging"
	"github.com/agustinyarrus/img/internal/tui"
)

// El encabezado dice la extensión del archivo que se va a escribir. Antes armaba
// "." + el nombre del formato, y con --to jpg decía "destino .jpeg" mientras la
// salida era foto.jpg.
func TestDestinoEsLaExtensionQueSeEscribe(t *testing.T) {
	for _, nombre := range []string{"png", "jpg", "jpeg", "gif", "bmp", "tiff"} {
		f, err := imaging.ParseFormat(nombre)
		if err != nil {
			t.Fatalf("--to %s: %v", nombre, err)
		}
		salida := destinoDe(`C:\fotos\foto.webp`, f, "")
		planes := []plan{{entrada: `C:\fotos\foto.webp`, salida: salida}}
		enc := strings.Join(resumenPlan(&tui.Term{}, planes, f, opciones{}), "\n")
		if want := "destino " + filepath.Ext(salida); !strings.Contains(enc, want) {
			t.Errorf("--to %s escribe %s, pero el encabezado dice:\n%s", nombre, filepath.Base(salida), enc)
		}
	}
}
