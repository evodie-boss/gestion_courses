// lib/test_course_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // généré par FlutterFire CLI
import 'pages/course_list_screen.dart'; // ton écran principal

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase pour le Web et mobile
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TestCourseApp());
}

class TestCourseApp extends StatelessWidget {
  const TestCourseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Courses - Test',
      theme: ThemeData(
        primaryColor: Colors.blueAccent,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      // Ici tu peux mettre directement ton CourseListScreen
      home: const CourseListScreen(),
    );
  }
}
