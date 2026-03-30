// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:care_ai/services/ai_service.dart';

void main() {
  test('Test Firebase AiService Response', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final aiService = AiService();
    aiService.initialize();

    final response = await aiService
        .getResponse('Say hello!')
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => 'Timed out, using fallback response.',
        );
    print('Firebase AI Response: $response');

    expect(response, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
