import 'package:flutter_test/flutter_test.dart';
import 'package:ar_landmark/models/landmark.dart';
import 'package:ar_landmark/services/landmark_data_service.dart';
import 'package:ar_landmark/services/ml_service.dart';
import 'package:ar_landmark/providers/scanner_provider.dart';

void main() {
  test('LandmarkDataService contains the 3 trained local landmarks', () {
    final landmarks = LandmarkDataService.allLandmarks;
    expect(landmarks.length, 3);

    final cathedral = LandmarkDataService.findByLabel('cathedral');
    expect(cathedral, isNotNull);
    expect(cathedral!.name, contains('San Sebastian Cathedral'));
    expect(cathedral.country, 'Philippines');
    expect(cathedral.funFacts.isNotEmpty, true);
    expect(cathedral.timeline.isNotEmpty, true);

    final lccb = LandmarkDataService.findByLabel('lccb');
    expect(lccb, isNotNull);
    expect(lccb!.name, contains('La Consolacion'));

    final plaza = LandmarkDataService.findByLabel('plaza');
    expect(plaza, isNotNull);
    expect(plaza!.name, contains('Public Plaza'));
  });

  test('LandmarkDataService returns null for unknown labels without fake fallback', () {
    final unknown = LandmarkDataService.findByLabel('eiffel_tower');
    expect(unknown, isNull);

    final searching = LandmarkDataService.findByLabel('searching');
    expect(searching, isNull);

    final empty = LandmarkDataService.findByLabel('');
    expect(empty, isNull);
  });

  test('BoundingBox calculates correct center and dimensions', () {
    const box = BoundingBox(left: 0.1, top: 0.2, right: 0.5, bottom: 0.6);
    expect(box.width, closeTo(0.4, 0.001));
    expect(box.height, closeTo(0.4, 0.001));
    expect(box.centerX, closeTo(0.3, 0.001));
    expect(box.centerY, closeTo(0.4, 0.001));
  });

  test('ScannerProvider initial state is searching with null landmark', () {
    final mlService = MLService();
    final provider = ScannerProvider(mlService: mlService);
    expect(provider.currentResult, isNull);
    expect(provider.isScanning, isTrue);
  });
}

