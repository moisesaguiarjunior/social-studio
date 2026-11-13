# Synthetic media fixtures

`tagged_red.png` is a 16 by 16 solid-red RGB image with PNG `tEXt` fields:
`Device=SyntheticPhotoDevice` and `Location=SyntheticPhotoLocation`. It was
constructed with Python's standard-library `struct` and `zlib` modules; its
pixels and metadata are entirely synthetic. It is an input fixture, not a golden.

The CLI metadata regression checks that both markers exist in the source and
that neither reaches encoded video or cover output. The capture-boundary test
reuses the same image. Neither test executes a historical probe generator.
