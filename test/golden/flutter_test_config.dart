import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    goldenFileComparator = TolerantComparator(
      goldenFileComparator as LocalFileComparator,
      tolerance: 0.20, // 20% tolerance for CI font rendering differences
    );
  }
  await testMain();
}

class TolerantComparator extends LocalFileComparator {
  TolerantComparator(LocalFileComparator original, {required this.tolerance})
    : super(original.basedir.resolve('dummy.dart'));

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= tolerance) {
      debugPrint(
        'A difference of ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        'was tolerated in $golden.',
      );
      return true;
    }
    if (!result.passed) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return true;
  }
}
