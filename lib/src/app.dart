import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_service.dart';
import 'finance_controller.dart';
import 'models.dart';

class HomeFinanceApp extends StatelessWidget {
  const HomeFinanceApp({
    super.key,
    required this.controller,
  });

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF124559),
        primary: const Color(0xFF124559),
        secondary: const Color(0xFFD88C51),
        surface: const Color(0xFFF7F3EB),
      ),
      scaffoldBackgroundColor: const Color(0xFFF3EEE3),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(0xFFF3EEE3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Finance',
      theme: theme,
      home: FinanceHome(
        controller: controller,
      ),
    );
  }
}

class FinanceHome extends StatefulWidget {
  const FinanceHome({
    super.key,
    required this.controller,
  });

  final FinanceController controller;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [
          widget.controller,
        ],
      ),
      builder: (context, _) {
        if (!widget.controller.settings.hasLedgers) {
          return LedgerSetupScreen(controller: widget.controller);
        }

        final screens = <Widget>[
          DashboardScreen(controller: widget.controller),
          ExpensesScreen(
            controller: widget.controller,
          ),
          ReportsScreen(controller: widget.controller),
          ForexTransferScreen(controller: widget.controller),
          ReviewScreen(controller: widget.controller),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Home Finance'),
            actions: [
              IconButton(
                onPressed: () => _showQuickAddSheet(context),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add entry',
              ),
              IconButton(
                onPressed: () => _showSettingsSheet(context),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _MonthNavigatorBar(controller: widget.controller),
                Expanded(child: screens[_currentIndex]),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Expense',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Reports',
              ),
              NavigationDestination(
                icon: Icon(Icons.currency_exchange_outlined),
                selectedIcon: Icon(Icons.currency_exchange),
                label: 'FXfer',
              ),
              NavigationDestination(
                icon: Icon(Icons.rule_folder_outlined),
                selectedIcon: Icon(Icons.rule_folder),
                label: 'Review',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSettingsSheet(BuildContext context) async {
    final currencyController = TextEditingController();
    final nameController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final ledgers = widget.controller.currencyLedgers
                .map(
                  (item) => CurrencyLedgerProfile(
                    id: item.id,
                    currencyCode: item.currencyCode,
                    displayName: item.displayName,
                  ),
                )
                .toList();
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Currency Ledgers',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Each currency acts as its own subtenant ledger. Dashboard and reports stay inside the selected currency.',
                    ),
                    const SizedBox(height: 16),
                    if (ledgers.isEmpty)
                      const Text('No ledgers added yet.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ledgers
                            .map(
                              (ledger) => InputChip(
                                label: Text(
                                  '${ledger.displayName} (${ledger.currencyCode})',
                                ),
                                selected: widget.controller.selectedLedgerId == ledger.id,
                                onPressed: () async {
                                  await widget.controller.setSelectedLedger(ledger.id);
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: currencyController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Currency code',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ledger display name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        final currency = currencyController.text.trim().toUpperCase();
                        if (currency.isEmpty) return;
                        await widget.controller.addCurrencyLedger(
                          currencyCode: currency,
                          displayName: nameController.text.trim(),
                        );
                        currencyController.clear();
                        nameController.clear();
                        setSheetState(() {});
                      },
                      child: const Text('Add currency ledger'),
                    ),
                    const SizedBox(height: 24),
                    _EditableStringSettingsSection(
                      title: 'Merchants',
                      subtitle: 'Add merchants like MacD or Uniqlo for expense selection.',
                      addLabel: 'Add merchant',
                      items: widget.controller.merchants,
                      onAdd: (value) async {
                        await widget.controller.updateMasterData(
                          merchants: [...widget.controller.merchants, value],
                        );
                        setSheetState(() {});
                      },
                      onDelete: (value) async {
                        await widget.controller.updateMasterData(
                          merchants: widget.controller.merchants
                              .where((item) => item != value)
                              .toList(),
                        );
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    _EditableStringSettingsSection(
                      title: 'Food & Groceries Items',
                      subtitle: 'Use these as quick comment items like FairPrice, Bakery, India Mart.',
                      addLabel: 'Add food/grocery item',
                      items: widget.controller.foodGroceriesItems,
                      onAdd: (value) async {
                        await widget.controller.updateMasterData(
                          foodGroceriesItems: [
                            ...widget.controller.foodGroceriesItems,
                            value,
                          ],
                        );
                        setSheetState(() {});
                      },
                      onDelete: (value) async {
                        await widget.controller.updateMasterData(
                          foodGroceriesItems: widget.controller.foodGroceriesItems
                              .where((item) => item != value)
                              .toList(),
                        );
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    _EditableStringSettingsSection(
                      title: 'Banks',
                      subtitle: 'Maintain the bank list used in expense payment details.',
                      addLabel: 'Add bank',
                      items: widget.controller.banks,
                      onAdd: (value) async {
                        await widget.controller.updateMasterData(
                          banks: [...widget.controller.banks, value],
                        );
                        setSheetState(() {});
                      },
                      onDelete: (value) async {
                        await widget.controller.updateMasterData(
                          banks: widget.controller.banks
                              .where((item) => item != value)
                              .toList(),
                        );
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    _EditableStringSettingsSection(
                      title: 'Cards',
                      subtitle: 'Maintain the card list used in expense payment details.',
                      addLabel: 'Add card',
                      items: widget.controller.cards,
                      onAdd: (value) async {
                        await widget.controller.updateMasterData(
                          cards: [...widget.controller.cards, value],
                        );
                        setSheetState(() {});
                      },
                      onDelete: (value) async {
                        await widget.controller.updateMasterData(
                          cards: widget.controller.cards
                              .where((item) => item != value)
                              .toList(),
                        );
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Backup & restore',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'JSON contains all records for full device-to-device backup. '
                      'CSV is expenses only for Excel or Sheets.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _exportBackupJson(context),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export full backup (JSON)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _exportExpensesCsv(context),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Export expenses (CSV)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _importBackupJson(context, setSheetState),
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Import full backup (JSON)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _importExpensesCsv(context, setSheetState),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Merge expenses from CSV'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportBackupJson(BuildContext context) async {
    try {
      final payload = BackupService.exportFullJson(widget.controller.data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/home_finance_backup.json');
      await file.writeAsString(payload);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Home Finance backup',
        text: 'Home Finance full backup (JSON)',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportExpensesCsv(BuildContext context) async {
    try {
      final csv = BackupService.exportExpensesCsv(widget.controller.data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/home_finance_expenses.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Home Finance expenses',
        text: 'Expense entries (CSV)',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackupJson(
    BuildContext context,
    void Function(void Function()) setSheetState,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'This removes existing finance data on this device and replaces it with the backup file.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final raw = utf8.decode(bytes);
      final data = BackupService.importFullJson(raw);
      await widget.controller.replaceAllData(data, recordId: 'file-import');
      setSheetState(() {});
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup imported.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importExpensesCsv(
    BuildContext context,
    void Function(void Function()) setSheetState,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    List<ExpenseEntry> parsed;
    try {
      parsed = BackupService.importExpensesCsv(utf8.decode(bytes));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read CSV: $e')),
        );
      }
      return;
    }
    if (parsed.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid expense rows in file.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge expense rows?'),
        content: Text(
          'Upsert ${parsed.length} expenses by id. Existing ids will be updated; new ids will be added.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Merge')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await widget.controller.mergeImportedExpenses(parsed);
    setSheetState(() {});
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merged ${parsed.length} expense rows.')),
      );
    }
  }

  Future<void> _showQuickAddSheet(BuildContext context) async {
    final controller = widget.controller;
    if (controller.selectedLedger == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Manual expense entry'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showManualExpenseSheet(context, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Add earning'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEarningSheet(context, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: const Text('Add savings'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSavingsSheet(context, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_up_outlined),
                title: const Text('Add investment'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showInvestmentSheet(context, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Add asset'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAssetSheet(context, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_score_outlined),
                title: const Text('Add liability'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showLiabilitySheet(context, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: const Text('Add scheduled EMI'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showScheduledEmiSheet(context, controller);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class LedgerSetupScreen extends StatefulWidget {
  const LedgerSetupScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<LedgerSetupScreen> createState() => _LedgerSetupScreenState();
}

class _LedgerSetupScreenState extends State<LedgerSetupScreen> {
  final _currencyController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Finance')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set up your first currency ledger',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No default currency is preloaded. Add the first currency you want to use in Home Finance.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _currencyController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Currency code'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Ledger name'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        final currency = _currencyController.text.trim().toUpperCase();
                        if (currency.isEmpty) return;
                        await widget.controller.initializeFirstLedger(
                          currencyCode: currency,
                          displayName: _nameController.text.trim(),
                        );
                      },
                      child: const Text('Start with this currency'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthNavigatorBar extends StatelessWidget {
  const _MonthNavigatorBar({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = controller.selectedMonth;
    final label =
        '${m.year}-${m.month.toString().padLeft(2, '0')}';
    return Material(
      elevation: 0,
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => controller.setSelectedMonth(DateTime(m.year, m.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: m,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDatePickerMode: DatePickerMode.year,
                  );
                  if (picked != null) {
                    await controller.setSelectedMonth(DateTime(picked.year, picked.month));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                      ),
                      Text(
                        'Dashboard · Expense · Reports scope',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => controller.setSelectedMonth(DateTime(m.year, m.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.dashboardSummary(forMonth: controller.selectedMonth);
    final currency = summary.currencyCode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroSummary(
          currencyCode: currency,
          netWorth: summary.netWorth,
          totalAssets: summary.totalAssets,
          totalLiabilities: summary.totalLiabilities,
          currentMonthEarnings: summary.currentMonthEarnings,
          currentMonthSpend: summary.currentMonthSpend,
          currentMonthRemaining: summary.currentMonthRemaining,
          currentMonthSavings: summary.currentMonthSavings,
          currentMonthInvestments: summary.currentMonthInvestments,
          totalInvestments: summary.totalInvestments,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Investments',
          subtitle:
              'Entries for ${controller.selectedMonth.year}-${controller.selectedMonth.month.toString().padLeft(2, '0')} in $currency',
          child: Column(
            children: [
              _BreakdownList(items: summary.investmentBreakdown, currencyCode: currency),
              const Divider(height: 24),
              _EditableLedgerList(
                emptyText: 'No investments added yet.',
                items: controller.investmentsForSelectedLedgerInSelectedMonth
                    .map(
                      (item) => _EditableLedgerItem(
                        title: item.type.label,
                        subtitle:
                            '${item.currencyCode} ${item.nativeAmount.toStringAsFixed(2)} • ${_formatDate(item.month)}'
                            '${item.notes.isNotEmpty ? ' • ${item.notes}' : ''}',
                        onEdit: () => _showInvestmentSheet(context, controller, item),
                        onDelete: () => _confirmDelete(
                          context,
                          title: 'Delete investment entry?',
                          onDelete: () => controller.deleteInvestmentEntry(item.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Assets',
          subtitle:
              'Valuation dated in ${controller.selectedMonth.year}-${controller.selectedMonth.month.toString().padLeft(2, '0')} • $currency',
          child: Column(
            children: [
              _BreakdownList(items: summary.assetBreakdown, currencyCode: currency),
              const Divider(height: 24),
              _EditableLedgerList(
                emptyText: 'No assets added yet.',
                items: controller.assetsForSelectedLedgerInSelectedMonth
                    .map(
                      (item) => _EditableLedgerItem(
                        title: item.name,
                        subtitle:
                            '${item.type.label} • ${item.currencyCode} ${item.nativeValue.toStringAsFixed(2)}',
                        onEdit: () => _showAssetSheet(context, controller, item),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Liabilities',
          subtitle:
              'Due date in selected month (entries without due date show only for current calendar month) • $currency',
          child: Column(
            children: [
              _BreakdownList(items: summary.liabilityBreakdown, currencyCode: currency),
              const Divider(height: 24),
              _EditableLedgerList(
                emptyText: 'No liabilities added yet.',
                items: controller.liabilitiesForSelectedLedgerInSelectedMonth
                    .map(
                      (item) => _EditableLedgerItem(
                        title: item.name,
                        subtitle:
                            '${item.type.label} • ${item.currencyCode} ${item.nativeOutstanding.toStringAsFixed(2)}',
                        onEdit: () => _showLiabilitySheet(context, controller, item),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Scheduled EMI',
          subtitle:
              'Recurring EMI plans active for ${controller.selectedMonth.year}-${controller.selectedMonth.month.toString().padLeft(2, '0')} in $currency',
          child: _EditableLedgerList(
            emptyText: 'No scheduled EMI plans added yet.',
            items: controller.scheduledEmisForSelectedLedgerInSelectedMonth
                .map(
                  (item) => _EditableLedgerItem(
                    title: item.name,
                    subtitle:
                        '${item.currencyCode} ${item.amount.toStringAsFixed(2)} • day ${item.dayOfMonth}'
                        '${item.merchant.isNotEmpty ? ' • ${item.merchant}' : ''}'
                        '${item.bankName.isNotEmpty ? ' • ${item.bankName}' : ''}'
                        '${item.cardName.isNotEmpty ? ' • ${item.cardName}' : ''}',
                    onEdit: () => _showScheduledEmiSheet(context, controller, item),
                    onDelete: () => _confirmDelete(
                      context,
                      title: 'Delete scheduled EMI?',
                      onDelete: () => controller.deleteScheduledEmi(item.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Monthly Earnings',
          subtitle: 'Editable monthly income entries',
          child: _EditableLedgerList(
            emptyText: 'No earnings added yet.',
            items: controller.earningsForSelectedLedgerInSelectedMonth
                .map(
                  (item) => _EditableLedgerItem(
                    title: item.source.label,
                    subtitle:
                        '${item.currencyCode} ${item.nativeAmount.toStringAsFixed(2)} • ${item.month.year}-${item.month.month.toString().padLeft(2, '0')}',
                    onEdit: () => _showEarningSheet(context, controller, item),
                    onDelete: () => _confirmDelete(
                      context,
                      title: 'Delete earning?',
                      onDelete: () => controller.deleteEarningRecord(item.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Monthly Savings',
          subtitle: 'Manual or derived savings entries',
          child: _EditableLedgerList(
            emptyText: 'No savings added yet.',
            items: controller.savingsForSelectedLedgerInSelectedMonth
                .map(
                  (item) => _EditableLedgerItem(
                    title: item.source.label,
                    subtitle:
                        '${item.currencyCode} ${item.nativeAmount.toStringAsFixed(2)} • ${item.month.year}-${item.month.month.toString().padLeft(2, '0')}',
                    onEdit: () => _showSavingsSheet(context, controller, item),
                    onDelete: () => _confirmDelete(
                      context,
                      title: 'Delete savings?',
                      onDelete: () => controller.deleteSavingsRecord(item.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ExpenseMonthTrendStrip extends StatelessWidget {
  const _ExpenseMonthTrendStrip({
    required this.currencyCode,
    required this.monthA,
    required this.monthB,
    required this.monthC,
    required this.totalA,
    required this.totalB,
    required this.totalC,
  });

  final String currencyCode;
  final DateTime monthA;
  final DateTime monthB;
  final DateTime monthC;
  final double totalA;
  final double totalB;
  final double totalC;

  String _label(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TrendMonthCell(
              label: _label(monthA),
              value: '$currencyCode ${totalA.toStringAsFixed(2)}',
              emphasized: false,
            ),
          ),
          Expanded(
            child: _TrendMonthCell(
              label: _label(monthB),
              value: '$currencyCode ${totalB.toStringAsFixed(2)}',
              emphasized: false,
            ),
          ),
          Expanded(
            child: _TrendMonthCell(
              label: _label(monthC),
              value: '$currencyCode ${totalC.toStringAsFixed(2)}',
              emphasized: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendMonthCell extends StatelessWidget {
  const _TrendMonthCell({
    required this.label,
    required this.value,
    required this.emphasized,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: emphasized ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 13 : 11,
            color: emphasized ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({
    super.key,
    required this.controller,
  });

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final expenses = controller.expensesForSelectedLedgerInSelectedMonth;
    final today = DateTime.now();
    final inCurrentCalendarMonth = controller.isSelectedMonthCurrentCalendarMonth;
    final todayExpenses = inCurrentCalendarMonth
        ? expenses.where((item) {
            return item.transactionDate.year == today.year &&
                item.transactionDate.month == today.month &&
                item.transactionDate.day == today.day;
          }).toList()
        : <ExpenseEntry>[];
    final todayTotal = todayExpenses.fold<double>(0, (sum, item) => sum + item.nativeAmount);
    final currency = controller.selectedCurrencyCode;
    final m = controller.selectedMonth;
    final m0 = DateTime(m.year, m.month - 2);
    final m1 = DateTime(m.year, m.month - 1);
    final t0 = controller.totalExpenseForLedgerInMonth(controller.selectedLedgerId, m0);
    final t1 = controller.totalExpenseForLedgerInMonth(controller.selectedLedgerId, m1);
    final t2 = controller.totalExpenseForLedgerInMonth(controller.selectedLedgerId, m);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(
          title: 'Daily Expenses',
          subtitle: 'Use the top-right plus button for new entries. Imported bank/SMS messages can still be pasted here inside the selected currency ledger.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showImportMessageSheet(context, controller),
          icon: const Icon(Icons.sms_outlined),
          label: const Text('Import message'),
        ),
        const SizedBox(height: 16),
        _ExpenseMonthTrendStrip(
          currencyCode: currency,
          monthA: m0,
          monthB: m1,
          monthC: m,
          totalA: t0,
          totalB: t1,
          totalC: t2,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: inCurrentCalendarMonth ? 'Today total expense' : 'Selected day total',
          subtitle: inCurrentCalendarMonth
              ? 'Current day spend in $currency (month ${m.year}-${m.month.toString().padLeft(2, '0')})'
              : 'Day total is only shown when the top month is the current calendar month',
          child: _MetricRow(
            label: 'Total',
            value: inCurrentCalendarMonth
                ? '$currency ${todayTotal.toStringAsFixed(2)}'
                : '$currency 0.00',
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Expense ledger',
          subtitle:
              '${expenses.length} entries in ${m.year}-${m.month.toString().padLeft(2, '0')} • ${controller.selectedLedger?.displayName ?? currency}',
          child: expenses.isEmpty
              ? const Text('No expenses added yet.')
              : Column(
                  children: List.generate(expenses.length, (index) {
                    final expense = expenses[index];
                    return Container(
                      color: index.isEven
                          ? Colors.transparent
                          : const Color(0xFFF8F3EA),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          expense.merchant.isEmpty ? expense.category.label : expense.merchant,
                        ),
                        subtitle: Text(
                          '${expense.category.label}'
                          '${expense.subtype != null ? ' • ${expense.subtype!.label}' : ''}'
                          '${expense.utilityType != null ? ' • ${expense.utilityType!.label}' : ''}'
                          '${expense.isScheduledEmiGenerated ? ' • Auto scheduled' : ''}'
                          '${expense.bankName.isNotEmpty ? ' • ${expense.bankName}' : ''}'
                          '${expense.cardName.isNotEmpty ? ' • ${expense.cardName}' : ''}'
                          '${expense.paymentChannel.isNotEmpty ? ' • ${expense.paymentChannel}' : ''}'
                          ' • ${_formatDate(expense.transactionDate)}'
                          '${expense.notes.isNotEmpty ? ' • ${expense.notes}' : ''}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              if (expense.isScheduledEmiGenerated) {
                                final schedule = controller.scheduledEmiById(
                                  expense.scheduledEmiPlanId,
                                );
                                if (schedule != null) {
                                  _showScheduledEmiSheet(context, controller, schedule);
                                }
                              } else {
                                _showManualExpenseSheet(context, controller, expense);
                              }
                            } else if (value == 'delete') {
                              _confirmDelete(
                                context,
                                title: expense.isScheduledEmiGenerated
                                    ? 'Delete scheduled EMI?'
                                    : 'Delete expense?',
                                onDelete: () => expense.isScheduledEmiGenerated
                                    ? controller.deleteScheduledEmi(
                                        expense.scheduledEmiPlanId,
                                      )
                                    : controller.deleteExpense(expense.id),
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                            PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              '${expense.currencyCode} ${expense.nativeAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.controller.selectedMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final monthScope = widget.controller.selectedMonth;
    final monthly = widget.controller.monthlyReport(monthScope);
    final yearly = widget.controller.yearlyReport(_year);
    final currency = widget.controller.selectedCurrencyCode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(
          title: 'Monthly and Yearly Reports',
          subtitle:
              'Reports stay inside the selected currency ledger. No cross-currency totals are combined here.',
          icon: Icons.pie_chart_outline,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MonthPickerCard(
                month: monthScope,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: monthScope,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDatePickerMode: DatePickerMode.year,
                  );
                  if (picked != null) {
                    await widget.controller.setSelectedMonth(
                      DateTime(picked.year, picked.month),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _YearPickerCard(
                year: _year,
                onIncrement: () => setState(() => _year += 1),
                onDecrement: () => setState(() => _year -= 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Monthly report',
          subtitle:
              'For ${monthScope.year}-${monthScope.month.toString().padLeft(2, '0')} in $currency',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricRow(
                label: 'Total earnings',
                value: '$currency ${monthly.totalEarnings.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Total expense',
                value: '$currency ${monthly.totalExpense.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Remaining balance',
                value: '$currency ${monthly.remainingBalance.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Savings entries',
                value: '$currency ${monthly.totalSavings.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Investments',
                value: '$currency ${monthly.totalInvestments.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Manual savings',
                value: '$currency ${monthly.manualSavings.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Derived savings',
                value: '$currency ${monthly.derivedSavings.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Asset snapshot',
                value: '$currency ${monthly.assetTotal.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Liability snapshot',
                value: '$currency ${monthly.liabilityTotal.toStringAsFixed(2)}',
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Expense by category',
                child: _BreakdownList(items: monthly.categoryTotals, currencyCode: currency),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Utility breakdown',
                child: _BreakdownList(items: monthly.utilityTotals, currencyCode: currency),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Savings allocation breakdown',
                child: _BreakdownList(
                  items: monthly.allocationTotals,
                  currencyCode: currency,
                ),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Investment breakdown',
                child: _BreakdownList(
                  items: monthly.investmentTotals,
                  currencyCode: currency,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Yearly report',
          subtitle: 'For $_year in $currency',
          child: Column(
            children: [
              _MetricRow(
                label: 'Year-end assets',
                value: '$currency ${yearly.assetTotal.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Year-end liabilities',
                value: '$currency ${yearly.liabilityTotal.toStringAsFixed(2)}',
              ),
              _MetricRow(
                label: 'Net worth',
                value: '$currency ${yearly.netWorth.toStringAsFixed(2)}',
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Earnings by month',
                child: _BreakdownList(items: yearly.earningsMonthTotals, currencyCode: currency),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Expenses by month',
                child: _BreakdownList(items: yearly.expenseMonthTotals, currencyCode: currency),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Remaining balance by month',
                child: _BreakdownList(
                  items: yearly.remainingMonthTotals,
                  currencyCode: currency,
                ),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Category trend',
                child: _BreakdownList(items: yearly.categoryTotals, currencyCode: currency),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Savings trend',
                child: _BreakdownList(items: yearly.savingsTotals, currencyCode: currency),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Allocation trend',
                child: _BreakdownList(items: yearly.allocationTotals, currencyCode: currency),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Investments by month',
                child: _BreakdownList(
                  items: yearly.investmentMonthTotals,
                  currencyCode: currency,
                ),
              ),
              const Divider(height: 24),
              _BreakdownSection(
                title: 'Investments by type',
                child: _BreakdownList(
                  items: yearly.investmentTypeTotals,
                  currencyCode: currency,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ForexTransferScreen extends StatelessWidget {
  const ForexTransferScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final report = controller.forexTransferReportForSelectedMonth();
    final transfers = controller.forexTransfersInSelectedMonth;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(
          title: 'Forex Transfer',
          subtitle:
              'This is the only tab that keeps cross-currency transfer and FX behavior.',
          icon: Icons.currency_exchange,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _showForexTransferSheet(context, controller),
          icon: const Icon(Icons.add),
          label: const Text('Add forex transfer'),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Transfer summary',
          subtitle:
              'Totals for ${controller.selectedMonth.year}-${controller.selectedMonth.month.toString().padLeft(2, '0')} only',
          child: Column(
            children: [
              _MetricRow(
                label: 'Total sent',
                value: report.totalFromAmount.toStringAsFixed(2),
              ),
              _MetricRow(
                label: 'Total received',
                value: report.totalToAmount.toStringAsFixed(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Monthly transfer report',
          subtitle: 'Selected month breakdown',
          child: _ForexBreakdownList(items: report.monthTotals),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Yearly transfer report',
          subtitle: 'How much was transferred each year',
          child: _ForexBreakdownList(items: report.yearTotals),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Transfer ledger',
          subtitle: '${transfers.length} transfers',
          child: transfers.isEmpty
              ? const Text('No forex transfers yet.')
              : Column(
                  children: transfers
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: IconButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete forex transfer?',
                              onDelete: () => controller.deleteForexTransfer(item.id),
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                          title: Text(
                            '${item.fromCurrencyCode} ${item.fromAmount.toStringAsFixed(2)} to ${item.toCurrencyCode} ${item.toAmount.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            '${_formatDate(item.transferDate)} • ${item.fromCountry.isEmpty ? 'From ledger A' : item.fromCountry} -> ${item.toCountry.isEmpty ? 'To ledger B' : item.toCountry}'
                            '${item.notes.isNotEmpty ? ' • ${item.notes}' : ''}',
                          ),
                          trailing: IconButton(
                            onPressed: () =>
                                _showForexTransferSheet(context, controller, item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.reviewQueue;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'Review Queue',
          subtitle: items.isEmpty
              ? 'No low-confidence imports right now.'
              : 'Review uncategorized or uncertain imports in the selected ledger.',
          icon: Icons.fact_check_outlined,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Needs attention',
          subtitle: '${items.length} imported entries',
          child: items.isEmpty
              ? const Text('Everything looks reviewed.')
              : Column(
                  children: items
                      .map(
                        (expense) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            expense.rawMessage.isEmpty
                                ? expense.merchant
                                : expense.rawMessage,
                          ),
                          subtitle: Text(
                            '${expense.category.label} • confidence ${(expense.confidenceScore * 100).toStringAsFixed(0)}%',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'review') {
                                _showReclassifyDialog(context, controller, expense);
                              } else if (value == 'delete') {
                                _confirmDelete(
                                  context,
                                  title: 'Delete imported expense?',
                                  onDelete: () =>
                                      controller.deleteExpense(expense.id),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'review',
                                child: Text('Review'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({
    required this.currencyCode,
    required this.netWorth,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.currentMonthEarnings,
    required this.currentMonthSpend,
    required this.currentMonthRemaining,
    required this.currentMonthSavings,
    required this.currentMonthInvestments,
    required this.totalInvestments,
  });

  final String currencyCode;
  final double netWorth;
  final double totalAssets;
  final double totalLiabilities;
  final double currentMonthEarnings;
  final double currentMonthSpend;
  final double currentMonthRemaining;
  final double currentMonthSavings;
  final double currentMonthInvestments;
  final double totalInvestments;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final columns = _responsiveGridColumns(
          constraints.maxWidth,
          compactMinWidth: compact ? 132 : 156,
          mediumMinWidth: compact ? 148 : 172,
          maxColumns: constraints.maxWidth > 900 ? 4 : 3,
        );
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF124559), Color(0xFF2C6E72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Net Worth Snapshot',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                '$currencyCode ${netWorth.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: compact ? 1.5 : 1.7,
                children: [
                  _PillMetric(
                    label: 'This month earning',
                    value: '$currencyCode ${currentMonthEarnings.toStringAsFixed(2)}',
                  ),
                  _PillMetric(
                    label: 'This month spend',
                    value: '$currencyCode ${currentMonthSpend.toStringAsFixed(2)}',
                  ),
                  _PillMetric(
                    label: 'Remaining balance',
                    value: '$currencyCode ${currentMonthRemaining.toStringAsFixed(2)}',
                  ),
                  _PillMetric(
                    label: 'Savings entries',
                    value: '$currencyCode ${currentMonthSavings.toStringAsFixed(2)}',
                  ),
                  _PillMetric(
                    label: 'This month invest',
                    value: '$currencyCode ${currentMonthInvestments.toStringAsFixed(2)}',
                  ),
                  _PillMetric(
                    label: 'Total invested',
                    value: '$currencyCode ${totalInvestments.toStringAsFixed(2)}',
                  ),
                  _PillMetric(
                    label: 'Assets',
                    value: '$currencyCode ${totalAssets.toStringAsFixed(2)}',
                  ),
                  _PillMetric(
                    label: 'Liabilities',
                    value: '$currencyCode ${totalLiabilities.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PillMetric extends StatelessWidget {
  const _PillMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        if (icon != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF124559)),
              const SizedBox(width: 8),
              const Text(
                'Finance Focus',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EditableStringSettingsSection extends StatefulWidget {
  const _EditableStringSettingsSection({
    required this.title,
    required this.subtitle,
    required this.addLabel,
    required this.items,
    required this.onAdd,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String addLabel;
  final List<String> items;
  final Future<void> Function(String value) onAdd;
  final Future<void> Function(String value) onDelete;

  @override
  State<_EditableStringSettingsSection> createState() =>
      _EditableStringSettingsSectionState();
}

class _EditableStringSettingsSectionState
    extends State<_EditableStringSettingsSection> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(labelText: widget.addLabel),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () async {
                final value = _controller.text.trim();
                if (value.isEmpty) return;
                await widget.onAdd(value);
                if (mounted) {
                  _controller.clear();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.items.isEmpty)
          const Text('No items added yet.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.items
                .map(
                  (item) => InputChip(
                    label: Text(item),
                    onDeleted: () => widget.onDelete(item),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _EditableLedgerItem {
  _EditableLedgerItem({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
}

class _EditableLedgerList extends StatelessWidget {
  const _EditableLedgerList({
    required this.items,
    required this.emptyText,
  });

  final List<_EditableLedgerItem> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text(emptyText);
    return Column(
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    item.onEdit();
                  } else if (value == 'delete' && item.onDelete != null) {
                    item.onDelete!();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  if (item.onDelete != null)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({
    required this.items,
    required this.currencyCode,
  });

  final List<TotalsByLabel> items;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No records yet.');
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: Text(item.label)),
                  Text(
                    '$currencyCode ${item.nativeTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ForexBreakdownList extends StatelessWidget {
  const _ForexBreakdownList({required this.items});

  final List<TotalsByLabel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No forex transfers yet.');
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: Text(item.label)),
                  Text(
                    item.nativeTotal.toStringAsFixed(2),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.reportingTotal.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPickerCard extends StatelessWidget {
  const _MonthPickerCard({required this.month, required this.onTap});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: const Text('Monthly report'),
        subtitle: Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
        trailing: const Icon(Icons.calendar_month),
      ),
    );
  }
}

class _YearPickerCard extends StatelessWidget {
  const _YearPickerCard({
    required this.year,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int year;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(onPressed: onDecrement, icon: const Icon(Icons.remove)),
            Expanded(
              child: Column(
                children: [
                  const Text('Yearly report'),
                  Text('$year', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            IconButton(onPressed: onIncrement, icon: const Icon(Icons.add)),
          ],
        ),
      ),
    );
  }
}

Future<void> _showManualExpenseSheet(
  BuildContext context,
  FinanceController controller, [
  ExpenseEntry? existingExpense,
]) async {
  final ledger = controller.selectedLedger;
  if (ledger == null) return;
  final merchantOptions = controller.merchants;
  final foodItemOptions = controller.foodGroceriesItems;
  final bankOptions = controller.banks;
  final cardOptions = controller.cards;
  final amountController = TextEditingController(
    text: existingExpense?.nativeAmount.toStringAsFixed(2) ?? '',
  );
  final merchantOptionsNonEmpty =
      existingExpense == null && merchantOptions.isNotEmpty;
  final merchantController = TextEditingController(
    text: (existingExpense?.merchant ?? '').isNotEmpty
        ? existingExpense!.merchant
        : (merchantOptionsNonEmpty ? merchantOptions.first : ''),
  );
  final notesController = TextEditingController(text: existingExpense?.notes ?? '');
  final countryController = TextEditingController(text: existingExpense?.country ?? '');
  var selectedCategory =
      existingExpense?.category ?? ExpenseCategory.foodGroceries;
  ExpenseSubtype? selectedSubtype = existingExpense?.subtype;
  UtilityType? selectedUtilityType = existingExpense?.utilityType;
  var selectedPaidByKind = existingExpense?.paidByKind ?? PaymentSourceKind.other;
  String? selectedBankName =
      existingExpense?.bankName.isNotEmpty == true ? existingExpense!.bankName : null;
  String? selectedCardName =
      existingExpense?.cardName.isNotEmpty == true ? existingExpense!.cardName : null;
  if (existingExpense == null) {
    if (bankOptions.isNotEmpty &&
        (selectedPaidByKind == PaymentSourceKind.bank ||
            selectedPaidByKind == PaymentSourceKind.upi)) {
      selectedBankName ??= bankOptions.first;
    }
    if (cardOptions.isNotEmpty && selectedPaidByKind == PaymentSourceKind.card) {
      selectedCardName ??= cardOptions.first;
    }
    if (foodItemOptions.isNotEmpty &&
        selectedCategory == ExpenseCategory.foodGroceries &&
        notesController.text.trim().isEmpty) {
      notesController.text = foodItemOptions.first;
    }
  }
  var selectedDate =
      existingExpense?.transactionDate ?? controller.defaultExpenseTransactionDate();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existingExpense == null ? 'Add Manual Expense' : 'Edit Expense',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyLedgerField(ledger: ledger),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Amount (${ledger.currencyCode})'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: ExpenseCategory.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedCategory = value;
                        if (!_supportsSubtype(value)) {
                          selectedSubtype = null;
                        }
                        if (value != ExpenseCategory.utilities) {
                          selectedUtilityType = null;
                        }
                      });
                    },
                  ),
                  if (selectedCategory == ExpenseCategory.foodGroceries &&
                      foodItemOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: foodItemOptions.contains(notesController.text.trim())
                          ? notesController.text.trim()
                          : (foodItemOptions.isNotEmpty ? foodItemOptions.first : null),
                      decoration: const InputDecoration(
                        labelText: 'Food / grocery item',
                      ),
                      items: foodItemOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => notesController.text = value);
                      },
                    ),
                  ],
                  if (_supportsSubtype(selectedCategory)) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ExpenseSubtype>(
                      initialValue: selectedSubtype ?? _subtypeOptionsForCategory(selectedCategory).first,
                      decoration: const InputDecoration(labelText: 'Subtype'),
                      items: _subtypeOptionsForCategory(selectedCategory)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setSheetState(() => selectedSubtype = value),
                    ),
                  ],
                  if (selectedCategory == ExpenseCategory.utilities) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UtilityType>(
                      initialValue: selectedUtilityType ?? UtilityType.electricity,
                      decoration: const InputDecoration(labelText: 'Utility type'),
                      items: UtilityType.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setSheetState(() => selectedUtilityType = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (merchantOptions.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: merchantOptions.contains(merchantController.text.trim())
                          ? merchantController.text.trim()
                          : null,
                      decoration: const InputDecoration(labelText: 'Merchant / paid to'),
                      items: merchantOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => merchantController.text = value);
                      },
                    )
                  else
                    TextField(
                      controller: merchantController,
                      decoration: const InputDecoration(labelText: 'Merchant / paid to'),
                    ),
                  if (merchantOptions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Or type custom merchant',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentSourceKind>(
                    initialValue: selectedPaidByKind,
                    decoration: const InputDecoration(labelText: 'Paid by'),
                    items: PaymentSourceKind.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedPaidByKind = value;
                        if (value != PaymentSourceKind.bank &&
                            value != PaymentSourceKind.upi) {
                          selectedBankName = null;
                        }
                        if (value != PaymentSourceKind.card) {
                          selectedCardName = null;
                        }
                      });
                    },
                  ),
                  if ((selectedPaidByKind == PaymentSourceKind.bank ||
                          selectedPaidByKind == PaymentSourceKind.upi) &&
                      bankOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: bankOptions.contains(selectedBankName)
                          ? selectedBankName
                          : null,
                      decoration: const InputDecoration(labelText: 'Bank'),
                      items: bankOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setSheetState(() => selectedBankName = value),
                    ),
                  ],
                  if (selectedPaidByKind == PaymentSourceKind.card &&
                      cardOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: cardOptions.contains(selectedCardName)
                          ? selectedCardName
                          : null,
                      decoration: const InputDecoration(labelText: 'Card'),
                      items: cardOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setSheetState(() => selectedCardName = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Comments'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expense date'),
                    subtitle: Text(_formatDate(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) return;
                      if (existingExpense == null) {
                        await controller.addManualExpense(
                          transactionDate: selectedDate,
                          ledgerId: ledger.id,
                          currencyCode: ledger.currencyCode,
                          amount: amount,
                          category: selectedCategory,
                          subtype: selectedSubtype,
                          utilityType: selectedCategory == ExpenseCategory.utilities
                              ? selectedUtilityType ?? UtilityType.other
                              : null,
                          merchant: merchantController.text.trim(),
                          notes: notesController.text.trim(),
                          paidByKind: selectedPaidByKind,
                          paymentChannel: selectedPaidByKind.label,
                          bankName: selectedBankName ?? '',
                          cardName: selectedCardName ?? '',
                          country: countryController.text.trim(),
                        );
                      } else {
                        await controller.updateExpense(
                          id: existingExpense.id,
                          transactionDate: selectedDate,
                          ledgerId: existingExpense.ledgerId,
                          currencyCode: existingExpense.currencyCode,
                          amount: amount,
                          category: selectedCategory,
                          subtype: selectedSubtype,
                          utilityType: selectedCategory == ExpenseCategory.utilities
                              ? selectedUtilityType ?? UtilityType.other
                              : null,
                          merchant: merchantController.text.trim(),
                          notes: notesController.text.trim(),
                          paidByKind: selectedPaidByKind,
                          paymentChannel: selectedPaidByKind.label,
                          bankName: selectedBankName ?? '',
                          cardName: selectedCardName ?? '',
                          country: countryController.text.trim(),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(existingExpense == null ? 'Save expense' : 'Update expense'),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
  );
}

Future<void> _showImportMessageSheet(
  BuildContext context,
  FinanceController controller,
) async {
  final ledger = controller.selectedLedger;
  if (ledger == null) return;
  final messageController = TextEditingController();
  final notesController = TextEditingController();
  final countryController = TextEditingController();
  var selectedSource = EntrySource.sms;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import Bank/SMS Message',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use this for pasted SMS alerts, shared bank notifications, or copied transaction messages.',
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyLedgerField(ledger: ledger),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EntrySource>(
                    initialValue: selectedSource,
                    decoration: const InputDecoration(labelText: 'Source'),
                    items: const [
                      DropdownMenuItem(
                        value: EntrySource.sms,
                        child: Text('SMS inbox message'),
                      ),
                      DropdownMenuItem(
                        value: EntrySource.sharedNotification,
                        child: Text('Shared bank notification'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedSource = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Paste message',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Country (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Optional comments'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      if (messageController.text.trim().isEmpty) return;
                      await controller.importExpenseMessage(
                        source: selectedSource,
                        rawMessage: messageController.text.trim(),
                        ledgerId: ledger.id,
                        currencyCode: ledger.currencyCode,
                        notes: notesController.text.trim(),
                        country: countryController.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Parse and save'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showAssetSheet(
  BuildContext context,
  FinanceController controller, [
  AssetHolding? existingAsset,
]) async {
  final ledger = existingAsset == null
      ? controller.selectedLedger
      : controller.ledgerById(existingAsset.ledgerId);
  if (ledger == null) return;
  final nameController = TextEditingController(text: existingAsset?.name ?? '');
  final amountController = TextEditingController(
    text: existingAsset?.nativeValue.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: existingAsset?.notes ?? '');
  final countryController = TextEditingController(text: existingAsset?.country ?? '');
  var type = existingAsset?.type ?? AssetType.house;
  var valuationDate = existingAsset?.valuationDate ?? DateTime.now();

  await _showValueSheet(
    context: context,
    title: existingAsset == null ? 'Add Asset' : 'Edit Asset',
    typeBuilder: DropdownButtonFormField<AssetType>(
      initialValue: type,
      decoration: const InputDecoration(labelText: 'Asset type'),
      items: AssetType.values
          .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          type = value;
        }
      },
    ),
    ledger: ledger,
    nameController: nameController,
    amountController: amountController,
    notesController: notesController,
    countryController: countryController,
    dateLabel: () => _formatDate(valuationDate),
    onPickDate: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: valuationDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) valuationDate = picked;
    },
    onSave: () async {
      final amount = double.tryParse(amountController.text) ?? 0;
      if (amount <= 0) return;
      if (existingAsset == null) {
        await controller.addAsset(
          type: type,
          name: nameController.text.trim(),
          ledgerId: ledger.id,
          currencyCode: ledger.currencyCode,
          amount: amount,
          valuationDate: valuationDate,
          notes: notesController.text.trim(),
          country: countryController.text.trim(),
        );
      } else {
        await controller.updateAsset(
          id: existingAsset.id,
          type: type,
          name: nameController.text.trim(),
          ledgerId: existingAsset.ledgerId,
          currencyCode: existingAsset.currencyCode,
          amount: amount,
          valuationDate: valuationDate,
          notes: notesController.text.trim(),
          country: countryController.text.trim(),
        );
      }
    },
  );
}

Future<void> _showLiabilitySheet(
  BuildContext context,
  FinanceController controller, [
  LiabilityHolding? existingLiability,
]) async {
  final ledger = existingLiability == null
      ? controller.selectedLedger
      : controller.ledgerById(existingLiability.ledgerId);
  if (ledger == null) return;
  final nameController = TextEditingController(text: existingLiability?.name ?? '');
  final amountController = TextEditingController(
    text: existingLiability?.nativeOutstanding.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: existingLiability?.notes ?? '');
  final countryController = TextEditingController(text: existingLiability?.country ?? '');
  var type = existingLiability?.type ?? LiabilityType.homeLoan;
  DateTime? dueDate = existingLiability?.dueDate ?? DateTime.now();

  await _showValueSheet(
    context: context,
    title: existingLiability == null ? 'Add Liability' : 'Edit Liability',
    typeBuilder: DropdownButtonFormField<LiabilityType>(
      initialValue: type,
      decoration: const InputDecoration(labelText: 'Liability type'),
      items: LiabilityType.values
          .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          type = value;
        }
      },
    ),
    ledger: ledger,
    nameController: nameController,
    amountController: amountController,
    notesController: notesController,
    countryController: countryController,
    dateLabel: () => dueDate == null ? 'No due date' : _formatDate(dueDate!),
    onPickDate: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: dueDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      dueDate = picked;
    },
    onSave: () async {
      final amount = double.tryParse(amountController.text) ?? 0;
      if (amount <= 0) return;
      if (existingLiability == null) {
        await controller.addLiability(
          type: type,
          name: nameController.text.trim(),
          ledgerId: ledger.id,
          currencyCode: ledger.currencyCode,
          amount: amount,
          dueDate: dueDate,
          notes: notesController.text.trim(),
          country: countryController.text.trim(),
        );
      } else {
        await controller.updateLiability(
          id: existingLiability.id,
          type: type,
          name: nameController.text.trim(),
          ledgerId: existingLiability.ledgerId,
          currencyCode: existingLiability.currencyCode,
          amount: amount,
          dueDate: dueDate,
          notes: notesController.text.trim(),
          country: countryController.text.trim(),
        );
      }
    },
  );
}

Future<void> _showScheduledEmiSheet(
  BuildContext context,
  FinanceController controller, [
  ScheduledEmiPlan? existingPlan,
]) async {
  final ledger = existingPlan == null
      ? controller.selectedLedger
      : controller.ledgerById(existingPlan.ledgerId);
  if (ledger == null) return;
  final bankOptions = controller.banks;
  final cardOptions = controller.cards;
  final nameController = TextEditingController(text: existingPlan?.name ?? '');
  final merchantController =
      TextEditingController(text: existingPlan?.merchant ?? '');
  final amountController = TextEditingController(
    text: existingPlan?.amount.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: existingPlan?.notes ?? '');
  final countryController =
      TextEditingController(text: existingPlan?.country ?? '');
  var selectedPaidByKind =
      existingPlan?.paidByKind ?? PaymentSourceKind.bank;
  String? selectedBankName = existingPlan?.bankName.isNotEmpty == true
      ? existingPlan!.bankName
      : (bankOptions.isNotEmpty ? bankOptions.first : null);
  String? selectedCardName = existingPlan?.cardName.isNotEmpty == true
      ? existingPlan!.cardName
      : (cardOptions.isNotEmpty ? cardOptions.first : null);
  var selectedDay = existingPlan?.dayOfMonth ?? 5;
  var startMonth =
      existingPlan?.startMonth ?? controller.selectedMonth;
  var hasEndMonth = existingPlan?.endMonth != null;
  var endMonth = existingPlan?.endMonth ?? controller.selectedMonth;
  var isActive = existingPlan?.isActive ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existingPlan == null ? 'Add Scheduled EMI' : 'Edit Scheduled EMI',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyLedgerField(ledger: ledger),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'EMI name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: merchantController,
                    decoration: const InputDecoration(
                      labelText: 'Lender / merchant',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Amount (${ledger.currencyCode})'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDay,
                    decoration: const InputDecoration(labelText: 'Payment day of month'),
                    items: List.generate(
                      31,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedDay = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentSourceKind>(
                    initialValue: selectedPaidByKind,
                    decoration: const InputDecoration(labelText: 'Paid by'),
                    items: PaymentSourceKind.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedPaidByKind = value;
                        if (value != PaymentSourceKind.bank &&
                            value != PaymentSourceKind.upi) {
                          selectedBankName = null;
                        } else if (selectedBankName == null &&
                            bankOptions.isNotEmpty) {
                          selectedBankName = bankOptions.first;
                        }
                        if (value != PaymentSourceKind.card) {
                          selectedCardName = null;
                        } else if (selectedCardName == null &&
                            cardOptions.isNotEmpty) {
                          selectedCardName = cardOptions.first;
                        }
                      });
                    },
                  ),
                  if ((selectedPaidByKind == PaymentSourceKind.bank ||
                          selectedPaidByKind == PaymentSourceKind.upi) &&
                      bankOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: bankOptions.contains(selectedBankName)
                          ? selectedBankName
                          : bankOptions.first,
                      decoration: const InputDecoration(labelText: 'Bank'),
                      items: bankOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setSheetState(() => selectedBankName = value),
                    ),
                  ],
                  if (selectedPaidByKind == PaymentSourceKind.card &&
                      cardOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: cardOptions.contains(selectedCardName)
                          ? selectedCardName
                          : cardOptions.first,
                      decoration: const InputDecoration(labelText: 'Card'),
                      items: cardOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setSheetState(() => selectedCardName = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Country (optional)'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hasEndMonth,
                    title: const Text('Set end month'),
                    onChanged: (value) => setSheetState(() => hasEndMonth = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: const Text('Active schedule'),
                    onChanged: (value) => setSheetState(() => isActive = value),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start month'),
                    subtitle: Text(
                      '${startMonth.year}-${startMonth.month.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        setSheetState(
                          () => startMonth = DateTime(picked.year, picked.month),
                        );
                      }
                    },
                  ),
                  if (hasEndMonth)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End month'),
                      subtitle: Text(
                        '${endMonth.year}-${endMonth.month.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endMonth,
                          firstDate: startMonth,
                          lastDate: DateTime(2100),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (picked != null) {
                          setSheetState(
                            () => endMonth = DateTime(picked.year, picked.month),
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0 || nameController.text.trim().isEmpty) return;
                      if (existingPlan == null) {
                        await controller.addScheduledEmi(
                          ledgerId: ledger.id,
                          currencyCode: ledger.currencyCode,
                          name: nameController.text.trim(),
                          merchant: merchantController.text.trim(),
                          amount: amount,
                          dayOfMonth: selectedDay,
                          startMonth: startMonth,
                          endMonth: hasEndMonth ? endMonth : null,
                          notes: notesController.text.trim(),
                          paidByKind: selectedPaidByKind,
                          bankName: selectedBankName ?? '',
                          cardName: selectedCardName ?? '',
                          country: countryController.text.trim(),
                          isActive: isActive,
                        );
                      } else {
                        await controller.updateScheduledEmi(
                          id: existingPlan.id,
                          ledgerId: existingPlan.ledgerId,
                          currencyCode: existingPlan.currencyCode,
                          name: nameController.text.trim(),
                          merchant: merchantController.text.trim(),
                          amount: amount,
                          dayOfMonth: selectedDay,
                          startMonth: startMonth,
                          endMonth: hasEndMonth ? endMonth : null,
                          notes: notesController.text.trim(),
                          paidByKind: selectedPaidByKind,
                          bankName: selectedBankName ?? '',
                          cardName: selectedCardName ?? '',
                          country: countryController.text.trim(),
                          isActive: isActive,
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(
                      existingPlan == null ? 'Save scheduled EMI' : 'Update scheduled EMI',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showSavingsSheet(
  BuildContext context,
  FinanceController controller, [
  MonthlySavingsRecord? existingRecord,
]) async {
  final ledger = existingRecord == null
      ? controller.selectedLedger
      : controller.ledgerById(existingRecord.ledgerId);
  if (ledger == null) return;
  final amountController = TextEditingController(
    text: existingRecord?.nativeAmount.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: existingRecord?.notes ?? '');
  final countryController = TextEditingController(text: existingRecord?.country ?? '');
  var source = existingRecord?.source ?? SavingsRecordSource.manual;
  var allocationType = SavingsAllocationType.mutualFund;
  var addAllocation = existingRecord == null;
  var month = existingRecord?.month ?? DateTime(DateTime.now().year, DateTime.now().month);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existingRecord == null ? 'Add Monthly Savings' : 'Edit Monthly Savings',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyLedgerField(ledger: ledger),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SavingsRecordSource>(
                    initialValue: source,
                    decoration: const InputDecoration(labelText: 'Savings source'),
                    items: SavingsRecordSource.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => source = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Amount (${ledger.currencyCode})'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: addAllocation,
                    title: const Text('Also record allocation'),
                    onChanged: (value) => setSheetState(() => addAllocation = value),
                  ),
                  if (addAllocation) ...[
                    DropdownButtonFormField<SavingsAllocationType>(
                      initialValue: allocationType,
                      decoration: const InputDecoration(labelText: 'Investment type'),
                      items: SavingsAllocationType.values
                          .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => allocationType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Country (optional)'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Month'),
                    subtitle: Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: month,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        setSheetState(() => month = DateTime(picked.year, picked.month));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) return;
                      if (existingRecord == null) {
                        await controller.addSavingsRecord(
                          month: month,
                          ledgerId: ledger.id,
                          currencyCode: ledger.currencyCode,
                          amount: amount,
                          source: source,
                          notes: notesController.text.trim(),
                          country: countryController.text.trim(),
                        );
                      } else {
                        await controller.updateSavingsRecord(
                          id: existingRecord.id,
                          month: month,
                          ledgerId: existingRecord.ledgerId,
                          currencyCode: existingRecord.currencyCode,
                          amount: amount,
                          source: source,
                          notes: notesController.text.trim(),
                          country: countryController.text.trim(),
                        );
                      }
                      if (existingRecord == null && addAllocation) {
                        await controller.addSavingsAllocation(
                          month: month,
                          type: allocationType,
                          ledgerId: ledger.id,
                          currencyCode: ledger.currencyCode,
                          amount: amount,
                          notes: notesController.text.trim(),
                          country: countryController.text.trim(),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(existingRecord == null ? 'Save savings' : 'Update savings'),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
}

Future<void> _showInvestmentSheet(
  BuildContext context,
  FinanceController controller, [
  InvestmentEntry? existingRecord,
]) async {
  final ledger = existingRecord == null
      ? controller.selectedLedger
      : controller.ledgerById(existingRecord.ledgerId);
  if (ledger == null) return;
  final amountController = TextEditingController(
    text: existingRecord?.nativeAmount.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: existingRecord?.notes ?? '');
  final countryController = TextEditingController(text: existingRecord?.country ?? '');
  var type = existingRecord?.type ?? InvestmentType.mutualFund;
  var investmentDate =
      existingRecord?.month ?? controller.defaultExpenseTransactionDate();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existingRecord == null ? 'Add investment' : 'Edit investment',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyLedgerField(ledger: ledger),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<InvestmentType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Investment type'),
                    items: InvestmentType.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Amount (${ledger.currencyCode})'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Country (optional)'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Investment date'),
                    subtitle: Text(_formatDate(investmentDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: investmentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(
                          () => investmentDate =
                              DateTime(picked.year, picked.month, picked.day),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) return;
                      if (existingRecord == null) {
                        await controller.addInvestmentEntry(
                          month: investmentDate,
                          type: type,
                          ledgerId: ledger.id,
                          currencyCode: ledger.currencyCode,
                          amount: amount,
                          notes: notesController.text.trim(),
                          country: countryController.text.trim(),
                        );
                      } else {
                        await controller.updateInvestmentEntry(
                          id: existingRecord.id,
                          month: investmentDate,
                          type: type,
                          ledgerId: existingRecord.ledgerId,
                          currencyCode: existingRecord.currencyCode,
                          amount: amount,
                          notes: notesController.text.trim(),
                          country: countryController.text.trim(),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(existingRecord == null ? 'Save investment' : 'Update investment'),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
  );
}

Future<void> _showEarningSheet(
  BuildContext context,
  FinanceController controller, [
  MonthlyEarningRecord? existingRecord,
]) async {
  final ledger = existingRecord == null
      ? controller.selectedLedger
      : controller.ledgerById(existingRecord.ledgerId);
  if (ledger == null) return;
  final amountController = TextEditingController(
    text: existingRecord?.nativeAmount.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: existingRecord?.notes ?? '');
  final countryController = TextEditingController(text: existingRecord?.country ?? '');
  var source = existingRecord?.source ?? EarningsRecordSource.salary;
  var month = existingRecord?.month ?? DateTime(DateTime.now().year, DateTime.now().month);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existingRecord == null ? 'Add Monthly Earning' : 'Edit Monthly Earning',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyLedgerField(ledger: ledger),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EarningsRecordSource>(
                    initialValue: source,
                    decoration: const InputDecoration(labelText: 'Earning source'),
                    items: EarningsRecordSource.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => source = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Amount (${ledger.currencyCode})'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Country (optional)'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Month'),
                    subtitle: Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: month,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        setSheetState(() => month = DateTime(picked.year, picked.month));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0) return;
                      if (existingRecord == null) {
                        await controller.addEarningRecord(
                          month: month,
                          ledgerId: ledger.id,
                          currencyCode: ledger.currencyCode,
                          amount: amount,
                          source: source,
                          notes: notesController.text.trim(),
                          country: countryController.text.trim(),
                        );
                      } else {
                        await controller.updateEarningRecord(
                          id: existingRecord.id,
                          month: month,
                          ledgerId: existingRecord.ledgerId,
                          currencyCode: existingRecord.currencyCode,
                          amount: amount,
                          source: source,
                          notes: notesController.text.trim(),
                          country: countryController.text.trim(),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(existingRecord == null ? 'Save earning' : 'Update earning'),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
  );
}

Future<void> _showForexTransferSheet(
  BuildContext context,
  FinanceController controller, [
  ForexTransfer? existingTransfer,
]) async {
  final fromAmountController = TextEditingController(
    text: existingTransfer?.fromAmount.toStringAsFixed(2) ?? '',
  );
  final toAmountController = TextEditingController(
    text: existingTransfer?.toAmount.toStringAsFixed(2) ?? '',
  );
  final notesController = TextEditingController(text: existingTransfer?.notes ?? '');
  final fromCountryController = TextEditingController(text: existingTransfer?.fromCountry ?? '');
  final toCountryController = TextEditingController(text: existingTransfer?.toCountry ?? '');
  String fromLedgerId = existingTransfer == null
      ? controller.selectedLedgerId
      : controller.currencyLedgers
              .firstWhere(
                (ledger) => ledger.currencyCode == existingTransfer.fromCurrencyCode,
                orElse: () => controller.selectedLedger!,
              )
              .id;
  String toLedgerId = existingTransfer == null
      ? (controller.currencyLedgers.length > 1
          ? controller.currencyLedgers.firstWhere(
              (ledger) => ledger.id != controller.selectedLedgerId,
              orElse: () => controller.selectedLedger!,
            ).id
          : controller.selectedLedgerId)
      : controller.currencyLedgers
              .firstWhere(
                (ledger) => ledger.currencyCode == existingTransfer.toCurrencyCode,
                orElse: () => controller.selectedLedger!,
              )
              .id;
  var transferDate = existingTransfer?.transferDate ?? DateTime.now();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final fromLedger = controller.ledgerById(fromLedgerId) ?? controller.selectedLedger;
          final toLedger = controller.ledgerById(toLedgerId) ?? controller.selectedLedger;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existingTransfer == null ? 'Add Forex Transfer' : 'Edit Forex Transfer',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: fromLedgerId,
                    decoration: const InputDecoration(labelText: 'From currency ledger'),
                    items: controller.currencyLedgers
                        .map(
                          (ledger) => DropdownMenuItem<String>(
                            value: ledger.id,
                            child: Text('${ledger.displayName} (${ledger.currencyCode})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value == toLedgerId) return;
                      setSheetState(() => fromLedgerId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fromAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Transferred amount (${fromLedger?.currencyCode ?? ''})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fromCountryController,
                    decoration: const InputDecoration(labelText: 'From country (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: toLedgerId,
                    decoration: const InputDecoration(labelText: 'To currency ledger'),
                    items: controller.currencyLedgers
                        .map(
                          (ledger) => DropdownMenuItem<String>(
                            value: ledger.id,
                            child: Text('${ledger.displayName} (${ledger.currencyCode})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value == fromLedgerId) return;
                      setSheetState(() => toLedgerId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: toAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Received amount (${toLedger?.currencyCode ?? ''})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: toCountryController,
                    decoration: const InputDecoration(labelText: 'To country (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Transfer date'),
                    subtitle: Text(_formatDate(transferDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: transferDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => transferDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final fromAmount = double.tryParse(fromAmountController.text) ?? 0;
                      final toAmount = double.tryParse(toAmountController.text) ?? 0;
                      if (fromAmount <= 0 || toAmount <= 0) return;
                      if (fromLedger == null || toLedger == null) return;
                      if (existingTransfer == null) {
                        await controller.addForexTransfer(
                          transferDate: transferDate,
                          fromCountry: fromCountryController.text.trim(),
                          fromCurrencyCode: fromLedger.currencyCode,
                          fromAmount: fromAmount,
                          toCountry: toCountryController.text.trim(),
                          toCurrencyCode: toLedger.currencyCode,
                          toAmount: toAmount,
                          notes: notesController.text.trim(),
                        );
                      } else {
                        await controller.updateForexTransfer(
                          id: existingTransfer.id,
                          transferDate: transferDate,
                          fromCountry: fromCountryController.text.trim(),
                          fromCurrencyCode: fromLedger.currencyCode,
                          fromAmount: fromAmount,
                          toCountry: toCountryController.text.trim(),
                          toCurrencyCode: toLedger.currencyCode,
                          toAmount: toAmount,
                          notes: notesController.text.trim(),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(existingTransfer == null ? 'Save transfer' : 'Update transfer'),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
  );
}

Future<void> _showReclassifyDialog(
  BuildContext context,
  FinanceController controller,
  ExpenseEntry expense,
) async {
  var category = expense.category;
  ExpenseSubtype? subtype = expense.subtype;
  UtilityType? utilityType = expense.utilityType;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Review imported expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ExpenseCategory.values
                      .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      category = value;
                      if (!_supportsSubtype(value)) {
                        subtype = null;
                      }
                      if (value != ExpenseCategory.utilities) {
                        utilityType = null;
                      }
                    });
                  },
                ),
                if (_supportsSubtype(category)) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ExpenseSubtype>(
                    initialValue: subtype ?? _subtypeOptionsForCategory(category).first,
                    decoration: const InputDecoration(labelText: 'Subtype'),
                    items: _subtypeOptionsForCategory(category)
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => subtype = value),
                  ),
                ],
                if (category == ExpenseCategory.utilities) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UtilityType>(
                    initialValue: utilityType ?? UtilityType.other,
                    decoration: const InputDecoration(labelText: 'Utility type'),
                    items: UtilityType.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => utilityType = value),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await controller.reclassifyExpense(
                    expense,
                    category: category,
                    subtype: subtype,
                    utilityType: utilityType,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required Future<void> Function() onDelete,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await onDelete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}

Future<void> _showValueSheet({
  required BuildContext context,
  required String title,
  required Widget typeBuilder,
  required CurrencyLedgerProfile ledger,
  required TextEditingController nameController,
  required TextEditingController amountController,
  required TextEditingController notesController,
  required TextEditingController countryController,
  required String Function() dateLabel,
  required Future<void> Function() onPickDate,
  required Future<void> Function() onSave,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              typeBuilder,
              const SizedBox(height: 12),
              _ReadOnlyLedgerField(ledger: ledger),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount (${ledger.currencyCode})'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: 'Country (optional)'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(dateLabel()),
                onTap: onPickDate,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await onSave();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ReadOnlyLedgerField extends StatelessWidget {
  const _ReadOnlyLedgerField({required this.ledger});

  final CurrencyLedgerProfile ledger;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Currency ledger'),
      child: Text('${ledger.displayName} (${ledger.currencyCode})'),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

int _responsiveGridColumns(
  double maxWidth, {
  required double compactMinWidth,
  required double mediumMinWidth,
  required int maxColumns,
}) {
  if (maxWidth >= mediumMinWidth * maxColumns) {
    return maxColumns;
  }
  if (maxWidth >= mediumMinWidth * 3) {
    return 3;
  }
  if (maxWidth >= compactMinWidth * 2) {
    return 2;
  }
  return 1;
}

bool _supportsSubtype(ExpenseCategory category) {
  return category == ExpenseCategory.housing ||
      category == ExpenseCategory.transport ||
      category == ExpenseCategory.healthcare;
}

List<ExpenseSubtype> _subtypeOptionsForCategory(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.housing:
      return const [
        ExpenseSubtype.rent,
        ExpenseSubtype.emi,
        ExpenseSubtype.maintenance,
      ];
    case ExpenseCategory.transport:
      return const [
        ExpenseSubtype.bus,
        ExpenseSubtype.train,
        ExpenseSubtype.cab,
        ExpenseSubtype.flight,
      ];
    case ExpenseCategory.healthcare:
      return const [
        ExpenseSubtype.vaccine,
        ExpenseSubtype.doctor,
        ExpenseSubtype.medicine,
      ];
    default:
      return const [];
  }
}
