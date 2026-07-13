package services

import (
	"context"
	"errors"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var ErrExchangeRateInvalid = errors.New("exchange rate numerator and denominator must be positive")

type ExchangeRateService struct {
	db *gorm.DB
}

type CreateExchangeRateInput struct {
	OrganizationID string
	FromCurrency   string
	ToCurrency     string
	RateDate       time.Time
	Numerator      int64
	Denominator    int64
	Source         string
}

func NewExchangeRateService(db *gorm.DB) ExchangeRateService {
	return ExchangeRateService{db: db}
}

func (s ExchangeRateService) List(ctx context.Context, organizationID string) ([]domain.ExchangeRate, error) {
	var rates []domain.ExchangeRate
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("rate_date DESC, from_currency ASC, to_currency ASC").
		Find(&rates).
		Error
	return rates, err
}

func (s ExchangeRateService) Create(ctx context.Context, input CreateExchangeRateInput) (domain.ExchangeRate, error) {
	if input.Numerator <= 0 || input.Denominator <= 0 {
		return domain.ExchangeRate{}, ErrExchangeRateInvalid
	}

	rate := domain.ExchangeRate{
		OrganizationID: input.OrganizationID,
		FromCurrency:   input.FromCurrency,
		ToCurrency:     input.ToCurrency,
		RateDate:       input.RateDate,
		Numerator:      input.Numerator,
		Denominator:    input.Denominator,
		Source:         input.Source,
	}
	err := s.db.WithContext(ctx).Create(&rate).Error
	return rate, err
}
