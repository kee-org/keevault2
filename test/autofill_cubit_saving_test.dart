import 'package:flutter/services.dart';
import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/cubit/autofill_cubit.dart';

class _TestAutofillCubit extends AutofillCubit {
  void setState(AutofillState s) => emit(s);
}

AutofillMetadata _metadata() => AutofillMetadata(
  appId: 'com.example.app',
  appIdSource: AppIdSource.component,
  webDomains: {},
  saveInfo: SaveInfoMetadata(username: 'u', password: 'p'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.keevault/flutter_autofill_service');
  late List<String> calls;
  late _TestAutofillCubit cubit;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    cubit = _TestAutofillCubit()..ownPackageNameForTesting = 'com.keevault.keevault';
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await cubit.close();
  });

  test('finishSaving leaves autofill saving mode and tells the plugin the request is complete', () async {
    cubit.setState(AutofillSaving(_metadata(), requestId: 1));
    expect(cubit.isAutofillSaving(), true);

    await cubit.finishSaving();

    expect(cubit.state, isA<AutofillAvailable>());
    expect(cubit.isAutofillSaving(), false);
    expect(cubit.isAutofilling(), false);
    expect(calls, ['onSaveComplete']);
  });

  test('abandonSaving leaves autofill saving mode and tells the plugin the request is complete', () async {
    cubit.setState(AutofillSaving(_metadata(), requestId: 1));

    await cubit.abandonSaving();

    expect(cubit.state, isA<AutofillAvailable>());
    expect(cubit.isAutofillSaving(), false);
    expect(calls, ['onSaveComplete']);
  });

  test('finishing or abandoning when not saving does nothing', () async {
    cubit.setState(AutofillAvailable(true));

    await cubit.abandonSaving();
    await cubit.finishSaving();

    expect(cubit.state, isA<AutofillAvailable>());
    expect(calls, isEmpty);
  });
}
