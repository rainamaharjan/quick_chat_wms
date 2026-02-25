import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'quick_chat_wms_method_channel.dart';

abstract class QuickChatWmsPlatform extends PlatformInterface {
  /// Constructs a QuickChatWmsPlatform.
  QuickChatWmsPlatform() : super(token: _token);

  static final Object _token = Object();

  static QuickChatWmsPlatform _instance = MethodChannelQuickChatWms();

  /// The default instance of [QuickChatWmsPlatform] to use.
  ///
  /// Defaults to [MethodChannelQuickChatWms].
  static QuickChatWmsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QuickChatWmsPlatform] when
  /// they register themselves.
  static set instance(QuickChatWmsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
