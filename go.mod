module github.com/pinkhop/chronos2-go-base

go 1.27.4

require (
	github.com/pinkhop/chronos2-go v1.0.0
	github.com/pinkhop/chronos2-go-base-part1 v1.0.0
	github.com/pinkhop/chronos2-go-base-part2 v1.0.0
	github.com/pinkhop/chronos2-go-base-part3 v1.0.0
	github.com/pinkhop/chronos2-go-base-part4 v1.0.0
)

// v1.0.0 cannot be downloaded through the Go module proxy.
retract v1.0.0
