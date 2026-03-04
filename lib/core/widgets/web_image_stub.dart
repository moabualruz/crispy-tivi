import 'package:flutter/widgets.dart';

Widget buildWebImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  String? proxyBaseUrl,
}) {
  throw UnsupportedError('buildWebImage is supported only on the Web.');
}
