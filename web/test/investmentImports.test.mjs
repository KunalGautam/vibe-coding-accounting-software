import test from "node:test";
import assert from "node:assert/strict";

import {
  investmentPriceImportFormats,
  investmentPriceImportMetadata,
  nextInvestmentPriceImportSource
} from "../.test-build/investmentImports.js";

test("investment import metadata covers every supported format", () => {
  assert.deepEqual(investmentPriceImportFormats, ["csv", "amfi", "nse", "bse", "yahoo", "alphavantage", "broker", "zerodha", "groww", "upstox", "angelone", "dhan", "icicidirect", "hdfcsky", "kotakneo", "paytmmoney", "motilaloswal", "sharekhan", "fivepaisa", "axisdirect", "sbisecurities", "nuvama", "geojit", "iiflsecurities", "fyers", "edelweiss"]);
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
  assert.equal(investmentPriceImportMetadata("hdfcsky").defaultSource, "hdfcsky_holdings_csv");
  assert.equal(investmentPriceImportMetadata("hdfcsky").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("kotakneo").defaultSource, "kotakneo_holdings_csv");
  assert.equal(investmentPriceImportMetadata("kotakneo").placeholder, "Trading Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("paytmmoney").defaultSource, "paytmmoney_holdings_csv");
  assert.equal(investmentPriceImportMetadata("paytmmoney").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("motilaloswal").defaultSource, "motilaloswal_holdings_csv");
  assert.equal(investmentPriceImportMetadata("motilaloswal").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("sharekhan").defaultSource, "sharekhan_holdings_csv");
  assert.equal(investmentPriceImportMetadata("sharekhan").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("fivepaisa").defaultSource, "fivepaisa_holdings_csv");
  assert.equal(investmentPriceImportMetadata("fivepaisa").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("axisdirect").defaultSource, "axisdirect_holdings_csv");
  assert.equal(investmentPriceImportMetadata("axisdirect").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("sbisecurities").defaultSource, "sbisecurities_holdings_csv");
  assert.equal(investmentPriceImportMetadata("sbisecurities").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("nuvama").defaultSource, "nuvama_holdings_csv");
  assert.equal(investmentPriceImportMetadata("nuvama").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("geojit").defaultSource, "geojit_holdings_csv");
  assert.equal(investmentPriceImportMetadata("geojit").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("iiflsecurities").defaultSource, "iiflsecurities_holdings_csv");
  assert.equal(investmentPriceImportMetadata("iiflsecurities").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("fyers").defaultSource, "fyers_holdings_csv");
  assert.equal(investmentPriceImportMetadata("fyers").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
  assert.equal(investmentPriceImportMetadata("edelweiss").defaultSource, "edelweiss_holdings_csv");
  assert.equal(investmentPriceImportMetadata("edelweiss").placeholder, "Symbol,ISIN,Date,LTP,Quantity");
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
  assert.equal(nextInvestmentPriceImportSource("icicidirect_holdings_csv", "hdfcsky"), "hdfcsky_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("hdfcsky_holdings_csv", "kotakneo"), "kotakneo_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("kotakneo_holdings_csv", "paytmmoney"), "paytmmoney_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("paytmmoney_holdings_csv", "motilaloswal"), "motilaloswal_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("motilaloswal_holdings_csv", "sharekhan"), "sharekhan_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("sharekhan_holdings_csv", "fivepaisa"), "fivepaisa_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("fivepaisa_holdings_csv", "axisdirect"), "axisdirect_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("axisdirect_holdings_csv", "sbisecurities"), "sbisecurities_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("sbisecurities_holdings_csv", "nuvama"), "nuvama_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("nuvama_holdings_csv", "geojit"), "geojit_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("geojit_holdings_csv", "iiflsecurities"), "iiflsecurities_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("iiflsecurities_holdings_csv", "fyers"), "fyers_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("fyers_holdings_csv", "edelweiss"), "edelweiss_holdings_csv");
  assert.equal(nextInvestmentPriceImportSource("my_custom_provider", "bse"), "my_custom_provider");
});
