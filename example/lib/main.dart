import 'package:flutter/material.dart';
import 'package:quick_chat_wms/quick_chat_wms.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          // isExtended: true,
          child: Icon(Icons.ac_unit),
          backgroundColor: Colors.blueAccent,
          onPressed: () {
            QuickChat.resetUser();
          },
        ),
        appBar: AppBar(
          title: const Text('Chat Inbox'),
          backgroundColor: Colors.blueAccent,
          centerTitle: true,
        ),
        body: const QuickChatWidget(id: ""));
  }
}
