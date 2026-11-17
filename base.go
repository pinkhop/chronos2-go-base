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
	"slices"
	"sync"

	chronos2 "github.com/pinkhop/chronos2-go"
	part1 "github.com/pinkhop/chronos2-go-base-part1"
	part2 "github.com/pinkhop/chronos2-go-base-part2"
	part3 "github.com/pinkhop/chronos2-go-base-part3"
	part4 "github.com/pinkhop/chronos2-go-base-part4"
)

// checkpointName is the name the model reports through Model.Name.
const checkpointName = "chronos-2"

// config is the checkpoint's config.json.
//
//go:embed weights/config.json
var config []byte

// load decodes the embedded checkpoint once per process and caches the result.
// The checkpoint's 12 shards are embedded by four part modules, three apiece,
// so that each module stays small enough for the Go module proxy to serve;
// load passes them to chronos2.Load in checkpoint order.
var load = sync.OnceValues(func() (*chronos2.Model, error) {
	return chronos2.Load(chronos2.Checkpoint{
		Name:   checkpointName,
		Config: config,
		Shards: slices.Concat(part1.Shards(), part2.Shards(), part3.Shards(), part4.Shards()),
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
