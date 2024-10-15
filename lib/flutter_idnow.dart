
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterIdnow {
  static const MethodChannel _channel =
   MethodChannel('flutter_idnow');

  static Future<String> removeHeader() async {
    final String version = await _channel.invokeMethod('removeHeader');
    return version;
  }

  static Future<String?> startIdentification({required String providerId,required providerCompanyId}) async {
    try {
      Map<String, dynamic> arguments = <String, dynamic> {};
      arguments.putIfAbsent("providerId", () => providerId);
      arguments.putIfAbsent("providerCompanyId", () => providerCompanyId);
      final String response = await _channel.invokeMethod('startIdentification', arguments);
      return response;

    } catch(e) {
      return e.toString();
    }
  }
  static Future<bool?> setShowVideoOverviewCheck(bool flag) async {
    try {
      Map<String, dynamic> arguments = <String, bool> {};
      arguments.putIfAbsent("setShowVideoFlag", () => flag);
      final bool version = await _channel.invokeMethod('setShowVideoOverviewCheck', arguments);
      return version;
    } catch(e) {
      return false;
    }
  }

}
