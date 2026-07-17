import 'dart:convert';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/sync/offline_sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AccountingApiConfig(
    baseUrl: 'http://localhost:8080/api/v1',
    accessToken: 'access-token',
    organizationId: 'org-1',
  );

  test('lists accounts with organization path and bearer token', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/organizations/org-1/accounts',
        );
        expect(request.headers['Authorization'], 'Bearer access-token');
        return http.Response(
          jsonEncode([
            {
              'id': 'acct-1',
              'code': '1000',
              'name': 'Cash',
              'type': 'asset',
              'currency': 'INR',
              'is_active': true,
            },
          ]),
          200,
        );
      }),
    );

    final accounts = await client.listAccounts();

    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Cash');
  });

  test('lists customers and vendors with organization path', () async {
    final requestedPaths = <String>[];
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.endsWith('/customers')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'customer-1',
                'organization_id': 'org-1',
                'display_name': 'Acme Exports',
                'email': 'billing@acme.test',
                'phone': '+91-99999-00001',
                'billing_address': 'Mumbai',
                'gstin': '27ABCDE1234F1Z5',
                'is_active': true,
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'vendor-1',
              'organization_id': 'org-1',
              'display_name': 'Stationery House',
              'email': 'ap@stationery.test',
              'phone': '+91-99999-00002',
              'billing_address': 'Pune',
              'gstin': '27ABCDE1234F1Z6',
              'is_active': true,
            },
          ]),
          200,
        );
      }),
    );

    final customers = await client.listCustomers();
    final vendors = await client.listVendors();

    expect(customers.single.displayName, 'Acme Exports');
    expect(customers.single.gstin, '27ABCDE1234F1Z5');
    expect(vendors.single.displayName, 'Stationery House');
    expect(vendors.single.email, 'ap@stationery.test');
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/customers',
      '/api/v1/organizations/org-1/vendors',
    ]);
  });

  test('fetches trial balance reports', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/reports/trial-balance',
        );
        expect(request.url.queryParameters['as_of'], '2026-07-31');
        return http.Response(
          jsonEncode({
            'as_of_date': '2026-07-31T00:00:00Z',
            'total_debit_minor': 125000,
            'total_credit_minor': 125000,
            'balanced': true,
            'rows': [
              {
                'account_id': 'acct-cash',
                'account_code': '1000',
                'account_name': 'Cash',
                'account_type': 'asset',
                'debit_minor': 125000,
                'credit_minor': 0,
                'balance_minor': 125000,
              },
            ],
          }),
          200,
        );
      }),
    );

    final report = await client.getTrialBalance(
      asOf: DateTime.utc(2026, 7, 31),
    );

    expect(report.balanced, true);
    expect(report.totalDebitMinor, 125000);
    expect(report.rows.single.accountName, 'Cash');
  });

  test('fetches profit and loss reports', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/reports/profit-and-loss'), true);
        expect(request.url.queryParameters['from'], '2026-04-01');
        expect(request.url.queryParameters['to'], '2026-07-31');
        return http.Response(
          jsonEncode({
            'from_date': '2026-04-01T00:00:00Z',
            'to_date': '2026-07-31T00:00:00Z',
            'total_income_minor': 500000,
            'total_expense_minor': 150000,
            'net_income_minor': 350000,
            'income_rows': [
              {
                'account_id': 'acct-sales',
                'account_code': '4000',
                'account_name': 'Sales',
                'account_type': 'income',
                'debit_minor': 0,
                'credit_minor': 500000,
                'balance_minor': -500000,
              },
            ],
            'expense_rows': [
              {
                'account_id': 'acct-rent',
                'account_code': '5000',
                'account_name': 'Rent',
                'account_type': 'expense',
                'debit_minor': 150000,
                'credit_minor': 0,
                'balance_minor': 150000,
              },
            ],
          }),
          200,
        );
      }),
    );

    final report = await client.getProfitAndLoss(
      from: DateTime.utc(2026, 4),
      to: DateTime.utc(2026, 7, 31),
    );

    expect(report.netIncomeMinor, 350000);
    expect(report.incomeRows.single.accountName, 'Sales');
    expect(report.expenseRows.single.accountName, 'Rent');
  });

  test('fetches balance sheet reports', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/reports/balance-sheet'), true);
        expect(request.url.queryParameters['as_of'], '2026-07-31');
        return http.Response(
          jsonEncode({
            'as_of_date': '2026-07-31T00:00:00Z',
            'total_assets_minor': 350000,
            'total_liabilities_minor': 0,
            'total_equity_minor': 350000,
            'balanced': true,
            'asset_rows': [
              {
                'account_id': 'acct-bank',
                'account_code': '1010',
                'account_name': 'Bank',
                'account_type': 'asset',
                'debit_minor': 350000,
                'credit_minor': 0,
                'balance_minor': 350000,
              },
            ],
            'liability_rows': [],
            'equity_rows': [
              {
                'account_id': 'acct-retained',
                'account_code': '3100',
                'account_name': 'Retained Earnings',
                'account_type': 'equity',
                'debit_minor': 0,
                'credit_minor': 350000,
                'balance_minor': -350000,
              },
            ],
          }),
          200,
        );
      }),
    );

    final report = await client.getBalanceSheet(
      asOf: DateTime.utc(2026, 7, 31),
    );

    expect(report.balanced, true);
    expect(report.totalAssetsMinor, 350000);
    expect(report.assetRows.single.accountName, 'Bank');
    expect(report.equityRows.single.accountName, 'Retained Earnings');
  });

  test('fetches cash flow and aging reports', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/reports/cash-flow')) {
          expect(request.url.queryParameters['from'], '2026-04-01');
          expect(request.url.queryParameters['to'], '2026-07-31');
          return http.Response(
            jsonEncode({
              'from_date': '2026-04-01T00:00:00Z',
              'to_date': '2026-07-31T00:00:00Z',
              'total_inflows_minor': 500000,
              'total_outflows_minor': 150000,
              'net_cash_flow_minor': 350000,
              'opening_cash_minor': 250000,
              'closing_cash_minor': 600000,
              'generated_from_subtypes': ['bank', 'cash'],
              'rows': [
                {
                  'account_id': 'acct-bank',
                  'account_code': '1010',
                  'account_name': 'Bank',
                  'source_module': 'invoice',
                  'inflow_minor': 500000,
                  'outflow_minor': 150000,
                  'net_cash_flow_minor': 350000,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/reports/ar-aging')) {
          expect(request.url.queryParameters['as_of'], '2026-07-31');
          return http.Response(
            jsonEncode({
              'as_of_date': '2026-07-31T00:00:00Z',
              'total_current_minor': 0,
              'total_one_to_thirty_minor': 118000,
              'total_thirty_one_to_sixty_minor': 0,
              'total_sixty_one_to_ninety_minor': 0,
              'total_over_ninety_minor': 0,
              'total_outstanding_minor': 118000,
              'rows': [
                {
                  'customer_id': 'cust-1',
                  'customer_name': 'Acme',
                  'invoice_id': 'inv-1',
                  'invoice_number': 'INV-001',
                  'due_date': '2026-07-01T00:00:00Z',
                  'days_overdue': 30,
                  'outstanding_minor': 118000,
                  'current_minor': 0,
                  'one_to_thirty_minor': 118000,
                  'thirty_one_to_sixty_minor': 0,
                  'sixty_one_to_ninety_minor': 0,
                  'over_ninety_minor': 0,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/reports/ap-aging')) {
          expect(request.url.queryParameters['as_of'], '2026-07-31');
          return http.Response(
            jsonEncode({
              'as_of_date': '2026-07-31T00:00:00Z',
              'total_current_minor': 0,
              'total_one_to_thirty_minor': 0,
              'total_thirty_one_to_sixty_minor': 59000,
              'total_sixty_one_to_ninety_minor': 0,
              'total_over_ninety_minor': 0,
              'total_outstanding_minor': 59000,
              'rows': [
                {
                  'vendor_id': 'vendor-1',
                  'vendor_name': 'Office Supplies Co',
                  'bill_id': 'bill-1',
                  'bill_number': 'BILL-001',
                  'due_date': '2026-06-30T00:00:00Z',
                  'days_overdue': 31,
                  'outstanding_minor': 59000,
                  'current_minor': 0,
                  'one_to_thirty_minor': 0,
                  'thirty_one_to_sixty_minor': 59000,
                  'sixty_one_to_ninety_minor': 0,
                  'over_ninety_minor': 0,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/reports/tax-liability')) {
          expect(request.url.queryParameters['from'], '2026-04-01');
          expect(request.url.queryParameters['to'], '2026-07-31');
          return http.Response(
            jsonEncode({
              'from_date': '2026-04-01T00:00:00Z',
              'to_date': '2026-07-31T00:00:00Z',
              'output_tax_minor': 90000,
              'input_tax_minor': 27000,
              'net_payable_minor': 63000,
              'rows': [
                {
                  'tax_rate_id': 'gst-18',
                  'name': 'GST 18%',
                  'output_tax_minor': 90000,
                  'input_tax_minor': 27000,
                  'net_payable_minor': 63000,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/reports/tax-summary')) {
          expect(request.url.queryParameters['from'], '2026-04-01');
          expect(request.url.queryParameters['to'], '2026-07-31');
          return http.Response(
            jsonEncode({
              'from_date': '2026-04-01T00:00:00Z',
              'to_date': '2026-07-31T00:00:00Z',
              'rows': [
                {
                  'tax_rate_id': 'gst-18',
                  'tax_group_id': 'gst-group-18',
                  'name': 'GST 18%',
                  'output_tax_minor': 90000,
                  'input_tax_minor': 27000,
                  'net_payable_minor': 63000,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/budgets')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'budget-1',
                'organization_id': 'org-1',
                'name': 'FY 2026 Operating Budget',
                'start_date': '2026-04-01T00:00:00Z',
                'end_date': '2027-03-31T00:00:00Z',
                'status': 'active',
                'lines': [
                  {
                    'id': 'budget-line-1',
                    'account_id': 'acct-rent',
                    'period_start': '2026-04-01T00:00:00Z',
                    'period_end': '2026-04-30T00:00:00Z',
                    'amount_minor': 150000,
                  },
                ],
              },
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/budgets/budget-1/vs-actual')) {
          return http.Response(
            jsonEncode({
              'budget_id': 'budget-1',
              'rows': [
                {
                  'account_id': 'acct-rent',
                  'account_code': '5000',
                  'account_name': 'Rent',
                  'period_start': '2026-04-01T00:00:00Z',
                  'period_end': '2026-04-30T00:00:00Z',
                  'budget_minor': 150000,
                  'actual_minor': 125000,
                  'variance_minor': 25000,
                  'variance_percent_basis': 1667,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('unexpected path', 404);
      }),
    );

    final cashFlow = await client.getCashFlow(
      from: DateTime.utc(2026, 4),
      to: DateTime.utc(2026, 7, 31),
    );
    final arAging = await client.getARAging(asOf: DateTime.utc(2026, 7, 31));
    final apAging = await client.getAPAging(asOf: DateTime.utc(2026, 7, 31));
    final taxLiability = await client.getTaxLiability(
      from: DateTime.utc(2026, 4),
      to: DateTime.utc(2026, 7, 31),
    );
    final taxSummary = await client.getTaxSummary(
      from: DateTime.utc(2026, 4),
      to: DateTime.utc(2026, 7, 31),
    );
    final budgets = await client.listBudgets();
    final budgetVsActual = await client.getBudgetVsActual(budgetId: 'budget-1');

    expect(cashFlow.closingCashMinor, 600000);
    expect(cashFlow.rows.single.sourceModule, 'invoice');
    expect(arAging.rows.single.invoiceNumber, 'INV-001');
    expect(arAging.totalOutstandingMinor, 118000);
    expect(apAging.rows.single.billNumber, 'BILL-001');
    expect(apAging.totalOutstandingMinor, 59000);
    expect(taxLiability.netPayableMinor, 63000);
    expect(taxLiability.rows.single.taxRateId, 'gst-18');
    expect(taxSummary.rows.single.taxGroupId, 'gst-group-18');
    expect(budgets.single.name, 'FY 2026 Operating Budget');
    expect(budgetVsActual.totalVarianceMinor, 25000);
  });

  test('lists invoice and expense summaries', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/invoices')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'inv-1',
                'invoice_number': 'INV-001',
                'status': 'draft',
                'subtotal_minor': 100000,
                'tax_total_minor': 18000,
                'total_minor': 118000,
                'currency': 'INR',
                'pdf_attachment_id': 'pdf-1',
                'lines': [
                  {
                    'id': 'line-1',
                    'description': 'Consulting services',
                    'quantity_millis': 1000,
                    'unit_price_minor': 100000,
                    'line_subtotal_minor': 100000,
                    'tax_amount_minor': 18000,
                    'line_total_minor': 118000,
                    'income_account_id': 'income-1',
                    'tax_group_id': 'gst-18',
                  },
                ],
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'exp-1',
              'expense_number': 'EXP-001',
              'status': 'draft',
              'total_minor': 59000,
              'currency': 'INR',
            },
          ]),
          200,
        );
      }),
    );

    final invoices = await client.listInvoices();
    final expenses = await client.listExpenses();

    expect(invoices.single.invoiceNumber, 'INV-001');
    expect(invoices.single.subtotalMinor, 100000);
    expect(invoices.single.taxTotalMinor, 18000);
    expect(invoices.single.pdfAttachmentId, 'pdf-1');
    expect(invoices.single.lines.single.description, 'Consulting services');
    expect(invoices.single.lines.single.taxGroupId, 'gst-18');
    expect(expenses.single.expenseNumber, 'EXP-001');
  });

  test('lists tax rates and groups', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/tax/rates')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'tax-rate-1',
                'name': 'GST 18%',
                'type': 'GST',
                'percentage_basis': 180000,
                'is_active': true,
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'tax-group-1',
              'name': 'CGST + SGST 18%',
              'description': 'Split GST',
              'is_active': true,
            },
          ]),
          200,
        );
      }),
    );

    final rates = await client.listTaxRates();
    final groups = await client.listTaxGroups();

    expect(rates.single.name, 'GST 18%');
    expect(rates.single.percentageBasis, 180000);
    expect(groups.single.description, 'Split GST');
  });

  test('lists investment lots and realized gains', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/investments/lots')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'lot-1',
                'account_id': 'brokerage-1',
                'symbol': 'NIFTYBEES',
                'security_name': 'Nippon India ETF Nifty BeES',
                'acquisition_date': '2026-04-01T00:00:00Z',
                'quantity_millis': 100000,
                'remaining_quantity_millis': 60000,
                'cost_basis_minor': 1000000,
                'currency': 'INR',
                'cost_method': 'specific_lot',
              },
            ]),
            200,
          );
        }

        expect(request.url.path.endsWith('/reports/realized-gains'), isTrue);
        expect(request.url.queryParameters['from'], '2026-04-01');
        expect(request.url.queryParameters['to'], '2026-07-31');
        return http.Response(
          jsonEncode({
            'from_date': '2026-04-01T00:00:00Z',
            'to_date': '2026-07-31T00:00:00Z',
            'total_proceeds_minor': 520000,
            'total_cost_basis_minor': 400000,
            'total_gain_loss_minor': 120000,
            'rows': [
              {
                'id': 'disp-1',
                'investment_lot_id': 'lot-1',
                'sale_date': '2026-07-12T00:00:00Z',
                'quantity_millis': 40000,
                'proceeds_minor': 520000,
                'allocated_cost_basis_minor': 400000,
                'realized_gain_loss_minor': 120000,
                'currency': 'INR',
              },
            ],
          }),
          200,
        );
      }),
    );

    final lots = await client.listInvestmentLots();
    final report = await client.getRealizedGains(
      from: DateTime.utc(2026, 4),
      to: DateTime.utc(2026, 7, 31),
    );

    expect(lots.single.symbol, 'NIFTYBEES');
    expect(lots.single.remainingQuantityMillis, 60000);
    expect(report.totalGainLossMinor, 120000);
    expect(report.rows.single.investmentLotId, 'lot-1');
  });

  test(
    'handles investment prices, valuation, and average-cost sales',
    () async {
      final client = AccountingApiClient(
        config: config,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/investments/lots')) {
            expect(request.method, 'POST');
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['account_id'], 'brokerage-1');
            expect(body['symbol'], 'LIQUIDFUND');
            expect(body['acquisition_date'], '2026-04-01');
            expect(body['quantity_millis'], 150000);
            expect(body['cost_basis_minor'], 2250000);
            expect(body['cost_method'], 'average_cost');
            return http.Response(
              jsonEncode({
                'id': 'lot-created-1',
                ...body,
                'acquisition_date': '2026-04-01T00:00:00Z',
                'remaining_quantity_millis': body['quantity_millis'],
              }),
              201,
            );
          }

          if (request.url.path.endsWith('/investments/prices')) {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'price-1',
                    'symbol': 'LIQUIDFUND',
                    'price_date': '2026-07-31T00:00:00Z',
                    'price_minor': 14000,
                    'currency': 'INR',
                    'source': 'manual',
                  },
                ]),
                200,
              );
            }
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['symbol'], 'LIQUIDFUND');
            expect(body['price_date'], '2026-07-31');
            return http.Response(
              jsonEncode({
                'id': 'price-2',
                ...body,
                'price_date': '2026-07-31T00:00:00Z',
              }),
              201,
            );
          }

          if (request.url.path.endsWith('/reports/investment-valuation')) {
            expect(request.url.queryParameters['as_of'], '2026-07-31');
            return http.Response(
              jsonEncode({
                'as_of_date': '2026-07-31T00:00:00Z',
                'total_cost_basis_minor': 2250000,
                'total_market_value_minor': 2400000,
                'total_unrealized_gain_loss_minor': 150000,
                'rows': [
                  {
                    'lot_id': 'lot-1',
                    'account_id': 'brokerage-1',
                    'symbol': 'LIQUIDFUND',
                    'security_name': 'Liquid Fund',
                    'acquisition_date': '2026-04-01T00:00:00Z',
                    'remaining_quantity_millis': 150000,
                    'remaining_cost_basis_minor': 2250000,
                    'market_price_minor': 16000,
                    'market_value_minor': 2400000,
                    'unrealized_gain_loss_minor': 150000,
                    'currency': 'INR',
                    'price_date': '2026-07-31T00:00:00Z',
                  },
                ],
              }),
              200,
            );
          }

          if (request.url.path.endsWith('/investments/dividends')) {
            expect(request.method, 'POST');
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['account_id'], 'brokerage-1');
            expect(body['symbol'], 'LIQUIDFUND');
            expect(body['dividend_date'], '2026-07-31');
            expect(body['amount_minor'], 12500);
            expect(body['cash_account_id'], 'bank-1');
            expect(body['income_account_id'], 'dividend-income-1');
            return http.Response(
              jsonEncode({
                'id': 'dividend-1',
                ...body,
                'dividend_date': '2026-07-31T00:00:00Z',
                'journal_transaction_id': 'journal-dividend-1',
              }),
              201,
            );
          }

          if (request.url.path.endsWith('/investments/corporate-actions')) {
            expect(request.method, 'POST');
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['account_id'], 'brokerage-1');
            expect(body['symbol'], 'LIQUIDFUND');
            expect(body['action_type'], 'split');
            expect(body['action_date'], '2026-08-01');
            expect(body['ratio_numerator'], 2);
            expect(body['ratio_denominator'], 1);
            return http.Response(
              jsonEncode({
                'id': 'corporate-action-1',
                ...body,
                'action_date': '2026-08-01T00:00:00Z',
                'affected_lots': 1,
                'quantity_delta_millis': 150000,
                'cost_basis_delta_minor': 0,
              }),
              201,
            );
          }

          if (request.url.path.endsWith(
            '/investments/lots/lot-created-1/sell',
          )) {
            expect(request.method, 'POST');
            final body = jsonDecode(request.body) as Map<String, Object?>;
            expect(body['sale_date'], '2026-07-31');
            expect(body['quantity_millis'], 1000);
            expect(body['proceeds_minor'], 16000);
            expect(body['proceeds_account_id'], 'bank-1');
            expect(body['gain_loss_account_id'], 'gain-loss-1');
            return http.Response(
              jsonEncode({
                'id': 'disp-specific-1',
                'investment_lot_id': 'lot-created-1',
                'sale_date': '2026-07-31T00:00:00Z',
                'quantity_millis': 1000,
                'proceeds_minor': 16000,
                'allocated_cost_basis_minor': 15000,
                'realized_gain_loss_minor': 1000,
                'currency': 'INR',
                'notes': 'Specific sale',
              }),
              201,
            );
          }

          expect(
            request.url.path.endsWith('/investments/average-cost-sales'),
            isTrue,
          );
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['account_id'], 'brokerage-1');
          expect(body['symbol'], 'LIQUIDFUND');
          expect(body['quantity_millis'], 150000);
          return http.Response(
            jsonEncode({
              'quantity_millis': 150000,
              'proceeds_minor': 2400000,
              'allocated_cost_basis_minor': 2250000,
              'realized_gain_loss_minor': 150000,
              'journal_transaction_id': 'journal-1',
              'dispositions': [
                {
                  'id': 'disp-avg-1',
                  'investment_lot_id': 'lot-1',
                  'sale_date': '2026-07-31T00:00:00Z',
                  'quantity_millis': 150000,
                  'proceeds_minor': 2400000,
                  'allocated_cost_basis_minor': 2250000,
                  'realized_gain_loss_minor': 150000,
                  'currency': 'INR',
                },
              ],
            }),
            201,
          );
        }),
      );

      final createdLot = await client.createInvestmentLot(
        CreateInvestmentLotRequest(
          accountId: 'brokerage-1',
          symbol: 'LIQUIDFUND',
          acquisitionDate: DateTime.utc(2026, 4),
          quantityMillis: 150000,
          costBasisMinor: 2250000,
          costMethod: 'average_cost',
        ),
      );
      final prices = await client.listInvestmentPrices();
      final createdPrice = await client.createInvestmentPrice(
        CreateInvestmentPriceRequest(
          symbol: 'LIQUIDFUND',
          priceDate: DateTime.utc(2026, 7, 31),
          priceMinor: 14000,
        ),
      );
      final valuation = await client.getInvestmentValuation(
        asOf: DateTime.utc(2026, 7, 31),
      );
      final dividend = await client.createInvestmentDividend(
        CreateInvestmentDividendRequest(
          accountId: 'brokerage-1',
          symbol: 'LIQUIDFUND',
          dividendDate: DateTime.utc(2026, 7, 31),
          amountMinor: 12500,
          cashAccountId: 'bank-1',
          incomeAccountId: 'dividend-income-1',
        ),
      );
      final corporateAction = await client.createInvestmentCorporateAction(
        CreateInvestmentCorporateActionRequest(
          accountId: 'brokerage-1',
          symbol: 'LIQUIDFUND',
          actionType: 'split',
          actionDate: DateTime.utc(2026, 8),
          ratioNumerator: 2,
          ratioDenominator: 1,
        ),
      );
      final specificSale = await client.sellInvestmentLot(
        'lot-created-1',
        SellInvestmentLotRequest(
          saleDate: DateTime.utc(2026, 7, 31),
          quantityMillis: 1000,
          proceedsMinor: 16000,
          proceedsAccountId: 'bank-1',
          gainLossAccountId: 'gain-loss-1',
          notes: 'Specific sale',
        ),
      );
      final sale = await client.sellAverageCost(
        SellAverageCostRequest(
          accountId: 'brokerage-1',
          symbol: 'LIQUIDFUND',
          saleDate: DateTime.utc(2026, 7, 31),
          quantityMillis: 150000,
          proceedsMinor: 2400000,
        ),
      );

      expect(createdLot.id, 'lot-created-1');
      expect(createdLot.costMethod, 'average_cost');
      expect(prices.single.priceMinor, 14000);
      expect(createdPrice.id, 'price-2');
      expect(valuation.totalUnrealizedGainLossMinor, 150000);
      expect(valuation.rows.single.marketValueMinor, 2400000);
      expect(dividend.journalTransactionId, 'journal-dividend-1');
      expect(dividend.amountMinor, 12500);
      expect(corporateAction.affectedLots, 1);
      expect(corporateAction.quantityDeltaMillis, 150000);
      expect(specificSale.investmentLotId, 'lot-created-1');
      expect(specificSale.realizedGainLossMinor, 1000);
      expect(sale.journalTransactionId, 'journal-1');
      expect(sale.dispositions.single.realizedGainLossMinor, 150000);
    },
  );

  test('imports broker holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/broker-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'broker_holdings_csv');
        expect(body['csv'], contains('Last Traded Price'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-broker-1',
                'symbol': 'TCS',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 345075,
                'currency': 'INR',
                'source': 'broker_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importBrokerHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv: 'Symbol,As of Date,Last Traded Price\nTCS,31-Jul-2026,3450.75',
      ),
    );

    expect(result.imported, 1);
    expect(result.skipped, 0);
    expect(result.prices.single.symbol, 'TCS');
    expect(result.prices.single.priceMinor, 345075);
  });

  test('imports Zerodha holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/zerodha-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'zerodha_holdings_csv');
        expect(body['csv'], contains('Instrument'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-zerodha-1',
                'symbol': 'HDFCBANK',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 157520,
                'currency': 'INR',
                'source': 'zerodha_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importZerodhaHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Instrument,ISIN,Date,LTP,Qty.\nHDFCBANK,INE040A01034,2026-07-31,1575.20,4',
        source: 'zerodha_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'HDFCBANK');
    expect(result.prices.single.priceMinor, 157520);
  });

  test('imports Groww holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/groww-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'groww_holdings_csv');
        expect(body['csv'], contains('Company Name'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-groww-1',
                'symbol': 'INE002A01018',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 141055,
                'currency': 'INR',
                'source': 'groww_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importGrowwHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Company Name,ISIN,Date,LTP,Quantity\nReliance Industries,INE002A01018,2026-07-31,1410.55,3',
        source: 'groww_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'INE002A01018');
    expect(result.prices.single.priceMinor, 141055);
  });

  test('imports Upstox holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/upstox-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'upstox_holdings_csv');
        expect(body['csv'], contains('Current Price'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-upstox-1',
                'symbol': 'SBIN',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 61525,
                'currency': 'INR',
                'source': 'upstox_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importUpstoxHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,Current Price,Quantity\nSBIN,INE062A01020,2026-07-31,615.25,12',
        source: 'upstox_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'SBIN');
    expect(result.prices.single.priceMinor, 61525);
  });

  test('imports Angel One holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/angelone-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'angelone_holdings_csv');
        expect(body['csv'], contains('Scrip'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-angelone-1',
                'symbol': 'ICICIBANK',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 124530,
                'currency': 'INR',
                'source': 'angelone_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importAngelOneHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Scrip,ISIN,Date,LTP,Quantity\nICICIBANK,INE090A01021,2026-07-31,1245.30,5',
        source: 'angelone_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'ICICIBANK');
    expect(result.prices.single.priceMinor, 124530);
  });

  test('imports Dhan holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/dhan-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'dhan_holdings_csv');
        expect(body['csv'], contains('Trading Symbol'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-dhan-1',
                'symbol': 'AXISBANK',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 118840,
                'currency': 'INR',
                'source': 'dhan_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importDhanHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Trading Symbol,ISIN,Date,LTP,Quantity\nAXISBANK,INE238A01034,2026-07-31,1188.40,8',
        source: 'dhan_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'AXISBANK');
    expect(result.prices.single.priceMinor, 118840);
  });

  test('imports ICICI Direct holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/icicidirect-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'icicidirect_holdings_csv');
        expect(body['csv'], contains('Market Price'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-icicidirect-1',
                'symbol': 'LT',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 362080,
                'currency': 'INR',
                'source': 'icicidirect_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importICICIDirectHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,Market Price,Quantity\nLT,INE018A01030,2026-07-31,3620.80,2',
        source: 'icicidirect_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'LT');
    expect(result.prices.single.priceMinor, 362080);
  });

  test('imports HDFC Sky holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/hdfcsky-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'hdfcsky_holdings_csv');
        expect(body['csv'], contains('MARUTI'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-hdfcsky-1',
                'symbol': 'MARUTI',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 1287565,
                'currency': 'INR',
                'source': 'hdfcsky_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importHDFCSkyHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nMARUTI,INE585B01010,2026-07-31,12875.65,1',
        source: 'hdfcsky_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'MARUTI');
    expect(result.prices.single.priceMinor, 1287565);
  });

  test('imports Kotak Neo holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/kotakneo-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'kotakneo_holdings_csv');
        expect(body['csv'], contains('BAJFINANCE'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-kotakneo-1',
                'symbol': 'BAJFINANCE',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 934210,
                'currency': 'INR',
                'source': 'kotakneo_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importKotakNeoHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Trading Symbol,ISIN,Date,LTP,Quantity\nBAJFINANCE,INE296A01024,2026-07-31,9342.10,2',
        source: 'kotakneo_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'BAJFINANCE');
    expect(result.prices.single.priceMinor, 934210);
  });

  test('imports Paytm Money holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/paytmmoney-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'paytmmoney_holdings_csv');
        expect(body['csv'], contains('TATAMOTORS'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-paytmmoney-1',
                'symbol': 'TATAMOTORS',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 109845,
                'currency': 'INR',
                'source': 'paytmmoney_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importPaytmMoneyHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nTATAMOTORS,INE155A01022,2026-07-31,1098.45,5',
        source: 'paytmmoney_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'TATAMOTORS');
    expect(result.prices.single.priceMinor, 109845);
  });

  test('imports Motilal Oswal holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/motilaloswal-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'motilaloswal_holdings_csv');
        expect(body['csv'], contains('ASIANPAINT'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-motilaloswal-1',
                'symbol': 'ASIANPAINT',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 298760,
                'currency': 'INR',
                'source': 'motilaloswal_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importMotilalOswalHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nASIANPAINT,INE021A01026,2026-07-31,2987.60,3',
        source: 'motilaloswal_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'ASIANPAINT');
    expect(result.prices.single.priceMinor, 298760);
  });

  test('imports Sharekhan holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/sharekhan-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'sharekhan_holdings_csv');
        expect(body['csv'], contains('HINDUNILVR'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-sharekhan-1',
                'symbol': 'HINDUNILVR',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 256735,
                'currency': 'INR',
                'source': 'sharekhan_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importSharekhanHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nHINDUNILVR,INE030A01027,2026-07-31,2567.35,4',
        source: 'sharekhan_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'HINDUNILVR');
    expect(result.prices.single.priceMinor, 256735);
  });

  test('imports 5paisa holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/fivepaisa-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'fivepaisa_holdings_csv');
        expect(body['csv'], contains('SBIN'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-fivepaisa-1',
                'symbol': 'SBIN',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 84570,
                'currency': 'INR',
                'source': 'fivepaisa_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importFivePaisaHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nSBIN,INE062A01020,2026-07-31,845.70,10',
        source: 'fivepaisa_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'SBIN');
    expect(result.prices.single.priceMinor, 84570);
  });

  test('imports Axis Direct holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/axisdirect-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'axisdirect_holdings_csv');
        expect(body['csv'], contains('TECHM'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-axisdirect-1',
                'symbol': 'TECHM',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 154325,
                'currency': 'INR',
                'source': 'axisdirect_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importAxisDirectHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nTECHM,INE669C01036,2026-07-31,1543.25,6',
        source: 'axisdirect_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'TECHM');
    expect(result.prices.single.priceMinor, 154325);
  });

  test('imports SBI Securities holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/sbisecurities-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'sbisecurities_holdings_csv');
        expect(body['csv'], contains('INFY'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-sbisecurities-1',
                'symbol': 'INFY',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 149995,
                'currency': 'INR',
                'source': 'sbisecurities_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importSBISecuritiesHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nINFY,INE009A01021,2026-07-31,1499.95,9',
        source: 'sbisecurities_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'INFY');
    expect(result.prices.single.priceMinor, 149995);
  });

  test('imports Nuvama holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/nuvama-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'nuvama_holdings_csv');
        expect(body['csv'], contains('WIPRO'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-nuvama-1',
                'symbol': 'WIPRO',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 51240,
                'currency': 'INR',
                'source': 'nuvama_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importNuvamaHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nWIPRO,INE075A01022,2026-07-31,512.40,11',
        source: 'nuvama_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'WIPRO');
    expect(result.prices.single.priceMinor, 51240);
  });

  test('imports Geojit holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/geojit-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'geojit_holdings_csv');
        expect(body['csv'], contains('HCLTECH'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-geojit-1',
                'symbol': 'HCLTECH',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 144480,
                'currency': 'INR',
                'source': 'geojit_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importGeojitHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nHCLTECH,INE860A01027,2026-07-31,1444.80,7',
        source: 'geojit_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'HCLTECH');
    expect(result.prices.single.priceMinor, 144480);
  });

  test('imports IIFL Securities holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/iiflsecurities-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'iiflsecurities_holdings_csv');
        expect(body['csv'], contains('TITAN'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-iiflsecurities-1',
                'symbol': 'TITAN',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 352015,
                'currency': 'INR',
                'source': 'iiflsecurities_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importIIFLSecuritiesHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nTITAN,INE280A01028,2026-07-31,3520.15,2',
        source: 'iiflsecurities_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'TITAN');
    expect(result.prices.single.priceMinor, 352015);
  });

  test('imports FYERS holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/fyers-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'fyers_holdings_csv');
        expect(body['csv'], contains('SBIN'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-fyers-1',
                'symbol': 'SBIN',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 82045,
                'currency': 'INR',
                'source': 'fyers_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importFYERSHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nSBIN,INE062A01020,2026-07-31,820.45,8',
        source: 'fyers_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'SBIN');
    expect(result.prices.single.priceMinor, 82045);
  });

  test('imports Edelweiss holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/edelweiss-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'edelweiss_holdings_csv');
        expect(body['csv'], contains('EDELWEISS'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-edelweiss-1',
                'symbol': 'EDELWEISS',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 91025,
                'currency': 'INR',
                'source': 'edelweiss_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importEdelweissHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nEDELWEISS,INE532F01054,2026-07-31,910.25,4',
        source: 'edelweiss_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'EDELWEISS');
    expect(result.prices.single.priceMinor, 91025);
  });

  test('imports Alice Blue holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/aliceblue-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'aliceblue_holdings_csv');
        expect(body['csv'], contains('TCS'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-aliceblue-1',
                'symbol': 'TCS',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 401230,
                'currency': 'INR',
                'source': 'aliceblue_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importAliceBlueHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nTCS,INE467B01029,2026-07-31,4012.30,3',
        source: 'aliceblue_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'TCS');
    expect(result.prices.single.priceMinor, 401230);
  });

  test('imports Samco holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/samco-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'samco_holdings_csv');
        expect(body['csv'], contains('SUNPHARMA'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-samco-1',
                'symbol': 'SUNPHARMA',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 167540,
                'currency': 'INR',
                'source': 'samco_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importSamcoHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nSUNPHARMA,INE044A01036,2026-07-31,1675.40,6',
        source: 'samco_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'SUNPHARMA');
    expect(result.prices.single.priceMinor, 167540);
  });

  test('imports Choice holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/choice-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'choice_holdings_csv');
        expect(body['csv'], contains('ULTRACEMCO'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-choice-1',
                'symbol': 'ULTRACEMCO',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 1123455,
                'currency': 'INR',
                'source': 'choice_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importChoiceHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nULTRACEMCO,INE481G01011,2026-07-31,11234.55,1',
        source: 'choice_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'ULTRACEMCO');
    expect(result.prices.single.priceMinor, 1123455);
  });

  test('imports Religare holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/religare-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'religare_holdings_csv');
        expect(body['csv'], contains('ADANIPORTS'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-religare-1',
                'symbol': 'ADANIPORTS',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 132575,
                'currency': 'INR',
                'source': 'religare_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importReligareHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nADANIPORTS,INE742F01042,2026-07-31,1325.75,5',
        source: 'religare_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'ADANIPORTS');
    expect(result.prices.single.priceMinor, 132575);
  });

  test('imports Jainam holdings investment prices', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/investments/prices/import/jainam-holdings',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['source'], 'jainam_holdings_csv');
        expect(body['csv'], contains('POWERGRID'));
        return http.Response(
          jsonEncode({
            'imported': 1,
            'skipped': 0,
            'errors': <String>[],
            'prices': [
              {
                'id': 'price-jainam-1',
                'symbol': 'POWERGRID',
                'price_date': '2026-07-31T00:00:00Z',
                'price_minor': 29865,
                'currency': 'INR',
                'source': 'jainam_holdings_csv',
              },
            ],
          }),
          201,
        );
      }),
    );

    final result = await client.importJainamHoldingsPrices(
      const ImportInvestmentPricesRequest(
        csv:
            'Symbol,ISIN,Date,LTP,Quantity\nPOWERGRID,INE752E01010,2026-07-31,298.65,20',
        source: 'jainam_holdings_csv',
      ),
    );

    expect(result.imported, 1);
    expect(result.prices.single.symbol, 'POWERGRID');
    expect(result.prices.single.priceMinor, 29865);
  });

  test('imports structured bank statement lines', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/bank-statements/import',
        );
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-bank');
        expect(body['file_name'], 'july-bank.csv');
        expect(body['format'], 'csv');
        final lines = body['lines']! as List;
        final line = lines.single as Map<String, Object?>;
        expect(line['posted_date'], '2026-07-15');
        expect(line['description'], 'UPI receipt');
        expect(line['amount_minor'], 125000);
        expect(line['reference'], 'UPI123');
        return http.Response(
          jsonEncode({
            'id': 'bank-import-1',
            'organization_id': 'org-1',
            'account_id': 'acct-bank',
            'file_name': 'july-bank.csv',
            'format': 'csv',
            'status': 'completed',
            'line_count': 1,
            'lines': [
              {
                'id': 'bank-line-1',
                'organization_id': 'org-1',
                'account_id': 'acct-bank',
                'posted_date': '2026-07-15T00:00:00Z',
                'description': 'UPI receipt',
                'amount_minor': 125000,
                'reference': 'UPI123',
                'is_duplicate': false,
              },
            ],
          }),
          201,
        );
      }),
    );

    final imported = await client.importStructuredBankStatement(
      ImportBankStatementRequest(
        accountId: 'acct-bank',
        fileName: 'july-bank.csv',
        lines: [
          ImportBankStatementLineRequest(
            postedDate: DateTime.utc(2026, 7, 15),
            description: 'UPI receipt',
            amountMinor: 125000,
            reference: 'UPI123',
          ),
        ],
      ),
    );

    expect(imported.id, 'bank-import-1');
    expect(imported.lineCount, 1);
    expect(imported.lines.single.description, 'UPI receipt');
    expect(imported.lines.single.isDuplicate, false);
  });

  test('imports QIF and OFX bank statement content', () async {
    final requestedPaths = <String>[];
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['account_id'], 'acct-bank');

        if (request.url.path.endsWith('/bank-statements/import/qif')) {
          expect(body['file_name'], 'july-bank.qif');
          expect(body['qif_content'], contains('!Type:Bank'));
          return _bankImportResponse(fileName: 'july-bank.qif', format: 'qif');
        }

        expect(request.url.path.endsWith('/bank-statements/import/ofx'), true);
        expect(body['file_name'], 'july-bank.ofx');
        expect(body['ofx_content'], contains('<OFX>'));
        return _bankImportResponse(fileName: 'july-bank.ofx', format: 'ofx');
      }),
    );

    final qif = await client.importQifBankStatement(
      const ImportQifBankStatementRequest(
        accountId: 'acct-bank',
        fileName: 'july-bank.qif',
        qifContent: '!Type:Bank\nD13/07/2026\nT1250.00\n^',
      ),
    );
    final ofx = await client.importOfxBankStatement(
      const ImportOfxBankStatementRequest(
        accountId: 'acct-bank',
        fileName: 'july-bank.ofx',
        ofxContent: '<OFX><STMTTRN><TRNAMT>1250.00',
      ),
    );

    expect(qif.format, 'qif');
    expect(ofx.format, 'ofx');
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/bank-statements/import/qif',
      '/api/v1/organizations/org-1/bank-statements/import/ofx',
    ]);
  });

  test('converts estimates and purchase orders', () async {
    final requestedPaths = <String>[];
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, Object?>;

        if (request.url.path.endsWith(
          '/estimates/estimate-1/convert-to-invoice',
        )) {
          expect(body['invoice_number'], 'INV-MOB-002');
          expect(body['issue_date'], '2026-07-18');
          expect(body['due_date'], '2026-08-17');
          expect(body['accounts_receivable_id'], 'acct-ar');
          expect(body['pdf_attachment_id'], 'attachment-pdf');
          return http.Response(
            jsonEncode({
              'id': 'invoice-2',
              'invoice_number': 'INV-MOB-002',
              'status': 'draft',
              'subtotal_minor': 100000,
              'tax_total_minor': 18000,
              'total_minor': 118000,
              'currency': 'INR',
              'pdf_attachment_id': 'attachment-pdf',
              'lines': [],
            }),
            201,
          );
        }

        expect(
          request.url.path.endsWith('/purchase-orders/po-1/convert-to-bill'),
          true,
        );
        expect(body['bill_number'], 'BILL-MOB-002');
        expect(body['issue_date'], '2026-07-19');
        expect(body['due_date'], '2026-08-18');
        expect(body['accounts_payable_id'], 'acct-ap');
        expect(body['document_attachment_id'], 'attachment-bill');
        return http.Response(
          jsonEncode({
            'id': 'bill-2',
            'bill_number': 'BILL-MOB-002',
            'status': 'draft',
            'total_minor': 59000,
            'currency': 'INR',
          }),
          201,
        );
      }),
    );

    final invoice = await client.convertEstimateToInvoice(
      'estimate-1',
      ConvertEstimateToInvoiceRequest(
        invoiceNumber: 'INV-MOB-002',
        issueDate: DateTime.utc(2026, 7, 18),
        dueDate: DateTime.utc(2026, 8, 17),
        accountsReceivableId: 'acct-ar',
        pdfAttachmentId: 'attachment-pdf',
      ),
    );
    final bill = await client.convertPurchaseOrderToBill(
      'po-1',
      ConvertPurchaseOrderToBillRequest(
        billNumber: 'BILL-MOB-002',
        issueDate: DateTime.utc(2026, 7, 19),
        dueDate: DateTime.utc(2026, 8, 18),
        accountsPayableId: 'acct-ap',
        documentAttachmentId: 'attachment-bill',
      ),
    );

    expect(invoice.id, 'invoice-2');
    expect(invoice.pdfAttachmentId, 'attachment-pdf');
    expect(bill.id, 'bill-2');
    expect(requestedPaths, [
      '/api/v1/organizations/org-1/estimates/estimate-1/convert-to-invoice',
      '/api/v1/organizations/org-1/purchase-orders/po-1/convert-to-bill',
    ]);
  });

  test('lists and creates attachment metadata', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/organizations/org-1/attachments');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'attachment-1',
                'file_name': 'receipt.jpg',
                'content_type': 'image/jpeg',
                'storage_driver': 'local',
                'storage_key': 'receipts/receipt.jpg',
                'size_bytes': 2048,
              },
            ]),
            200,
          );
        }

        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['file_name'], 'invoice.pdf');
        expect(body['content_type'], 'application/pdf');
        expect(body['storage_driver'], 'local');
        expect(body['storage_key'], 'invoices/invoice.pdf');
        expect(body['size_bytes'], 4096);

        return http.Response(
          jsonEncode({
            'id': 'attachment-2',
            'file_name': 'invoice.pdf',
            'content_type': 'application/pdf',
            'storage_driver': 'local',
            'storage_key': 'invoices/invoice.pdf',
            'size_bytes': 4096,
          }),
          201,
        );
      }),
    );

    final attachments = await client.listAttachments();
    expect(attachments.single.fileName, 'receipt.jpg');
    expect(attachments.single.sizeBytes, 2048);

    final created = await client.createAttachment(
      const CreateAttachmentMetadata(
        fileName: 'invoice.pdf',
        contentType: 'application/pdf',
        storageKey: 'invoices/invoice.pdf',
        sizeBytes: 4096,
      ),
    );
    expect(created.id, 'attachment-2');
    expect(created.contentType, 'application/pdf');
  });

  test('uploads and downloads attachment binaries', () async {
    final seenMethods = <String>[];
    final client = AccountingApiClient(
      config: config,
      httpClient: _StreamingMockClient((request) async {
        seenMethods.add(request.method);
        expect(request.headers['Authorization'], 'Bearer access-token');

        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/v1/organizations/org-1/attachments/upload',
          );
          expect(request, isA<http.MultipartRequest>());
          final multipart = request as http.MultipartRequest;
          expect(multipart.files.single.field, 'file');
          expect(multipart.files.single.filename, 'receipt.txt');
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'id': 'attachment-uploaded',
                  'file_name': 'receipt.txt',
                  'content_type': 'text/plain',
                  'storage_driver': 'local',
                  'storage_key': 'org-1/attachment-uploaded/receipt.txt',
                  'size_bytes': 13,
                }),
              ),
            ),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/v1/organizations/org-1/attachments/attachment-uploaded/download',
        );
        return http.StreamedResponse(
          Stream.value(utf8.encode('hello receipt')),
          200,
          headers: {
            'content-type': 'text/plain',
            'content-disposition': 'attachment; filename="receipt.txt"',
          },
        );
      }),
    );

    final uploaded = await client.uploadAttachmentBytes(
      fileName: 'receipt.txt',
      bytes: utf8.encode('hello receipt'),
    );
    expect(uploaded.id, 'attachment-uploaded');
    expect(uploaded.storageKey, 'org-1/attachment-uploaded/receipt.txt');

    final downloaded = await client.downloadAttachment(uploaded.id);
    expect(utf8.decode(downloaded.bytes), 'hello receipt');
    expect(downloaded.contentType, 'text/plain');
    expect(downloaded.fileName, 'receipt.txt');
    expect(seenMethods, ['POST', 'GET']);
  });

  test('calculates tax for configured rates or groups', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/organizations/org-1/tax/calculate');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['base_amount_minor'], 100000);
        expect(body['tax_inclusive'], false);
        expect(body['tax_group_id'], 'tax-group-1');

        return http.Response(
          jsonEncode({
            'base_amount_minor': 100000,
            'tax_amount_minor': 18000,
            'total_amount_minor': 118000,
            'components': [
              {
                'tax_rate_id': 'cgst-9',
                'name': 'CGST 9%',
                'percentage_basis': 90000,
                'tax_amount_minor': 9000,
              },
              {
                'tax_rate_id': 'sgst-9',
                'name': 'SGST 9%',
                'percentage_basis': 90000,
                'tax_amount_minor': 9000,
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.calculateTax(
      const CalculateTaxRequest(
        baseAmountMinor: 100000,
        taxInclusive: false,
        taxGroupId: 'tax-group-1',
      ),
    );

    expect(result.taxAmountMinor, 18000);
    expect(result.components, hasLength(2));
    expect(result.components.first.name, 'CGST 9%');
  });

  test('syncs queued expense draft to create expense endpoint', () async {
    final createdAt = DateTime.utc(2026, 7, 11);
    final operation = SyncOperation(
      id: 'expense-local-1',
      module: 'expenses',
      action: 'create_draft',
      createdAt: createdAt,
      payload: const {
        'expense_number': 'EXP-MOB-001',
        'amount_minor': 125000,
        'expense_account_id': 'acct-expense',
        'payment_account_id': 'acct-cash',
        'receipt_attachment_id': 'attachment-1',
        'tax_rate_id': 'tax-rate-1',
        'tax_group_id': 'tax-group-1',
        'tax_inclusive': true,
        'reimbursable': true,
      },
    );
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/organizations/org-1/expenses');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['expense_number'], 'EXP-MOB-001');
        expect(body['expense_date'], '2026-07-11');
        expect(body['amount_minor'], 125000);
        expect(body['expense_account_id'], 'acct-expense');
        expect(body['payment_account_id'], 'acct-cash');
        expect(body['receipt_attachment_id'], 'attachment-1');
        expect(body['tax_rate_id'], 'tax-rate-1');
        expect(body['tax_group_id'], 'tax-group-1');
        expect(body['tax_inclusive'], true);
        expect(body['reimbursable'], true);

        return http.Response(
          jsonEncode({
            'id': 'exp-1',
            'expense_number': 'EXP-MOB-001',
            'status': 'draft',
            'total_minor': 125000,
            'currency': 'INR',
          }),
          201,
        );
      }),
    );

    final expense = await client.syncExpenseDraft(operation);

    expect(expense.id, 'exp-1');
    expect(expense.totalMinor, 125000);
  });

  test('syncs queued expense draft edits to update endpoint', () async {
    final operation = SyncOperation(
      id: 'expense-edit-local-1',
      module: 'expenses',
      action: 'update_draft',
      createdAt: DateTime.utc(2026, 7, 16),
      payload: const {
        'expense_id': 'exp-1',
        'expense_number': 'EXP-MOB-001-EDIT',
        'amount_minor': 99000,
        'expense_account_id': 'acct-expense',
        'payment_account_id': 'acct-bank',
        'receipt_attachment_id': 'attachment-2',
        'tax_group_id': 'tax-group-1',
        'tax_inclusive': true,
        'reimbursable': true,
      },
    );
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/organizations/org-1/expenses/exp-1');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['expense_number'], 'EXP-MOB-001-EDIT');
        expect(body['expense_date'], '2026-07-16');
        expect(body['amount_minor'], 99000);
        expect(body['expense_account_id'], 'acct-expense');
        expect(body['payment_account_id'], 'acct-bank');
        expect(body['receipt_attachment_id'], 'attachment-2');
        expect(body['tax_group_id'], 'tax-group-1');
        expect(body['tax_inclusive'], true);
        expect(body['reimbursable'], true);

        return http.Response(
          jsonEncode({
            'id': 'exp-1',
            'expense_number': 'EXP-MOB-001-EDIT',
            'status': 'draft',
            'total_minor': 99000,
            'currency': 'INR',
          }),
          200,
        );
      }),
    );

    final expense = await client.syncExpenseDraftUpdate(operation);

    expect(expense.id, 'exp-1');
    expect(expense.expenseNumber, 'EXP-MOB-001-EDIT');
    expect(expense.totalMinor, 99000);
  });

  test('syncs queued invoice draft edits to update endpoint', () async {
    final operation = SyncOperation(
      id: 'invoice-edit-local-1',
      module: 'invoices',
      action: 'update_draft',
      createdAt: DateTime.utc(2026, 7, 16),
      payload: const {
        'invoice_id': 'inv-1',
        'customer_id': 'customer-1',
        'invoice_number': 'INV-MOB-001-EDIT',
        'issue_date': '2026-07-16',
        'due_date': '2026-08-15',
        'currency': 'INR',
        'tax_inclusive': false,
        'accounts_receivable_id': 'acct-ar',
        'pdf_attachment_id': 'pdf-2',
        'lines': [
          {
            'description': 'Updated field service',
            'quantity_millis': 1000,
            'unit_price_minor': 175000,
            'income_account_id': 'acct-income',
            'tax_group_id': 'tax-group-1',
          },
        ],
      },
    );
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/organizations/org-1/invoices/inv-1');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['customer_id'], 'customer-1');
        expect(body['invoice_number'], 'INV-MOB-001-EDIT');
        expect(body['issue_date'], '2026-07-16');
        expect(body['due_date'], '2026-08-15');
        expect(body['accounts_receivable_id'], 'acct-ar');
        expect(body['pdf_attachment_id'], 'pdf-2');
        final lines = body['lines']! as List;
        final line = lines.single as Map<String, Object?>;
        expect(line['description'], 'Updated field service');
        expect(line['unit_price_minor'], 175000);
        expect(line['tax_group_id'], 'tax-group-1');

        return http.Response(
          jsonEncode({
            'id': 'inv-1',
            'invoice_number': 'INV-MOB-001-EDIT',
            'status': 'draft',
            'subtotal_minor': 175000,
            'tax_total_minor': 31500,
            'total_minor': 206500,
            'currency': 'INR',
            'pdf_attachment_id': 'pdf-2',
            'lines': [],
          }),
          200,
        );
      }),
    );

    final invoice = await client.syncInvoiceDraftUpdate(operation);

    expect(invoice.id, 'inv-1');
    expect(invoice.invoiceNumber, 'INV-MOB-001-EDIT');
    expect(invoice.totalMinor, 206500);
  });

  test('throws API exception with backend error message', () async {
    final client = AccountingApiClient(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'invalid_request', 'message': 'bad payload'},
          }),
          400,
        );
      }),
    );

    expect(
      client.listAccounts,
      throwsA(
        isA<AccountingApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having((error) => error.message, 'message', 'bad payload'),
      ),
    );
  });
}

class _StreamingMockClient extends http.BaseClient {
  _StreamingMockClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return handler(request);
  }
}

http.Response _bankImportResponse({
  required String fileName,
  required String format,
}) {
  return http.Response(jsonEncode(_bankImportJson(fileName, format)), 201);
}

Map<String, Object?> _bankImportJson(String fileName, String format) {
  return {
    'id': 'bank-import-$format',
    'organization_id': 'org-1',
    'account_id': 'acct-bank',
    'file_name': fileName,
    'format': format,
    'status': 'completed',
    'line_count': 1,
    'lines': [
      {
        'id': 'bank-line-$format',
        'organization_id': 'org-1',
        'account_id': 'acct-bank',
        'posted_date': '2026-07-15T00:00:00Z',
        'description': 'Imported line',
        'amount_minor': 125000,
        'reference': 'BANK-123',
        'is_duplicate': false,
      },
    ],
  };
}
