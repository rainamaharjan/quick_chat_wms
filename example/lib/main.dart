import 'package:flutter/material.dart';
import 'package:quick_chat_wms/quick_chat_wms.dart';

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
    QuickChatWms.init(
      context,
      widgetCode: 'eb1fc3ee-7fc0-4a1c-b136-6a6106a72477',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Quick Chat WMS Test')),
        body: QuickChatWms.screen,
      ),
    );
  }
}
