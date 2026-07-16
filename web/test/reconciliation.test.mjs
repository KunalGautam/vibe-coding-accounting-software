import test from "node:test";
import assert from "node:assert/strict";

import {
  importNotice,
  mapCsvStatementLines,
  parseCsvRows,
  summarizeReconciliation,
  suggestReconciliationMatches
} from "../.test-build/reconciliation.js";

const mapping = {
  date_columns: "date,posted date,value date,transaction date",
  description_columns: "description,narration,details,particulars",
  amount_columns: "amount,transaction amount",
  debit_columns: "debit,withdrawal",
  credit_columns: "credit,deposit",
  reference_columns: "reference,ref,utr"
};

test("parseCsvRows handles quoted commas and escaped quotes", () => {
  assert.deepEqual(parseCsvRows("Date,Description\n2026-01-02,\"Bank, Fee \"\"Monthly\"\"\""), [
    ["Date", "Description"],
    ["2026-01-02", "Bank, Fee \"Monthly\""]
  ]);
});

test("mapCsvStatementLines maps signed amount columns and skips zero rows", () => {
  const lines = mapCsvStatementLines("Date,Description,Amount,Reference\n2026-01-02,\"Bank, Fee\",-12.34,FEE-1\n2026-01-03,Zero,0,ZERO", mapping);
  assert.deepEqual(lines, [{
    posted_date: "2026-01-02",
    description: "Bank, Fee",
    amount_minor: -1234,
    reference: "FEE-1"
  }]);
});

test("mapCsvStatementLines maps debit and credit columns", () => {
  const lines = mapCsvStatementLines("Date,Narration,Debit,Credit\n04/01/2026,Customer receipt,,250.50\n05/01/2026,Rent,100.00,", {
    ...mapping,
    amount_columns: ""
  });
  assert.deepEqual(lines.map((line) => [line.posted_date, line.description, line.amount_minor]), [
    ["2026-01-04", "Customer receipt", 25050],
    ["2026-01-05", "Rent", -10000]
  ]);
});

test("mapCsvStatementLines reports unsupported statement dates", () => {
  assert.throws(
    () => mapCsvStatementLines("Date,Description,Amount\nnot-a-date,Fee,10", mapping),
    /unsupported date/i
  );
});

test("importNotice includes duplicate counts", () => {
  assert.equal(importNotice(2, [
    statementLine({ id: "line-1", amount_minor: 1000 }),
    statementLine({ id: "line-2", amount_minor: 1000, is_duplicate: true })
  ]), "Imported 2 statement line(s). 1 duplicate candidate(s) flagged.");
});

test("summarizeReconciliation returns line and split rollups", () => {
  const summary = summarizeReconciliation([
    statementLine({ id: "line-1", amount_minor: 25000, matched_split_id: "split-1" }),
    statementLine({ id: "line-2", amount_minor: -10000, is_duplicate: true })
  ], [
    candidate("txn-1", "split-1", 25000, 0, true),
    candidate("txn-2", "split-2", 0, 10000, false)
  ]);
  assert.deepEqual(summary, {
    lineCount: 2,
    matchedLineCount: 1,
    openLineCount: 1,
    duplicateLineCount: 1,
    inflowMinor: 25000,
    outflowMinor: 10000,
    netMinor: 15000,
    splitCount: 2,
    reconciledSplitCount: 1,
    unreconciledSplitCount: 1
  });
});

test("suggestReconciliationMatches picks best one-to-one exact amount matches", () => {
  const suggestions = suggestReconciliationMatches([
    statementLine({ id: "line-1", posted_date: "2026-01-10", description: "Acme payment", amount_minor: 50000 }),
    statementLine({ id: "line-2", posted_date: "2026-01-11", description: "Acme payment", amount_minor: 50000 }),
    statementLine({ id: "line-3", posted_date: "2026-01-20", description: "Too late", amount_minor: 50000 })
  ], [
    candidate("txn-1", "split-1", 50000, 0, false, "2026-01-10", "Acme payment"),
    candidate("txn-2", "split-2", 50000, 0, false, "2026-01-30", "Too late")
  ]);
  assert.equal(suggestions.length, 1);
  assert.equal(suggestions[0].line.id, "line-1");
  assert.equal(suggestions[0].candidate.split.id, "split-1");
  assert.match(suggestions[0].reason, /same date/);
});

function statementLine(overrides = {}) {
  return {
    id: "line",
    organization_id: "org-1",
    account_id: "bank-1",
    import_batch_id: "batch-1",
    posted_date: "2026-01-01",
    description: "Statement line",
    amount_minor: 1000,
    reference: "",
    checksum: "checksum",
    is_duplicate: false,
    duplicate_of_id: null,
    matched_split_id: null,
    created_at: "2026-01-01T00:00:00Z",
    ...overrides
  };
}

function candidate(transactionId, splitId, debitMinor, creditMinor, reconciled, transactionDate = "2026-01-01", memo = "Statement line") {
  return {
    transaction: {
      id: transactionId,
      organization_id: "org-1",
      transaction_date: transactionDate,
      description: memo,
      memo,
      source_module: "ledger",
      source_id: "",
      reversed_transaction_id: null,
      created_by_id: "user-1",
      created_at: "2026-01-01T00:00:00Z",
      splits: []
    },
    split: {
      id: splitId,
      transaction_id: transactionId,
      account_id: "bank-1",
      debit_minor: debitMinor,
      credit_minor: creditMinor,
      currency: "INR",
      memo,
      cleared: false,
      reconciled
    }
  };
}
