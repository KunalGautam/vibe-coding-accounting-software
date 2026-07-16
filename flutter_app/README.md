# Accounting Flutter App

Flutter desktop and mobile shell for the Ledger Works accounting platform.

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
dart format lib test
flutter analyze
flutter test
```

## Current Scope

- Responsive mobile/desktop navigation shell.
- Offline-ready status indicators and shared Dart draft sync queue.
- Draft expense form for merchant/memo, INR amount, receipt attachment ID, cached receipt attachment selection, tax rate/group IDs, tax-inclusive mode, and reimbursable flag.
- Draft expense validation prevents sending both a tax rate ID and tax group ID for the same expense.
- Tax rate/group fields clear each other while typing so drafts naturally keep one tax target.
- Pending draft list showing merchant, amount, receipt attachment ID, tax metadata, reimbursable status, and posting-account readiness.
- Local editing and deletion for queued expense drafts before sync.
- Typed Dart API client for accounts, invoices, expenses, and queued expense draft sync.
- Typed Dart API client for attachment metadata plus binary upload/download used by receipt and invoice PDF workflows.
- Offline account cache with file-backed storage for chart-of-account lookup.
- Offline invoice cache with file-backed storage for read-only invoice review, including line items, subtotal, tax total, and grand total.
- Offline attachment metadata cache with file-backed storage for receipt/PDF ID review.
- Offline attachment binary cache with file-backed storage for downloaded receipt/PDF bytes.
- Offline tax catalog cache with file-backed storage for configured tax rate/group lookup.
- Offline queued replay for draft invoice and draft expense edits against the API `PUT` update endpoints.
- Sync coordinator that drains successful expense draft operations and keeps failures queued for retry.
- Sync operation repository boundary with an in-memory implementation ready to swap for SQLite.
- File-backed sync operation repository using each platform's application support directory.
- Sync page action/status UI that reports pending local operations and blocked credential state.
- File-backed sync settings for API URL, JWT token, organization ID, and default expense/payment accounts.
- Credential-gated live sync path for queued expense drafts.
- Account lookup from the API so users can discover chart-of-account IDs for sync settings.
- One-tap account selection for default expense and payment posting accounts.
- Resolved default account labels from the cached chart of accounts for offline review.
- Customer/vendor lookup from the API with SQLite-backed offline party snapshots for AR/AP reference.
- Tax lookup from the API so users can discover configured tax rate/group IDs for expense drafts.
- One-tap tax rate/group selection for default config-driven tax metadata.
- Resolved default tax labels from the cached tax catalog for offline review.
- Attachment metadata lookup, sample binary upload, binary download check, cached binary inspection, offline availability status, and local metadata/binary caching from the sync page.
- File picker, gallery picker, and camera receipt capture for binary attachments, with local path fallback and offline upload queueing when credentials are absent.
- Draft invoice/expense edit replay through `invoices.update_draft` and `expenses.update_draft` sync operations.
- Cached attachment IDs can be selected directly from the expense draft form for receipt posting.
- Tax preview for draft expenses using configured API tax rates/groups before queueing.
- Expense capture entry point for receipt and reimbursable workflows.
- Invoice draft creation form that queues one-line AR drafts through `invoices.create_draft`.
- Invoice cache refresh for offline AR snapshots with line-level GST/VAT tax context visible while offline.
- Invoice PDF attachment ID metadata preserved for offline invoice review.
- Invoice PDF attachment download and cached-byte inspection directly from cached invoice rows.
- Reports page with Trial Balance, P&L, Balance Sheet, Cash Flow, AR Aging, AP Aging, Tax Liability, Tax Summary, and Budget vs Actual API refresh, prior-period comparison for statements/aging/tax reports, selected-vs-previous budget comparison, plus SQLite-backed offline report snapshot review and local app-storage/Downloads/share-sheet CSV exports.
- Investment cache refresh for offline lots, realized gains, market prices, and valuation snapshots.
- Typed investment transport for lot creation, dividend capture, corporate actions, average-cost pooled sales, price maintenance, broker holdings price imports, realized gains, and valuation reports.
- Investments page includes lot creation that queues `investments.create_lot` for later sync.
- Investments page includes manual investment price capture that queues `investments.create_price` for later sync.
- Investments page includes dividend capture that queues `investments.create_dividend` for later sync.
- Investments page includes split/bonus corporate action capture that queues `investments.create_corporate_action` for later sync.
- Investments page includes specific-lot sale capture that queues `investments.sell_lot` for later sync.
- Investments page includes average-cost sale capture that queues `investments.sell_average_cost` for later sync.
- Offline replay for broker holdings price imports through the `investments.import_broker_holdings` sync operation.
- Investments page includes broker holdings CSV paste and file-pick flows that queue imports for later sync.
- Sync settings placeholder for API base URL and organization selection.

The full generated OpenAPI client, desktop import/export actions, broader mobile/desktop module parity, and richer multi-line invoice detail/edit views are still pending.
