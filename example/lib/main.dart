import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_idnow/flutter_idnow.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    initIdNow();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initIdNow() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      var response = await FlutterIdnow.startIdentification(providerId: "TS2-AFHCH", providerCompanyId: "expvodenovi");
      if (kDebugMode) {
        print("response");
        print(response);
      }
    } on PlatformException {
      if (kDebugMode) {
        print("issue with idnow plugin");
      }
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: InkWell(
              onTap: (){
                    initIdNow();
              },
              child: const Text("idnow test"
              )
          ),
        ),
      ),
    );
  }
}
