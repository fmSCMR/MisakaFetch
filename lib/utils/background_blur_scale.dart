/// Allocate most slider travel to the nearly clear part of the blur range.
abstract final class BackgroundBlurScale {
  static double toBlur(double position) {
    final p = position.clamp(0.0, 1.0);
    if (p <= .7) return p / .7;
    if (p <= .9) return 1 + (p - .7) / .2 * 4;
    return 5 + (p - .9) / .1 * 25;
  }

  static double toPosition(double blur) {
    final b = blur.clamp(0.0, 30.0);
    if (b <= 1) return b * .7;
    if (b <= 5) return .7 + (b - 1) / 4 * .2;
    return .9 + (b - 5) / 25 * .1;
  }
}
