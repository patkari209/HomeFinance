import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:home_finance/src/app.dart';
import 'package:home_finance/src/finance_controller.dart';
import 'package:home_finance/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parser detects grocery-style import fields', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await FinanceController.load();

    final parsed = controller.parseExpenseMessage(
      'Card spent INR 1299.50 at Fresh Mart on 03/04/2026 using UPI',
      country: 'India',
      currencyCode: 'INR',
    );

    expect(parsed.amount, 1299.50);
    expect(parsed.category, ExpenseCategory.foodGroceries);
    expect(parsed.paymentChannel, 'UPI');
    expect(parsed.date, DateTime(2026, 4, 3));
  });

  testWidgets('app shows finance dashboard and expenses tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await FinanceController.load();

    await tester.pumpWidget(
      HomeFinanceApp(
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home Finance'), findsOneWidget);
    expect(find.text('Set up your first currency ledger'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'SGD');
    await tester.enterText(find.byType(TextField).at(1), 'Singapore Wallet');
    await tester.tap(find.text('Start with this currency'));
    await tester.pumpAndSettle();

    expect(find.text('Net Worth Snapshot'), findsOneWidget);

    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Expenses'), findsOneWidget);
    expect(find.text('Import message'), findsOneWidget);
    expect(find.byTooltip('Add entry'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    controller.dispose();
  });

  test('scheduled EMI automatically appears in monthly expense ledger', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await FinanceController.load();
    await controller.initializeFirstLedger(
      currencyCode: 'SGD',
      displayName: 'Singapore Wallet',
    );

    await controller.addScheduledEmi(
      ledgerId: controller.selectedLedgerId,
      currencyCode: controller.selectedCurrencyCode,
      name: 'Home loan EMI',
      merchant: 'DBS Loan',
      amount: 1200,
      dayOfMonth: 8,
      startMonth: DateTime(2026, 4),
      notes: 'Recurring housing EMI',
      paidByKind: PaymentSourceKind.bank,
      bankName: 'DBS',
    );

    final expenses = controller.expensesForSelectedLedgerInMonth(DateTime(2026, 4));

    expect(expenses, isNotEmpty);
    expect(expenses.first.subtype, ExpenseSubtype.emi);
    expect(expenses.first.isScheduledEmiGenerated, isTrue);
    expect(
      controller.totalExpenseForLedgerInMonth(
        controller.selectedLedgerId,
        DateTime(2026, 4),
      ),
      equals(1200),
    );
  });

  test('forex transfer report tracks SGD to INR totals', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await FinanceController.load();

    await controller.addForexTransfer(
      transferDate: DateTime(2026, 4, 9),
      fromCountry: 'Singapore',
      fromCurrencyCode: 'SGD',
      fromAmount: 250,
      toCountry: 'India',
      toCurrencyCode: 'INR',
      toAmount: 15500,
      notes: 'April transfer',
    );

    final report = controller.forexTransferReport();

    expect(report.totalFromAmount, equals(250));
    expect(report.totalToAmount, equals(15500));
    expect(report.monthTotals.any((item) => item.label.contains('2026-04')), isTrue);
  });
}
