import 'dart:typed_data';

import 'package:field_inventory_edge_ai/features/edge_vision/data/repositories/damage_segmentation_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('paints only the damage mask, aligned to a letterboxed photo', () {
    final photo = img.Image(width: 32, height: 16);
    const anchors = 8400;
    final detections = Float32List(40 * anchors);
    detections[0] = 320; // Center x
    detections[anchors] = 320; // Center y
    detections[2 * anchors] = 16;
    detections[3 * anchors] = 8;
    detections[6 * anchors] = 0.9; // Bong sơn
    detections[8 * anchors] = 1; // Coefficient of the first prototype
    final prototypes = Float32List(32 * 160 * 160);
    prototypes[80 * 160 + 80] = 2;
    prototypes[80 * 160 + 77] = 2; // Outside the predicted box

    expect(paintDamageMasks(photo, detections, prototypes, 304, 312), [
      'Bong sơn (90%)',
    ]);
    expect(photo.getPixel(16, 8).r, greaterThan(0));
    expect(photo.getPixel(12, 8).r, 0); // Inside the box, outside the mask
    expect(photo.getPixel(4, 8).r, 0); // Outside the box
  });
}
