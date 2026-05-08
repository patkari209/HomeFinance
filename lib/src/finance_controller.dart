import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'collaboration_models.dart';
import 'models.dart';

class ParsedExpenseDraft {
  ParsedExpenseDraft({
    required this.ledgerId,
    required this.country,
    required this.currencyCode,
    required this.amount,
    required this.date,
    required this.category,
    required this.subtype,
    required this.utilityType,
    required this.merchant,
    required this.confidence,
    required this.paymentChannel,
    required this.paidByKind,
    required this.rawMessage,
    required this.notes,
  });

  final String ledgerId;
  final String country;
  final String currencyCode;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final ExpenseSubtype? subtype;
  final UtilityType? utilityType;
  final String merchant;
  final double confidence;
  final String paymentChannel;
  final PaymentSourceKind paidByKind;
  final String rawMessage;
  final String notes;
}

class TotalsByLabel {
  TotalsByLabel(this.label, this.nativeTotal, [this.reportingTotal = 0]);

  final String label;
  final double nativeTotal;
  final double reportingTotal;
}

class MonthlyReport {
  MonthlyReport({
    required this.month,
    required this.currencyCode,
    required this.totalEarnings,
    required this.totalExpense,
    required this.remainingBalance,
    required this.totalSavings,
    required this.totalInvestments,
    required this.manualSavings,
    required this.derivedSavings,
    required this.categoryTotals,
    required this.utilityTotals,
    required this.allocationTotals,
    required this.investmentTotals,
    required this.assetTotal,
    required this.liabilityTotal,
  });

  final DateTime month;
  final String currencyCode;
  final double totalEarnings;
  final double totalExpense;
  final double remainingBalance;
  final double totalSavings;
  final double totalInvestments;
  final double manualSavings;
  final double derivedSavings;
  final List<TotalsByLabel> categoryTotals;
  final List<TotalsByLabel> utilityTotals;
  final List<TotalsByLabel> allocationTotals;
  final List<TotalsByLabel> investmentTotals;
  final double assetTotal;
  final double liabilityTotal;
}

class YearlyReport {
  YearlyReport({
    required this.year,
    required this.currencyCode,
    required this.earningsMonthTotals,
    required this.expenseMonthTotals,
    required this.remainingMonthTotals,
    required this.categoryTotals,
    required this.allocationTotals,
    required this.savingsTotals,
    required this.investmentMonthTotals,
    required this.investmentTypeTotals,
    required this.assetTotal,
    required this.liabilityTotal,
    required this.netWorth,
  });

  final int year;
  final String currencyCode;
  final List<TotalsByLabel> earningsMonthTotals;
  final List<TotalsByLabel> expenseMonthTotals;
  final List<TotalsByLabel> remainingMonthTotals;
  final List<TotalsByLabel> categoryTotals;
  final List<TotalsByLabel> allocationTotals;
  final List<TotalsByLabel> savingsTotals;
  final List<TotalsByLabel> investmentMonthTotals;
  final List<TotalsByLabel> investmentTypeTotals;
  final double assetTotal;
  final double liabilityTotal;
  final double netWorth;
}

class DashboardSummary {
  DashboardSummary({
    required this.currencyCode,
    required this.currentMonthEarnings,
    required this.currentMonthSpend,
    required this.currentMonthSavings,
    required this.currentMonthInvestments,
    required this.currentMonthRemaining,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.totalInvestments,
    required this.investmentBreakdown,
    required this.assetBreakdown,
    required this.liabilityBreakdown,
  });

  final String currencyCode;
  final double currentMonthEarnings;
  final double currentMonthSpend;
  final double currentMonthSavings;
  final double currentMonthInvestments;
  final double currentMonthRemaining;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double totalInvestments;
  final List<TotalsByLabel> investmentBreakdown;
  final List<TotalsByLabel> assetBreakdown;
  final List<TotalsByLabel> liabilityBreakdown;
}

class ForexTransferReport {
  ForexTransferReport({
    required this.monthTotals,
    required this.yearTotals,
    required this.totalFromAmount,
    required this.totalToAmount,
    required this.totalReportingAmount,
  });

  final List<TotalsByLabel> monthTotals;
  final List<TotalsByLabel> yearTotals;
  final double totalFromAmount;
  final double totalToAmount;
  final double totalReportingAmount;
}

class FinanceController extends ChangeNotifier {
  FinanceController._(this._prefs, this._data, this._selectedMonth);

  static const _storageKey = 'finance_data_v4';
  static const _legacyStorageKey = 'finance_data_v3';
  static const _selectedMonthKey = 'dashboard_month_v1';

  final SharedPreferences _prefs;
  FinanceData _data;
  DateTime _selectedMonth;
  final StreamController<FinanceSyncEvent> _syncEvents =
      StreamController<FinanceSyncEvent>.broadcast();

  FinanceData get data => _data;
  Stream<FinanceSyncEvent> get syncEvents => _syncEvents.stream;
  FinanceSettings get settings => _data.settings;
  CurrencyLedgerProfile? get selectedLedger => settings.selectedLedger;
  String get selectedLedgerId => selectedLedger?.id ?? '';
  String get selectedCurrencyCode => selectedLedger?.currencyCode ?? '';

  /// First day of the month used for dashboard, reports, and expense list scope.
  DateTime get selectedMonth => DateTime(_selectedMonth.year, _selectedMonth.month);

  List<CurrencyLedgerProfile> get currencyLedgers => [...settings.currencyLedgers];
  List<String> get merchants => [...settings.merchants];
  List<String> get foodGroceriesItems => [...settings.foodGroceriesItems];
  List<String> get banks => [...settings.banks];
  List<String> get cards => [...settings.cards];

  List<ExpenseEntry> get expenses =>
      _sortByDateDescending(_data.expenses, (item) => item.transactionDate);

  List<ExpenseEntry> get expensesByExpenseDateDescThenCreatedAtDesc => [..._data.expenses]
    ..sort((a, b) {
      final tx = b.transactionDate.compareTo(a.transactionDate);
      if (tx != 0) return tx;
      return b.createdAt.compareTo(a.createdAt);
    });
  List<ExpenseEntry> get reviewQueue => expensesForSelectedLedger.where((item) => item.needsReview).toList();
  List<MonthlyEarningRecord> get earningsRecords => _sortByDateDescending(_data.earningsRecords, (item) => item.month);
  List<MonthlySavingsRecord> get savingsRecords => _sortByDateDescending(_data.savingsRecords, (item) => item.month);
  List<SavingsAllocation> get allocations => _sortByDateDescending(_data.allocations, (item) => item.month);
  List<InvestmentEntry> get investments => _sortByDateDescending(_data.investments, (item) => item.month);
  List<AssetHolding> get assets => _sortByDateDescending(_data.assets, (item) => item.valuationDate);
  List<LiabilityHolding> get liabilities => _sortByNullableDateDescending(_data.liabilities, (item) => item.dueDate);
  List<FxRate> get fxRates => _sortByDateDescending(_data.fxRates, (item) => item.effectiveDate);
  List<ForexTransfer> get forexTransfers => _sortByDateDescending(_data.forexTransfers, (item) => item.transferDate);

  List<ExpenseEntry> get expensesForSelectedLedger =>
      _filterBySelectedLedger(expensesByExpenseDateDescThenCreatedAtDesc, (item) => item.ledgerId);

  List<ExpenseEntry> expensesForSelectedLedgerInMonth(DateTime month) {
    final m = DateTime(month.year, month.month);
    return expensesForSelectedLedger
        .where(
          (item) =>
              item.transactionDate.year == m.year && item.transactionDate.month == m.month,
        )
        .toList()
      ..sort((a, b) {
        final tx = b.transactionDate.compareTo(a.transactionDate);
        if (tx != 0) return tx;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  List<ExpenseEntry> get expensesForSelectedLedgerInSelectedMonth =>
      expensesForSelectedLedgerInMonth(selectedMonth);

  double totalExpenseForLedgerInMonth(String ledgerId, DateTime month) {
    final m = DateTime(month.year, month.month);
    return _data.expenses
        .where(
          (item) =>
              item.ledgerId == ledgerId &&
              item.transactionDate.year == m.year &&
              item.transactionDate.month == m.month,
        )
        .fold<double>(0, (sum, item) => sum + item.nativeAmount);
  }
  List<MonthlyEarningRecord> get earningsForSelectedLedger => _filterBySelectedLedger(earningsRecords, (item) => item.ledgerId);
  List<MonthlySavingsRecord> get savingsForSelectedLedger => _filterBySelectedLedger(savingsRecords, (item) => item.ledgerId);
  List<SavingsAllocation> get allocationsForSelectedLedger => _filterBySelectedLedger(allocations, (item) => item.ledgerId);
  List<InvestmentEntry> get investmentsForSelectedLedger => _filterBySelectedLedger(investments, (item) => item.ledgerId);
  List<AssetHolding> get assetsForSelectedLedger => _filterBySelectedLedger(assets, (item) => item.ledgerId);
  List<LiabilityHolding> get liabilitiesForSelectedLedger => _filterBySelectedLedger(liabilities, (item) => item.ledgerId);

  bool _sameCalendarMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  List<InvestmentEntry> get investmentsForSelectedLedgerInSelectedMonth =>
      investmentsForSelectedLedger
          .where((item) => _sameCalendarMonth(item.month, selectedMonth))
          .toList();

  List<MonthlyEarningRecord> get earningsForSelectedLedgerInSelectedMonth =>
      earningsForSelectedLedger
          .where((item) => _sameCalendarMonth(item.month, selectedMonth))
          .toList();

  List<MonthlySavingsRecord> get savingsForSelectedLedgerInSelectedMonth =>
      savingsForSelectedLedger
          .where((item) => _sameCalendarMonth(item.month, selectedMonth))
          .toList();

  List<SavingsAllocation> get allocationsForSelectedLedgerInSelectedMonth =>
      allocationsForSelectedLedger
          .where((item) => _sameCalendarMonth(item.month, selectedMonth))
          .toList();

  List<AssetHolding> get assetsForSelectedLedgerInSelectedMonth =>
      assetsForSelectedLedger
          .where((item) => _sameCalendarMonth(item.valuationDate, selectedMonth))
          .toList();

  List<LiabilityHolding> get liabilitiesForSelectedLedgerInSelectedMonth {
    final now = DateTime.now();
    final isThisCalendarMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    return liabilitiesForSelectedLedger.where((item) {
      final due = item.dueDate;
      if (due != null) {
        return _sameCalendarMonth(due, selectedMonth);
      }
      return isThisCalendarMonth;
    }).toList();
  }

  static Future<FinanceController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? prefs.getString(_legacyStorageKey);
    if (raw == null || raw.isEmpty) {
      final controller = FinanceController._(prefs, _emptyData(), _loadSelectedMonth(prefs));
      await controller._persist();
      return controller;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final controller = FinanceController._(
      prefs,
      FinanceData.fromJson(decoded),
      _loadSelectedMonth(prefs),
    );
    await controller._migrateIfNeeded();
    await controller._persist();
    return controller;
  }

  static DateTime _loadSelectedMonth(SharedPreferences prefs) {
    final raw = prefs.getString(_selectedMonthKey);
    if (raw == null || raw.isEmpty) {
      final n = DateTime.now();
      return DateTime(n.year, n.month);
    }
    try {
      final d = DateTime.parse(raw);
      return DateTime(d.year, d.month);
    } catch (_) {
      final n = DateTime.now();
      return DateTime(n.year, n.month);
    }
  }

  Future<void> setSelectedMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month);
    await _prefs.setString(
      _selectedMonthKey,
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01',
    );
    notifyListeners();
  }

  bool get isSelectedMonthCurrentCalendarMonth {
    final n = DateTime.now();
    return selectedMonth.year == n.year && selectedMonth.month == n.month;
  }

  /// Default date for new manual expenses: today if viewing this month, else first day of selected month.
  DateTime defaultExpenseTransactionDate() {
    final now = DateTime.now();
    final sel = selectedMonth;
    if (sel.year == now.year && sel.month == now.month) {
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(sel.year, sel.month, 1);
  }

  static FinanceData _emptyData() {
    return FinanceData(
      settings: FinanceSettings(
        currencyLedgers: const [],
        selectedLedgerId: null,
        merchants: const [],
        foodGroceriesItems: const [],
        banks: const [],
        cards: const [],
      ),
      expenses: const [],
      earningsRecords: const [],
      savingsRecords: const [],
      allocations: const [],
      investments: const [],
      assets: const [],
      liabilities: const [],
      fxRates: const [],
      forexTransfers: const [],
    );
  }

  Future<void> _migrateIfNeeded() async {
    final inferredLedgers = <CurrencyLedgerProfile>[];
    final seen = <String>{};

    void addLedger(String ledgerId, String currencyCode, [String? displayName]) {
      final normalizedCurrency = currencyCode.trim().toUpperCase();
      if (normalizedCurrency.isEmpty) return;
      final normalizedId = ledgerId.trim().isEmpty ? normalizedCurrency.toLowerCase() : ledgerId.trim();
      if (seen.contains(normalizedId)) return;
      seen.add(normalizedId);
      inferredLedgers.add(
        CurrencyLedgerProfile(
          id: normalizedId,
          currencyCode: normalizedCurrency,
          displayName: (displayName == null || displayName.trim().isEmpty)
              ? normalizedCurrency
              : displayName.trim(),
        ),
      );
    }

    for (final ledger in settings.currencyLedgers) {
      addLedger(ledger.id, ledger.currencyCode, ledger.displayName);
    }
    for (final expense in _data.expenses) {
      addLedger(expense.ledgerId, expense.currencyCode);
    }
    for (final item in _data.earningsRecords) {
      addLedger(item.ledgerId, item.currencyCode);
    }
    for (final item in _data.savingsRecords) {
      addLedger(item.ledgerId, item.currencyCode);
    }
    for (final item in _data.allocations) {
      addLedger(item.ledgerId, item.currencyCode);
    }
    for (final item in _data.investments) {
      addLedger(item.ledgerId, item.currencyCode);
    }
    for (final item in _data.assets) {
      addLedger(item.ledgerId, item.currencyCode);
    }
    for (final item in _data.liabilities) {
      addLedger(item.ledgerId, item.currencyCode);
    }

    _data = _data.copyWith(
      settings: FinanceSettings(
        currencyLedgers: inferredLedgers,
        selectedLedgerId: settings.selectedLedgerId ??
            (inferredLedgers.isEmpty ? null : inferredLedgers.first.id),
        merchants: settings.merchants,
        foodGroceriesItems: settings.foodGroceriesItems,
        banks: settings.banks,
        cards: settings.cards,
      ),
    );
  }

  Future<void> _persist() async {
    await _prefs.setString(_storageKey, _data.encode());
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';

  void _emitSyncEvent({
    required SyncEntityType entityType,
    required SyncActionType actionType,
    required String recordId,
  }) {
    _syncEvents.add(
      FinanceSyncEvent(
        id: _newId('sync'),
        entityType: entityType,
        actionType: actionType,
        recordId: recordId,
        timestamp: DateTime.now(),
        snapshot: _data.encode(),
      ),
    );
  }

  Future<void> mergeImportedExpenses(List<ExpenseEntry> incoming) async {
    final map = <String, ExpenseEntry>{for (final e in _data.expenses) e.id: e};
    for (final e in incoming) {
      map[e.id] = e;
    }
    _data = _data.copyWith(expenses: map.values.toList());
    await _persist();
    _emitSyncEvent(
      entityType: SyncEntityType.settings,
      actionType: SyncActionType.updated,
      recordId: 'expense-csv-import',
    );
    notifyListeners();
  }

  Future<void> replaceAllData(FinanceData data, {String recordId = 'all'}) async {
    _data = data;
    await _migrateIfNeeded();
    await _persist();
    _emitSyncEvent(
      entityType: SyncEntityType.settings,
      actionType: SyncActionType.replaced,
      recordId: recordId,
    );
    notifyListeners();
  }

  Future<void> initializeFirstLedger({
    required String currencyCode,
    required String displayName,
  }) async {
    if (settings.hasLedgers) return;
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final ledger = CurrencyLedgerProfile(
      id: normalizedCurrency.toLowerCase(),
      currencyCode: normalizedCurrency,
      displayName: displayName.trim().isEmpty ? normalizedCurrency : displayName.trim(),
    );
    _data = _data.copyWith(
      settings: FinanceSettings(
        currencyLedgers: [ledger],
        selectedLedgerId: ledger.id,
        merchants: settings.merchants,
        foodGroceriesItems: settings.foodGroceriesItems,
        banks: settings.banks,
        cards: settings.cards,
      ),
    );
    await _persist();
    _emitSyncEvent(
      entityType: SyncEntityType.settings,
      actionType: SyncActionType.created,
      recordId: ledger.id,
    );
    notifyListeners();
  }

  Future<void> addCurrencyLedger({
    required String currencyCode,
    required String displayName,
  }) async {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    if (normalizedCurrency.isEmpty) return;
    final exists = settings.currencyLedgers.any(
      (ledger) => ledger.currencyCode == normalizedCurrency,
    );
    if (exists) return;
    final ledger = CurrencyLedgerProfile(
      id: normalizedCurrency.toLowerCase(),
      currencyCode: normalizedCurrency,
      displayName: displayName.trim().isEmpty ? normalizedCurrency : displayName.trim(),
    );
    _data = _data.copyWith(
      settings: settings.copyWith(
        currencyLedgers: [...settings.currencyLedgers, ledger],
        selectedLedgerId: settings.selectedLedgerId ?? ledger.id,
      ),
    );
    await _persist();
    _emitSyncEvent(
      entityType: SyncEntityType.settings,
      actionType: SyncActionType.created,
      recordId: ledger.id,
    );
    notifyListeners();
  }

  Future<void> updateCurrencyLedgers({
    required List<CurrencyLedgerProfile> ledgers,
    String? selectedLedgerId,
  }) async {
    _data = _data.copyWith(
      settings: FinanceSettings(
        currencyLedgers: ledgers,
        selectedLedgerId: selectedLedgerId ?? (ledgers.isEmpty ? null : ledgers.first.id),
        merchants: settings.merchants,
        foodGroceriesItems: settings.foodGroceriesItems,
        banks: settings.banks,
        cards: settings.cards,
      ),
    );
    await _persist();
    _emitSyncEvent(
      entityType: SyncEntityType.settings,
      actionType: SyncActionType.updated,
      recordId: 'ledgers',
    );
    notifyListeners();
  }

  Future<void> setSelectedLedger(String ledgerId) async {
    if (!settings.currencyLedgers.any((ledger) => ledger.id == ledgerId)) return;
    _data = _data.copyWith(
      settings: settings.copyWith(selectedLedgerId: ledgerId),
    );
    await _persist();
    _emitSyncEvent(
      entityType: SyncEntityType.settings,
      actionType: SyncActionType.updated,
      recordId: ledgerId,
    );
    notifyListeners();
  }

  CurrencyLedgerProfile? ledgerById(String ledgerId) {
    for (final ledger in settings.currencyLedgers) {
      if (ledger.id == ledgerId) return ledger;
    }
    return null;
  }

  Future<void> updateMasterData({
    List<String>? merchants,
    List<String>? foodGroceriesItems,
    List<String>? banks,
    List<String>? cards,
  }) async {
    _data = _data.copyWith(
      settings: settings.copyWith(
        merchants: merchants != null ? _normalizeStringItems(merchants) : null,
        foodGroceriesItems: foodGroceriesItems != null
            ? _normalizeStringItems(foodGroceriesItems)
            : null,
        banks: banks != null ? _normalizeStringItems(banks) : null,
        cards: cards != null ? _normalizeStringItems(cards) : null,
      ),
    );
    await _persistAndNotify(
      SyncEntityType.settings,
      SyncActionType.updated,
      'master-data',
    );
  }

  ParsedExpenseDraft parseExpenseMessage(
    String message, {
    String ledgerId = '',
    required String country,
    required String currencyCode,
  }) {
    final lowered = message.toLowerCase();
    final amountMatch = RegExp(
      r'(?:rs\.?|inr|sgd|usd|eur|gbp|s\$|\$)?\s?(\d+(?:[,\d]{0,12})?(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    final amount = double.tryParse(
          amountMatch?.group(1)?.replaceAll(',', '') ?? '',
        ) ??
        0;

    final date = _parseDate(message) ?? DateTime.now();
    final utilityType = _inferUtilityType(lowered);
    final category = _inferCategory(lowered, utilityType);
    final subtype = _inferSubtype(lowered, category);
    final merchant = _inferMerchant(message);
    final confidence = _scoreConfidence(
      amount: amount,
      merchant: merchant,
      category: category,
      utilityType: utilityType,
    );

    return ParsedExpenseDraft(
      ledgerId: ledgerId,
      country: country,
      currencyCode: currencyCode,
      amount: amount,
      date: date,
      category: category,
      subtype: subtype,
      utilityType: utilityType,
      merchant: merchant,
      confidence: confidence,
      paidByKind: _inferPaymentKind(lowered),
      paymentChannel: _inferPaymentKind(lowered).label,
      rawMessage: message.trim(),
      notes: confidence < 0.75 ? 'Needs review' : 'Imported from message',
    );
  }

  DateTime? _parseDate(String message) {
    final slash = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(message);
    if (slash != null) {
      final day = int.parse(slash.group(1)!);
      final month = int.parse(slash.group(2)!);
      final year = int.parse(slash.group(3)!);
      return DateTime(year < 100 ? 2000 + year : year, month, day);
    }
    return null;
  }

  UtilityType? _inferUtilityType(String lowered) {
    if (lowered.contains('water')) return UtilityType.water;
    if (lowered.contains('electricity') || lowered.contains('power')) {
      return UtilityType.electricity;
    }
    if (lowered.contains('gas')) return UtilityType.gas;
    if (lowered.contains('wifi') || lowered.contains('broadband')) {
      return UtilityType.wifiRecharge;
    }
    if (lowered.contains('phone') ||
        lowered.contains('mobile recharge') ||
        lowered.contains('recharge')) {
      return UtilityType.phone;
    }
    return null;
  }

  ExpenseCategory _inferCategory(String lowered, UtilityType? utilityType) {
    if (utilityType != null) return ExpenseCategory.utilities;
    if (lowered.contains('grocery') ||
        lowered.contains('supermarket') ||
        lowered.contains('mart')) {
      return ExpenseCategory.foodGroceries;
    }
    if (lowered.contains('zomato') ||
        lowered.contains('swiggy') ||
        lowered.contains('grabfood') ||
        lowered.contains('restaurant') ||
        lowered.contains('cafe') ||
        lowered.contains('food')) {
      return ExpenseCategory.foodGroceries;
    }
    if (lowered.contains('uber') ||
        lowered.contains('ola') ||
        lowered.contains('grab') ||
        lowered.contains('metro') ||
        lowered.contains('fuel')) {
      return ExpenseCategory.transport;
    }
    if (lowered.contains('doctor') ||
        lowered.contains('pharmacy') ||
        lowered.contains('hospital')) {
      return ExpenseCategory.healthcare;
    }
    if (lowered.contains('movie') ||
        lowered.contains('netflix') ||
        lowered.contains('spotify')) {
      return ExpenseCategory.entertainment;
    }
    if (lowered.contains('rent') || lowered.contains('maintenance')) {
      return ExpenseCategory.housing;
    }
    if (lowered.contains('amazon') ||
        lowered.contains('flipkart') ||
        lowered.contains('store') ||
        lowered.contains('shopping')) {
      return ExpenseCategory.shopping;
    }
    return ExpenseCategory.other;
  }

  ExpenseSubtype? _inferSubtype(String lowered, ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.housing:
        if (lowered.contains('rent')) return ExpenseSubtype.rent;
        if (lowered.contains('emi')) return ExpenseSubtype.emi;
        if (lowered.contains('maintenance')) return ExpenseSubtype.maintenance;
        return null;
      case ExpenseCategory.transport:
        if (lowered.contains('bus')) return ExpenseSubtype.bus;
        if (lowered.contains('train') || lowered.contains('metro')) {
          return ExpenseSubtype.train;
        }
        if (lowered.contains('cab') || lowered.contains('uber') || lowered.contains('ola') || lowered.contains('grab')) {
          return ExpenseSubtype.cab;
        }
        if (lowered.contains('flight') || lowered.contains('air')) {
          return ExpenseSubtype.flight;
        }
        return null;
      case ExpenseCategory.healthcare:
        if (lowered.contains('vaccine')) return ExpenseSubtype.vaccine;
        if (lowered.contains('doctor')) return ExpenseSubtype.doctor;
        if (lowered.contains('medicine') || lowered.contains('pharmacy')) {
          return ExpenseSubtype.medicine;
        }
        return null;
      default:
        return null;
    }
  }

  String _inferMerchant(String message) {
    final merchantMatch = RegExp(
      r'(?:at|to)\s+([A-Za-z0-9 &._-]{3,40})',
      caseSensitive: false,
    ).firstMatch(message);
    return merchantMatch?.group(1)?.trim() ?? 'Unknown merchant';
  }

  PaymentSourceKind _inferPaymentKind(String lowered) {
    if (lowered.contains('upi')) return PaymentSourceKind.upi;
    if (lowered.contains('card') || lowered.contains('credit card')) {
      return PaymentSourceKind.card;
    }
    if (lowered.contains('bank transfer') || lowered.contains('neft')) {
      return PaymentSourceKind.bank;
    }
    if (lowered.contains('cash')) return PaymentSourceKind.cash;
    return PaymentSourceKind.other;
  }

  double _scoreConfidence({
    required double amount,
    required String merchant,
    required ExpenseCategory category,
    required UtilityType? utilityType,
  }) {
    var score = 0.3;
    if (amount > 0) score += 0.25;
    if (merchant != 'Unknown merchant') score += 0.2;
    if (category != ExpenseCategory.other) score += 0.2;
    if (utilityType != null) score += 0.1;
    return score.clamp(0, 1);
  }

  Future<void> addManualExpense({
    required DateTime transactionDate,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required ExpenseCategory category,
    ExpenseSubtype? subtype,
    UtilityType? utilityType,
    required String merchant,
    required String notes,
    PaymentSourceKind paidByKind = PaymentSourceKind.other,
    String paymentChannel = 'Manual',
    String bankName = '',
    String cardName = '',
    String externalMessageId = '',
    String country = '',
  }) async {
    final item = ExpenseEntry(
      id: _newId('expense'),
      ledgerId: ledgerId,
      source: EntrySource.manual,
      createdAt: DateTime.now(),
      transactionDate: transactionDate,
      currencyCode: currencyCode,
      nativeAmount: amount,
      category: category,
      subtype: subtype,
      utilityType: utilityType,
      notes: notes,
      merchant: merchant,
      confidenceScore: 1,
      rawMessage: '',
      paymentChannel: paymentChannel,
      paidByKind: paidByKind,
      bankName: bankName,
      cardName: cardName,
      externalMessageId: externalMessageId,
      country: country,
    );
    _data = _data.copyWith(expenses: [..._data.expenses, item]);
    await _persistAndNotify(SyncEntityType.expense, SyncActionType.created, item.id);
  }

  Future<void> updateExpense({
    required String id,
    required DateTime transactionDate,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required ExpenseCategory category,
    ExpenseSubtype? subtype,
    UtilityType? utilityType,
    required String merchant,
    required String notes,
    PaymentSourceKind paidByKind = PaymentSourceKind.other,
    String paymentChannel = 'Manual',
    String bankName = '',
    String cardName = '',
    String externalMessageId = '',
    String country = '',
  }) async {
    _data = _data.copyWith(
      expenses: _data.expenses.map((item) {
        if (item.id != id) return item;
        return item.copyWith(
          transactionDate: transactionDate,
          ledgerId: ledgerId,
          currencyCode: currencyCode,
          nativeAmount: amount,
          category: category,
          subtype: subtype,
          utilityType: utilityType,
          merchant: merchant,
          notes: notes,
          paymentChannel: paymentChannel,
          paidByKind: paidByKind,
          bankName: bankName,
          cardName: cardName,
          externalMessageId: externalMessageId,
          country: country,
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.expense, SyncActionType.updated, id);
  }

  Future<void> deleteExpense(String id) async {
    _data = _data.copyWith(
      expenses: _data.expenses.where((item) => item.id != id).toList(),
    );
    await _persistAndNotify(SyncEntityType.expense, SyncActionType.deleted, id);
  }

  Future<void> importExpenseMessage({
    required EntrySource source,
    required String rawMessage,
    required String ledgerId,
    required String currencyCode,
    String externalMessageId = '',
    String notes = '',
    String country = '',
  }) async {
    if (externalMessageId.isNotEmpty &&
        _data.expenses.any((item) => item.externalMessageId == externalMessageId)) {
      return;
    }
    final parsed = parseExpenseMessage(
      rawMessage,
      ledgerId: ledgerId,
      country: country,
      currencyCode: currencyCode,
    );
    final item = ExpenseEntry(
      id: _newId('expense'),
      ledgerId: parsed.ledgerId,
      source: source,
      createdAt: DateTime.now(),
      transactionDate: parsed.date,
      currencyCode: parsed.currencyCode,
      nativeAmount: parsed.amount,
      category: parsed.category,
      subtype: parsed.subtype,
      utilityType: parsed.utilityType,
      notes: notes.isEmpty ? parsed.notes : notes,
      merchant: parsed.merchant,
      confidenceScore: parsed.confidence,
      rawMessage: parsed.rawMessage,
      paymentChannel: parsed.paymentChannel,
      paidByKind: parsed.paidByKind,
      bankName: '',
      cardName: '',
      externalMessageId: externalMessageId,
      country: parsed.country,
    );
    _data = _data.copyWith(expenses: [..._data.expenses, item]);
    await _persistAndNotify(SyncEntityType.expense, SyncActionType.imported, item.id);
  }

  Future<void> autoImportSmsExpense({
    required String messageId,
    required String rawMessage,
    required DateTime receivedAt,
    String sender = '',
  }) async {
    if (messageId.isEmpty ||
        _data.expenses.any((item) => item.externalMessageId == messageId)) {
      return;
    }
    final matchedLedger = _inferLedgerForMessage(rawMessage);
    final ledger = matchedLedger ?? selectedLedger ?? (settings.currencyLedgers.isNotEmpty ? settings.currencyLedgers.first : null);
    if (ledger == null) return;
    await importExpenseMessage(
      source: EntrySource.sms,
      rawMessage: rawMessage,
      ledgerId: ledger.id,
      currencyCode: ledger.currencyCode,
      externalMessageId: messageId,
      notes: sender.trim().isEmpty
          ? 'Auto imported from SMS'
          : 'Auto imported from SMS • $sender',
      country: '',
    );
  }

  CurrencyLedgerProfile? _inferLedgerForMessage(String message) {
    final upper = message.toUpperCase();
    for (final ledger in settings.currencyLedgers) {
      final currency = ledger.currencyCode.toUpperCase();
      if (upper.contains(currency)) {
        return ledger;
      }
      if (currency == 'SGD' && upper.contains('S\$')) {
        return ledger;
      }
      if (currency == 'INR' &&
          (upper.contains('RS') || upper.contains('RS.') || upper.contains('₹'))) {
        return ledger;
      }
    }
    return null;
  }

  Future<void> reclassifyExpense(
    ExpenseEntry expense, {
    required ExpenseCategory category,
    ExpenseSubtype? subtype,
    UtilityType? utilityType,
  }) async {
    _data = _data.copyWith(
      expenses: _data.expenses.map((item) {
        if (item.id != expense.id) return item;
        return item.copyWith(
          category: category,
          subtype: subtype,
          utilityType: utilityType,
          confidenceScore: 1,
          notes: item.notes.isEmpty ? 'reviewed' : '${item.notes} • reviewed',
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.expense, SyncActionType.updated, expense.id);
  }

  Future<void> addSavingsRecord({
    required DateTime month,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required SavingsRecordSource source,
    required String notes,
    String country = '',
  }) async {
    final item = MonthlySavingsRecord(
      id: _newId('saving'),
      ledgerId: ledgerId,
      month: DateTime(month.year, month.month),
      currencyCode: currencyCode,
      nativeAmount: amount,
      source: source,
      notes: notes,
      country: country,
    );
    _data = _data.copyWith(savingsRecords: [..._data.savingsRecords, item]);
    await _persistAndNotify(SyncEntityType.savings, SyncActionType.created, item.id);
  }

  Future<void> updateSavingsRecord({
    required String id,
    required DateTime month,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required SavingsRecordSource source,
    required String notes,
    String country = '',
  }) async {
    _data = _data.copyWith(
      savingsRecords: _data.savingsRecords.map((item) {
        if (item.id != id) return item;
        return MonthlySavingsRecord(
          id: item.id,
          ledgerId: ledgerId,
          month: DateTime(month.year, month.month),
          currencyCode: currencyCode,
          nativeAmount: amount,
          source: source,
          notes: notes,
          country: country,
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.savings, SyncActionType.updated, id);
  }

  Future<void> deleteSavingsRecord(String id) async {
    _data = _data.copyWith(
      savingsRecords: _data.savingsRecords.where((item) => item.id != id).toList(),
    );
    await _persistAndNotify(SyncEntityType.savings, SyncActionType.deleted, id);
  }

  Future<void> addEarningRecord({
    required DateTime month,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required EarningsRecordSource source,
    required String notes,
    String country = '',
  }) async {
    final item = MonthlyEarningRecord(
      id: _newId('earning'),
      ledgerId: ledgerId,
      month: DateTime(month.year, month.month),
      currencyCode: currencyCode,
      nativeAmount: amount,
      source: source,
      notes: notes,
      country: country,
    );
    _data = _data.copyWith(earningsRecords: [..._data.earningsRecords, item]);
    await _persistAndNotify(SyncEntityType.earning, SyncActionType.created, item.id);
  }

  Future<void> updateEarningRecord({
    required String id,
    required DateTime month,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required EarningsRecordSource source,
    required String notes,
    String country = '',
  }) async {
    _data = _data.copyWith(
      earningsRecords: _data.earningsRecords.map((item) {
        if (item.id != id) return item;
        return MonthlyEarningRecord(
          id: item.id,
          ledgerId: ledgerId,
          month: DateTime(month.year, month.month),
          currencyCode: currencyCode,
          nativeAmount: amount,
          source: source,
          notes: notes,
          country: country,
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.earning, SyncActionType.updated, id);
  }

  Future<void> deleteEarningRecord(String id) async {
    _data = _data.copyWith(
      earningsRecords: _data.earningsRecords.where((item) => item.id != id).toList(),
    );
    await _persistAndNotify(SyncEntityType.earning, SyncActionType.deleted, id);
  }

  Future<void> addSavingsAllocation({
    required DateTime month,
    required SavingsAllocationType type,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required String notes,
    String country = '',
  }) async {
    final item = SavingsAllocation(
      id: _newId('allocation'),
      ledgerId: ledgerId,
      month: DateTime(month.year, month.month),
      type: type,
      currencyCode: currencyCode,
      nativeAmount: amount,
      notes: notes,
      country: country,
    );
    _data = _data.copyWith(allocations: [..._data.allocations, item]);
    await _persistAndNotify(SyncEntityType.savingsAllocation, SyncActionType.created, item.id);
  }

  Future<void> addInvestmentEntry({
    required DateTime month,
    required InvestmentType type,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required String notes,
    String country = '',
  }) async {
    final item = InvestmentEntry(
      id: _newId('investment'),
      ledgerId: ledgerId,
      month: DateTime(month.year, month.month, month.day),
      type: type,
      currencyCode: currencyCode,
      nativeAmount: amount,
      notes: notes,
      country: country,
    );
    _data = _data.copyWith(investments: [..._data.investments, item]);
    await _persistAndNotify(SyncEntityType.investment, SyncActionType.created, item.id);
  }

  Future<void> updateInvestmentEntry({
    required String id,
    required DateTime month,
    required InvestmentType type,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required String notes,
    String country = '',
  }) async {
    _data = _data.copyWith(
      investments: _data.investments.map((item) {
        if (item.id != id) return item;
        return InvestmentEntry(
          id: item.id,
          ledgerId: ledgerId,
          month: DateTime(month.year, month.month, month.day),
          type: type,
          currencyCode: currencyCode,
          nativeAmount: amount,
          notes: notes,
          country: country,
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.investment, SyncActionType.updated, id);
  }

  Future<void> deleteInvestmentEntry(String id) async {
    _data = _data.copyWith(
      investments: _data.investments.where((item) => item.id != id).toList(),
    );
    await _persistAndNotify(SyncEntityType.investment, SyncActionType.deleted, id);
  }

  Future<void> addAsset({
    required AssetType type,
    required String name,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required DateTime valuationDate,
    required String notes,
    String country = '',
  }) async {
    final item = AssetHolding(
      id: _newId('asset'),
      ledgerId: ledgerId,
      type: type,
      name: name,
      currencyCode: currencyCode,
      nativeValue: amount,
      valuationDate: valuationDate,
      notes: notes,
      country: country,
    );
    _data = _data.copyWith(assets: [..._data.assets, item]);
    await _persistAndNotify(SyncEntityType.asset, SyncActionType.created, item.id);
  }

  Future<void> updateAsset({
    required String id,
    required AssetType type,
    required String name,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    required DateTime valuationDate,
    required String notes,
    String country = '',
  }) async {
    _data = _data.copyWith(
      assets: _data.assets.map((item) {
        if (item.id != id) return item;
        return AssetHolding(
          id: item.id,
          ledgerId: ledgerId,
          type: type,
          name: name,
          currencyCode: currencyCode,
          nativeValue: amount,
          valuationDate: valuationDate,
          notes: notes,
          country: country,
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.asset, SyncActionType.updated, id);
  }

  Future<void> addLiability({
    required LiabilityType type,
    required String name,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    DateTime? dueDate,
    required String notes,
    String country = '',
  }) async {
    final item = LiabilityHolding(
      id: _newId('liability'),
      ledgerId: ledgerId,
      type: type,
      name: name,
      currencyCode: currencyCode,
      nativeOutstanding: amount,
      dueDate: dueDate,
      notes: notes,
      country: country,
    );
    _data = _data.copyWith(liabilities: [..._data.liabilities, item]);
    await _persistAndNotify(SyncEntityType.liability, SyncActionType.created, item.id);
  }

  Future<void> updateLiability({
    required String id,
    required LiabilityType type,
    required String name,
    required String ledgerId,
    required String currencyCode,
    required double amount,
    DateTime? dueDate,
    required String notes,
    String country = '',
  }) async {
    _data = _data.copyWith(
      liabilities: _data.liabilities.map((item) {
        if (item.id != id) return item;
        return LiabilityHolding(
          id: item.id,
          ledgerId: ledgerId,
          type: type,
          name: name,
          currencyCode: currencyCode,
          nativeOutstanding: amount,
          dueDate: dueDate,
          notes: notes,
          country: country,
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.liability, SyncActionType.updated, id);
  }

  Future<void> addFxRate({
    required DateTime effectiveDate,
    required String country,
    required String currencyCode,
    required String toCurrencyCode,
    required double rate,
  }) async {
    final item = FxRate(
      id: _newId('fx'),
      effectiveDate: effectiveDate,
      country: country,
      currencyCode: currencyCode,
      reportingCurrency: toCurrencyCode,
      rateToReportingCurrency: rate,
    );
    _data = _data.copyWith(fxRates: [..._data.fxRates, item]);
    await _persistAndNotify(SyncEntityType.fxRate, SyncActionType.created, item.id);
  }

  double _conversionRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    required String country,
    required DateTime asOf,
  }) {
    final matching = _data.fxRates.where((rate) {
      return rate.currencyCode == fromCurrencyCode &&
          rate.reportingCurrency == toCurrencyCode &&
          (country.isEmpty || rate.country == country) &&
          !rate.effectiveDate.isAfter(asOf);
    }).toList()
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    if (matching.isNotEmpty) return matching.first.rateToReportingCurrency;

    final fallback = _data.fxRates.where((rate) {
      return rate.currencyCode == fromCurrencyCode &&
          rate.reportingCurrency == toCurrencyCode;
    }).toList()
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return fallback.isEmpty ? 0 : fallback.first.rateToReportingCurrency;
  }

  Future<void> addForexTransfer({
    required DateTime transferDate,
    required String fromCountry,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCountry,
    required String toCurrencyCode,
    required double toAmount,
    required String notes,
  }) async {
    final item = ForexTransfer(
      id: _newId('fxfer'),
      transferDate: transferDate,
      fromCountry: fromCountry,
      fromCurrencyCode: fromCurrencyCode,
      fromAmount: fromAmount,
      toCountry: toCountry,
      toCurrencyCode: toCurrencyCode,
      toAmount: toAmount,
      reportingAmount: toAmount,
      notes: notes,
      fxRateApplied: fromAmount == 0
          ? _conversionRate(
              fromCurrencyCode: fromCurrencyCode,
              toCurrencyCode: toCurrencyCode,
              country: fromCountry,
              asOf: transferDate,
            )
          : toAmount / fromAmount,
    );
    _data = _data.copyWith(forexTransfers: [..._data.forexTransfers, item]);
    await _persistAndNotify(SyncEntityType.forexTransfer, SyncActionType.created, item.id);
  }

  Future<void> updateForexTransfer({
    required String id,
    required DateTime transferDate,
    required String fromCountry,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCountry,
    required String toCurrencyCode,
    required double toAmount,
    required String notes,
  }) async {
    _data = _data.copyWith(
      forexTransfers: _data.forexTransfers.map((item) {
        if (item.id != id) return item;
        return ForexTransfer(
          id: item.id,
          transferDate: transferDate,
          fromCountry: fromCountry,
          fromCurrencyCode: fromCurrencyCode,
          fromAmount: fromAmount,
          toCountry: toCountry,
          toCurrencyCode: toCurrencyCode,
          toAmount: toAmount,
          reportingAmount: toAmount,
          notes: notes,
          fxRateApplied: fromAmount == 0
              ? _conversionRate(
                  fromCurrencyCode: fromCurrencyCode,
                  toCurrencyCode: toCurrencyCode,
                  country: fromCountry,
                  asOf: transferDate,
                )
              : toAmount / fromAmount,
        );
      }).toList(),
    );
    await _persistAndNotify(SyncEntityType.forexTransfer, SyncActionType.updated, id);
  }

  Future<void> deleteForexTransfer(String id) async {
    _data = _data.copyWith(
      forexTransfers: _data.forexTransfers.where((item) => item.id != id).toList(),
    );
    await _persistAndNotify(SyncEntityType.forexTransfer, SyncActionType.deleted, id);
  }

  MonthlyReport monthlyReport(DateTime month, {String? ledgerId}) {
    final activeLedgerId = ledgerId ?? selectedLedgerId;
    final currencyCode = ledgerById(activeLedgerId)?.currencyCode ?? '';
    final filteredExpenses = _data.expenses.where((item) {
      return item.ledgerId == activeLedgerId &&
          item.transactionDate.year == month.year &&
          item.transactionDate.month == month.month;
    }).toList();
    final filteredEarnings = _data.earningsRecords.where((item) {
      return item.ledgerId == activeLedgerId &&
          item.month.year == month.year &&
          item.month.month == month.month;
    }).toList();
    final filteredSavings = _data.savingsRecords.where((item) {
      return item.ledgerId == activeLedgerId &&
          item.month.year == month.year &&
          item.month.month == month.month;
    }).toList();
    final filteredAllocations = _data.allocations.where((item) {
      return item.ledgerId == activeLedgerId &&
          item.month.year == month.year &&
          item.month.month == month.month;
    }).toList();
    final filteredInvestments = _data.investments.where((item) {
      return item.ledgerId == activeLedgerId &&
          item.month.year == month.year &&
          item.month.month == month.month;
    }).toList();
    final inboundTransfers = _data.forexTransfers.where((item) {
      return item.toCurrencyCode == currencyCode &&
          item.transferDate.year == month.year &&
          item.transferDate.month == month.month;
    }).toList();

    final assetTotal = _data.assets
        .where((item) => item.ledgerId == activeLedgerId)
        .fold<double>(0, (sum, item) => sum + item.nativeValue);
    final liabilityTotal = _data.liabilities
        .where((item) => item.ledgerId == activeLedgerId)
        .fold<double>(0, (sum, item) => sum + item.nativeOutstanding);

    final totalEarnings = filteredEarnings.fold<double>(0, (sum, item) => sum + item.nativeAmount) +
        inboundTransfers.fold<double>(0, (sum, item) => sum + item.toAmount);
    final totalExpense = filteredExpenses.fold<double>(0, (sum, item) => sum + item.nativeAmount);
    final totalSavings = filteredSavings.fold<double>(0, (sum, item) => sum + item.nativeAmount) +
        inboundTransfers.fold<double>(0, (sum, item) => sum + item.toAmount);
    final totalInvestments =
        filteredInvestments.fold<double>(0, (sum, item) => sum + item.nativeAmount);

    return MonthlyReport(
      month: DateTime(month.year, month.month),
      currencyCode: currencyCode,
      totalEarnings: totalEarnings,
      totalExpense: totalExpense,
      remainingBalance: totalEarnings - totalExpense,
      totalSavings: totalSavings,
      totalInvestments: totalInvestments,
      manualSavings: filteredSavings
          .where((item) => item.source == SavingsRecordSource.manual)
          .fold<double>(0, (sum, item) => sum + item.nativeAmount),
      derivedSavings: filteredSavings
          .where((item) => item.source == SavingsRecordSource.derived)
          .fold<double>(0, (sum, item) => sum + item.nativeAmount),
      categoryTotals: _sumExpensesBy(filteredExpenses, (item) => item.category.label),
      utilityTotals: _sumExpensesBy(
        filteredExpenses.where((item) => item.utilityType != null).toList(),
        (item) => item.utilityType!.label,
      ),
      allocationTotals: _sumAllocationsBy(filteredAllocations, (item) => item.type.label),
      investmentTotals: _sumInvestmentsBy(filteredInvestments, (item) => item.type.label),
      assetTotal: assetTotal,
      liabilityTotal: liabilityTotal,
    );
  }

  YearlyReport yearlyReport(int year, {String? ledgerId}) {
    final activeLedgerId = ledgerId ?? selectedLedgerId;
    final currencyCode = ledgerById(activeLedgerId)?.currencyCode ?? '';
    final yearExpenses = _data.expenses.where((item) {
      return item.ledgerId == activeLedgerId && item.transactionDate.year == year;
    }).toList();
    final yearEarnings = _data.earningsRecords.where((item) {
      return item.ledgerId == activeLedgerId && item.month.year == year;
    }).toList();
    final yearSavings = _data.savingsRecords.where((item) {
      return item.ledgerId == activeLedgerId && item.month.year == year;
    }).toList();
    final yearAllocations = _data.allocations.where((item) {
      return item.ledgerId == activeLedgerId && item.month.year == year;
    }).toList();
    final yearInvestments = _data.investments.where((item) {
      return item.ledgerId == activeLedgerId && item.month.year == year;
    }).toList();
    final yearInboundTransfers = _data.forexTransfers.where((item) {
      return item.toCurrencyCode == currencyCode && item.transferDate.year == year;
    }).toList();
    final assetsTotal = _data.assets
        .where((item) => item.ledgerId == activeLedgerId)
        .fold<double>(0, (sum, item) => sum + item.nativeValue);
    final liabilitiesTotal = _data.liabilities
        .where((item) => item.ledgerId == activeLedgerId)
        .fold<double>(0, (sum, item) => sum + item.nativeOutstanding);

    final expenseByMonth = _sumExpensesBy(
      yearExpenses,
      (item) => '${item.transactionDate.year}-${item.transactionDate.month.toString().padLeft(2, '0')}',
    );
    final earningsByMonth = _sumEarningsBy(
      yearEarnings,
      (item) => '${item.month.year}-${item.month.month.toString().padLeft(2, '0')}',
    );
    for (final transfer in yearInboundTransfers) {
      final key =
          '${transfer.transferDate.year}-${transfer.transferDate.month.toString().padLeft(2, '0')}';
      final matchIndex = earningsByMonth.indexWhere((item) => item.label == key);
      if (matchIndex >= 0) {
        final current = earningsByMonth[matchIndex];
        earningsByMonth[matchIndex] =
            TotalsByLabel(current.label, current.nativeTotal + transfer.toAmount, current.reportingTotal + transfer.toAmount);
      } else {
        earningsByMonth.add(TotalsByLabel(key, transfer.toAmount, transfer.toAmount));
      }
    }
    earningsByMonth.sort((a, b) => a.label.compareTo(b.label));

    final remainingMap = <String, double>{};
    for (final item in earningsByMonth) {
      remainingMap[item.label] = (remainingMap[item.label] ?? 0) + item.nativeTotal;
    }
    for (final item in expenseByMonth) {
      remainingMap[item.label] = (remainingMap[item.label] ?? 0) - item.nativeTotal;
    }
    final remainingByMonth = remainingMap.entries
        .map((entry) => TotalsByLabel(entry.key, entry.value, entry.value))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return YearlyReport(
      year: year,
      currencyCode: currencyCode,
      earningsMonthTotals: earningsByMonth,
      expenseMonthTotals: expenseByMonth,
      remainingMonthTotals: remainingByMonth,
      categoryTotals: _sumExpensesBy(yearExpenses, (item) => item.category.label),
      allocationTotals: _sumAllocationsBy(yearAllocations, (item) => item.type.label),
      savingsTotals: _sumSavingsTotalsWithTransfers(yearSavings, yearInboundTransfers),
      investmentMonthTotals: _sumInvestmentsBy(
        yearInvestments,
        (item) => '${item.month.year}-${item.month.month.toString().padLeft(2, '0')}',
      )..sort((a, b) => a.label.compareTo(b.label)),
      investmentTypeTotals: _sumInvestmentsBy(yearInvestments, (item) => item.type.label),
      assetTotal: assetsTotal,
      liabilityTotal: liabilitiesTotal,
      netWorth: assetsTotal - liabilitiesTotal,
    );
  }

  List<ForexTransfer> get forexTransfersInSelectedMonth =>
      forexTransfers.where((item) {
        return item.transferDate.year == selectedMonth.year &&
            item.transferDate.month == selectedMonth.month;
      }).toList();

  ForexTransferReport forexTransferReportForSelectedMonth() {
    final list = forexTransfersInSelectedMonth;
    return ForexTransferReport(
      monthTotals: _sumForexBy(
        list,
        (item) => '${item.transferDate.year}-${item.transferDate.month.toString().padLeft(2, '0')}',
      ),
      yearTotals: _sumForexBy(list, (item) => '${item.transferDate.year}'),
      totalFromAmount: list.fold<double>(0, (sum, item) => sum + item.fromAmount),
      totalToAmount: list.fold<double>(0, (sum, item) => sum + item.toAmount),
      totalReportingAmount:
          list.fold<double>(0, (sum, item) => sum + item.reportingAmount),
    );
  }

  ForexTransferReport forexTransferReport() {
    return ForexTransferReport(
      monthTotals: _sumForexBy(
        _data.forexTransfers,
        (item) => '${item.transferDate.year}-${item.transferDate.month.toString().padLeft(2, '0')}',
      ),
      yearTotals: _sumForexBy(_data.forexTransfers, (item) => '${item.transferDate.year}'),
      totalFromAmount: _data.forexTransfers.fold<double>(0, (sum, item) => sum + item.fromAmount),
      totalToAmount: _data.forexTransfers.fold<double>(0, (sum, item) => sum + item.toAmount),
      totalReportingAmount: _data.forexTransfers.fold<double>(0, (sum, item) => sum + item.reportingAmount),
    );
  }

  DashboardSummary dashboardSummary({String? ledgerId, DateTime? forMonth}) {
    final activeLedgerId = ledgerId ?? selectedLedgerId;
    final asOfMonth = forMonth ?? selectedMonth;
    final currentMonth = monthlyReport(asOfMonth, ledgerId: activeLedgerId);
    final assetBreakdown = _sumAssetsBy(
      _data.assets.where((item) => item.ledgerId == activeLedgerId).toList(),
      (item) => item.type.label,
    );
    final investmentEntries =
        _data.investments.where((item) => item.ledgerId == activeLedgerId).toList();
    final investmentEntriesInMonth = investmentEntries
        .where(
          (item) =>
              item.month.year == asOfMonth.year && item.month.month == asOfMonth.month,
        )
        .toList();
    final currentMonthInvestments =
        investmentEntriesInMonth.fold<double>(0, (sum, item) => sum + item.nativeAmount);
    final liabilityBreakdown = _sumLiabilitiesBy(
      _data.liabilities.where((item) => item.ledgerId == activeLedgerId).toList(),
      (item) => item.type.label,
    );
    return DashboardSummary(
      currencyCode: currentMonth.currencyCode,
      currentMonthEarnings: currentMonth.totalEarnings,
      currentMonthSpend: currentMonth.totalExpense,
      currentMonthSavings: currentMonth.totalSavings,
      currentMonthInvestments: currentMonthInvestments,
      currentMonthRemaining: currentMonth.remainingBalance,
      totalAssets: currentMonth.assetTotal,
      totalLiabilities: currentMonth.liabilityTotal,
      netWorth: currentMonth.assetTotal - currentMonth.liabilityTotal,
      totalInvestments:
          investmentEntries.fold<double>(0, (sum, item) => sum + item.nativeAmount),
      investmentBreakdown:
          _sumInvestmentsBy(investmentEntriesInMonth, (item) => item.type.label),
      assetBreakdown: assetBreakdown,
      liabilityBreakdown: liabilityBreakdown,
    );
  }

  List<ExpenseEntry> currentMonthExpenses({String? ledgerId}) {
    final activeLedgerId = ledgerId ?? selectedLedgerId;
    final now = DateTime.now();
    return _data.expenses.where((item) {
      return item.ledgerId == activeLedgerId &&
          item.transactionDate.year == now.year &&
          item.transactionDate.month == now.month;
    }).toList();
  }

  Future<void> _persistAndNotify(
    SyncEntityType entityType,
    SyncActionType actionType,
    String recordId,
  ) async {
    await _persist();
    _emitSyncEvent(
      entityType: entityType,
      actionType: actionType,
      recordId: recordId,
    );
    notifyListeners();
  }

  List<String> _normalizeStringItems(List<String> items) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        normalized.add(trimmed);
      }
    }
    normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return normalized;
  }

  List<T> _filterBySelectedLedger<T>(
    List<T> items,
    String Function(T item) ledgerSelector,
  ) {
    if (selectedLedgerId.isEmpty) return <T>[];
    return items.where((item) => ledgerSelector(item) == selectedLedgerId).toList();
  }

  List<T> _sortByDateDescending<T>(List<T> items, DateTime Function(T item) selector) {
    return [...items]..sort((a, b) => selector(b).compareTo(selector(a)));
  }

  List<T> _sortByNullableDateDescending<T>(
    List<T> items,
    DateTime? Function(T item) selector,
  ) {
    return [...items]..sort((a, b) {
      final aDate = selector(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = selector(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  }

  List<TotalsByLabel> _sumExpensesBy(
    List<ExpenseEntry> entries,
    String Function(ExpenseEntry item) selector,
  ) {
    final map = <String, double>{};
    for (final item in entries) {
      final key = selector(item);
      map[key] = (map[key] ?? 0) + item.nativeAmount;
    }
    return _toTotals(map);
  }

  List<TotalsByLabel> _sumAllocationsBy(
    List<SavingsAllocation> entries,
    String Function(SavingsAllocation item) selector,
  ) {
    final map = <String, double>{};
    for (final item in entries) {
      final key = selector(item);
      map[key] = (map[key] ?? 0) + item.nativeAmount;
    }
    return _toTotals(map);
  }

  List<TotalsByLabel> _sumEarningsBy(
    List<MonthlyEarningRecord> entries,
    String Function(MonthlyEarningRecord item) selector,
  ) {
    final map = <String, double>{};
    for (final item in entries) {
      final key = selector(item);
      map[key] = (map[key] ?? 0) + item.nativeAmount;
    }
    return _toTotals(map);
  }

  List<TotalsByLabel> _sumAssetsBy(
    List<AssetHolding> entries,
    String Function(AssetHolding item) selector,
  ) {
    final map = <String, double>{};
    for (final item in entries) {
      final key = selector(item);
      map[key] = (map[key] ?? 0) + item.nativeValue;
    }
    return _toTotals(map);
  }

  List<TotalsByLabel> _sumInvestmentsBy(
    List<InvestmentEntry> entries,
    String Function(InvestmentEntry item) selector,
  ) {
    final map = <String, double>{};
    for (final item in entries) {
      final key = selector(item);
      map[key] = (map[key] ?? 0) + item.nativeAmount;
    }
    return _toTotals(map);
  }

  List<TotalsByLabel> _sumLiabilitiesBy(
    List<LiabilityHolding> entries,
    String Function(LiabilityHolding item) selector,
  ) {
    final map = <String, double>{};
    for (final item in entries) {
      final key = selector(item);
      map[key] = (map[key] ?? 0) + item.nativeOutstanding;
    }
    return _toTotals(map);
  }

  List<TotalsByLabel> _sumForexBy(
    List<ForexTransfer> entries,
    String Function(ForexTransfer item) selector,
  ) {
    final map = <String, TotalsByLabel>{};
    for (final item in entries) {
      final key = selector(item);
      final current = map[key];
      map[key] = TotalsByLabel(
        key,
        (current?.nativeTotal ?? 0) + item.fromAmount,
        (current?.reportingTotal ?? 0) + item.toAmount,
      );
    }
    final results = map.values.toList()
      ..sort((a, b) => b.label.compareTo(a.label));
    return results;
  }

  List<TotalsByLabel> _sumSavingsTotalsWithTransfers(
    List<MonthlySavingsRecord> savings,
    List<ForexTransfer> inboundTransfers,
  ) {
    final map = <String, double>{};
    for (final item in savings) {
      final key = '${item.month.year}-${item.month.month.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + item.nativeAmount;
    }
    for (final item in inboundTransfers) {
      final key =
          '${item.transferDate.year}-${item.transferDate.month.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + item.toAmount;
    }
    return _toTotals(map)..sort((a, b) => a.label.compareTo(b.label));
  }

  List<TotalsByLabel> _toTotals(Map<String, double> map) {
    final results = map.entries
        .map((entry) => TotalsByLabel(entry.key, entry.value, entry.value))
        .toList()
      ..sort((a, b) => b.nativeTotal.compareTo(a.nativeTotal));
    return results;
  }
}
