import 'dart:convert';

import 'package:csv/csv.dart';

import 'models.dart';

/// Export/import helpers for JSON (full fidelity) and CSV (spreadsheet-friendly).
class BackupService {
  BackupService._();

  static const expenseCsvHeaders = <String>[
    'id',
    'ledgerId',
    'source',
    'createdAt',
    'transactionDate',
    'currencyCode',
    'nativeAmount',
    'category',
    'subtype',
    'utilityType',
    'notes',
    'merchant',
    'confidenceScore',
    'rawMessage',
    'paymentChannel',
    'paidByKind',
    'bankName',
    'cardName',
    'externalMessageId',
    'country',
  ];

  static String exportFullJson(FinanceData data) => data.encode();

  static FinanceData importFullJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return FinanceData.fromJson(decoded);
  }

  static String exportExpensesCsv(FinanceData data) {
    final rows = <List<String>>[
      expenseCsvHeaders,
      ...data.expenses.map(_expenseToCsvRow),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static List<String> _expenseToCsvRow(ExpenseEntry e) {
    return [
      e.id,
      e.ledgerId,
      e.source.name,
      e.createdAt.toIso8601String(),
      e.transactionDate.toIso8601String(),
      e.currencyCode,
      e.nativeAmount.toString(),
      e.category.name,
      e.subtype?.name ?? '',
      e.utilityType?.name ?? '',
      e.notes,
      e.merchant,
      e.confidenceScore.toString(),
      e.rawMessage,
      e.paymentChannel,
      e.paidByKind.name,
      e.bankName,
      e.cardName,
      e.externalMessageId,
      e.country,
    ];
  }

  /// Parses exported expense CSV; skips invalid rows. Empty/missing createdAt uses transactionDate.
  static List<ExpenseEntry> importExpensesCsv(String raw) {
    final table = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(raw);
    if (table.isEmpty) return [];
    final header = table.first.map((c) => c.toString().trim()).toList();
    final idx = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      idx[header[i]] = i;
    }
    final need = {'id', 'ledgerId', 'transactionDate', 'currencyCode', 'nativeAmount', 'category'};
    if (!need.every(idx.containsKey)) {
      throw FormatException(
        'CSV must include columns: ${need.join(', ')}',
      );
    }
    final out = <ExpenseEntry>[];
    for (var r = 1; r < table.length; r++) {
      final row = table[r];
      try {
        String cell(String k) {
          final i = idx[k];
          if (i == null || i >= row.length) return '';
          return row[i].toString();
        }

        final id = cell('id').trim();
        if (id.isEmpty) continue;
        final tx = DateTime.parse(cell('transactionDate'));
        final createdRaw = cell('createdAt').trim();
        final createdAt =
            createdRaw.isEmpty ? tx : DateTime.parse(createdRaw);
        out.add(
          ExpenseEntry(
            id: id,
            ledgerId: cell('ledgerId').trim(),
            source: enumByName(
              EntrySource.values,
              cell('source').trim().isEmpty ? EntrySource.manual.name : cell('source').trim(),
              EntrySource.manual,
            ),
            createdAt: createdAt,
            transactionDate: tx,
            currencyCode: cell('currencyCode').trim().toUpperCase(),
            nativeAmount: double.tryParse(cell('nativeAmount')) ?? 0,
            category: _categoryFromCsv(cell('category').trim()),
            subtype: cell('subtype').trim().isEmpty
                ? null
                : enumByName(
                    ExpenseSubtype.values,
                    cell('subtype').trim(),
                    ExpenseSubtype.rent,
                  ),
            utilityType: cell('utilityType').trim().isEmpty
                ? null
                : enumByName(
                    UtilityType.values,
                    cell('utilityType').trim(),
                    UtilityType.other,
                  ),
            notes: cell('notes'),
            merchant: cell('merchant'),
            confidenceScore: double.tryParse(cell('confidenceScore')) ?? 1,
            rawMessage: cell('rawMessage'),
            paymentChannel: cell('paymentChannel'),
            paidByKind: enumByName(
              PaymentSourceKind.values,
              cell('paidByKind').trim().isEmpty
                  ? PaymentSourceKind.other.name
                  : cell('paidByKind').trim(),
              PaymentSourceKind.other,
            ),
            bankName: cell('bankName'),
            cardName: cell('cardName'),
            externalMessageId: cell('externalMessageId'),
            country: cell('country'),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  static ExpenseCategory _categoryFromCsv(String raw) {
    final n = raw.trim();
    if (n.isEmpty) return ExpenseCategory.other;
    if (n == 'food' || n == 'groceries') return ExpenseCategory.foodGroceries;
    return enumByName(ExpenseCategory.values, n, ExpenseCategory.other);
  }
}
