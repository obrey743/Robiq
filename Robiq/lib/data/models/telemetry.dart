/// A single telemetry reading, e.g. `battery = 7.4` at a point in time.
class TelemetrySample {
  const TelemetrySample(this.timestamp, this.value);

  final DateTime timestamp;
  final double value;
}
