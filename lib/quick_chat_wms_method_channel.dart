import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quick_chat_wms_platform_interface.dart';

/// An implementation of [QuickChatWmsPlatform] that uses method channels.
class MethodChannelQuickChatWms extends QuickChatWmsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('quick_chat_wms');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
