import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/network/http_service.dart';

void main() {
  group('HttpService', () {
    late HttpService service;

    setUp(() {
      service = HttpService();
    });

    test('creates Dio instance with correct defaults', () {
      final dio = service.dio;
      expect(dio.options.connectTimeout, const Duration(seconds: 15));
      expect(dio.options.receiveTimeout, const Duration(seconds: 60));
      expect(dio.options.headers['User-Agent'], 'CrispyTivi/1.0');
    });
  });
}
