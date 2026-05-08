import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/collaboration_controller.dart';
import 'src/finance_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final financeController = await FinanceController.load();
  final collaborationController =
      await CollaborationController.load(financeController);
  runApp(
    HomeFinanceApp(
      controller: financeController,
      collaborationController: collaborationController,
    ),
  );
}
