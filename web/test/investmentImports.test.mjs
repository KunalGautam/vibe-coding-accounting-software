import test from "node:test";
import assert from "node:assert/strict";

import {
  investmentPriceImportFormats,
  investmentPriceImportMetadata,
  nextInvestmentPriceImportSource
} from "../.test-build/investmentImports.js";

test("investment import metadata covers every supported format", () => {
  assert.deepEqual(investmentPriceImportFormats, ["csv", "amfi", "nse", "bse", "yahoo", "alphavantage", "broker", "zerodha"]);
  assert.equal(investmentPriceImportMetadata("zerodha").defaultSource, "zerodha_holdings_csv");
  assert.equal(investmentPriceImportMetadata("zerodha").placeholder, "Instrument,ISIN,Date,LTP,Qty.");
  assert.equal(investmentPriceImportMetadata("yahoo").requiresSingleSymbol, true);
  assert.equal(investmentPriceImportMetadata("amfi").isAMFI, true);
});

test("nextInvestmentPriceImportSource switches managed defaults but preserves custom sources", () => {
  assert.equal(nextInvestmentPriceImportSource("csv_import", "nse"), "nse_equity_csv");
  assert.equal(nextInvestmentPriceImportSource("broker_holdings_csv", "zerodha"), "zerodha_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("my_custom_provider", "bse"), "my_custom_provider");
});
