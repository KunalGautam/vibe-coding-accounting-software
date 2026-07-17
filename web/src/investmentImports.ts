export type InvestmentPriceImportFormat = "csv" | "amfi" | "nse" | "bse" | "yahoo" | "alphavantage" | "broker" | "zerodha" | "groww";

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
  "groww"
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
