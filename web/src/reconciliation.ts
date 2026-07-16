import type { BankStatementLine, ImportBankStatementInput, JournalTransaction, LedgerSplit } from "./api/client";

export type CsvBankMappingConfig = {
  date_columns: string;
  description_columns: string;
  amount_columns: string;
  debit_columns: string;
  credit_columns: string;
  reference_columns: string;
};

export type ReconciliationCandidate = {
  transaction: JournalTransaction;
  split: LedgerSplit;
};

export type ReconciliationSuggestion = {
  line: BankStatementLine;
  candidate: ReconciliationCandidate;
  score: number;
  reason: string;
};

export function importNotice(lineCount: number, lines: BankStatementLine[], label = "statement") {
  const duplicateCount = lines.filter((line) => line.is_duplicate).length;
  const prefix = label === "statement" ? `Imported ${lineCount} statement line(s).` : `Imported ${lineCount} ${label} statement line(s).`;
  return duplicateCount > 0 ? `${prefix} ${duplicateCount} duplicate candidate(s) flagged.` : prefix;
}

export function mapCsvStatementLines(content: string, mapping: CsvBankMappingConfig): ImportBankStatementInput["lines"] {
  const rows = parseCsvRows(content);
  if (rows.length < 2) {
    throw new Error("CSV must include a header row and at least one statement line.");
  }
  const headers = rows[0].map(normalizeCsvHeader);
  const dateIndex = findCsvColumn(headers, mapping.date_columns);
  const descriptionIndex = findCsvColumn(headers, mapping.description_columns);
  const amountIndex = findCsvColumn(headers, mapping.amount_columns);
  const debitIndex = findCsvColumn(headers, mapping.debit_columns);
  const creditIndex = findCsvColumn(headers, mapping.credit_columns);
  const referenceIndex = findCsvColumn(headers, mapping.reference_columns);

  if (dateIndex === -1) {
    throw new Error("CSV mapper could not find a date column.");
  }
  if (amountIndex === -1 && debitIndex === -1 && creditIndex === -1) {
    throw new Error("CSV mapper could not find an amount or debit/credit column.");
  }

  const mappedLines = rows.slice(1).reduce<ImportBankStatementInput["lines"]>((lines, row, rowIndex) => {
    if (row.every((cell) => !cell.trim())) {
      return lines;
    }
    const postedDate = parseCsvDate(row[dateIndex], rowIndex + 2);
    const amountMinor = amountIndex >= 0
      ? parseMinorAmount(row[amountIndex])
      : parseMinorAmount(row[creditIndex] ?? "") - parseMinorAmount(row[debitIndex] ?? "");
    if (amountMinor === 0) {
      return lines;
    }
    lines.push({
      posted_date: postedDate,
      description: descriptionIndex >= 0 ? row[descriptionIndex]?.trim() || undefined : undefined,
      amount_minor: amountMinor,
      reference: referenceIndex >= 0 ? row[referenceIndex]?.trim() || undefined : undefined
    });
    return lines;
  }, []);
  if (mappedLines.length === 0) {
    throw new Error("CSV mapper did not find any non-zero statement lines.");
  }
  return mappedLines;
}

export function parseCsvRows(content: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let inQuotes = false;

  for (let index = 0; index < content.length; index += 1) {
    const char = content[index];
    const nextChar = content[index + 1];
    if (char === "\"") {
      if (inQuotes && nextChar === "\"") {
        cell += "\"";
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char === "," && !inQuotes) {
      row.push(cell);
      cell = "";
      continue;
    }
    if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && nextChar === "\n") {
        index += 1;
      }
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
      continue;
    }
    cell += char;
  }

  if (cell || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows.filter((parsedRow) => parsedRow.some((value) => value.trim()));
}

export function summarizeReconciliation(lines: BankStatementLine[], candidates: ReconciliationCandidate[]) {
  const inflowMinor = lines.reduce((total, line) => total + Math.max(line.amount_minor, 0), 0);
  const outflowMinor = lines.reduce((total, line) => total + Math.abs(Math.min(line.amount_minor, 0)), 0);
  const matchedLineCount = lines.filter((line) => Boolean(line.matched_split_id)).length;
  const reconciledSplitCount = candidates.filter(({ split }) => split.reconciled).length;
  return {
    lineCount: lines.length,
    matchedLineCount,
    openLineCount: lines.length - matchedLineCount,
    duplicateLineCount: lines.filter((line) => line.is_duplicate).length,
    inflowMinor,
    outflowMinor,
    netMinor: inflowMinor - outflowMinor,
    splitCount: candidates.length,
    reconciledSplitCount,
    unreconciledSplitCount: candidates.length - reconciledSplitCount
  };
}

export function suggestReconciliationMatches(lines: BankStatementLine[], candidates: ReconciliationCandidate[]): ReconciliationSuggestion[] {
  const suggestions = lines.flatMap((line) => candidates.map((candidate) => scoreReconciliationCandidate(line, candidate)).filter((suggestion): suggestion is ReconciliationSuggestion => suggestion !== null));
  const usedLines = new Set<string>();
  const usedSplits = new Set<string>();
  return suggestions
    .sort((left, right) => right.score - left.score || left.line.posted_date.localeCompare(right.line.posted_date))
    .filter((suggestion) => {
      if (usedLines.has(suggestion.line.id) || usedSplits.has(suggestion.candidate.split.id)) {
        return false;
      }
      usedLines.add(suggestion.line.id);
      usedSplits.add(suggestion.candidate.split.id);
      return true;
    });
}

function findCsvColumn(headers: string[], aliases: string) {
  const normalizedAliases = aliases.split(",").map(normalizeCsvHeader).filter(Boolean);
  return headers.findIndex((header) => normalizedAliases.includes(header));
}

function normalizeCsvHeader(value: string) {
  return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, " ").replace(/\s+/g, " ").trim();
}

function parseCsvDate(value: string, rowNumber: number) {
  const raw = value.trim();
  const isoMatch = raw.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/);
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2].padStart(2, "0")}-${isoMatch[3].padStart(2, "0")}`;
  }
  const indianDateMatch = raw.match(/^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$/);
  if (indianDateMatch) {
    const year = indianDateMatch[3].length === 2 ? `20${indianDateMatch[3]}` : indianDateMatch[3];
    return `${year}-${indianDateMatch[2].padStart(2, "0")}-${indianDateMatch[1].padStart(2, "0")}`;
  }
  throw new Error(`CSV row ${rowNumber} has an unsupported date: ${raw || "(blank)"}`);
}

function parseMinorAmount(value: string) {
  const trimmed = value.trim();
  if (!trimmed || trimmed === "-") {
    return 0;
  }
  const upper = trimmed.toUpperCase();
  const isNegative = upper.includes("DR") || upper.startsWith("(") || upper.startsWith("-");
  const numeric = upper.replace(/CR|DR|INR|RS\.?|₹|\(|\)|,/g, "").trim();
  const amount = Number.parseFloat(numeric);
  if (!Number.isFinite(amount)) {
    return 0;
  }
  return Math.round(Math.abs(amount) * 100) * (isNegative ? -1 : 1);
}

function scoreReconciliationCandidate(line: BankStatementLine, candidate: ReconciliationCandidate): ReconciliationSuggestion | null {
  const splitAmountMinor = candidate.split.debit_minor - candidate.split.credit_minor;
  if (line.amount_minor !== splitAmountMinor) {
    return null;
  }
  const daysApart = Math.abs(daysBetween(line.posted_date, candidate.transaction.transaction_date));
  if (daysApart > 3) {
    return null;
  }
  const statementText = normalizeMatchText(`${line.description ?? ""} ${line.reference ?? ""}`);
  const ledgerText = normalizeMatchText(`${candidate.transaction.memo ?? ""} ${candidate.transaction.source_module ?? ""}`);
  const textOverlap = statementText && ledgerText && (statementText.includes(ledgerText) || ledgerText.includes(statementText));
  const score = 100 - (daysApart * 10) + (textOverlap ? 15 : 0);
  const reason = daysApart === 0 ? "Exact amount, same date" : `Exact amount, ${daysApart} day(s) apart`;
  return {
    line,
    candidate,
    score,
    reason: textOverlap ? `${reason}, similar memo` : reason
  };
}

function daysBetween(leftDate: string, rightDate: string) {
  const left = Date.parse(leftDate.slice(0, 10));
  const right = Date.parse(rightDate.slice(0, 10));
  if (!Number.isFinite(left) || !Number.isFinite(right)) {
    return 999;
  }
  return Math.round((left - right) / 86_400_000);
}

function normalizeMatchText(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}
