import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:visionverse_ai/home_page.dart';
import 'package:visionverse_ai/static_values.dart';
import 'dart:io';

Future<void> main() async{
  const apiKey = StaticValues.apiKey;
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  Gemini.init(apiKey: apiKey);
  Platform.environment[apiKey];
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: "OpenSans",
        primaryColor: const Color(0xFF075E54),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF128C7E),
        ),
      ),
      home: const HomePage(),
    );
  }
}
