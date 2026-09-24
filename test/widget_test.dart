import 'package:flutter_test/flutter_test.dart';
import 'package:ar_landmark/models/landmark.dart';
import 'package:ar_landmark/services/landmark_data_service.dart';

void main() {
  test('LandmarkDataService contains rich historical landmarks', () {
    final landmarks = LandmarkDataService.allLandmarks;
    expect(landmarks.isNotEmpty, true);

    final eiffel = LandmarkDataService.findByLabel('eiffel_tower');
    expect(eiffel, isNotNull);
    expect(eiffel!.name, 'Eiffel Tower');
    expect(eiffel.country, 'France');
    expect(eiffel.funFacts.isNotEmpty, true);
    expect(eiffel.timeline.isNotEmpty, true);
  });

  test('BoundingBox calculates correct center and dimensions', () {
    const box = BoundingBox(left: 0.1, top: 0.2, right: 0.5, bottom: 0.6);
    expect(box.width, closeTo(0.4, 0.001));
    expect(box.height, closeTo(0.4, 0.001));
    expect(box.centerX, closeTo(0.3, 0.001));
    expect(box.centerY, closeTo(0.4, 0.001));
  });
}
