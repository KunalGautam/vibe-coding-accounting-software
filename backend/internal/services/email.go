package services

import (
	"bytes"
	"context"
	"fmt"
	"net/smtp"
	"strings"
)

type EmailMessage struct {
	To      string
	Subject string
	Text    string
}

type EmailSender interface {
	Send(ctx context.Context, message EmailMessage) error
}

type SMTPEmailSender struct {
	Host     string
	Port     int
	Username string
	Password string
	From     string
}

func (s SMTPEmailSender) Send(ctx context.Context, message EmailMessage) error {
	if strings.TrimSpace(s.Host) == "" || s.Port <= 0 || strings.TrimSpace(s.From) == "" {
		return fmt.Errorf("smtp sender requires host, port, and from address")
	}
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	address := fmt.Sprintf("%s:%d", s.Host, s.Port)
	var auth smtp.Auth
	if s.Username != "" || s.Password != "" {
		auth = smtp.PlainAuth("", s.Username, s.Password, s.Host)
	}
	return smtp.SendMail(address, auth, s.From, []string{message.To}, emailBytes(s.From, message))
}

func emailBytes(from string, message EmailMessage) []byte {
	var buffer bytes.Buffer
	buffer.WriteString("From: " + from + "\r\n")
	buffer.WriteString("To: " + message.To + "\r\n")
	buffer.WriteString("Subject: " + sanitizeEmailHeader(message.Subject) + "\r\n")
	buffer.WriteString("MIME-Version: 1.0\r\n")
	buffer.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	buffer.WriteString("\r\n")
	buffer.WriteString(message.Text)
	return buffer.Bytes()
}

func sanitizeEmailHeader(value string) string {
	value = strings.ReplaceAll(value, "\r", "")
	value = strings.ReplaceAll(value, "\n", "")
	return value
}
