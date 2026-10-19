import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/features/ai/data/ai_gateway_impl.dart';
import 'package:hottea/features/ai/domain/ai_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AI Gateway Domain & Privacy Policy Tests', () {
    test('Provider registry lists available providers and default configuration', () {
      final gateway = AiGatewayImpl();

      final providers = gateway.availableProviders;
      expect(providers.length, greaterThanOrEqualTo(2));

      final active = gateway.activeConfig;
      expect(active.id, 'openai-compatible');
      expect(active.isLocal, isFalse);

      final openAiCap = gateway.getCapability('openai-compatible');
      expect(openAiCap.isLocal, isFalse);
      expect(openAiCap.isAvailable, isTrue);

      final localCap = gateway.getCapability('local-runtime');
      expect(localCap.isLocal, isTrue);
      expect(localCap.isAvailable, isFalse);
    });

    test('Local inference fails explicitly and never silently redirects to cloud', () async {
      final gateway = AiGatewayImpl();
      gateway.setActiveProvider('local-runtime');

      final request = AiRequest.prompt(
        prompt: 'Explain privacy invariants',
        providerId: 'local-runtime',
        model: 'llama-3.2-3b',
      );

      expect(
        () => gateway.complete(request, userConsentGiven: true),
        throwsA(isA<LocalInferenceFailureException>()),
      );
    });

    test('Remote cloud request without explicit user consent is blocked', () async {
      final gateway = AiGatewayImpl();
      final request = AiRequest.prompt(
        prompt: 'Summarize web research',
        providerId: 'openai-compatible',
        model: 'gpt-4o-mini',
      );

      try {
        await gateway.complete(request, userConsentGiven: false);
        fail('Should have thrown UnconsentedExternalTransmissionException');
      } on UnconsentedExternalTransmissionException catch (e) {
        expect(e.disclosure.providerName, contains('OpenAI-Compatible'));
        expect(e.disclosure.endpoint, 'https://api.openai.com/v1');
        expect(e.disclosure.isCloudService, isTrue);
        expect(e.disclosure.promptCharacterCount, greaterThan(0));
      }
    });

    test('Attached research context is reported in transmission disclosure and preserved', () async {
      final gateway = AiGatewayImpl();
      final contextRef = ResearchContextReference(
        title: 'SQLite Thread Safety',
        contentSnippet: 'WAL mode enables concurrent reads without locking.',
        sourceUrl: Uri.parse('https://sqlite.org/wal.html'),
      );

      final request = AiRequest.prompt(
        prompt: 'How does WAL work?',
        researchContext: [contextRef],
        providerId: 'openai-compatible',
        model: 'gpt-4o-mini',
      );

      try {
        await gateway.complete(request, userConsentGiven: false);
        fail('Should require consent');
      } on UnconsentedExternalTransmissionException catch (e) {
        expect(e.disclosure.containsSensitiveContext, isTrue);
        expect(e.disclosure.attachedResearchPassages.length, 1);
        expect(e.disclosure.attachedResearchPassages.first.title, 'SQLite Thread Safety');
        expect(e.disclosure.attachedResearchPassages.first.sourceUrl.toString(), 'https://sqlite.org/wal.html');
      }
    });
  });

  group('OpenAI Chat Completions Adapter HTTP Tests', () {
    test('Successful 200 completion parses response and token usage', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/chat/completions');
        expect(request.headers['authorization'], 'Bearer test-api-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4o-mini');
        expect(body['messages'], isNotEmpty);

        final responseJson = {
          'id': 'chatcmpl-123',
          'model': 'gpt-4o-mini-2024-07-18',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': 'HotTea prioritizes user data control and local persistence.',
              },
              'finish_reason': 'stop',
            }
          ],
          'usage': {
            'prompt_tokens': 15,
            'completion_tokens': 12,
            'total_tokens': 27,
          }
        };

        return http.Response(jsonEncode(responseJson), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final gateway = AiGatewayImpl(injectedClient: mockClient);
      gateway.updateProviderConfig(
        gateway.activeConfig.copyWith(apiKey: 'test-api-key'),
      );

      final request = AiRequest.prompt(
        prompt: 'What is HotTea?',
        providerId: 'openai-compatible',
        model: 'gpt-4o-mini',
      );

      final response = await gateway.complete(request, userConsentGiven: true);

      expect(response.isSuccess, isTrue);
      expect(response.text, 'HotTea prioritizes user data control and local persistence.');
      expect(response.promptTokens, 15);
      expect(response.completionTokens, 12);
      expect(response.executedOn, AiExecutionTarget.externalProvider);
      expect(response.model, 'gpt-4o-mini-2024-07-18');
    });

    test('HTTP 401 triggers AiAuthenticationException without leaking API key', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'message': 'Incorrect API key provided'}}),
          401,
        );
      });

      final gateway = AiGatewayImpl(injectedClient: mockClient);
      gateway.updateProviderConfig(
        gateway.activeConfig.copyWith(apiKey: 'invalid-secret-key-12345'),
      );

      final request = AiRequest.prompt(
        prompt: 'Test auth',
        providerId: 'openai-compatible',
        model: 'gpt-4o-mini',
      );

      try {
        await gateway.complete(request, userConsentGiven: true);
        fail('Should throw AiAuthenticationException');
      } on AiAuthenticationException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, contains('API key in Settings'));
        // Invariant: Exception must never contain the actual API key
        expect(e.toString(), isNot(contains('invalid-secret-key-12345')));
      }
    });

    test('HTTP 429 triggers AiRateLimitException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'message': 'Rate limit exceeded'}}),
          429,
        );
      });

      final gateway = AiGatewayImpl(injectedClient: mockClient);
      gateway.updateProviderConfig(
        gateway.activeConfig.copyWith(apiKey: 'test-key'),
      );

      final request = AiRequest.prompt(
        prompt: 'Test rate limit',
        providerId: 'openai-compatible',
        model: 'gpt-4o-mini',
      );

      expect(
        () => gateway.complete(request, userConsentGiven: true),
        throwsA(isA<AiRateLimitException>()),
      );
    });

    test('Malformed JSON response triggers AiMalformedResponseException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"unexpected_payload": true}', 200);
      });

      final gateway = AiGatewayImpl(injectedClient: mockClient);
      gateway.updateProviderConfig(
        gateway.activeConfig.copyWith(apiKey: 'test-key'),
      );

      final request = AiRequest.prompt(
        prompt: 'Test malformed',
        providerId: 'openai-compatible',
        model: 'gpt-4o-mini',
      );

      expect(
        () => gateway.complete(request, userConsentGiven: true),
        throwsA(isA<AiMalformedResponseException>()),
      );
    });

    test('Missing API key on remote endpoint throws immediate authentication error', () async {
      final gateway = AiGatewayImpl();
      gateway.updateProviderConfig(
        gateway.activeConfig.copyWith(apiKey: ''), // Empty key
      );

      final request = AiRequest.prompt(
        prompt: 'No key prompt',
        providerId: 'openai-compatible',
        model: 'gpt-4o-mini',
      );

      expect(
        () => gateway.complete(request, userConsentGiven: true),
        throwsA(isA<AiAuthenticationException>()),
      );
    });
  });
}
