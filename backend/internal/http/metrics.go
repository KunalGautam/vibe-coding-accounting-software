package http

import (
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type HTTPMetrics struct {
	mu        sync.Mutex
	startedAt time.Time
	requests  map[httpMetricKey]httpMetricValue
}

type httpMetricKey struct {
	Method string
	Route  string
	Status int
}

type httpMetricValue struct {
	Count       uint64
	DurationSum time.Duration
}

func NewHTTPMetrics() *HTTPMetrics {
	return &HTTPMetrics{
		startedAt: time.Now(),
		requests:  map[httpMetricKey]httpMetricValue{},
	}
}

func MetricsMiddleware(metrics *HTTPMetrics) gin.HandlerFunc {
	if metrics == nil {
		return func(c *gin.Context) {
			c.Next()
		}
	}
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		route := c.FullPath()
		if route == "" {
			route = c.Request.URL.Path
		}
		metrics.Record(c.Request.Method, route, c.Writer.Status(), time.Since(start))
	}
}

func (m *HTTPMetrics) Record(method string, route string, status int, duration time.Duration) {
	if m == nil {
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()

	key := httpMetricKey{Method: method, Route: route, Status: status}
	value := m.requests[key]
	value.Count++
	value.DurationSum += duration
	m.requests[key] = value
}

func (m *HTTPMetrics) Handler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Data(http.StatusOK, "text/plain; version=0.0.4; charset=utf-8", []byte(m.Prometheus()))
	}
}

func (m *HTTPMetrics) Prometheus() string {
	if m == nil {
		return ""
	}
	m.mu.Lock()
	defer m.mu.Unlock()

	keys := make([]httpMetricKey, 0, len(m.requests))
	for key := range m.requests {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool {
		if keys[i].Route != keys[j].Route {
			return keys[i].Route < keys[j].Route
		}
		if keys[i].Method != keys[j].Method {
			return keys[i].Method < keys[j].Method
		}
		return keys[i].Status < keys[j].Status
	})

	var builder strings.Builder
	builder.WriteString("# HELP accounting_process_uptime_seconds Process uptime in seconds.\n")
	builder.WriteString("# TYPE accounting_process_uptime_seconds gauge\n")
	builder.WriteString(fmt.Sprintf("accounting_process_uptime_seconds %.3f\n", time.Since(m.startedAt).Seconds()))
	builder.WriteString("# HELP accounting_http_requests_total Total HTTP requests by method, route, and status.\n")
	builder.WriteString("# TYPE accounting_http_requests_total counter\n")
	for _, key := range keys {
		value := m.requests[key]
		builder.WriteString(fmt.Sprintf(
			"accounting_http_requests_total{method=%q,route=%q,status=%q} %d\n",
			key.Method,
			key.Route,
			fmt.Sprintf("%d", key.Status),
			value.Count,
		))
	}
	builder.WriteString("# HELP accounting_http_request_duration_seconds_sum Total HTTP request latency by method, route, and status.\n")
	builder.WriteString("# TYPE accounting_http_request_duration_seconds_sum counter\n")
	for _, key := range keys {
		value := m.requests[key]
		builder.WriteString(fmt.Sprintf(
			"accounting_http_request_duration_seconds_sum{method=%q,route=%q,status=%q} %.6f\n",
			key.Method,
			key.Route,
			fmt.Sprintf("%d", key.Status),
			value.DurationSum.Seconds(),
		))
	}
	builder.WriteString("# HELP accounting_http_request_duration_seconds_count HTTP request latency sample count by method, route, and status.\n")
	builder.WriteString("# TYPE accounting_http_request_duration_seconds_count counter\n")
	for _, key := range keys {
		value := m.requests[key]
		builder.WriteString(fmt.Sprintf(
			"accounting_http_request_duration_seconds_count{method=%q,route=%q,status=%q} %d\n",
			key.Method,
			key.Route,
			fmt.Sprintf("%d", key.Status),
			value.Count,
		))
	}
	return builder.String()
}
