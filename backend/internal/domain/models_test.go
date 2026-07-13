package domain

import "testing"

func TestJournalTransactionValidateBalanced(t *testing.T) {
	tests := []struct {
		name        string
		transaction JournalTransaction
		wantErr     error
	}{
		{
			name: "balanced transaction",
			transaction: JournalTransaction{
				Splits: []LedgerSplit{
					{DebitMinor: 10000},
					{CreditMinor: 10000},
				},
			},
		},
		{
			name: "requires at least two splits",
			transaction: JournalTransaction{
				Splits: []LedgerSplit{{DebitMinor: 10000}},
			},
			wantErr: ErrJournalRequiresSplits,
		},
		{
			name: "rejects both debit and credit on one split",
			transaction: JournalTransaction{
				Splits: []LedgerSplit{
					{DebitMinor: 10000, CreditMinor: 10000},
					{CreditMinor: 10000},
				},
			},
			wantErr: ErrSplitHasBothSides,
		},
		{
			name: "rejects empty split amount",
			transaction: JournalTransaction{
				Splits: []LedgerSplit{
					{DebitMinor: 10000},
					{},
				},
			},
			wantErr: ErrSplitHasNoAmount,
		},
		{
			name: "rejects unbalanced transaction",
			transaction: JournalTransaction{
				Splits: []LedgerSplit{
					{DebitMinor: 10000},
					{CreditMinor: 9999},
				},
			},
			wantErr: ErrJournalNotBalanced,
		},
		{
			name: "balances on base currency amounts when present",
			transaction: JournalTransaction{
				Splits: []LedgerSplit{
					{DebitMinor: 10000, BaseDebitMinor: 835000},
					{CreditMinor: 835000, BaseCreditMinor: 835000},
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.transaction.ValidateBalanced()
			if err != tt.wantErr {
				t.Fatalf("ValidateBalanced() error = %v, want %v", err, tt.wantErr)
			}
		})
	}
}
