import 'package:flutter/material.dart';

void main() {
  runApp(const FridgoApp());
}

class FridgoApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridgo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const Scaffold(body: Center(child: Text('Fridgo'))),
    );
  }
}
