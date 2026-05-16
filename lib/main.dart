import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/app_widget.dart';
import 'core/services/order_cleanup_job.dart';
import 'core/services/pet_provider.dart';
import 'core/services/product_provider.dart';
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

  // Pre-load pets into PetProvider (single source of truth)
  PetProvider.instance.loadPets();

  // Pre-load products into ProductProvider (single source of truth)
  ProductProvider.instance.loadProducts();

  runApp(const AppWidget());
}
