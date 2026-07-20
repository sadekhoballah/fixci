import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/auth/phone_verification_provider.dart';
import 'package:mobile/core/auth/phone_verification_service.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/onboarding/onboarding_controller.dart';
import 'package:mobile/features/onboarding/onboarding_repository.dart';

const _correctCode = '123456';

// Fakes only the true I/O boundary (mirrors _FakeApiClient/_FakeIdCardPicker
// in widget_test.dart) — everything above it (OtpController, OnboardingController,
// the screens) runs for real.
class _FakePhoneVerificationService implements PhoneVerificationService {
  _FakePhoneVerificationService({this.failSend = false});

  final bool failSend;
  int sendCodeCallCount = 0;

  @override
  Future<void> sendCode({
    required String phoneNumber,
    required void Function(CodeSentResult result) onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(PhoneVerificationException error) onFailed,
  }) async {
    sendCodeCallCount++;
    if (failSend) {
      onFailed(PhoneVerificationException('Numéro de téléphone invalide.'));
      return;
    }
    onCodeSent(CodeSentResult(verificationId: 'fake-verification-id'));
  }

  @override
  Future<String?> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (smsCode != _correctCode) {
      throw PhoneVerificationException('Code incorrect. Veuillez réessayer.');
    }
    return 'fake-id-token';
  }
}

class _FakeApiClient extends ApiClient {
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path == '/users/register') {
      return {
        'id': 'fake-user-id',
        'phone': body['phone'],
        'fullName': body['fullName'],
        'role': body['role'],
      };
    }
    throw UnimplementedError('Unexpected path in fake client: $path');
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path,
    String fieldName,
    List<int> bytes,
    String filename, {
    String? contentTypeHeader,
  }) => throw UnimplementedError('Not exercised in this test file');
}

void main() {
  Widget buildApp(PhoneVerificationService phoneService) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        phoneVerificationServiceProvider.overrideWithValue(phoneService),
      ],
      child: const FixCiApp(),
    );
  }

  Future<void> goToOtpScreen(WidgetTester tester, {String phone = '+2250700000099'}) async {
    await tester.pumpWidget(buildApp(_FakePhoneVerificationService()));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Numéro de téléphone'),
      phone,
    );
    await tester.pump();

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();
  }

  testWidgets('correct code verifies the phone and completes registration', (
    tester,
  ) async {
    await goToOtpScreen(tester);
    expect(find.text('Vérification du numéro'), findsOneWidget);

    await tester.enterText(find.byType(TextField), _correctCode);
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue !'), findsOneWidget);
  });

  testWidgets('wrong code shows an inline error and stays on the OTP screen', (
    tester,
  ) async {
    await goToOtpScreen(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(find.text('Vérification du numéro'), findsOneWidget);
    expect(find.text('Code incorrect. Veuillez réessayer.'), findsOneWidget);

    // Correcting the code afterwards still works — the failure didn't
    // burn the verification session.
    await tester.enterText(find.byType(TextField), _correctCode);
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue !'), findsOneWidget);
  });

  testWidgets('resend is disabled during the cooldown window', (
    tester,
  ) async {
    await goToOtpScreen(tester);

    final resendButton = find.byType(TextButton);
    expect(resendButton, findsOneWidget);
    expect(
      tester.widget<TextButton>(resendButton).onPressed,
      isNull,
      reason: 'Resend should be disabled immediately after a code is sent',
    );
    expect(find.textContaining('Renvoyer le code ('), findsOneWidget);
  });

  testWidgets('a failed send shows an inline error with a retry option', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(_FakePhoneVerificationService(failSend: true)),
    );
    await tester.pumpAndSettle(const Duration(seconds: 4));

    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Numéro de téléphone'),
      '+2250700000098',
    );
    await tester.pump();
    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    expect(find.text('Numéro de téléphone invalide.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  test('editing the phone after verifying it clears the verification', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(onboardingControllerProvider.notifier);

    controller.setPhone('+2250700000001');
    controller.setVerifiedPhone(
      phone: '+2250700000001',
      idToken: 'fake-id-token',
    );
    expect(container.read(onboardingControllerProvider).isPhoneVerified, isTrue);

    controller.setPhone('+2250700000002');
    final state = container.read(onboardingControllerProvider);
    expect(state.isPhoneVerified, isFalse);
    expect(state.firebaseIdToken, isNull);
  });
}
