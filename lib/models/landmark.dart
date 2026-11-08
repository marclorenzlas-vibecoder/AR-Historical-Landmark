import 'package:flutter/material.dart';

/// Bounding box in normalized coordinates (0.0 to 1.0)
class BoundingBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => (right - left).clamp(0.0, 1.0);
  double get height => (bottom - top).clamp(0.0, 1.0);
  double get centerX => left + (width / 2);
  double get centerY => top + (height / 2);

  Rect toRect(Size screenSize) {
    return Rect.fromLTRB(
      left * screenSize.width,
      top * screenSize.height,
      right * screenSize.width,
      bottom * screenSize.height,
    );
  }

  /// Maps normalized [0.0..1.0] image coordinates to widget coordinates
  /// accounting for [BoxFit] (e.g. BoxFit.cover for live camera, BoxFit.contain for static photos),
  /// matching its411yolo's BoxMapper behavior so the outline follows the object 1:1.
  Rect toFittedRect({
    required Size imageSize,
    required Size widgetSize,
    BoxFit fit = BoxFit.cover,
  }) {
    if (imageSize.isEmpty ||
        widgetSize.isEmpty ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return toRect(widgetSize);
    }

    double scaleX = widgetSize.width / imageSize.width;
    double scaleY = widgetSize.height / imageSize.height;

    if (fit == BoxFit.cover) {
      final double scale = scaleX > scaleY ? scaleX : scaleY;
      scaleX = scale;
      scaleY = scale;
    } else if (fit == BoxFit.contain) {
      final double scale = scaleX < scaleY ? scaleX : scaleY;
      scaleX = scale;
      scaleY = scale;
    }

    final double scaledW = imageSize.width * scaleX;
    final double scaledH = imageSize.height * scaleY;
    final double offsetX = (widgetSize.width - scaledW) / 2.0;
    final double offsetY = (widgetSize.height - scaledH) / 2.0;

    final double mappedLeft =
        (offsetX + left * scaledW).clamp(4.0, widgetSize.width - 24.0);
    final double mappedTop =
        (offsetY + top * scaledH).clamp(28.0, widgetSize.height - 24.0);
    final double mappedRight =
        (offsetX + right * scaledW).clamp(mappedLeft + 20.0, widgetSize.width - 4.0);
    final double mappedBottom =
        (offsetY + bottom * scaledH).clamp(mappedTop + 20.0, widgetSize.height - 4.0);

    return Rect.fromLTRB(mappedLeft, mappedTop, mappedRight, mappedBottom);
  }
}

/// Result of the dual YOLO + CNN detection pipeline
class RecognitionResult {
  final String label;
  final double yoloConfidence;
  final double cnnConfidence;
  final BoundingBox? boundingBox;
  final Size imageSize;
  final int inferenceTimeMs;
  final Landmark? landmark;
  final DateTime detectedAt;
  final Map<String, double> allProbabilities;

  RecognitionResult({
    required this.label,
    required this.yoloConfidence,
    required this.cnnConfidence,
    this.boundingBox,
    this.imageSize = Size.zero,
    required this.inferenceTimeMs,
    this.landmark,
    DateTime? detectedAt,
    this.allProbabilities = const {},
  }) : detectedAt = detectedAt ?? DateTime.now();

  double get overallConfidence => (yoloConfidence * 0.4) + (cnnConfidence * 0.6);
}

/// Comprehensive historical landmark information model
class Landmark {
  final String id;
  final String labelKey;
  final String name;
  final String nativeName;
  final String location;
  final String country;
  final String era;
  final String yearBuilt;
  final String architecturalStyle;
  final String architect;
  final String description;
  final List<String> funFacts;
  final List<TimelineEvent> timeline;
  final String audioGuideScript;
  final String imageAsset;
  final double estimatedDistanceMeters;
  final String unescoStatus;

  const Landmark({
    required this.id,
    required this.labelKey,
    required this.name,
    required this.nativeName,
    required this.location,
    required this.country,
    required this.era,
    required this.yearBuilt,
    required this.architecturalStyle,
    required this.architect,
    required this.description,
    required this.funFacts,
    required this.timeline,
    required this.audioGuideScript,
    required this.imageAsset,
    this.estimatedDistanceMeters = 42.0,
    this.unescoStatus = 'UNESCO World Heritage Site',
  });
}

class TimelineEvent {
  final String year;
  final String title;
  final String description;

  const TimelineEvent({
    required this.year,
    required this.title,
    required this.description,
  });
}
