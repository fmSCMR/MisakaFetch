import 'package:flutter_test/flutter_test.dart';
import 'package:misaka_fetch/utils/background_blur_scale.dart';

void main() {
  test('清晰区间占七成行程，完整范围连续、递增且可还原', () {
    expect(BackgroundBlurScale.toBlur(0), 0);
    expect(BackgroundBlurScale.toBlur(.7), closeTo(1, 1e-9));
    expect(BackgroundBlurScale.toBlur(.9), closeTo(5, 1e-9));
    expect(BackgroundBlurScale.toBlur(1), closeTo(30, 1e-9));
    var previous = -1.0;
    for (var index = 0; index <= 300; index++) {
      final position = index / 300;
      final blur = BackgroundBlurScale.toBlur(position);
      expect(blur, greaterThan(previous));
      expect(BackgroundBlurScale.toPosition(blur), closeTo(position, 1e-9));
      previous = blur;
    }
    expect(BackgroundBlurScale.toPosition(10), closeTo(.92, 1e-9));
    expect(BackgroundBlurScale.toBlur(-1), 0);
    expect(BackgroundBlurScale.toPosition(100), 1);
  });
}
