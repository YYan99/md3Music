import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:md3music/providers/kugou_provider.dart';
import 'package:md3music/services/kugou_api/kugou_api_client.dart';
import 'package:md3music/services/kugou_api/kugou_endpoints.dart';

/// 独立测试入口：只替换远端响应，使用发布配置的真实钥匙串和应用偏好。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final inset = await const MethodChannel(
      'md3music/macos_titlebar',
    ).invokeMethod<double>('getInset');
    if (inset == null || inset <= 0) throw StateError('窗口未给红黄绿按钮预留安全区');
    const user = 'macos-ci-fixture';
    const token = 'fixture-session';
    final api = KugouApiClient();
    api.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (req, next) {
          next.resolve(
            Response(
              requestOptions: req,
              statusCode: 200,
              data: {
                'status': 1,
                'data': req.path == KugouEndpoints.loginCellphone
                    ? {'userid': user, 'token': token}
                    : <String, dynamic>{},
              },
            ),
          );
        },
      ),
    );
    final mode = Platform.environment['MD3_LOGIN_RESTART_PHASE'];
    if (mode == 'write') {
      final provider = KugouProvider(registerDeviceOnStart: false);
      if (await api.isLoggedInWhenReady()) throw StateError('测试环境已有登录账号');
      final result = await provider.loginByPhone('00000000000', '000000');
      if (result.status != PhoneLoginStatus.success || !provider.isLoggedIn) {
        throw StateError('测试凭据未能保存：${provider.error}');
      }
    } else if (mode == 'restore') {
      final provider = KugouProvider();
      if (!await api.isLoggedInWhenReady() ||
          api.token != token ||
          api.userid != user ||
          api.vipToken != null) {
        throw StateError('重启后未恢复测试凭据');
      }
      for (var i = 0; !provider.isLoggedIn && i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!provider.isLoggedIn) throw StateError('账号页面仍为未登录');
      await api.clearCookies();
    } else {
      throw StateError('缺少测试阶段');
    }
    stdout.writeln('MD3_LOGIN_TEST_OK=$mode');
    await stdout.flush();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exit(1);
  }
}
