package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"accounting.abhashtech.com/internal/domain"
	"gorm.io/gorm"
)

var ErrScheduledReportInvalid = errors.New("scheduled report requires name, type, frequency, organization, and next run date")

type CreateScheduledReportInput struct {
	OrganizationID  string
	Name            string
	ReportType      domain.ScheduledReportType
	Frequency       domain.ScheduledReportFrequency
	ParametersJSON  string
	EmailRecipients string
	NextRunAt       time.Time
}

type ScheduledReportRunResult struct {
	ReportsProcessed int `json:"reports_processed"`
	CompletedCount   int `json:"completed_count"`
	FailedCount      int `json:"failed_count"`
}

func (s ReportService) CreateScheduledReport(ctx context.Context, input CreateScheduledReportInput) (domain.ScheduledReport, error) {
	if input.OrganizationID == "" || input.Name == "" || input.ReportType == "" || input.Frequency == "" || input.NextRunAt.IsZero() {
		return domain.ScheduledReport{}, ErrScheduledReportInvalid
	}
	if !supportedScheduledReportType(input.ReportType) || !supportedScheduledReportFrequency(input.Frequency) {
		return domain.ScheduledReport{}, ErrScheduledReportInvalid
	}
	report := domain.ScheduledReport{
		OrganizationID:  input.OrganizationID,
		Name:            input.Name,
		ReportType:      input.ReportType,
		Frequency:       input.Frequency,
		ParametersJSON:  input.ParametersJSON,
		EmailRecipients: input.EmailRecipients,
		NextRunAt:       input.NextRunAt,
		IsActive:        true,
	}
	err := s.db.WithContext(ctx).Create(&report).Error
	return report, err
}

func (s ReportService) ListScheduledReports(ctx context.Context, organizationID string) ([]domain.ScheduledReport, error) {
	var reports []domain.ScheduledReport
	err := s.db.WithContext(ctx).
		Where("organization_id = ?", organizationID).
		Order("next_run_at ASC, created_at ASC").
		Find(&reports).
		Error
	return reports, err
}

func (s ReportService) ListScheduledReportRuns(ctx context.Context, organizationID string, scheduledReportID string) ([]domain.ScheduledReportRun, error) {
	var runs []domain.ScheduledReportRun
	err := s.db.WithContext(ctx).
		Where("organization_id = ? AND scheduled_report_id = ?", organizationID, scheduledReportID).
		Order("created_at DESC").
		Find(&runs).
		Error
	return runs, err
}

func (s ReportService) RunDueScheduledReports(ctx context.Context, asOf time.Time) (ScheduledReportRunResult, error) {
	var scheduled []domain.ScheduledReport
	if err := s.db.WithContext(ctx).
		Where("is_active = ? AND next_run_at <= ?", true, asOf).
		Order("next_run_at ASC, created_at ASC").
		Find(&scheduled).
		Error; err != nil {
		return ScheduledReportRunResult{}, err
	}

	result := ScheduledReportRunResult{ReportsProcessed: len(scheduled)}
	for _, schedule := range scheduled {
		run := s.runScheduledReport(ctx, schedule, asOf)
		s.emailScheduledReportRun(ctx, schedule, &run)
		if run.Status == domain.ScheduledReportRunCompleted {
			result.CompletedCount++
		} else {
			result.FailedCount++
		}
		if err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&run).Error; err != nil {
				return err
			}
			return tx.Model(&domain.ScheduledReport{}).
				Where("id = ?", schedule.ID).
				Updates(map[string]any{
					"last_run_at": asOf,
					"next_run_at": nextScheduledReportRun(schedule.Frequency, schedule.NextRunAt, asOf),
				}).
				Error
		}); err != nil {
			return ScheduledReportRunResult{}, err
		}
	}
	return result, nil
}

func (s ReportService) runScheduledReport(ctx context.Context, schedule domain.ScheduledReport, asOf time.Time) domain.ScheduledReportRun {
	run := domain.ScheduledReportRun{
		OrganizationID:    schedule.OrganizationID,
		ScheduledReportID: schedule.ID,
		ReportType:        schedule.ReportType,
		Status:            domain.ScheduledReportRunCompleted,
	}
	parameters := scheduledReportParameters{}
	if schedule.ParametersJSON != "" {
		if err := json.Unmarshal([]byte(schedule.ParametersJSON), &parameters); err != nil {
			run.Status = domain.ScheduledReportRunFailed
			run.ErrorMessage = err.Error()
			return run
		}
	}
	payload, err := s.scheduledReportPayload(ctx, schedule, parameters, asOf, &run)
	if err != nil {
		run.Status = domain.ScheduledReportRunFailed
		run.ErrorMessage = err.Error()
		return run
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		run.Status = domain.ScheduledReportRunFailed
		run.ErrorMessage = err.Error()
		return run
	}
	run.ReportJSON = string(encoded)
	return run
}

func (s ReportService) emailScheduledReportRun(ctx context.Context, schedule domain.ScheduledReport, run *domain.ScheduledReportRun) {
	if s.emailSender == nil || strings.TrimSpace(schedule.EmailRecipients) == "" || run.Status != domain.ScheduledReportRunCompleted {
		return
	}
	recipients := scheduledReportRecipients(schedule.EmailRecipients)
	if len(recipients) == 0 {
		return
	}
	for _, recipient := range recipients {
		if err := s.emailSender.Send(ctx, EmailMessage{
			To:      recipient,
			Subject: scheduledReportEmailSubject(schedule, *run),
			Text:    scheduledReportEmailText(schedule, *run),
		}); err != nil {
			run.Status = domain.ScheduledReportRunFailed
			run.ErrorMessage = "email delivery failed: " + err.Error()
			return
		}
	}
}

func scheduledReportRecipients(value string) []string {
	parts := strings.FieldsFunc(value, func(r rune) bool {
		return r == ',' || r == ';' || r == '\n'
	})
	recipients := make([]string, 0, len(parts))
	for _, part := range parts {
		recipient := strings.TrimSpace(part)
		if recipient != "" {
			recipients = append(recipients, recipient)
		}
	}
	return recipients
}

func scheduledReportEmailSubject(schedule domain.ScheduledReport, run domain.ScheduledReportRun) string {
	return fmt.Sprintf("Accounting report: %s", schedule.Name)
}

func scheduledReportEmailText(schedule domain.ScheduledReport, run domain.ScheduledReportRun) string {
	var period string
	switch {
	case run.AsOfDate != nil:
		period = "As of " + run.AsOfDate.Format("2006-01-02")
	case run.PeriodStart != nil && run.PeriodEnd != nil:
		period = run.PeriodStart.Format("2006-01-02") + " to " + run.PeriodEnd.Format("2006-01-02")
	default:
		period = "Generated " + time.Now().UTC().Format(time.RFC3339)
	}
	return fmt.Sprintf("Scheduled report: %s\nType: %s\nPeriod: %s\n\nJSON snapshot:\n%s\n", schedule.Name, schedule.ReportType, period, run.ReportJSON)
}

type scheduledReportParameters struct {
	FromDate string `json:"from_date"`
	ToDate   string `json:"to_date"`
	AsOfDate string `json:"as_of_date"`
}

func (s ReportService) scheduledReportPayload(ctx context.Context, schedule domain.ScheduledReport, parameters scheduledReportParameters, asOf time.Time, run *domain.ScheduledReportRun) (any, error) {
	switch schedule.ReportType {
	case domain.ScheduledReportTrialBalance:
		asOfDate, err := scheduledAsOf(parameters.AsOfDate, asOf)
		if err != nil {
			return nil, err
		}
		run.AsOfDate = &asOfDate
		return s.TrialBalance(ctx, schedule.OrganizationID, asOfDate)
	case domain.ScheduledReportBalanceSheet:
		asOfDate, err := scheduledAsOf(parameters.AsOfDate, asOf)
		if err != nil {
			return nil, err
		}
		run.AsOfDate = &asOfDate
		return s.BalanceSheet(ctx, schedule.OrganizationID, asOfDate)
	case domain.ScheduledReportProfitAndLoss:
		from, to, err := scheduledRange(parameters.FromDate, parameters.ToDate, asOf)
		if err != nil {
			return nil, err
		}
		run.PeriodStart = &from
		run.PeriodEnd = &to
		return s.ProfitAndLoss(ctx, schedule.OrganizationID, from, to)
	default:
		return nil, ErrScheduledReportInvalid
	}
}

func scheduledAsOf(value string, fallback time.Time) (time.Time, error) {
	if value == "" {
		return dateOnly(fallback), nil
	}
	return time.Parse("2006-01-02", value)
}

func scheduledRange(fromValue string, toValue string, fallback time.Time) (time.Time, time.Time, error) {
	if fromValue == "" && toValue == "" {
		to := dateOnly(fallback)
		return time.Date(to.Year(), to.Month(), 1, 0, 0, 0, 0, time.UTC), to, nil
	}
	from, err := time.Parse("2006-01-02", fromValue)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	to, err := time.Parse("2006-01-02", toValue)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	return from, to, nil
}

func dateOnly(value time.Time) time.Time {
	return time.Date(value.Year(), value.Month(), value.Day(), 0, 0, 0, 0, time.UTC)
}

func nextScheduledReportRun(frequency domain.ScheduledReportFrequency, previous time.Time, asOf time.Time) time.Time {
	next := previous
	for !next.After(asOf) {
		switch frequency {
		case domain.ScheduledReportFrequencyDaily:
			next = next.AddDate(0, 0, 1)
		case domain.ScheduledReportFrequencyWeekly:
			next = next.AddDate(0, 0, 7)
		default:
			next = next.AddDate(0, 1, 0)
		}
	}
	return next
}

func supportedScheduledReportType(reportType domain.ScheduledReportType) bool {
	switch reportType {
	case domain.ScheduledReportTrialBalance, domain.ScheduledReportProfitAndLoss, domain.ScheduledReportBalanceSheet:
		return true
	default:
		return false
	}
}

func supportedScheduledReportFrequency(frequency domain.ScheduledReportFrequency) bool {
	switch frequency {
	case domain.ScheduledReportFrequencyDaily, domain.ScheduledReportFrequencyWeekly, domain.ScheduledReportFrequencyMonthly:
		return true
	default:
		return false
	}
}
