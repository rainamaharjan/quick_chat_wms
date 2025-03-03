import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:quick_chat_wms/quick_chat_wms.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
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
        body: Container(
          child: InkWell(
              onTap: () {
                QuickChat.init(context,'',appBarTitle: "this is test");
              },
              child: Center(child: Text('Click me to navigate',))),
        ));
  }
}