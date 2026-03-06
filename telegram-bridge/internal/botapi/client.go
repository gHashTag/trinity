// Package botapi provides Telegram Bot API client for handling callbacks
// This works alongside the MTProto client (gotd/td) for hybrid user-bot mode
package botapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

// BotClient wraps the Telegram Bot API for callback handling
type BotClient struct {
	api           *tgbotapi.BotAPI
	token         string
	webhookURL    string
	gleamURL      string // URL to forward callbacks to Gleam
	apiKey        string // API key for Gleam authentication
	callbackQueue chan *tgbotapi.CallbackQuery
	mu            sync.RWMutex
}

// Config holds bot configuration
type Config struct {
	Token      string
	WebhookURL string // e.g., https://vibee-telegram-bridge.fly.dev/api/v1/bot/webhook
	GleamURL   string // e.g., https://vibee-mcp.fly.dev
	ApiKey     string // VIBEE_API_KEY for Gleam authentication
}

// NewBotClient creates a new Bot API client
func NewBotClient(cfg Config) (*BotClient, error) {
	if cfg.Token == "" {
		return nil, fmt.Errorf("bot token is required")
	}

	bot, err := tgbotapi.NewBotAPI(cfg.Token)
	if err != nil {
		return nil, fmt.Errorf("failed to create bot: %w", err)
	}

	log.Printf("[BotAPI] Authorized as @%s", bot.Self.UserName)

	return &BotClient{
		api:           bot,
		token:         cfg.Token,
		webhookURL:    cfg.WebhookURL,
		gleamURL:      cfg.GleamURL,
		apiKey:        cfg.ApiKey,
		callbackQueue: make(chan *tgbotapi.CallbackQuery, 100),
	}, nil
}

// SetWebhook configures the webhook for receiving updates
func (c *BotClient) SetWebhook(webhookURL string) error {
	log.Printf("[BotAPI] Setting webhook to: %s", webhookURL)

	// First delete existing webhook to clear any cached errors
	log.Printf("[BotAPI] Deleting existing webhook first...")
	delCfg := tgbotapi.DeleteWebhookConfig{DropPendingUpdates: true}
	if _, err := c.api.Request(delCfg); err != nil {
		log.Printf("[BotAPI] ⚠️ Delete webhook warning: %v", err)
	}

	wh, err := tgbotapi.NewWebhook(webhookURL)
	if err != nil {
		log.Printf("[BotAPI] ❌ Failed to create webhook config: %v", err)
		return fmt.Errorf("failed to create webhook: %w", err)
	}

	// Explicitly allow callback_query updates for inline buttons
	wh.AllowedUpdates = []string{"callback_query", "message"}
	log.Printf("[BotAPI] AllowedUpdates: %v", wh.AllowedUpdates)

	resp, err := c.api.Request(wh)
	if err != nil {
		log.Printf("[BotAPI] ❌ Failed to set webhook: %v", err)
		return fmt.Errorf("failed to set webhook: %w", err)
	}

	log.Printf("[BotAPI] ✅ Webhook set successfully: %s (response ok=%v)", webhookURL, resp.Ok)

	// Verify webhook is set by getting info
	info, err := c.api.GetWebhookInfo()
	if err != nil {
		log.Printf("[BotAPI] ⚠️ Could not verify webhook: %v", err)
	} else {
		log.Printf("[BotAPI] Webhook info: URL=%s, PendingUpdates=%d, LastError=%s",
			info.URL, info.PendingUpdateCount, info.LastErrorMessage)
	}

	return nil
}

// GetWebhookInfo returns current webhook configuration
func (c *BotClient) GetWebhookInfo() (tgbotapi.WebhookInfo, error) {
	return c.api.GetWebhookInfo()
}

// DeleteWebhook removes the webhook configuration
func (c *BotClient) DeleteWebhook() error {
	log.Printf("[BotAPI] Deleting webhook...")

	// Use deleteWebhook API call
	cfg := tgbotapi.DeleteWebhookConfig{DropPendingUpdates: false}
	_, err := c.api.Request(cfg)
	if err != nil {
		log.Printf("[BotAPI] ❌ Failed to delete webhook: %v", err)
		return fmt.Errorf("failed to delete webhook: %w", err)
	}

	log.Printf("[BotAPI] ✅ Webhook deleted")
	return nil
}

// SendMessage sends a plain text message via Bot API
func (c *BotClient) SendMessage(chatID int64, text string) (int, error) {
	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "Markdown"

	sent, err := c.api.Send(msg)
	if err != nil {
		return 0, fmt.Errorf("send message: %w", err)
	}

	log.Printf("[BotAPI] Sent message to %d, msg_id=%d", chatID, sent.MessageID)
	return sent.MessageID, nil
}

// InlineButton represents a single inline keyboard button
type InlineButton struct {
	Text         string `json:"text"`
	CallbackData string `json:"callback_data,omitempty"`
	URL          string `json:"url,omitempty"`
}

// SendWithButtons sends a message with inline keyboard
func (c *BotClient) SendWithButtons(chatID int64, text string, buttons [][]InlineButton) (int, error) {
	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "Markdown"

	// Convert to tgbotapi keyboard format
	var keyboard [][]tgbotapi.InlineKeyboardButton
	for _, row := range buttons {
		var keyboardRow []tgbotapi.InlineKeyboardButton
		for _, btn := range row {
			// Check if it's a URL button or callback button
			if btn.URL != "" {
				keyboardRow = append(keyboardRow, tgbotapi.NewInlineKeyboardButtonURL(btn.Text, btn.URL))
			} else {
				keyboardRow = append(keyboardRow, tgbotapi.NewInlineKeyboardButtonData(btn.Text, btn.CallbackData))
			}
		}
		keyboard = append(keyboard, keyboardRow)
	}

	msg.ReplyMarkup = tgbotapi.NewInlineKeyboardMarkup(keyboard...)

	sent, err := c.api.Send(msg)
	if err != nil {
		return 0, fmt.Errorf("send with buttons: %w", err)
	}

	log.Printf("[BotAPI] Sent message with buttons to %d, msg_id=%d", chatID, sent.MessageID)
	return sent.MessageID, nil
}

// AnswerCallback answers a callback query
func (c *BotClient) AnswerCallback(queryID string, text string, showAlert bool) error {
	callback := tgbotapi.NewCallback(queryID, text)
	callback.ShowAlert = showAlert

	_, err := c.api.Request(callback)
	if err != nil {
		return fmt.Errorf("answer callback: %w", err)
	}

	log.Printf("[BotAPI] Answered callback %s", queryID)
	return nil
}

// EditMessageText edits a message text
func (c *BotClient) EditMessageText(chatID int64, messageID int, text string) error {
	edit := tgbotapi.NewEditMessageText(chatID, messageID, text)
	edit.ParseMode = "Markdown"

	_, err := c.api.Send(edit)
	if err != nil {
		return fmt.Errorf("edit message: %w", err)
	}

	return nil
}

// EditMessageButtons edits message with new buttons
func (c *BotClient) EditMessageButtons(chatID int64, messageID int, text string, buttons [][]InlineButton) error {
	edit := tgbotapi.NewEditMessageText(chatID, messageID, text)
	edit.ParseMode = "Markdown"

	var keyboard [][]tgbotapi.InlineKeyboardButton
	for _, row := range buttons {
		var keyboardRow []tgbotapi.InlineKeyboardButton
		for _, btn := range row {
			keyboardRow = append(keyboardRow, tgbotapi.NewInlineKeyboardButtonData(btn.Text, btn.CallbackData))
		}
		keyboard = append(keyboard, keyboardRow)
	}

	markup := tgbotapi.NewInlineKeyboardMarkup(keyboard...)
	edit.ReplyMarkup = &markup

	_, err := c.api.Send(edit)
	if err != nil {
		return fmt.Errorf("edit message buttons: %w", err)
	}

	return nil
}

// CallbackData represents callback query data for forwarding
type CallbackData struct {
	QueryID   string `json:"query_id"`
	ChatID    int64  `json:"chat_id"`
	UserID    int64  `json:"user_id"`
	Username  string `json:"username"`
	Data      string `json:"data"`
	MessageID int    `json:"message_id"`
}

// MessageData represents incoming message for forwarding to Gleam
type MessageData struct {
	MessageID   int    `json:"message_id"`
	ChatID      int64  `json:"chat_id"`
	UserID      int64  `json:"user_id"`
	Username    string `json:"username"`
	FirstName   string `json:"first_name"`
	LastName    string `json:"last_name"`
	Text        string `json:"text"`
	PhotoFileID string `json:"photo_file_id,omitempty"`
	Caption     string `json:"caption,omitempty"`
}

// UpdateResult holds parsed webhook update - either callback or message
type UpdateResult struct {
	Callback *CallbackData
	Message  *MessageData
}

// HandleWebhook processes incoming webhook updates
// Returns UpdateResult with either callback or message data
func (c *BotClient) HandleWebhook(r *http.Request) (*UpdateResult, error) {
	var update tgbotapi.Update
	if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
		return nil, fmt.Errorf("decode update: %w", err)
	}

	result := &UpdateResult{}

	// Handle callback queries (button presses)
	if update.CallbackQuery != nil {
		cq := update.CallbackQuery
		log.Printf("[BotAPI] Received callback: query_id=%s, data=%s, from=%d", cq.ID, cq.Data, cq.From.ID)

		result.Callback = &CallbackData{
			QueryID:  cq.ID,
			UserID:   cq.From.ID,
			Username: cq.From.UserName,
			Data:     cq.Data,
		}

		if cq.Message != nil {
			result.Callback.ChatID = cq.Message.Chat.ID
			result.Callback.MessageID = cq.Message.MessageID
		}

		return result, nil
	}

	// Handle regular messages (commands, text, photos)
	if update.Message != nil {
		msg := update.Message
		log.Printf("[BotAPI] Received message: id=%d, from=%d, text=%q", msg.MessageID, msg.From.ID, msg.Text)

		result.Message = &MessageData{
			MessageID: msg.MessageID,
			ChatID:    msg.Chat.ID,
			UserID:    msg.From.ID,
			Username:  msg.From.UserName,
			FirstName: msg.From.FirstName,
			LastName:  msg.From.LastName,
			Text:      msg.Text,
		}

		// Handle photo messages
		if msg.Photo != nil && len(msg.Photo) > 0 {
			// Get highest resolution photo
			bestPhoto := msg.Photo[len(msg.Photo)-1]
			result.Message.PhotoFileID = bestPhoto.FileID
			result.Message.Caption = msg.Caption
			log.Printf("[BotAPI] Message has photo: file_id=%s", bestPhoto.FileID)
		}

		return result, nil
	}

	log.Printf("[BotAPI] Ignoring unsupported update type")
	return nil, nil
}

// ForwardCallbackToGleam forwards callback data to Gleam service
// FULL DIAGNOSTIC LOGGING - 2025-12-26
func (c *BotClient) ForwardCallbackToGleam(ctx context.Context, data *CallbackData) error {
	fmt.Fprintf(os.Stderr, "\n--- ForwardCallbackToGleam START ---\n")
	fmt.Fprintf(os.Stderr, "[FWD 1] gleamURL=%q\n", c.gleamURL)
	fmt.Fprintf(os.Stderr, "[FWD 1] apiKey set=%v (len=%d)\n", c.apiKey != "", len(c.apiKey))

	if c.gleamURL == "" {
		fmt.Fprintf(os.Stderr, "[FWD 1] ❌ FAIL: gleamURL is empty!\n")
		return fmt.Errorf("gleam URL not configured")
	}
	fmt.Fprintf(os.Stderr, "[FWD 1] ✅ gleamURL OK\n")

	// Marshal payload
	fmt.Fprintf(os.Stderr, "[FWD 2] Marshaling data: query_id=%s, data=%s\n", data.QueryID, data.Data)
	payload, err := json.Marshal(data)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[FWD 2] ❌ FAIL: marshal error: %v\n", err)
		return fmt.Errorf("marshal callback: %w", err)
	}
	fmt.Fprintf(os.Stderr, "[FWD 2] ✅ Marshaled: %s\n", string(payload))

	// Build URL
	url := c.gleamURL + "/api/v1/bot/callback"
	fmt.Fprintf(os.Stderr, "[FWD 3] Target URL: %s\n", url)

	// Create request
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(payload))
	if err != nil {
		fmt.Fprintf(os.Stderr, "[FWD 3] ❌ FAIL: create request: %v\n", err)
		return fmt.Errorf("create request: %w", err)
	}
	fmt.Fprintf(os.Stderr, "[FWD 3] ✅ Request created\n")

	// Set headers
	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
		fmt.Fprintf(os.Stderr, "[FWD 4] Authorization header set\n")
	} else {
		fmt.Fprintf(os.Stderr, "[FWD 4] ⚠️ No API key, no auth header\n")
	}

	// Send request
	fmt.Fprintf(os.Stderr, "[FWD 5] Sending HTTP request...\n")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[FWD 5] ❌ FAIL: HTTP error: %v\n", err)
		return fmt.Errorf("forward callback: %w", err)
	}
	defer resp.Body.Close()
	fmt.Fprintf(os.Stderr, "[FWD 5] ✅ Got response: status=%d\n", resp.StatusCode)

	// Read response
	body, _ := io.ReadAll(resp.Body)
	fmt.Fprintf(os.Stderr, "[FWD 6] Response body: %s\n", string(body))

	if resp.StatusCode != http.StatusOK {
		fmt.Fprintf(os.Stderr, "[FWD 6] ❌ FAIL: non-200 status\n")
		fmt.Fprintf(os.Stderr, "--- ForwardCallbackToGleam END (ERROR) ---\n\n")
		return fmt.Errorf("gleam returned %d: %s", resp.StatusCode, string(body))
	}

	fmt.Fprintf(os.Stderr, "[FWD 6] ✅ SUCCESS\n")
	fmt.Fprintf(os.Stderr, "--- ForwardCallbackToGleam END (OK) ---\n\n")
	return nil
}

// ForwardMessageToGleam forwards message data to Gleam service
func (c *BotClient) ForwardMessageToGleam(ctx context.Context, data *MessageData) error {
	log.Printf("[BotAPI] ForwardMessageToGleam: chat=%d, user=%d, text=%q", data.ChatID, data.UserID, data.Text)

	if c.gleamURL == "" {
		return fmt.Errorf("gleam URL not configured")
	}

	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("marshal message: %w", err)
	}

	url := c.gleamURL + "/api/v1/bot/message"
	log.Printf("[BotAPI] Forwarding message to: %s", url)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("forward message: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	log.Printf("[BotAPI] Gleam response: status=%d, body=%s", resp.StatusCode, string(body))

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("gleam returned %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

// GetBotUsername returns the bot's username
func (c *BotClient) GetBotUsername() string {
	return c.api.Self.UserName
}

// GetBotID returns the bot's user ID
func (c *BotClient) GetBotID() int64 {
	return c.api.Self.ID
}

// ReplyButton represents a single reply keyboard button
type ReplyButton struct {
	Text string `json:"text"`
}

// ReplyKeyboardMarkup represents a reply keyboard (bottom of screen)
type ReplyKeyboardMarkup struct {
	Keyboard        [][]ReplyButton `json:"keyboard"`
	ResizeKeyboard  bool            `json:"resize_keyboard"`
	OneTimeKeyboard bool            `json:"one_time_keyboard"`
}

// SendWithReplyKeyboard sends a message with reply keyboard (bottom buttons)
func (c *BotClient) SendWithReplyKeyboard(chatID int64, text string, keyboard ReplyKeyboardMarkup) (int, error) {
	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "Markdown"

	// Convert to tgbotapi keyboard format
	var replyKeyboard [][]tgbotapi.KeyboardButton
	for _, row := range keyboard.Keyboard {
		var keyboardRow []tgbotapi.KeyboardButton
		for _, btn := range row {
			keyboardRow = append(keyboardRow, tgbotapi.NewKeyboardButton(btn.Text))
		}
		replyKeyboard = append(replyKeyboard, keyboardRow)
	}

	markup := tgbotapi.NewReplyKeyboard(replyKeyboard...)
	markup.ResizeKeyboard = keyboard.ResizeKeyboard
	markup.OneTimeKeyboard = keyboard.OneTimeKeyboard
	msg.ReplyMarkup = markup

	sent, err := c.api.Send(msg)
	if err != nil {
		return 0, fmt.Errorf("send with reply keyboard: %w", err)
	}

	log.Printf("[BotAPI] Sent message with reply keyboard to %d, msg_id=%d", chatID, sent.MessageID)
	return sent.MessageID, nil
}

// RemoveReplyKeyboard sends a message that removes the reply keyboard
func (c *BotClient) RemoveReplyKeyboard(chatID int64, text string) (int, error) {
	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "Markdown"
	msg.ReplyMarkup = tgbotapi.NewRemoveKeyboard(false)

	sent, err := c.api.Send(msg)
	if err != nil {
		return 0, fmt.Errorf("remove reply keyboard: %w", err)
	}

	log.Printf("[BotAPI] Sent message with keyboard removed to %d, msg_id=%d", chatID, sent.MessageID)
	return sent.MessageID, nil
}
