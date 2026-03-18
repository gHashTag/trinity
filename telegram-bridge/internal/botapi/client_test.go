package botapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

func TestNewBotClient_EmptyToken(t *testing.T) {
	cfg := Config{
		Token: "",
	}

	_, err := NewBotClient(cfg)
	if err == nil {
		t.Error("Expected error for empty token")
	}
}

func TestInlineButton_JSON(t *testing.T) {
	btn := InlineButton{
		Text:         "Test Button",
		CallbackData: "callback_data",
	}

	data, err := json.Marshal(btn)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var parsed InlineButton
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if parsed.Text != btn.Text {
		t.Errorf("Expected text %s, got %s", btn.Text, parsed.Text)
	}

	if parsed.CallbackData != btn.CallbackData {
		t.Errorf("Expected callback_data %s, got %s", btn.CallbackData, parsed.CallbackData)
	}
}

func TestInlineButton_URL(t *testing.T) {
	btn := InlineButton{
		Text: "Link",
		URL:  "https://example.com",
	}

	data, err := json.Marshal(btn)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var parsed InlineButton
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if parsed.URL != btn.URL {
		t.Errorf("Expected URL %s, got %s", btn.URL, parsed.URL)
	}
}

func TestCallbackData_JSON(t *testing.T) {
	data := CallbackData{
		QueryID:   "query123",
		ChatID:    12345,
		UserID:    67890,
		Username:  "testuser",
		Data:      "button_pressed",
		MessageID: 111,
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var parsed CallbackData
	if err := json.Unmarshal(jsonData, &parsed); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if parsed.QueryID != data.QueryID {
		t.Errorf("Expected QueryID %s, got %s", data.QueryID, parsed.QueryID)
	}

	if parsed.ChatID != data.ChatID {
		t.Errorf("Expected ChatID %d, got %d", data.ChatID, parsed.ChatID)
	}

	if parsed.UserID != data.UserID {
		t.Errorf("Expected UserID %d, got %d", data.UserID, parsed.UserID)
	}
}

func TestMessageData_JSON(t *testing.T) {
	data := MessageData{
		MessageID:   123,
		ChatID:      456,
		UserID:      789,
		Username:    "user",
		FirstName:   "John",
		LastName:    "Doe",
		Text:        "Hello",
		PhotoFileID: "file123",
		Caption:     "Photo caption",
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var parsed MessageData
	if err := json.Unmarshal(jsonData, &parsed); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if parsed.Text != data.Text {
		t.Errorf("Expected Text %s, got %s", data.Text, parsed.Text)
	}

	if parsed.PhotoFileID != data.PhotoFileID {
		t.Errorf("Expected PhotoFileID %s, got %s", data.PhotoFileID, parsed.PhotoFileID)
	}
}

func TestConfig_Fields(t *testing.T) {
	cfg := Config{
		Token:      "123:ABC",
		WebhookURL: "https://example.com/webhook",
		GleamURL:   "https://gleam.example.com",
		ApiKey:     "secret",
	}

	if cfg.Token != "123:ABC" {
		t.Errorf("Expected token, got %s", cfg.Token)
	}

	if cfg.WebhookURL != "https://example.com/webhook" {
		t.Errorf("Expected webhook URL, got %s", cfg.WebhookURL)
	}
}

// Mock BotClient for testing forward functions
type mockBotClient struct {
	gleamURL string
	apiKey   string
}

func TestForwardCallbackToGleam_NoURL(t *testing.T) {
	// Create a minimal client with empty gleamURL
	c := &BotClient{
		gleamURL: "",
	}

	data := &CallbackData{
		QueryID: "test",
		Data:    "button",
	}

	err := c.ForwardCallbackToGleam(context.Background(), data)
	if err == nil {
		t.Error("Expected error for empty gleamURL")
	}
}

func TestForwardMessageToGleam_NoURL(t *testing.T) {
	c := &BotClient{
		gleamURL: "",
	}

	data := &MessageData{
		MessageID: 123,
		Text:      "Hello",
	}

	err := c.ForwardMessageToGleam(context.Background(), data)
	if err == nil {
		t.Error("Expected error for empty gleamURL")
	}
}

func TestForwardCallbackToGleam_Success(t *testing.T) {
	// Create a test server that accepts the callback
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/bot/callback" {
			t.Errorf("Expected path /api/v1/bot/callback, got %s", r.URL.Path)
		}

		if r.Header.Get("Content-Type") != "application/json" {
			t.Error("Expected Content-Type application/json")
		}

		if r.Header.Get("Authorization") != "Bearer test-api-key" {
			t.Errorf("Expected Authorization header, got %s", r.Header.Get("Authorization"))
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success": true}`))
	}))
	defer server.Close()

	c := &BotClient{
		gleamURL: server.URL,
		apiKey:   "test-api-key",
	}

	data := &CallbackData{
		QueryID:   "query123",
		ChatID:    12345,
		UserID:    67890,
		Data:      "button_click",
		MessageID: 111,
	}

	err := c.ForwardCallbackToGleam(context.Background(), data)
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
}

func TestForwardMessageToGleam_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/bot/message" {
			t.Errorf("Expected path /api/v1/bot/message, got %s", r.URL.Path)
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success": true}`))
	}))
	defer server.Close()

	c := &BotClient{
		gleamURL: server.URL,
		apiKey:   "test-api-key",
	}

	data := &MessageData{
		MessageID: 123,
		ChatID:    456,
		UserID:    789,
		Text:      "Hello world",
	}

	err := c.ForwardMessageToGleam(context.Background(), data)
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
}

func TestForwardCallbackToGleam_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"error": "internal error"}`))
	}))
	defer server.Close()

	c := &BotClient{
		gleamURL: server.URL,
		apiKey:   "test-api-key",
	}

	data := &CallbackData{
		QueryID: "query123",
		Data:    "button_click",
	}

	err := c.ForwardCallbackToGleam(context.Background(), data)
	if err == nil {
		t.Error("Expected error for 500 response")
	}
}

func TestHandleWebhook_CallbackQuery(t *testing.T) {
	// Create a mock BotClient (without real API)
	c := &BotClient{}

	// Create a mock webhook request with callback query
	update := tgbotapi.Update{
		CallbackQuery: &tgbotapi.CallbackQuery{
			ID:   "callback123",
			Data: "button_pressed",
			From: &tgbotapi.User{
				ID:       12345,
				UserName: "testuser",
			},
			Message: &tgbotapi.Message{
				MessageID: 999,
				Chat: &tgbotapi.Chat{
					ID: 67890,
				},
			},
		},
	}

	body, _ := json.Marshal(update)
	req := httptest.NewRequest("POST", "/webhook", bytes.NewReader(body))

	result, err := c.HandleWebhook(req)
	if err != nil {
		t.Fatalf("HandleWebhook error: %v", err)
	}

	if result == nil {
		t.Fatal("Expected non-nil result")
	}

	if result.Callback == nil {
		t.Fatal("Expected callback data")
	}

	if result.Callback.QueryID != "callback123" {
		t.Errorf("Expected QueryID callback123, got %s", result.Callback.QueryID)
	}

	if result.Callback.Data != "button_pressed" {
		t.Errorf("Expected Data button_pressed, got %s", result.Callback.Data)
	}

	if result.Callback.UserID != 12345 {
		t.Errorf("Expected UserID 12345, got %d", result.Callback.UserID)
	}

	if result.Callback.ChatID != 67890 {
		t.Errorf("Expected ChatID 67890, got %d", result.Callback.ChatID)
	}
}

func TestHandleWebhook_Message(t *testing.T) {
	c := &BotClient{}

	update := tgbotapi.Update{
		Message: &tgbotapi.Message{
			MessageID: 123,
			Text:      "Hello world",
			From: &tgbotapi.User{
				ID:        12345,
				UserName:  "testuser",
				FirstName: "Test",
				LastName:  "User",
			},
			Chat: &tgbotapi.Chat{
				ID: 67890,
			},
		},
	}

	body, _ := json.Marshal(update)
	req := httptest.NewRequest("POST", "/webhook", bytes.NewReader(body))

	result, err := c.HandleWebhook(req)
	if err != nil {
		t.Fatalf("HandleWebhook error: %v", err)
	}

	if result == nil {
		t.Fatal("Expected non-nil result")
	}

	if result.Message == nil {
		t.Fatal("Expected message data")
	}

	if result.Message.Text != "Hello world" {
		t.Errorf("Expected text 'Hello world', got %s", result.Message.Text)
	}

	if result.Message.UserID != 12345 {
		t.Errorf("Expected UserID 12345, got %d", result.Message.UserID)
	}
}

func TestHandleWebhook_MessageWithPhoto(t *testing.T) {
	c := &BotClient{}

	update := tgbotapi.Update{
		Message: &tgbotapi.Message{
			MessageID: 123,
			Caption:   "Photo caption",
			From: &tgbotapi.User{
				ID: 12345,
			},
			Chat: &tgbotapi.Chat{
				ID: 67890,
			},
			Photo: []tgbotapi.PhotoSize{
				{FileID: "small_photo"},
				{FileID: "large_photo"}, // Last one is highest resolution
			},
		},
	}

	body, _ := json.Marshal(update)
	req := httptest.NewRequest("POST", "/webhook", bytes.NewReader(body))

	result, err := c.HandleWebhook(req)
	if err != nil {
		t.Fatalf("HandleWebhook error: %v", err)
	}

	if result.Message.PhotoFileID != "large_photo" {
		t.Errorf("Expected large_photo, got %s", result.Message.PhotoFileID)
	}

	if result.Message.Caption != "Photo caption" {
		t.Errorf("Expected caption, got %s", result.Message.Caption)
	}
}

func TestHandleWebhook_InvalidJSON(t *testing.T) {
	c := &BotClient{}

	req := httptest.NewRequest("POST", "/webhook", bytes.NewReader([]byte("invalid json")))

	_, err := c.HandleWebhook(req)
	if err == nil {
		t.Error("Expected error for invalid JSON")
	}
}

func TestHandleWebhook_UnsupportedUpdate(t *testing.T) {
	c := &BotClient{}

	// Empty update (no callback or message)
	update := tgbotapi.Update{}

	body, _ := json.Marshal(update)
	req := httptest.NewRequest("POST", "/webhook", bytes.NewReader(body))

	result, err := c.HandleWebhook(req)
	if err != nil {
		t.Fatalf("HandleWebhook error: %v", err)
	}

	if result != nil {
		t.Error("Expected nil result for unsupported update")
	}
}

func TestUpdateResult_Structure(t *testing.T) {
	result := UpdateResult{
		Callback: &CallbackData{
			QueryID: "test",
		},
	}

	if result.Callback == nil {
		t.Error("Expected callback to be set")
	}

	if result.Message != nil {
		t.Error("Expected message to be nil")
	}
}
