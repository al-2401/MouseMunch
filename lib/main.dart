import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MouseMunchApp());
}

/// Небольшая игра: мышка бегает по полу и подбирает крошки из кормушки.
class MouseMunchApp extends StatelessWidget {
  const MouseMunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MouseMunch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB07B48),
          brightness: Brightness.dark,
        ),
      ),
      home: const GameScreen(),
    );
  }
}
