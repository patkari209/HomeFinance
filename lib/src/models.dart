import 'dart:convert';

enum EntrySource { sms, sharedNotification, manual }

enum ExpenseCategory {
  foodGroceries,
  utilities,
  transport,
  shopping,
  healthcare,
  entertainment,
  housing,
  other,
}

enum UtilityType { water, electricity, gas, phone, wifiRecharge, other }

enum ExpenseSubtype {
  rent,
  emi,
  maintenance,
  bus,
  train,
  cab,
  flight,
  vaccine,
  doctor,
  medicine,
}

enum PaymentSourceKind { cash, bank, card, upi, other }

enum SavingsRecordSource { derived, manual, adjustment }

enum EarningsRecordSource { salary, business, freelance, rental, other }

enum SavingsAllocationType {
  mutualFund,
  stock,
  savingsAccount,
  fd,
  rd,
  ppfRetirement,
  cash,
  other,
}

enum InvestmentType {
  mutualFund,
  stock,
  fd,
  rd,
  gold,
  house,
  other,
}

enum AssetType {
  house,
  car,
  savingsAccount,
  mutualFund,
  stock,
  fd,
  rd,
  cash,
  gold,
  other,
}

enum LiabilityType {
  homeLoan,
  carLoan,
  personalLoan,
  creditCardOutstanding,
  other,
}

extension EnumLabel on Enum {
  String get label {
    switch (this) {
      case ExpenseCategory.foodGroceries:
        return 'Food & Groceries';
      case ExpenseSubtype.emi:
        return 'EMI';
      case UtilityType.wifiRecharge:
        return 'WiFi Recharge';
      case SavingsAllocationType.ppfRetirement:
        return 'PPF Retirement';
      case LiabilityType.creditCardOutstanding:
        return 'Credit Card Outstanding';
      case PaymentSourceKind.upi:
        return 'UPI';
      default:
        break;
    }
    final raw = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    );
    return raw
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

T enumByName<T extends Enum>(Iterable<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

class CurrencyLedgerProfile {
  CurrencyLedgerProfile({
    required this.id,
    required this.currencyCode,
    required this.displayName,
  });

  final String id;
  final String currencyCode;
  final String displayName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'currencyCode': currencyCode,
        'displayName': displayName,
      };

  factory CurrencyLedgerProfile.fromJson(Map<String, dynamic> json) {
    final currencyCode = (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    return CurrencyLedgerProfile(
      id: json['id'] as String? ?? currencyCode.toLowerCase(),
      currencyCode: currencyCode,
      displayName: json['displayName'] as String? ?? currencyCode,
    );
  }
}

class FinanceSettings {
  FinanceSettings({
    required this.currencyLedgers,
    required this.selectedLedgerId,
    required this.merchants,
    required this.foodGroceriesItems,
    required this.banks,
    required this.cards,
  });

  final List<CurrencyLedgerProfile> currencyLedgers;
  final String? selectedLedgerId;
  final List<String> merchants;
  final List<String> foodGroceriesItems;
  final List<String> banks;
  final List<String> cards;

  bool get hasLedgers => currencyLedgers.isNotEmpty;

  CurrencyLedgerProfile? get selectedLedger {
    if (currencyLedgers.isEmpty) return null;
    for (final ledger in currencyLedgers) {
      if (ledger.id == selectedLedgerId) return ledger;
    }
    return currencyLedgers.first;
  }

  String get selectedCurrencyCode => selectedLedger?.currencyCode ?? '';

  FinanceSettings copyWith({
    List<CurrencyLedgerProfile>? currencyLedgers,
    String? selectedLedgerId,
    List<String>? merchants,
    List<String>? foodGroceriesItems,
    List<String>? banks,
    List<String>? cards,
  }) {
    return FinanceSettings(
      currencyLedgers: currencyLedgers ?? this.currencyLedgers,
      selectedLedgerId: selectedLedgerId ?? this.selectedLedgerId,
      merchants: merchants ?? this.merchants,
      foodGroceriesItems: foodGroceriesItems ?? this.foodGroceriesItems,
      banks: banks ?? this.banks,
      cards: cards ?? this.cards,
    );
  }

  Map<String, dynamic> toJson() => {
        'currencyLedgers': currencyLedgers.map((item) => item.toJson()).toList(),
        'selectedLedgerId': selectedLedgerId,
        'merchants': merchants,
        'foodGroceriesItems': foodGroceriesItems,
        'banks': banks,
        'cards': cards,
      };

  factory FinanceSettings.fromJson(Map<String, dynamic> json) {
    final ledgers = (json['currencyLedgers'] as List<dynamic>?)
        ?.map((item) => CurrencyLedgerProfile.fromJson(item as Map<String, dynamic>))
        .toList();
    if (ledgers != null && ledgers.isNotEmpty) {
      return FinanceSettings(
        currencyLedgers: ledgers,
        selectedLedgerId: json['selectedLedgerId'] as String? ?? ledgers.first.id,
        merchants: _decodeStringList(json['merchants']),
        foodGroceriesItems: _decodeStringList(json['foodGroceriesItems']),
        banks: _decodeStringList(json['banks']),
        cards: _decodeStringList(json['cards']),
      );
    }

    final profiles = (json['countryProfiles'] as List<dynamic>?)
        ?.map((item) => item as Map<String, dynamic>)
        .toList();
    final migratedLedgers = <CurrencyLedgerProfile>[];
    final seen = <String>{};
    if (profiles != null) {
      for (final profile in profiles) {
        final currencyCode =
            (profile['currencyCode'] as String? ?? '').trim().toUpperCase();
        if (currencyCode.isEmpty || seen.contains(currencyCode)) {
          continue;
        }
        seen.add(currencyCode);
        migratedLedgers.add(
          CurrencyLedgerProfile(
            id: currencyCode.toLowerCase(),
            currencyCode: currencyCode,
            displayName: profile['name'] as String? ?? currencyCode,
          ),
        );
      }
    }

    final reportingCurrency =
        (json['reportingCurrency'] as String? ?? '').trim().toUpperCase();
    if (reportingCurrency.isNotEmpty && !seen.contains(reportingCurrency)) {
      migratedLedgers.add(
        CurrencyLedgerProfile(
          id: reportingCurrency.toLowerCase(),
          currencyCode: reportingCurrency,
          displayName: reportingCurrency,
        ),
      );
    }

    return FinanceSettings(
      currencyLedgers: migratedLedgers,
      selectedLedgerId: migratedLedgers.isEmpty ? null : migratedLedgers.first.id,
      merchants: _decodeStringList(json['merchants']),
      foodGroceriesItems: _decodeStringList(json['foodGroceriesItems']),
      banks: _decodeStringList(json['banks']),
      cards: _decodeStringList(json['cards']),
    );
  }
}

List<String> _decodeStringList(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class ExpenseEntry {
  ExpenseEntry({
    required this.id,
    required this.ledgerId,
    required this.source,
    required this.createdAt,
    required this.transactionDate,
    required this.currencyCode,
    required this.nativeAmount,
    required this.category,
    this.subtype,
    this.utilityType,
    required this.notes,
    required this.merchant,
    required this.confidenceScore,
    required this.rawMessage,
    required this.paymentChannel,
    required this.paidByKind,
    required this.bankName,
    required this.cardName,
    required this.externalMessageId,
    required this.country,
  });

  final String id;
  final String ledgerId;
  final EntrySource source;
  /// When the entry was added to the app (preserves list order independent of backdated transaction dates).
  final DateTime createdAt;
  final DateTime transactionDate;
  final String currencyCode;
  final double nativeAmount;
  final ExpenseCategory category;
  final ExpenseSubtype? subtype;
  final UtilityType? utilityType;
  final String notes;
  final String merchant;
  final double confidenceScore;
  final String rawMessage;
  final String paymentChannel;
  final PaymentSourceKind paidByKind;
  final String bankName;
  final String cardName;
  final String externalMessageId;
  final String country;

  bool get needsReview =>
      source != EntrySource.manual &&
      (category == ExpenseCategory.other || confidenceScore < 0.75);

  ExpenseEntry copyWith({
    String? ledgerId,
    EntrySource? source,
    DateTime? createdAt,
    DateTime? transactionDate,
    String? currencyCode,
    double? nativeAmount,
    ExpenseCategory? category,
    ExpenseSubtype? subtype,
    UtilityType? utilityType,
    String? notes,
    String? merchant,
    double? confidenceScore,
    String? rawMessage,
    String? paymentChannel,
    PaymentSourceKind? paidByKind,
    String? bankName,
    String? cardName,
    String? externalMessageId,
    String? country,
  }) {
    return ExpenseEntry(
      id: id,
      ledgerId: ledgerId ?? this.ledgerId,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      transactionDate: transactionDate ?? this.transactionDate,
      currencyCode: currencyCode ?? this.currencyCode,
      nativeAmount: nativeAmount ?? this.nativeAmount,
      category: category ?? this.category,
      subtype: subtype ?? this.subtype,
      utilityType: utilityType ?? this.utilityType,
      notes: notes ?? this.notes,
      merchant: merchant ?? this.merchant,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      rawMessage: rawMessage ?? this.rawMessage,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      paidByKind: paidByKind ?? this.paidByKind,
      bankName: bankName ?? this.bankName,
      cardName: cardName ?? this.cardName,
      externalMessageId: externalMessageId ?? this.externalMessageId,
      country: country ?? this.country,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'source': source.name,
        'createdAt': createdAt.toIso8601String(),
        'transactionDate': transactionDate.toIso8601String(),
        'currencyCode': currencyCode,
        'nativeAmount': nativeAmount,
        'category': category.name,
        'subtype': subtype?.name,
        'utilityType': utilityType?.name,
        'notes': notes,
        'merchant': merchant,
        'confidenceScore': confidenceScore,
        'rawMessage': rawMessage,
        'paymentChannel': paymentChannel,
        'paidByKind': paidByKind.name,
        'bankName': bankName,
        'cardName': cardName,
        'externalMessageId': externalMessageId,
        'country': country,
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    final currencyCode = (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    final categoryName = json['category'] as String? ?? ExpenseCategory.other.name;
    return ExpenseEntry(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String? ?? currencyCode.toLowerCase(),
      source: enumByName(
        EntrySource.values,
        json['source'] as String? ?? EntrySource.manual.name,
        EntrySource.manual,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.parse(json['transactionDate'] as String),
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      currencyCode: currencyCode,
      nativeAmount: (json['nativeAmount'] as num?)?.toDouble() ?? 0,
      category: _expenseCategoryFromName(categoryName),
      subtype: json['subtype'] == null
          ? null
          : enumByName(
              ExpenseSubtype.values,
              json['subtype'] as String,
              ExpenseSubtype.rent,
            ),
      utilityType: json['utilityType'] == null
          ? null
          : enumByName(
              UtilityType.values,
              json['utilityType'] as String,
              UtilityType.other,
            ),
      notes: json['notes'] as String? ?? '',
      merchant: json['merchant'] as String? ?? '',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
      rawMessage: json['rawMessage'] as String? ?? '',
      paymentChannel: json['paymentChannel'] as String? ?? '',
      paidByKind: enumByName(
        PaymentSourceKind.values,
        json['paidByKind'] as String? ?? _inferLegacyPaidByKindName(json['paymentChannel'] as String? ?? ''),
        PaymentSourceKind.other,
      ),
      bankName: json['bankName'] as String? ?? '',
      cardName: json['cardName'] as String? ?? '',
      externalMessageId: json['externalMessageId'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

ExpenseCategory _expenseCategoryFromName(String name) {
  if (name == 'food' || name == 'groceries') {
    return ExpenseCategory.foodGroceries;
  }
  return enumByName(
    ExpenseCategory.values,
    name,
    ExpenseCategory.other,
  );
}

String _inferLegacyPaidByKindName(String paymentChannel) {
  final lowered = paymentChannel.toLowerCase();
  if (lowered.contains('upi')) return PaymentSourceKind.upi.name;
  if (lowered.contains('card')) return PaymentSourceKind.card.name;
  if (lowered.contains('bank')) return PaymentSourceKind.bank.name;
  if (lowered.contains('cash')) return PaymentSourceKind.cash.name;
  return PaymentSourceKind.other.name;
}

class MonthlySavingsRecord {
  MonthlySavingsRecord({
    required this.id,
    required this.ledgerId,
    required this.month,
    required this.currencyCode,
    required this.nativeAmount,
    required this.source,
    required this.notes,
    required this.country,
  });

  final String id;
  final String ledgerId;
  final DateTime month;
  final String currencyCode;
  final double nativeAmount;
  final SavingsRecordSource source;
  final String notes;
  final String country;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'month': DateTime(month.year, month.month).toIso8601String(),
        'currencyCode': currencyCode,
        'nativeAmount': nativeAmount,
        'source': source.name,
        'notes': notes,
        'country': country,
      };

  factory MonthlySavingsRecord.fromJson(Map<String, dynamic> json) {
    final currencyCode = (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    return MonthlySavingsRecord(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String? ?? currencyCode.toLowerCase(),
      month: DateTime.parse(json['month'] as String),
      currencyCode: currencyCode,
      nativeAmount: (json['nativeAmount'] as num?)?.toDouble() ?? 0,
      source: enumByName(
        SavingsRecordSource.values,
        json['source'] as String? ?? SavingsRecordSource.manual.name,
        SavingsRecordSource.manual,
      ),
      notes: json['notes'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

class MonthlyEarningRecord {
  MonthlyEarningRecord({
    required this.id,
    required this.ledgerId,
    required this.month,
    required this.currencyCode,
    required this.nativeAmount,
    required this.source,
    required this.notes,
    required this.country,
  });

  final String id;
  final String ledgerId;
  final DateTime month;
  final String currencyCode;
  final double nativeAmount;
  final EarningsRecordSource source;
  final String notes;
  final String country;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'month': DateTime(month.year, month.month).toIso8601String(),
        'currencyCode': currencyCode,
        'nativeAmount': nativeAmount,
        'source': source.name,
        'notes': notes,
        'country': country,
      };

  factory MonthlyEarningRecord.fromJson(Map<String, dynamic> json) {
    final currencyCode = (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    return MonthlyEarningRecord(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String? ?? currencyCode.toLowerCase(),
      month: DateTime.parse(json['month'] as String),
      currencyCode: currencyCode,
      nativeAmount: (json['nativeAmount'] as num?)?.toDouble() ?? 0,
      source: enumByName(
        EarningsRecordSource.values,
        json['source'] as String? ?? EarningsRecordSource.salary.name,
        EarningsRecordSource.salary,
      ),
      notes: json['notes'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

class SavingsAllocation {
  SavingsAllocation({
    required this.id,
    required this.ledgerId,
    required this.month,
    required this.type,
    required this.currencyCode,
    required this.nativeAmount,
    required this.notes,
    required this.country,
  });

  final String id;
  final String ledgerId;
  final DateTime month;
  final SavingsAllocationType type;
  final String currencyCode;
  final double nativeAmount;
  final String notes;
  final String country;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'month': DateTime(month.year, month.month).toIso8601String(),
        'type': type.name,
        'currencyCode': currencyCode,
        'nativeAmount': nativeAmount,
        'notes': notes,
        'country': country,
      };

  factory SavingsAllocation.fromJson(Map<String, dynamic> json) {
    final currencyCode = (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    return SavingsAllocation(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String? ?? currencyCode.toLowerCase(),
      month: DateTime.parse(json['month'] as String),
      type: enumByName(
        SavingsAllocationType.values,
        json['type'] as String? ?? SavingsAllocationType.other.name,
        SavingsAllocationType.other,
      ),
      currencyCode: currencyCode,
      nativeAmount: (json['nativeAmount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

class AssetHolding {
  AssetHolding({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.name,
    required this.currencyCode,
    required this.nativeValue,
    required this.valuationDate,
    required this.notes,
    required this.country,
  });

  final String id;
  final String ledgerId;
  final AssetType type;
  final String name;
  final String currencyCode;
  final double nativeValue;
  final DateTime valuationDate;
  final String notes;
  final String country;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'type': type.name,
        'name': name,
        'currencyCode': currencyCode,
        'nativeValue': nativeValue,
        'valuationDate': valuationDate.toIso8601String(),
        'notes': notes,
        'country': country,
      };

  factory AssetHolding.fromJson(Map<String, dynamic> json) {
    final currencyCode = (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    return AssetHolding(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String? ?? currencyCode.toLowerCase(),
      type: enumByName(
        AssetType.values,
        json['type'] as String? ?? AssetType.other.name,
        AssetType.other,
      ),
      name: json['name'] as String? ?? '',
      currencyCode: currencyCode,
      nativeValue: (json['nativeValue'] as num?)?.toDouble() ?? 0,
      valuationDate: DateTime.parse(json['valuationDate'] as String),
      notes: json['notes'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

class InvestmentEntry {
  InvestmentEntry({
    required this.id,
    required this.ledgerId,
    required this.month,
    required this.type,
    required this.currencyCode,
    required this.nativeAmount,
    required this.notes,
    required this.country,
  });

  final String id;
  final String ledgerId;
  final DateTime month;
  final InvestmentType type;
  final String currencyCode;
  final double nativeAmount;
  final String notes;
  final String country;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'month':
            DateTime(month.year, month.month, month.day).toIso8601String(),
        'type': type.name,
        'currencyCode': currencyCode,
        'nativeAmount': nativeAmount,
        'notes': notes,
        'country': country,
      };

  factory InvestmentEntry.fromJson(Map<String, dynamic> json) {
    final currencyCode =
        (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    return InvestmentEntry(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String? ?? currencyCode.toLowerCase(),
      month: DateTime.parse(json['month'] as String),
      type: enumByName(
        InvestmentType.values,
        json['type'] as String? ?? InvestmentType.other.name,
        InvestmentType.other,
      ),
      currencyCode: currencyCode,
      nativeAmount: (json['nativeAmount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

class LiabilityHolding {
  LiabilityHolding({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.name,
    required this.currencyCode,
    required this.nativeOutstanding,
    required this.dueDate,
    required this.notes,
    required this.country,
  });

  final String id;
  final String ledgerId;
  final LiabilityType type;
  final String name;
  final String currencyCode;
  final double nativeOutstanding;
  final DateTime? dueDate;
  final String notes;
  final String country;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'type': type.name,
        'name': name,
        'currencyCode': currencyCode,
        'nativeOutstanding': nativeOutstanding,
        'dueDate': dueDate?.toIso8601String(),
        'notes': notes,
        'country': country,
      };

  factory LiabilityHolding.fromJson(Map<String, dynamic> json) {
    final currencyCode = (json['currencyCode'] as String? ?? '').trim().toUpperCase();
    return LiabilityHolding(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String? ?? currencyCode.toLowerCase(),
      type: enumByName(
        LiabilityType.values,
        json['type'] as String? ?? LiabilityType.other.name,
        LiabilityType.other,
      ),
      name: json['name'] as String? ?? '',
      currencyCode: currencyCode,
      nativeOutstanding: (json['nativeOutstanding'] as num?)?.toDouble() ?? 0,
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      notes: json['notes'] as String? ?? '',
      country: json['country'] as String? ?? '',
    );
  }
}

class FxRate {
  FxRate({
    required this.id,
    required this.effectiveDate,
    required this.country,
    required this.currencyCode,
    required this.reportingCurrency,
    required this.rateToReportingCurrency,
  });

  final String id;
  final DateTime effectiveDate;
  final String country;
  final String currencyCode;
  final String reportingCurrency;
  final double rateToReportingCurrency;

  Map<String, dynamic> toJson() => {
        'id': id,
        'effectiveDate': effectiveDate.toIso8601String(),
        'country': country,
        'currencyCode': currencyCode,
        'reportingCurrency': reportingCurrency,
        'rateToReportingCurrency': rateToReportingCurrency,
      };

  factory FxRate.fromJson(Map<String, dynamic> json) {
    return FxRate(
      id: json['id'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      country: json['country'] as String? ?? '',
      currencyCode: (json['currencyCode'] as String? ?? '').trim().toUpperCase(),
      reportingCurrency:
          (json['reportingCurrency'] as String? ?? '').trim().toUpperCase(),
      rateToReportingCurrency:
          (json['rateToReportingCurrency'] as num?)?.toDouble() ?? 1,
    );
  }
}

class ForexTransfer {
  ForexTransfer({
    required this.id,
    required this.transferDate,
    required this.fromCountry,
    required this.fromCurrencyCode,
    required this.fromAmount,
    required this.toCountry,
    required this.toCurrencyCode,
    required this.toAmount,
    required this.reportingAmount,
    required this.notes,
    required this.fxRateApplied,
  });

  final String id;
  final DateTime transferDate;
  final String fromCountry;
  final String fromCurrencyCode;
  final double fromAmount;
  final String toCountry;
  final String toCurrencyCode;
  final double toAmount;
  final double reportingAmount;
  final String notes;
  final double fxRateApplied;

  Map<String, dynamic> toJson() => {
        'id': id,
        'transferDate': transferDate.toIso8601String(),
        'fromCountry': fromCountry,
        'fromCurrencyCode': fromCurrencyCode,
        'fromAmount': fromAmount,
        'toCountry': toCountry,
        'toCurrencyCode': toCurrencyCode,
        'toAmount': toAmount,
        'reportingAmount': reportingAmount,
        'notes': notes,
        'fxRateApplied': fxRateApplied,
      };

  factory ForexTransfer.fromJson(Map<String, dynamic> json) {
    return ForexTransfer(
      id: json['id'] as String,
      transferDate: DateTime.parse(json['transferDate'] as String),
      fromCountry: json['fromCountry'] as String? ?? '',
      fromCurrencyCode:
          (json['fromCurrencyCode'] as String? ?? '').trim().toUpperCase(),
      fromAmount: (json['fromAmount'] as num?)?.toDouble() ?? 0,
      toCountry: json['toCountry'] as String? ?? '',
      toCurrencyCode:
          (json['toCurrencyCode'] as String? ?? '').trim().toUpperCase(),
      toAmount: (json['toAmount'] as num?)?.toDouble() ?? 0,
      reportingAmount: (json['reportingAmount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String? ?? '',
      fxRateApplied: (json['fxRateApplied'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FinanceData {
  FinanceData({
    required this.settings,
    required this.expenses,
    required this.earningsRecords,
    required this.savingsRecords,
    required this.allocations,
    required this.investments,
    required this.assets,
    required this.liabilities,
    required this.fxRates,
    required this.forexTransfers,
  });

  final FinanceSettings settings;
  final List<ExpenseEntry> expenses;
  final List<MonthlyEarningRecord> earningsRecords;
  final List<MonthlySavingsRecord> savingsRecords;
  final List<SavingsAllocation> allocations;
  final List<InvestmentEntry> investments;
  final List<AssetHolding> assets;
  final List<LiabilityHolding> liabilities;
  final List<FxRate> fxRates;
  final List<ForexTransfer> forexTransfers;

  FinanceData copyWith({
    FinanceSettings? settings,
    List<ExpenseEntry>? expenses,
    List<MonthlyEarningRecord>? earningsRecords,
    List<MonthlySavingsRecord>? savingsRecords,
    List<SavingsAllocation>? allocations,
    List<InvestmentEntry>? investments,
    List<AssetHolding>? assets,
    List<LiabilityHolding>? liabilities,
    List<FxRate>? fxRates,
    List<ForexTransfer>? forexTransfers,
  }) {
    return FinanceData(
      settings: settings ?? this.settings,
      expenses: expenses ?? this.expenses,
      earningsRecords: earningsRecords ?? this.earningsRecords,
      savingsRecords: savingsRecords ?? this.savingsRecords,
      allocations: allocations ?? this.allocations,
      investments: investments ?? this.investments,
      assets: assets ?? this.assets,
      liabilities: liabilities ?? this.liabilities,
      fxRates: fxRates ?? this.fxRates,
      forexTransfers: forexTransfers ?? this.forexTransfers,
    );
  }

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'expenses': expenses.map((item) => item.toJson()).toList(),
        'earningsRecords': earningsRecords.map((item) => item.toJson()).toList(),
        'savingsRecords': savingsRecords.map((item) => item.toJson()).toList(),
        'allocations': allocations.map((item) => item.toJson()).toList(),
        'investments': investments.map((item) => item.toJson()).toList(),
        'assets': assets.map((item) => item.toJson()).toList(),
        'liabilities': liabilities.map((item) => item.toJson()).toList(),
        'fxRates': fxRates.map((item) => item.toJson()).toList(),
        'forexTransfers': forexTransfers.map((item) => item.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  factory FinanceData.fromJson(Map<String, dynamic> json) {
    return FinanceData(
      settings: FinanceSettings.fromJson(
        json['settings'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      expenses: (json['expenses'] as List<dynamic>? ?? const [])
          .map((item) => ExpenseEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      earningsRecords: (json['earningsRecords'] as List<dynamic>? ?? const [])
          .map((item) => MonthlyEarningRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      savingsRecords: (json['savingsRecords'] as List<dynamic>? ?? const [])
          .map((item) => MonthlySavingsRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      allocations: (json['allocations'] as List<dynamic>? ?? const [])
          .map((item) => SavingsAllocation.fromJson(item as Map<String, dynamic>))
          .toList(),
      investments: (json['investments'] as List<dynamic>? ?? const [])
          .map((item) => InvestmentEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      assets: (json['assets'] as List<dynamic>? ?? const [])
          .map((item) => AssetHolding.fromJson(item as Map<String, dynamic>))
          .toList(),
      liabilities: (json['liabilities'] as List<dynamic>? ?? const [])
          .map((item) => LiabilityHolding.fromJson(item as Map<String, dynamic>))
          .toList(),
      fxRates: (json['fxRates'] as List<dynamic>? ?? const [])
          .map((item) => FxRate.fromJson(item as Map<String, dynamic>))
          .toList(),
      forexTransfers: (json['forexTransfers'] as List<dynamic>? ?? const [])
          .map((item) => ForexTransfer.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
