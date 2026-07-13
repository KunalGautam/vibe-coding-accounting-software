package handlers

import "github.com/gin-gonic/gin"

func respondError(c *gin.Context, status int, code string, message string) {
	errorBody := gin.H{
		"code":    code,
		"message": message,
	}
	if requestID := c.GetString("request_id"); requestID != "" {
		errorBody["request_id"] = requestID
	}
	c.JSON(status, gin.H{
		"error": errorBody,
	})
}
