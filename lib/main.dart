import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/app_widget.dart';
import 'core/services/order_cleanup_job.dart';
import 'features/auth/services/auth_session.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");
  await AuthSession.instance.load();

  // Start background job to auto-cancel unpaid orders after 24h
  OrderCleanupJob.instance.start();

  runApp(const AppWidget());
}
