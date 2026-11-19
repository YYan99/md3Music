import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 让页面背景延伸到标题栏，同时让顶栏和安全区内的按钮避开窗口控件。
class MacosTitlebarInsets extends StatefulWidget {
  const MacosTitlebarInsets({super.key, required this.child});
  final Widget child;

  @override
  State<MacosTitlebarInsets> createState() => _MacosTitlebarInsetsState();
}

class _MacosTitlebarInsetsState extends State<MacosTitlebarInsets> {
  static const _channel = MethodChannel('md3music/macos_titlebar');
  double _top = 0;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'insetChanged') _update(call.arguments as double?);
    });
    _channel.invokeMethod<double>('getInset').then(_update);
  }

  void _update(double? value) {
    if (mounted && value != null && value != _top) setState(() => _top = value);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: math.max(media.padding.top, _top)),
        viewPadding: media.viewPadding.copyWith(
          top: math.max(media.viewPadding.top, _top),
        ),
      ),
      child: widget.child,
    );
  }
}
