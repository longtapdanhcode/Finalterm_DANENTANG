import 'dart:typed_data';

bool get supportsDamageSegmentation => false;

Future<({Uint8List image, List<String> labels})> analyzeDamagePhoto(
  Uint8List photo,
) async => throw UnsupportedError('Phân vùng hư hỏng cần app hiện trường.');
