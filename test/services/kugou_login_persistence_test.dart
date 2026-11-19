import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:md3music/providers/kugou_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md3music/services/kugou_api/kugou_api_client.dart';
import '../test_helpers/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('验证码通过但钥匙串拒绝保存时，两种手机号入口都返回失败', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = KugouProvider(registerDeviceOnStart: false);
    final api = provider.apiClient;
    await api.isLoggedInWhenReady();
    final response = InterceptorsWrapper(
      onRequest: (request, handler) {
        handler.resolve(
          Response(
            requestOptions: request,
            statusCode: 200,
            data: {
              'status': 1,
              'data': {'userid': 'fixture-user', 'token': 'fixture-token'},
            },
          ),
        );
      },
    );
    api.dio.interceptors.insert(0, response);
    addTearDown(() => api.dio.interceptors.remove(response));
    addTearDown(provider.dispose);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => throw PlatformException(code: '-34018'),
        );
    addTearDown(uninstallFakeSecureStorage);
    final result = await provider.loginByPhone('00000000000', '000000');
    expect(result.status, PhoneLoginStatus.failed);
    expect(
      await provider.loginByPhoneWithAccount(
        '00000000000',
        '000000',
        'fixture-user',
      ),
      isFalse,
    );
    expect(provider.error, contains('凭证保存失败'));
    expect(provider.isLoggedIn, isFalse);
  });
  test('凭证保存失败必须返回失败且保留原账号的内存登录状态', () async {
    SharedPreferences.setMockInitialValues({});
    installFakeSecureStorage();
    addTearDown(uninstallFakeSecureStorage);
    final api = KugouApiClient();
    await api.setLoginCookies('old-token', 'old-user');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => throw PlatformException(code: 'keystore-unavailable'),
        );
    await expectLater(
      api.setLoginCookies('new-token', 'new-user'),
      throwsStateError,
    );
    expect(api.userid, 'old-user');
    expect(api.isLoggedIn, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kugou_current_userid'), 'old-user');
  });
}
