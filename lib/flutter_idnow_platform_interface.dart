import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_idnow_method_channel.dart';

abstract class FlutterIdnowPlatform extends PlatformInterface {
  /// Constructs a FlutterIdnowPlatform.
  FlutterIdnowPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterIdnowPlatform _instance = MethodChannelFlutterIdnow();

  /// The default instance of [FlutterIdnowPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterIdnow].
  static FlutterIdnowPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterIdnowPlatform] when
  /// they register themselves.
  static set instance(FlutterIdnowPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
