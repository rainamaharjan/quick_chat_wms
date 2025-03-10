import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/quick_chat_wms.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

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
        appBar: AppBar(
          title: const Text('Title'),
          backgroundColor: Colors.blueAccent,
        ),
        body: InkWell(
              onTap: () {
                QuickChat.init(context,
                    widgetCode: 'YOUR-WIDGET-CODE',
                    fcmServerKey: 'YOUR-FCM-SERVER-KEY',
                    appBarBackgroundColor: const Color(0XFF0066B3));
              },
              child: //YOUR Container
       ),
    );
  }
}
