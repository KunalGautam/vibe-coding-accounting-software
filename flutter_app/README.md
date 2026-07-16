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
- Invoice cache refresh for offline AR snapshots with line-level GST/VAT tax context visible while offline.
- Invoice PDF attachment ID metadata preserved for offline invoice review.
- Reports page with Trial Balance API refresh and SQLite-backed offline report snapshot review.
- Investment cache refresh for offline lots, realized gains, market prices, and valuation snapshots.
- Typed investment transport for average-cost pooled sales, price maintenance, realized gains, and valuation reports.
- Sync settings placeholder for API base URL and organization selection.

The full generated OpenAPI client, desktop import/export actions, broader mobile/desktop module parity, and invoice PDF generation/detail views are still pending.
