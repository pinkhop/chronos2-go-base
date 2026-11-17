# Agent Guide

This repository is `chronos2-go-base`, a Go module that embeds Amazon's `amazon/chronos-2` checkpoint for [`chronos2-go`](https://github.com/pinkhop/chronos2-go), the pure-Go Chronos-2 forecasting library. Its one package, `base`, exposes the checkpoint as a ready-to-use model through `New()`. The checkpoint's 12 shards live three apiece in four part modules, [`chronos2-go-base-part1`](https://github.com/pinkhop/chronos2-go-base-part1) through [`-part4`](https://github.com/pinkhop/chronos2-go-base-part4), which this module imports; this module holds the config. These instructions apply to any agent or developer changing the repository.

The forecasting library, its design, and its parity tests live in `chronos2-go`. Its [`AGENTS.md`](https://github.com/pinkhop/chronos2-go/blob/main/AGENTS.md) holds the full set of conventions, and its `docs/DESIGN.md` describes how the library loads and runs this checkpoint. [`chronos2-go-small`](https://github.com/pinkhop/chronos2-go-small) packages the smaller checkpoint, which fits in one module, so it embeds its shards directly; keep the two repositories parallel in structure otherwise.


## Repository Layout

The module sits at the repository root, and the repository holds nothing else:

| Path | Role |
|---|---|
| `base.go` | Package `base`: the `//go:embed` declaration for the config, the imports of the four parts, and `New()`. |
| `weights/config.json` | The checkpoint's configuration, as published upstream. |
| `weights/manifest.json` | The upstream source (repository, revision, file, and SHA-256), the config's SHA-256, and the part modules in checkpoint order (`shard_modules`). |
| `go.mod` | The module definition, which requires `github.com/pinkhop/chronos2-go` and the four part modules. |
| `README.md` | The consumer-facing overview. |
| `AGENTS.md` | This guide; `CLAUDE.md` is a symbolic link to it. |
| `Makefile` | Formatting, analysis, builds, and the weight and size checks. |
| `mise.toml`, `mise.lock` | The pinned Go toolchain and developer tools. |
| `LICENSE`, `NOTICE` | The Apache-2.0 license and the attribution for Chronos-2. |
| `.editorconfig`, `.gitattributes`, `.gitignore` | Editor and Git settings; `.gitattributes` keeps `*.safetensors` binary and out of Git LFS. |


## Commands

Tool versions, including Go itself, are pinned in `mise.toml` and `mise.lock`. Run `mise install` once, then use the `Makefile`:

| Command | Purpose |
|---|---|
| `make help` | List all targets. |
| `make format` | Format Go files with `goimports`, then `gofumpt`. |
| `make lint` | Check formatting, then run `go vet`, `staticcheck`, `errcheck`, `ineffassign`, `misspell`, and `typos`. |
| `make security` | Run `gosec` and `govulncheck`. |
| `make build` | Compile the package, which embeds the config and imports the four parts. |
| `make verify-weights` | Check `config.json` against `weights/manifest.json`. Each part's own `make verify-weights` checks its shards. |
| `make check-size` | Check the working tree, as it would be committed, against Go's two 500 MiB module limits, and print the headroom under each. |
| `make check` | Run `verify-weights`, then `check-size`. |

`check-size` stages the working tree into a temporary index, so it measures exactly what `git add -A` and a commit would publish without touching the real index, `HEAD`, or any ref.

Before considering a change complete, run `make format`, `make lint`, `make security`, and `make check`.


## Hard Constraints

These protect properties that are expensive or impossible to restore once broken.

### Weights

- Never store weights with Git LFS; `go get` cannot fetch LFS content. Weights are committed to the part modules as plain safetensors shards of at most 45 MB each (`max_shard_bytes` in each part's manifest), three per part.
- Never edit, re-encode, or re-shard weight files by hand. Every tensor stays bit-identical to the upstream checkpoint at the revision the manifest pins.
- Keep every manifest accurate. A change to the config updates this module's manifest, and a change to the shards updates the parts' manifests, in the same change; `make verify-weights` must pass in every repository it touches.
- The parts embed shards with `//go:embed` into `[]byte` variables, never `string`. `chronos2.Load` aliases aligned shard bytes as float32 tensors instead of copying them, and the Go linker currently aligns `[]byte` embeds but not string data. The alias test in `chronos2-go`'s `parity` module enforces both the embed type and the absence of a copy.
- `New()` passes the parts' shards to `chronos2.Load` in checkpoint order: part 1's first. When the set of parts changes, change the imports, the `slices.Concat` call in `base.go`, the `require` block in `go.mod`, and `shard_modules` in the manifest to match.

### Module Size

- Go downloads a module at a repository root as a `git archive` of the whole repository and refuses that archive above 500 MiB. It also refuses a module whose files total more than 500 MiB uncompressed. Everything committed counts toward both limits. The Go module proxy also fails to serve modules far below them, so the shards live in the part modules, each about 100–120 MiB, and this module holds no shards.
- Never add shards, Go tests, `testdata/`, nested modules, or any other large file. Tests of this checkpoint belong in `chronos2-go`'s `parity` module.
- `make check` must pass before any change is considered complete.

### Dependencies and API

- The module requires `github.com/pinkhop/chronos2-go` and the four part modules, and nothing else. Never add a third-party dependency.
- The package's API is `New()` alone, returning the shared `*chronos2.Model`. Never change its signature, and never add an exported symbol without discussing the need.
- `checkpointName` is the name the model reports through `Model.Name`. Keep it equal to the upstream repository's name without its owner (`chronos-2`).


## Go Conventions

`chronos2-go`'s `AGENTS.md` ("Go Conventions") governs Go code here. The rules that apply most often:

- Every declaration, exported or not, has a doc comment stating what it does and why a caller would use it.
- Assign every returned error, including one being discarded, and wrap returned errors with `%w`.
- Use American spelling and the serial comma in identifiers, file names, and comments.
- Keep the Go version in `mise.toml` and `go.mod` in sync with `chronos2-go`'s.
- Pin every Go-based developer tool in `mise.toml` (adding with `mise use --pin`) and commit `mise.lock`, at the versions `chronos2-go` pins. Never declare tools with `go.mod` `tool` directives, and never use `golangci-lint`.


## Documentation

- Documents describe the current state of the repository. Keep decision history, superseded approaches, and change narratives out of them; commit messages carry history.
- Keep `README.md` consistent with `chronos2-go`'s README and with `chronos2-go-small`'s, including the sizes, capabilities, and provenance they state.
- Markdown uses ATX headings in title case, two blank lines before every H1 and H2 (except a first-line title), `-` list markers, four-space nested indents, one paragraph per source line, and a language tag on every fenced code block.


## Commits

Write commit messages in the Conventional Commits format (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`), with the subject in lowercase imperative mood.
