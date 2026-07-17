export type InvestmentPriceImportFormat = "csv" | "amfi" | "nse" | "bse" | "yahoo" | "alphavantage" | "broker" | "zerodha" | "groww" | "upstox" | "angelone" | "dhan" | "icicidirect" | "hdfcsky" | "kotakneo" | "paytmmoney" | "motilaloswal" | "sharekhan" | "fivepaisa" | "axisdirect" | "sbisecurities" | "nuvama" | "geojit" | "iiflsecurities" | "fyers" | "edelweiss" | "aliceblue" | "samco";

export type InvestmentPriceImportMetadata = {
  label: string;
  buttonLabel: string;
  defaultSource: string;
  placeholder: string;
  requiresSingleSymbol: boolean;
  isAMFI: boolean;
};

export const investmentPriceImportFormats: InvestmentPriceImportFormat[] = [
  "csv",
  "amfi",
  "nse",
  "bse",
  "yahoo",
  "alphavantage",
  "broker",
  "zerodha",
  "groww",
  "upstox",
  "angelone",
  "dhan",
  "icicidirect",
  "hdfcsky",
  "kotakneo",
  "paytmmoney",
  "motilaloswal",
  "sharekhan",
  "fivepaisa",
  "axisdirect",
  "sbisecurities",
  "nuvama",
  "geojit",
  "iiflsecurities",
  "fyers",
  "edelweiss",
  "aliceblue",
  "samco"
];

const metadata: Record<InvestmentPriceImportFormat, InvestmentPriceImportMetadata> = {
  csv: {
    label: "Generic CSV",
    buttonLabel: "Import price CSV",
    defaultSource: "csv_import",
    placeholder: "symbol,price_date,price_minor,currency",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  amfi: {
    label: "AMFI NAV text",
    buttonLabel: "Import AMFI NAV",
    defaultSource: "amfi_nav",
    placeholder: "Scheme Code;...;Net Asset Value;Date",
    requiresSingleSymbol: false,
    isAMFI: true
  },
  nse: {
    label: "NSE equity CSV",
    buttonLabel: "Import NSE CSV",
    defaultSource: "nse_equity_csv",
    placeholder: "SYMBOL,SERIES,DATE1,CLOSE_PRICE",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  bse: {
    label: "BSE equity CSV",
    buttonLabel: "Import BSE CSV",
    defaultSource: "bse_equity_csv",
    placeholder: "SC_CODE,SC_GROUP,TRADING_DATE,CLOSE",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  yahoo: {
    label: "Yahoo Finance CSV",
    buttonLabel: "Import Yahoo CSV",
    defaultSource: "yahoo_finance_csv",
    placeholder: "Date,Open,High,Low,Close,Adj Close,Volume",
    requiresSingleSymbol: true,
    isAMFI: false
  },
  alphavantage: {
    label: "Alpha Vantage CSV",
    buttonLabel: "Import Alpha Vantage CSV",
    defaultSource: "alpha_vantage_csv",
    placeholder: "timestamp,open,high,low,close,volume",
    requiresSingleSymbol: true,
    isAMFI: false
  },
  broker: {
    label: "Broker holdings CSV",
    buttonLabel: "Import broker holdings",
    defaultSource: "broker_holdings_csv",
    placeholder: "Symbol,ISIN,As of Date,Last Traded Price,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  zerodha: {
    label: "Zerodha holdings CSV",
    buttonLabel: "Import Zerodha holdings",
    defaultSource: "zerodha_holdings_csv",
    placeholder: "Instrument,ISIN,Date,LTP,Qty.",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  groww: {
    label: "Groww holdings CSV",
    buttonLabel: "Import Groww holdings",
    defaultSource: "groww_holdings_csv",
    placeholder: "Company Name,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  upstox: {
    label: "Upstox holdings CSV",
    buttonLabel: "Import Upstox holdings",
    defaultSource: "upstox_holdings_csv",
    placeholder: "Symbol,ISIN,Date,Current Price,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  angelone: {
    label: "Angel One holdings CSV",
    buttonLabel: "Import Angel One holdings",
    defaultSource: "angelone_holdings_csv",
    placeholder: "Scrip,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  dhan: {
    label: "Dhan holdings CSV",
    buttonLabel: "Import Dhan holdings",
    defaultSource: "dhan_holdings_csv",
    placeholder: "Trading Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  icicidirect: {
    label: "ICICI Direct holdings CSV",
    buttonLabel: "Import ICICI Direct holdings",
    defaultSource: "icicidirect_holdings_csv",
    placeholder: "Symbol,ISIN,Date,Market Price,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  hdfcsky: {
    label: "HDFC Sky holdings CSV",
    buttonLabel: "Import HDFC Sky holdings",
    defaultSource: "hdfcsky_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  kotakneo: {
    label: "Kotak Neo holdings CSV",
    buttonLabel: "Import Kotak Neo holdings",
    defaultSource: "kotakneo_holdings_csv",
    placeholder: "Trading Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  paytmmoney: {
    label: "Paytm Money holdings CSV",
    buttonLabel: "Import Paytm Money holdings",
    defaultSource: "paytmmoney_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  motilaloswal: {
    label: "Motilal Oswal holdings CSV",
    buttonLabel: "Import Motilal Oswal holdings",
    defaultSource: "motilaloswal_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  sharekhan: {
    label: "Sharekhan holdings CSV",
    buttonLabel: "Import Sharekhan holdings",
    defaultSource: "sharekhan_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  fivepaisa: {
    label: "5paisa holdings CSV",
    buttonLabel: "Import 5paisa holdings",
    defaultSource: "fivepaisa_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  axisdirect: {
    label: "Axis Direct holdings CSV",
    buttonLabel: "Import Axis Direct holdings",
    defaultSource: "axisdirect_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  sbisecurities: {
    label: "SBI Securities holdings CSV",
    buttonLabel: "Import SBI Securities holdings",
    defaultSource: "sbisecurities_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  nuvama: {
    label: "Nuvama holdings CSV",
    buttonLabel: "Import Nuvama holdings",
    defaultSource: "nuvama_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  geojit: {
    label: "Geojit holdings CSV",
    buttonLabel: "Import Geojit holdings",
    defaultSource: "geojit_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  iiflsecurities: {
    label: "IIFL Securities holdings CSV",
    buttonLabel: "Import IIFL Securities holdings",
    defaultSource: "iiflsecurities_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  fyers: {
    label: "FYERS holdings CSV",
    buttonLabel: "Import FYERS holdings",
    defaultSource: "fyers_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  edelweiss: {
    label: "Edelweiss holdings CSV",
    buttonLabel: "Import Edelweiss holdings",
    defaultSource: "edelweiss_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  aliceblue: {
    label: "Alice Blue holdings CSV",
    buttonLabel: "Import Alice Blue holdings",
    defaultSource: "aliceblue_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  },
  samco: {
    label: "Samco holdings CSV",
    buttonLabel: "Import Samco holdings",
    defaultSource: "samco_holdings_csv",
    placeholder: "Symbol,ISIN,Date,LTP,Quantity",
    requiresSingleSymbol: false,
    isAMFI: false
  }
};

export function investmentPriceImportMetadata(format: InvestmentPriceImportFormat) {
  return metadata[format];
}

export function nextInvestmentPriceImportSource(currentSource: string, nextFormat: InvestmentPriceImportFormat) {
  const managedSources = new Set(Object.values(metadata).map((entry) => entry.defaultSource));
  if (!managedSources.has(currentSource)) {
    return currentSource;
  }
  return metadata[nextFormat].defaultSource;
}
