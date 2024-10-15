import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_idnow/flutter_idnow.dart';
import 'package:flutter_idnow/flutter_idnow_platform_interface.dart';
import 'package:flutter_idnow/flutter_idnow_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterIdnowPlatform
    with MockPlatformInterfaceMixin
    implements FlutterIdnowPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterIdnowPlatform initialPlatform = FlutterIdnowPlatform.instance;

  test('$MethodChannelFlutterIdnow is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterIdnow>());
  });

  test('getPlatformVersion', () async {
    FlutterIdnow flutterIdnowPlugin = FlutterIdnow();
    MockFlutterIdnowPlatform fakePlatform = MockFlutterIdnowPlatform();
    FlutterIdnowPlatform.instance = fakePlatform;

    expect(await FlutterIdnow.startIdentification(providerId: "", providerCompanyId: ""), '42');
  });
}
