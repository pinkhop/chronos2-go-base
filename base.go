// Package base embeds the amazon/chronos-2 checkpoint (a saved copy of the trained
// Chronos-2 model) and provides it as a ready-to-use [chronos2.Model].
// Importing this package adds the checkpoint's weights to the binary; package
// [github.com/pinkhop/chronos2-go] documents the forecasting API.
//
// It is the larger of the two published models: it adds about 478 MB to a
// binary, runs slower, and predicts 21 percentile levels natively. Package
// [github.com/pinkhop/chronos2-go-small] embeds the smaller model,
// with 13 native levels; switching between them changes only the import path.
package base

import (
	_ "embed"
	"sync"

	chronos2 "github.com/pinkhop/chronos2-go"
)

// checkpointName is the name the model reports through Model.Name.
const checkpointName = "chronos-2"

// config is the checkpoint's config.json.
//
//go:embed weights/config.json
var config []byte

// The shards are embedded as byte slices rather than strings because the Go
// linker currently aligns embedded byte-slice data but not string data (not
// a language guarantee; the alias test in the chronos2-go repository's parity
// module verifies it): chronos2.Load can then view the weights in place
// instead of copying the whole checkpoint onto the heap. Nothing may write to
// these slices; the model every goroutine shares reads them for the life of
// the process.
var (
	// shard01 is weights/model-00001-of-00012.safetensors.
	//
	//go:embed weights/model-00001-of-00012.safetensors
	shard01 []byte

	// shard02 is weights/model-00002-of-00012.safetensors.
	//
	//go:embed weights/model-00002-of-00012.safetensors
	shard02 []byte

	// shard03 is weights/model-00003-of-00012.safetensors.
	//
	//go:embed weights/model-00003-of-00012.safetensors
	shard03 []byte

	// shard04 is weights/model-00004-of-00012.safetensors.
	//
	//go:embed weights/model-00004-of-00012.safetensors
	shard04 []byte

	// shard05 is weights/model-00005-of-00012.safetensors.
	//
	//go:embed weights/model-00005-of-00012.safetensors
	shard05 []byte

	// shard06 is weights/model-00006-of-00012.safetensors.
	//
	//go:embed weights/model-00006-of-00012.safetensors
	shard06 []byte

	// shard07 is weights/model-00007-of-00012.safetensors.
	//
	//go:embed weights/model-00007-of-00012.safetensors
	shard07 []byte

	// shard08 is weights/model-00008-of-00012.safetensors.
	//
	//go:embed weights/model-00008-of-00012.safetensors
	shard08 []byte

	// shard09 is weights/model-00009-of-00012.safetensors.
	//
	//go:embed weights/model-00009-of-00012.safetensors
	shard09 []byte

	// shard10 is weights/model-00010-of-00012.safetensors.
	//
	//go:embed weights/model-00010-of-00012.safetensors
	shard10 []byte

	// shard11 is weights/model-00011-of-00012.safetensors.
	//
	//go:embed weights/model-00011-of-00012.safetensors
	shard11 []byte

	// shard12 is weights/model-00012-of-00012.safetensors.
	//
	//go:embed weights/model-00012-of-00012.safetensors
	shard12 []byte
)

// load decodes the embedded checkpoint once per process and caches the result.
var load = sync.OnceValues(func() (*chronos2.Model, error) {
	return chronos2.Load(chronos2.Checkpoint{
		Name:   checkpointName,
		Config: config,
		Shards: [][]byte{shard01, shard02, shard03, shard04, shard05, shard06, shard07, shard08, shard09, shard10, shard11, shard12},
	})
})

// New returns the package's shared, immutable Chronos-2 model. The first call
// decodes the embedded amazon/chronos-2 checkpoint, viewing its weights in place where
// the platform allows instead of copying them; every later call returns the same
// [*chronos2.Model]. The model is safe for concurrent use by any number of
// goroutines. An error matches [chronos2.ErrInvalidCheckpoint], indicates
// damaged embedded files, and is returned on every call.
func New() (*chronos2.Model, error) {
	return load()
}
