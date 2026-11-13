/// Adapts a scheduler pump to a sequential, frame-zero capture.
///
/// [fps] is the video's positive frame rate. The callback returned here is
/// called once per frame, in order, and must be awaited. Its first duration is
/// zero. Later durations are differences of rounded absolute timestamps, so
/// fractional frame periods never accumulate rounding error.
///
/// Callers using Fluvie 0.3.1 must disable the frame cache: cache hits skip
/// this callback and would leave its sequential counter behind.
///
/// The host owns scheduler advancement. This does not seek or rewind tickers.
/// Throws [ArgumentError] for a non-positive frame rate.
Future<void> Function() captureFramePump({
  required int fps,
  required Future<void> Function(Duration elapsed) pump,
}) {
  if (fps <= 0) throw ArgumentError.value(fps, 'fps', 'must be positive');
  var frame = 0;
  var previousTimestamp = 0;
  return () async {
    final timestamp = (frame * Duration.microsecondsPerSecond / fps).round();
    await pump(Duration(microseconds: timestamp - previousTimestamp));
    previousTimestamp = timestamp;
    frame++;
  };
}
