import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/finance_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final financeController = await FinanceController.load();
  runApp(
    HomeFinanceApp(
      controller: financeController,
    ),
  );
}
