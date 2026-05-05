import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Iniciando app...');

  try {
    print('📱 Inicializando Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase inicializado correctamente');
  } catch (e) {
    print('❌ Error inicializando Firebase: $e');
  }

  print('🎯 Ejecutando runApp...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏠 Construyendo MyApp...');
    return MaterialApp(
      title: 'Tekos Gym',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
