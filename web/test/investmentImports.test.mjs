import test from "node:test";
import assert from "node:assert/strict";

import {
  investmentPriceImportFormats,
  investmentPriceImportMetadata,
  nextInvestmentPriceImportSource
} from "../.test-build/investmentImports.js";

test("investment import metadata covers every supported format", () => {
  assert.deepEqual(investmentPriceImportFormats, ["csv", "amfi", "nse", "bse", "yahoo", "alphavantage", "broker", "zerodha", "groww", "upstox", "angelone", "dhan", "icicidirect"]);
  assert.equal(investmentPriceImportMetadata("zerodha").defaultSource, "zerodha_holdings_csv");
  assert.equal(investmentPriceImportMetadata("zerodha").placeholder, "Instrument,ISIN,Date,LTP,Qty.");
  assert.equal(investmentPriceImportMetadata("groww").defaultSource, "groww_holdings_csv");
  assert.equal(investmentPriceImportMetadata("groww").placeholder, "Company Name,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("upstox").defaultSource, "upstox_holdings_csv");
  assert.equal(investmentPriceImportMetadata("upstox").placeholder, "Symbol,ISIN,Date,Current Price,Quantity");
  assert.equal(investmentPriceImportMetadata("angelone").defaultSource, "angelone_holdings_csv");
  assert.equal(investmentPriceImportMetadata("angelone").placeholder, "Scrip,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("dhan").defaultSource, "dhan_holdings_csv");
  assert.equal(investmentPriceImportMetadata("dhan").placeholder, "Trading Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("icicidirect").defaultSource, "icicidirect_holdings_csv");
  assert.equal(investmentPriceImportMetadata("icicidirect").placeholder, "Symbol,ISIN,Date,Market Price,Quantity");
  assert.equal(investmentPriceImportMetadata("yahoo").requiresSingleSymbol, true);
  assert.equal(investmentPriceImportMetadata("amfi").isAMFI, true);
});

test("nextInvestmentPriceImportSource switches managed defaults but preserves custom sources", () => {
  assert.equal(nextInvestmentPriceImportSource("csv_import", "nse"), "nse_equity_csv");
  assert.equal(nextInvestmentPriceImportSource("broker_holdings_csv", "zerodha"), "zerodha_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("zerodha_holdings_csv", "groww"), "groww_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("groww_holdings_csv", "upstox"), "upstox_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("upstox_holdings_csv", "angelone"), "angelone_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("angelone_holdings_csv", "dhan"), "dhan_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("dhan_holdings_csv", "icicidirect"), "icicidirect_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("my_custom_provider", "bse"), "my_custom_provider");
});
