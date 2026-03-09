package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/gotd/td/session"
	"github.com/vibee/telegram-bridge/internal/botapi"
	"github.com/vibee/telegram-bridge/internal/config"
	"github.com/vibee/telegram-bridge/internal/mcpswarm"
	"github.com/vibee/telegram-bridge/internal/telegram"
)

// Router handles HTTP requests
type Router struct {
	cfg       *config.Config
	mux       *http.ServeMux
	db        *sql.DB
	clients   map[string]*telegram.Client
	botClient *botapi.BotClient
	upgrader  websocket.Upgrader
	wsHub     *WSHub
	mu        sync.RWMutex
	// Swarm MCP proxy and command handler
	swarmProxy *mcpswarm.Proxy
	swarmCmdH  *mcpswarm.CommandHandler
}

// NewRouter creates a new HTTP router
func NewRouter(cfg *config.Config, db *sql.DB) *Router {
	r := &Router{
		cfg:     cfg,
		mux:     http.NewServeMux(),
		db:      db,
		clients: make(map[string]*telegram.Client),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				origin := r.Header.Get("Origin")
				return cfg.IsOriginAllowed(origin)
			},
		},
		wsHub: NewWSHub(),
	}

	// Initialize Bot API client if token is configured
	log.Printf("[INIT] BotToken set: %v (len=%d)", cfg.BotToken != "", len(cfg.BotToken))
	log.Printf("[INIT] BotWebhookURL: %s", cfg.BotWebhookURL)
	log.Printf("[INIT] GleamURL: %s", cfg.GleamURL)

	if cfg.BotToken != "" {
		log.Printf("[INIT] Creating Bot API client...")
		botCfg := botapi.Config{
			Token:      cfg.BotToken,
			WebhookURL: cfg.BotWebhookURL,
			GleamURL:   cfg.GleamURL,
			ApiKey:     cfg.ApiKey,
		}
		botClient, err := botapi.NewBotClient(botCfg)
		if err != nil {
			log.Printf("⚠️ [INIT] Failed to create Bot API client: %v", err)
		} else {
			r.botClient = botClient
			log.Printf("✅ [INIT] Bot API client initialized: @%s", botClient.GetBotUsername())

			// Set webhook if URL is configured
			if cfg.BotWebhookURL != "" {
				log.Printf("[INIT] Setting webhook to: %s", cfg.BotWebhookURL)
				if err := botClient.SetWebhook(cfg.BotWebhookURL); err != nil {
					log.Printf("⚠️ [INIT] Failed to set webhook: %v", err)
				} else {
					log.Printf("✅ [INIT] Webhook set successfully")
				}
			}
		}
	} else {
		log.Println("ℹ️ [INIT] TELEGRAM_BOT_TOKEN not set, Bot API disabled")
	}

	// Initialize swarm MCP proxy (connects to Zig trinity-mcp server)
	mcpBinary := os.Getenv("TRINITY_MCP_BINARY")
	swarmProxy, err := mcpswarm.NewProxy(mcpBinary)
	if err != nil {
		log.Printf("⚠️ [INIT] Swarm MCP proxy failed: %v (swarm commands disabled)", err)
	} else {
		r.swarmProxy = swarmProxy
		r.swarmCmdH = mcpswarm.NewCommandHandler(swarmProxy)
		log.Println("[INIT] Swarm MCP proxy initialized")
	}

	// Start WebSocket hub
	go r.wsHub.Run()

	// Setup routes first so server can start immediately
	r.setupRoutes()

	// Restore sessions in background (don't block server startup)
	go r.restoreSessions()

	return r
}

// restoreSessions loads existing session files and reconnects to Telegram
func (r *Router) restoreSessions() {
	if r.cfg.AppID == 0 || r.cfg.AppHash == "" {
		log.Println("⚠️ TELEGRAM_APP_ID or TELEGRAM_APP_HASH not set, skipping session restoration")
		return
	}

	// Read session directory
	entries, err := os.ReadDir(r.cfg.SessionDir)
	if err != nil {
		log.Printf("⚠️ Failed to read session directory %s: %v", r.cfg.SessionDir, err)
		return
	}

	restored := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		name := entry.Name()
		if !strings.HasSuffix(name, ".session") {
			continue
		}

		// Extract session ID from filename (e.g., "sess_xxx.session" -> "sess_xxx")
		sessionID := strings.TrimSuffix(name, ".session")
		sessionPath := r.cfg.SessionDir + "/" + name

		log.Printf("🔄 Restoring session: %s", sessionID)

		// Create session storage - use gotd's FileStorage directly
		sessionStorage := &session.FileStorage{Path: sessionPath}

		// Create Telegram client
		client, err := telegram.NewClient(r.cfg.AppID, r.cfg.AppHash, sessionStorage)
		if err != nil {
			log.Printf("❌ Failed to create client for session %s: %v", sessionID, err)
			continue
		}

		// Connect to Telegram - use background context for long-running connection
		// Only timeout the initial connection establishment, not the ongoing connection
		ctx := context.Background()
		if err := client.Connect(ctx); err != nil {
			log.Printf("❌ Failed to connect session %s: %v", sessionID, err)
			continue
		}
		// Note: do NOT cancel the context - it keeps the MTProto connection alive

		// Store client
		r.mu.Lock()
		r.clients[sessionID] = client
		r.mu.Unlock()

		// Start forwarding updates
		go r.forwardUpdates(sessionID, client)

		if client.IsAuthorized() {
			log.Printf("✅ Restored session %s (authorized)", sessionID)
		} else {
			log.Printf("⚠️ Restored session %s (not authorized)", sessionID)
		}
		restored++
	}

	log.Printf("📊 Session restoration complete: %d sessions restored", restored)
}

func (r *Router) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	// Check and set CORS headers based on allowed origins
	origin := req.Header.Get("Origin")
	if r.cfg.IsOriginAllowed(origin) {
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Access-Control-Allow-Credentials", "true")
	}
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Session-ID")

	if req.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	r.mux.ServeHTTP(w, req)
}

func (r *Router) setupRoutes() {
	// Health check
	r.mux.HandleFunc("/health", r.handleHealth)

	// API v1 routes
	r.mux.HandleFunc("/api/v1/connect", r.handleConnect)
	r.mux.HandleFunc("/api/v1/auth/status", r.handleAuthStatus)
	r.mux.HandleFunc("/api/v1/auth/phone", r.handleAuthPhone)
	r.mux.HandleFunc("/api/v1/auth/code", r.handleAuthCode)
	r.mux.HandleFunc("/api/v1/auth/2fa", r.handleAuth2FA)
	r.mux.HandleFunc("/api/v1/me", r.handleGetMe)
	r.mux.HandleFunc("/api/v1/dialogs", r.handleGetDialogs)
	r.mux.HandleFunc("/api/v1/history/", r.handleGetHistory)
	r.mux.HandleFunc("/api/v1/send", r.handleSendMessage)
	r.mux.HandleFunc("/api/v1/send/photo", r.handleSendPhoto)
	r.mux.HandleFunc("/api/v1/resolve", r.handleResolveUsername)

	// Media endpoints
	r.mux.HandleFunc("/api/v1/download", r.handleDownloadMedia)
	r.mux.HandleFunc("/api/v1/media/", r.handleGetMediaInfo)

	// User profile photo endpoints
	r.mux.HandleFunc("/api/v1/user/photos/", r.handleGetUserPhotos)
	r.mux.HandleFunc("/api/v1/user/photo/download/", r.handleDownloadUserPhoto)

	// Callback endpoint (for clicking inline buttons)
	r.mux.HandleFunc("/api/v1/callback", r.handleCallback)

	// Bot API endpoints (for inline buttons with real callbacks)
	r.mux.HandleFunc("/api/v1/bot/send-buttons", r.handleBotSendButtons)
	r.mux.HandleFunc("/api/v1/bot/send-message", r.handleBotSendMessage)
	r.mux.HandleFunc("/api/v1/bot/webhook", r.handleBotWebhook)
	r.mux.HandleFunc("/api/v1/bot/answer", r.handleBotAnswer)
	r.mux.HandleFunc("/api/v1/bot/status", r.handleBotStatus)
	r.mux.HandleFunc("/api/v1/bot/webhook-info", r.handleBotWebhookInfo)
	r.mux.HandleFunc("/api/v1/bot/webhook-debug", r.handleBotWebhookDebug)
	r.mux.HandleFunc("/api/v1/bot/webhook-setup", r.handleBotWebhookSetup)

	// WebSocket for updates
	r.mux.HandleFunc("/api/v1/updates", r.handleWebSocket)

	// Swarm API endpoints (proxied to Zig MCP server)
	if r.swarmProxy != nil {
		swarmAPI := mcpswarm.NewAPIHandler(r.swarmProxy)
		swarmAPI.RegisterRoutes(r.mux)
	}
}

// Response helpers
func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		log.Printf("Error encoding JSON: %v", err)
	}
}

func respondError(w http.ResponseWriter, status int, message string) {
	respondJSON(w, status, map[string]string{"error": message})
}

// truncate cuts a string to max length for logging
func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}

// getSessionID extracts session ID from X-Session-ID header (preferred) or query parameter (deprecated)
// SECURITY: Using header is more secure as it's not logged in access logs or browser history
func getSessionID(req *http.Request) string {
	// Prefer header (secure)
	sessionID := req.Header.Get("X-Session-ID")
	if sessionID != "" {
		return sessionID
	}
	// Fallback to query parameter (deprecated, for backwards compatibility)
	return req.URL.Query().Get("session_id")
}

// Handlers

func (r *Router) handleHealth(w http.ResponseWriter, req *http.Request) {
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "ok",
		"service": "telegram-bridge",
		"version": "0.1.0",
	})
}

func (r *Router) handleAuthStatus(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")

	// If no session provided, return list of active sessions
	if sessionID == "" {
		r.mu.RLock()
		sessions := make([]map[string]interface{}, 0, len(r.clients))
		for id, client := range r.clients {
			sessions = append(sessions, map[string]interface{}{
				"session_id": id,
				"authorized": client.IsAuthorized(),
			})
		}
		r.mu.RUnlock()

		respondJSON(w, http.StatusOK, map[string]interface{}{
			"status":        "ok",
			"sessions":      sessions,
			"total_sessions": len(sessions),
		})
		return
	}

	// Check specific session
	client := r.getClient(sessionID)
	if client == nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"status":     "not_found",
			"session_id": sessionID,
			"authorized": false,
			"message":    "Session not found. Use /api/v1/connect to create a new session.",
		})
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":     "ok",
		"session_id": sessionID,
		"authorized": client.IsAuthorized(),
	})
}

// ConnectRequest is the request body for /connect
type ConnectRequest struct {
	AppID   int    `json:"app_id"`
	AppHash string `json:"app_hash"`
	Phone   string `json:"phone,omitempty"`
}

func (r *Router) handleConnect(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var body ConnectRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid JSON body")
		return
	}

	if body.AppID == 0 || body.AppHash == "" {
		respondError(w, http.StatusBadRequest, "app_id and app_hash are required")
		return
	}

	// Generate session ID
	sessionID := generateSessionID()

	// Create session storage - use gotd's FileStorage directly for proper persistence
	sessionStorage := &session.FileStorage{Path: r.cfg.SessionDir + "/" + sessionID + ".session"}

	// Create Telegram client
	client, err := telegram.NewClient(body.AppID, body.AppHash, sessionStorage)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to create client: "+err.Error())
		return
	}

	// Connect to Telegram - use Background context so connection persists after handler returns
	// The connection goroutine needs to stay alive for subsequent API calls
	if err := client.Connect(context.Background()); err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to connect: "+err.Error())
		return
	}

	// Store client
	r.mu.Lock()
	r.clients[sessionID] = client
	r.mu.Unlock()

	// Start forwarding updates to WebSocket
	go r.forwardUpdates(sessionID, client)

	log.Printf("Connect request: app_id=%d, session=%s", body.AppID, sessionID)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":      "connected",
		"session_id":  sessionID,
		"authorized":  client.IsAuthorized(),
		"message":     "Connection established. Use /auth/phone to start authentication if not authorized.",
	})
}

// AuthPhoneRequest is the request for /auth/phone
type AuthPhoneRequest struct {
	SessionID string `json:"session_id,omitempty"`
	Phone     string `json:"phone"`
}

func (r *Router) handleAuthPhone(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var body AuthPhoneRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid JSON body")
		return
	}

	// Get session ID from header (preferred) or body (fallback)
	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		sessionID = body.SessionID
	}

	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	if body.Phone == "" {
		respondError(w, http.StatusBadRequest, "phone is required")
		return
	}

	log.Printf("Sending code to phone: %s", body.Phone)

	// Retry logic for DC migration - Telegram may require reconnection to different data center
	var codeHash string
	var err error
	maxRetries := 2
	for attempt := 1; attempt <= maxRetries; attempt++ {
		// Use longer timeout per attempt to allow DC migration to complete
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)

		codeHash, err = client.SendCode(ctx, body.Phone)
		cancel()

		if err == nil {
			break
		}

		log.Printf("SendCode attempt %d/%d error for phone %s: %v", attempt, maxRetries, body.Phone, err)

		// Check if it's a DC migration error - if so, wait and retry
		if strings.Contains(err.Error(), "migrate") && attempt < maxRetries {
			log.Printf("DC migration detected, waiting 5 seconds before retry...")
			time.Sleep(5 * time.Second)
			continue
		}

		// For other errors, don't retry
		break
	}

	if err != nil {
		log.Printf("SendCode final error for phone %s: %v", body.Phone, err)
		respondError(w, http.StatusInternalServerError, "Failed to send code: "+err.Error())
		return
	}

	log.Printf("Auth phone request success: phone=%s", body.Phone)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":    "code_sent",
		"code_hash": codeHash,
		"message":   "Verification code sent to phone",
	})
}

// AuthCodeRequest is the request for /auth/code
type AuthCodeRequest struct {
	SessionID string `json:"session_id,omitempty"`
	Code      string `json:"code"`
}

func (r *Router) handleAuthCode(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var body AuthCodeRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid JSON body")
		return
	}

	// Get session ID from header (preferred) or body (fallback)
	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		sessionID = body.SessionID
	}

	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	if body.Code == "" {
		respondError(w, http.StatusBadRequest, "code is required")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	user, err := client.SignIn(ctx, body.Code)
	if err != nil {
		// Check if 2FA required
		if strings.Contains(err.Error(), "SESSION_PASSWORD_NEEDED") {
			respondJSON(w, http.StatusOK, map[string]interface{}{
				"status":  "2fa_required",
				"message": "Two-factor authentication required",
			})
			return
		}
		respondError(w, http.StatusUnauthorized, "Failed to sign in: "+err.Error())
		return
	}

	log.Printf("Auth code request: user=%s", user.Username)

	// Explicitly save session to disk
	if err := client.SaveSession(); err != nil {
		log.Printf("⚠️ Failed to save session after SignIn: %v", err)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "authenticated",
		"message": "Successfully authenticated",
		"user":    user,
	})
}

// Auth2FARequest is the request for /auth/2fa
type Auth2FARequest struct {
	SessionID string `json:"session_id,omitempty"`
	Password  string `json:"password"`
}

func (r *Router) handleAuth2FA(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var body Auth2FARequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid JSON body")
		return
	}

	// Get session ID from header (preferred) or body (fallback)
	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		sessionID = body.SessionID
	}

	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	if body.Password == "" {
		respondError(w, http.StatusBadRequest, "password is required")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	user, err := client.Check2FA(ctx, body.Password)
	if err != nil {
		respondError(w, http.StatusUnauthorized, "2FA verification failed: "+err.Error())
		return
	}

	log.Printf("Auth 2FA request: user=%s", user.Username)

	// Explicitly save session to disk
	if err := client.SaveSession(); err != nil {
		log.Printf("⚠️ Failed to save session after 2FA: %v", err)
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "authenticated",
		"message": "2FA verification successful",
		"user":    user,
	})
}

func (r *Router) handleGetMe(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	user, err := client.GetMe(ctx)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get user: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, user)
}

func (r *Router) handleGetDialogs(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	limit := 100
	if l := req.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	dialogs, err := client.GetDialogs(ctx, limit)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get dialogs: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"dialogs": dialogs,
	})
}

func (r *Router) handleGetHistory(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	// Extract chat ID from path: /api/v1/history/{chat_id}
	path := strings.TrimPrefix(req.URL.Path, "/api/v1/history/")
	chatID, err := strconv.ParseInt(path, 10, 64)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid chat_id")
		return
	}

	limit := 100
	if l := req.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	offsetID := 0
	if o := req.URL.Query().Get("offset_id"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed > 0 {
			offsetID = parsed
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	messages, err := client.GetHistoryWithOffset(ctx, chatID, limit, offsetID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get history: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"messages": messages,
	})
}

// SendMessageRequest is the request for /send
type SendMessageRequest struct {
	ChatID  int64  `json:"chat_id"`
	Text    string `json:"text"`
	ReplyTo int    `json:"reply_to,omitempty"`
}

func (r *Router) handleSendMessage(w http.ResponseWriter, req *http.Request) {
	log.Printf("[handleSendMessage] ═══════════════════════════════════════")
	log.Printf("[handleSendMessage] Method: %s", req.Method)

	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	log.Printf("[handleSendMessage] Session-ID: %s", sessionID)

	client := r.getClient(sessionID)
	if client == nil {
		log.Printf("[handleSendMessage] ❌ Invalid session: %s", sessionID)
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}
	log.Printf("[handleSendMessage] ✅ Client found for session")

	var body SendMessageRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		log.Printf("[handleSendMessage] ❌ JSON decode error: %v", err)
		respondError(w, http.StatusBadRequest, "Invalid JSON body")
		return
	}

	log.Printf("[handleSendMessage] 📩 chat_id=%d", body.ChatID)
	log.Printf("[handleSendMessage] 📝 text=%s...", truncate(body.Text, 50))
	log.Printf("[handleSendMessage] 📌 reply_to=%d", body.ReplyTo)

	if body.ChatID == 0 || body.Text == "" {
		log.Printf("[handleSendMessage] ❌ Missing chat_id or text")
		respondError(w, http.StatusBadRequest, "chat_id and text are required")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	log.Printf("[handleSendMessage] 🚀 Calling client.SendMessage...")
	messageID, err := client.SendMessage(ctx, body.ChatID, body.Text, body.ReplyTo)
	if err != nil {
		log.Printf("[handleSendMessage] ❌ SendMessage error: %v", err)
		respondError(w, http.StatusInternalServerError, "Failed to send message: "+err.Error())
		return
	}

	log.Printf("[handleSendMessage] ✅ Message sent: chat_id=%d, message_id=%d", body.ChatID, messageID)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"success":    true,
		"message_id": messageID,
	})
}

// SendPhotoRequest is the request for /send/photo
type SendPhotoRequest struct {
	ChatID   int64  `json:"chat_id"`
	PhotoURL string `json:"photo_url"`
	Caption  string `json:"caption,omitempty"`
}

func (r *Router) handleSendPhoto(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	var body SendPhotoRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid JSON body")
		return
	}

	if body.ChatID == 0 || body.PhotoURL == "" {
		respondError(w, http.StatusBadRequest, "chat_id and photo_url are required")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	messageID, err := client.SendPhoto(ctx, body.ChatID, body.PhotoURL, body.Caption)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to send photo: "+err.Error())
		return
	}

	log.Printf("Send photo: chat_id=%d, message_id=%d, url=%s", body.ChatID, messageID, body.PhotoURL[:min(50, len(body.PhotoURL))])

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"success":    true,
		"message_id": messageID,
	})
}

// handleResolveUsername resolves a username to a peer ID
func (r *Router) handleResolveUsername(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid or missing session")
		return
	}

	username := req.URL.Query().Get("username")
	if username == "" {
		respondError(w, http.StatusBadRequest, "username parameter required")
		return
	}

	// Remove @ prefix if present
	username = strings.TrimPrefix(username, "@")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	result, err := client.ResolveUsername(ctx, username)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to resolve username: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, result)
}

// WebSocket handler
func (r *Router) handleWebSocket(w http.ResponseWriter, req *http.Request) {
	sessionID := getSessionID(req)
	if sessionID == "" {
		respondError(w, http.StatusBadRequest, "X-Session-ID header required (or session_id query param)")
		return
	}

	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusUnauthorized, "Invalid session")
		return
	}

	conn, err := r.upgrader.Upgrade(w, req, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	wsClient := &WSClient{
		hub:       r.wsHub,
		conn:      conn,
		send:      make(chan []byte, 256),
		sessionID: sessionID,
	}

	r.wsHub.register <- wsClient

	go wsClient.writePump()
	go wsClient.readPump()
}

// Helper methods

func (r *Router) getClient(sessionID string) *telegram.Client {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.clients[sessionID]
}

func (r *Router) forwardUpdates(sessionID string, client *telegram.Client) {
	for update := range client.Updates() {
		data, err := json.Marshal(update)
		if err != nil {
			continue
		}
		r.wsHub.broadcast <- WSMessage{
			SessionID: sessionID,
			Data:      data,
		}
	}
}

func generateSessionID() string {
	// Simple session ID generation
	return "sess_" + strconv.FormatInt(time.Now().UnixNano(), 36)
}

// handleDownloadMedia downloads media from a message
// POST /api/v1/download
// Body: {"chat_id": 123, "message_id": 456}
func (r *Router) handleDownloadMedia(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		respondError(w, http.StatusBadRequest, "X-Session-ID header required")
		return
	}

	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusNotFound, "session not found")
		return
	}

	var body struct {
		ChatID    int64 `json:"chat_id"`
		MessageID int   `json:"message_id"`
	}

	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if body.ChatID == 0 || body.MessageID == 0 {
		respondError(w, http.StatusBadRequest, "chat_id and message_id required")
		return
	}

	ctx, cancel := context.WithTimeout(req.Context(), 2*time.Minute)
	defer cancel()

	result, err := client.DownloadMedia(ctx, body.ChatID, body.MessageID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "download error: "+err.Error())
		return
	}

	if !result.Success {
		respondError(w, http.StatusBadRequest, result.Error)
		return
	}

	respondJSON(w, http.StatusOK, result)
}

// handleGetMediaInfo gets media info for a specific message
// GET /api/v1/media/{chat_id}/{message_id}
func (r *Router) handleGetMediaInfo(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		respondError(w, http.StatusBadRequest, "X-Session-ID header required")
		return
	}

	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusNotFound, "session not found")
		return
	}

	// Parse path: /api/v1/media/{chat_id}/{message_id}
	path := strings.TrimPrefix(req.URL.Path, "/api/v1/media/")
	parts := strings.Split(path, "/")
	if len(parts) != 2 {
		respondError(w, http.StatusBadRequest, "path must be /api/v1/media/{chat_id}/{message_id}")
		return
	}

	chatID, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid chat_id")
		return
	}

	messageID, err := strconv.Atoi(parts[1])
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid message_id")
		return
	}

	ctx, cancel := context.WithTimeout(req.Context(), 30*time.Second)
	defer cancel()

	msg, err := client.GetMessageWithMedia(ctx, chatID, messageID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "get message error: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, msg)
}

// CallbackRequest is the request for /callback
type CallbackRequest struct {
	ChatID       int64  `json:"chat_id"`
	MsgID        int    `json:"msg_id"`
	CallbackData string `json:"data"`
}

// handleCallback clicks an inline keyboard button
// POST /api/v1/callback
// Body: {"chat_id": 123, "msg_id": 456, "data": "t2v:kling"}
func (r *Router) handleCallback(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		respondError(w, http.StatusBadRequest, "X-Session-ID header required")
		return
	}

	client := r.getClient(sessionID)
	if client == nil {
		respondError(w, http.StatusNotFound, "session not found")
		return
	}

	var body CallbackRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if body.ChatID == 0 || body.MsgID == 0 || body.CallbackData == "" {
		respondError(w, http.StatusBadRequest, "chat_id, msg_id, and data are required")
		return
	}

	log.Printf("[handleCallback] chat_id=%d, msg_id=%d, data=%s", body.ChatID, body.MsgID, body.CallbackData)

	ctx, cancel := context.WithTimeout(req.Context(), 30*time.Second)
	defer cancel()

	message, err := client.ClickButton(ctx, body.ChatID, body.MsgID, body.CallbackData)
	if err != nil {
		log.Printf("[handleCallback] error: %v", err)
		respondError(w, http.StatusInternalServerError, "callback error: "+err.Error())
		return
	}

	log.Printf("[handleCallback] success, message: %s", message)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": message,
	})
}

// ============================================================================
// Bot API Handlers (for inline keyboard callbacks)
// ============================================================================

// BotSendButtonsRequest is the request for /bot/send-buttons
type BotSendButtonsRequest struct {
	ChatID  int64                     `json:"chat_id"`
	Text    string                    `json:"text"`
	Buttons [][]botapi.InlineButton   `json:"buttons"`
}

// handleBotSendButtons sends a message with inline keyboard via Bot API
// POST /api/v1/bot/send-buttons
func (r *Router) handleBotSendButtons(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	if r.botClient == nil {
		respondError(w, http.StatusServiceUnavailable, "Bot API not configured")
		return
	}

	var body BotSendButtonsRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if body.ChatID == 0 || body.Text == "" || len(body.Buttons) == 0 {
		respondError(w, http.StatusBadRequest, "chat_id, text, and buttons are required")
		return
	}

	log.Printf("[BotAPI] Sending buttons to chat %d: %s", body.ChatID, truncate(body.Text, 50))

	messageID, err := r.botClient.SendWithButtons(body.ChatID, body.Text, body.Buttons)
	if err != nil {
		log.Printf("[BotAPI] SendWithButtons error: %v", err)
		respondError(w, http.StatusInternalServerError, "failed to send: "+err.Error())
		return
	}

	log.Printf("[BotAPI] Message sent: chat_id=%d, message_id=%d", body.ChatID, messageID)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"success":    true,
		"message_id": messageID,
	})
}

// BotSendMessageRequest is the request for /bot/send-message
type BotSendMessageRequest struct {
	ChatID      int64                       `json:"chat_id"`
	Text        string                      `json:"text"`
	ReplyMarkup *BotReplyMarkup             `json:"reply_markup,omitempty"`
}

// BotReplyMarkup can be either reply keyboard or remove keyboard
type BotReplyMarkup struct {
	Keyboard        [][]BotReplyButton `json:"keyboard,omitempty"`
	ResizeKeyboard  bool               `json:"resize_keyboard,omitempty"`
	OneTimeKeyboard bool               `json:"one_time_keyboard,omitempty"`
	RemoveKeyboard  bool               `json:"remove_keyboard,omitempty"`
}

// BotReplyButton represents a reply keyboard button
type BotReplyButton struct {
	Text string `json:"text"`
}

// handleBotSendMessage sends a message with optional reply keyboard via Bot API
// POST /api/v1/bot/send-message
func (r *Router) handleBotSendMessage(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	if r.botClient == nil {
		respondError(w, http.StatusServiceUnavailable, "Bot API not configured")
		return
	}

	var body BotSendMessageRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		respondError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if body.ChatID == 0 || body.Text == "" {
		respondError(w, http.StatusBadRequest, "chat_id and text are required")
		return
	}

	log.Printf("[BotAPI] SendMessage to chat %d: %s", body.ChatID, truncate(body.Text, 50))

	var messageID int
	var err error

	// Check if we need to send with reply keyboard
	if body.ReplyMarkup != nil {
		if body.ReplyMarkup.RemoveKeyboard {
			// Remove keyboard
			messageID, err = r.botClient.RemoveReplyKeyboard(body.ChatID, body.Text)
		} else if len(body.ReplyMarkup.Keyboard) > 0 {
			// Send with reply keyboard
			keyboard := botapi.ReplyKeyboardMarkup{
				ResizeKeyboard:  body.ReplyMarkup.ResizeKeyboard,
				OneTimeKeyboard: body.ReplyMarkup.OneTimeKeyboard,
			}
			for _, row := range body.ReplyMarkup.Keyboard {
				var keyboardRow []botapi.ReplyButton
				for _, btn := range row {
					keyboardRow = append(keyboardRow, botapi.ReplyButton{Text: btn.Text})
				}
				keyboard.Keyboard = append(keyboard.Keyboard, keyboardRow)
			}
			messageID, err = r.botClient.SendWithReplyKeyboard(body.ChatID, body.Text, keyboard)
		} else {
			// Plain message
			messageID, err = r.botClient.SendMessage(body.ChatID, body.Text)
		}
	} else {
		// Plain message
		messageID, err = r.botClient.SendMessage(body.ChatID, body.Text)
	}

	if err != nil {
		log.Printf("[BotAPI] SendMessage error: %v", err)
		respondError(w, http.StatusInternalServerError, "failed to send: "+err.Error())
		return
	}

	log.Printf("[BotAPI] Message sent: chat_id=%d, message_id=%d", body.ChatID, messageID)

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"success":    true,
		"message_id": messageID,
	})
}

// lastWebhookDebug stores debug info about last webhook call
var lastWebhookDebug struct {
	Time       string `json:"time"`
	Method     string `json:"method"`
	RemoteAddr string `json:"remote_addr"`
	Error      string `json:"error,omitempty"`
	CallbackID string `json:"callback_id,omitempty"`
	Data       string `json:"data,omitempty"`
}
var webhookDebugMu sync.Mutex

// handleBotWebhook receives callback queries from Telegram
// POST /api/v1/bot/webhook
// Updated: 2025-12-26 - FULL DIAGNOSTIC LOGGING
func (r *Router) handleBotWebhook(w http.ResponseWriter, req *http.Request) {
	startTime := time.Now()

	// STEP 1: Log entry
	fmt.Fprintf(os.Stderr, "\n\n========== WEBHOOK START ==========\n")
	fmt.Fprintf(os.Stderr, "[STEP 1] WEBHOOK HIT: method=%s, path=%s, remote=%s, time=%s\n",
		req.Method, req.URL.Path, req.RemoteAddr, startTime.Format(time.RFC3339))

	// Store debug info
	webhookDebugMu.Lock()
	lastWebhookDebug.Time = startTime.Format(time.RFC3339)
	lastWebhookDebug.Method = req.Method
	lastWebhookDebug.RemoteAddr = req.RemoteAddr
	lastWebhookDebug.Error = "processing..."
	lastWebhookDebug.CallbackID = ""
	lastWebhookDebug.Data = ""
	webhookDebugMu.Unlock()

	// STEP 2: Method check
	fmt.Fprintf(os.Stderr, "[STEP 2] Checking method: %s\n", req.Method)
	if req.Method != http.MethodPost {
		webhookDebugMu.Lock()
		lastWebhookDebug.Error = "wrong method: " + req.Method
		webhookDebugMu.Unlock()
		fmt.Fprintf(os.Stderr, "[STEP 2] ❌ FAILED: wrong method\n")
		respondError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	fmt.Fprintf(os.Stderr, "[STEP 2] ✅ Method OK\n")

	// STEP 3: Bot client check
	fmt.Fprintf(os.Stderr, "[STEP 3] Checking botClient: %v\n", r.botClient != nil)
	if r.botClient == nil {
		webhookDebugMu.Lock()
		lastWebhookDebug.Error = "botClient is nil"
		webhookDebugMu.Unlock()
		fmt.Fprintf(os.Stderr, "[STEP 3] ❌ FAILED: botClient is nil\n")
		respondError(w, http.StatusServiceUnavailable, "Bot API not configured")
		return
	}
	fmt.Fprintf(os.Stderr, "[STEP 3] ✅ botClient OK\n")

	// STEP 4: Parse webhook
	fmt.Fprintf(os.Stderr, "[STEP 4] Parsing webhook body...\n")
	updateResult, err := r.botClient.HandleWebhook(req)
	if err != nil {
		webhookDebugMu.Lock()
		lastWebhookDebug.Error = "parse error: " + err.Error()
		webhookDebugMu.Unlock()
		fmt.Fprintf(os.Stderr, "[STEP 4] ❌ FAILED: %v\n", err)
		respondError(w, http.StatusBadRequest, "webhook error: "+err.Error())
		return
	}

	// STEP 5: Check what type of update we got
	if updateResult == nil {
		webhookDebugMu.Lock()
		lastWebhookDebug.Error = "unsupported update type"
		webhookDebugMu.Unlock()
		fmt.Fprintf(os.Stderr, "[STEP 5] ⚠️ Unsupported update type, ignoring\n")
		respondJSON(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}

	// STEP 5a: Handle callback query (button press)
	if updateResult.Callback != nil {
		callbackData := updateResult.Callback
		fmt.Fprintf(os.Stderr, "[STEP 5] ✅ Callback: query_id=%s, data=%s, user=%d, chat=%d\n",
			callbackData.QueryID, callbackData.Data, callbackData.UserID, callbackData.ChatID)

		webhookDebugMu.Lock()
		lastWebhookDebug.CallbackID = callbackData.QueryID
		lastWebhookDebug.Data = callbackData.Data
		lastWebhookDebug.Error = "forwarding callback to gleam..."
		webhookDebugMu.Unlock()

		// Answer callback IMMEDIATELY
		fmt.Fprintf(os.Stderr, "[STEP 6] Answering callback immediately...\n")
		if err := r.botClient.AnswerCallback(callbackData.QueryID, "⏳", false); err != nil {
			fmt.Fprintf(os.Stderr, "[STEP 6] ⚠️ AnswerCallback failed: %v\n", err)
		} else {
			fmt.Fprintf(os.Stderr, "[STEP 6] ✅ Callback answered\n")
		}

		// Forward to Gleam asynchronously
		go func() {
			var forwardErr error
			for attempt := 1; attempt <= 3; attempt++ {
				ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
				forwardErr = r.botClient.ForwardCallbackToGleam(ctx, callbackData)
				cancel()

				if forwardErr == nil {
					fmt.Fprintf(os.Stderr, "[CALLBACK FWD] ✅ Forward succeeded on attempt %d\n", attempt)
					break
				}
				fmt.Fprintf(os.Stderr, "[CALLBACK FWD] ⚠️ Attempt %d failed: %v\n", attempt, forwardErr)
				if attempt < 3 {
					time.Sleep(time.Duration(attempt) * time.Second)
				}
			}

			webhookDebugMu.Lock()
			if forwardErr != nil {
				lastWebhookDebug.Error = "CALLBACK FORWARD ERROR: " + forwardErr.Error()
			} else {
				lastWebhookDebug.Error = "SUCCESS: callback forwarded"
			}
			webhookDebugMu.Unlock()
		}()

		elapsed := time.Since(startTime)
		fmt.Fprintf(os.Stderr, "[STEP 8] Responding OK (callback), elapsed=%v\n", elapsed)
		respondJSON(w, http.StatusOK, callbackData)
		return
	}

	// STEP 5b: Handle regular message (commands, text, photos)
	if updateResult.Message != nil {
		msgData := updateResult.Message
		fmt.Fprintf(os.Stderr, "[STEP 5] ✅ Message: id=%d, user=%d, chat=%d, text=%q\n",
			msgData.MessageID, msgData.UserID, msgData.ChatID, msgData.Text)

		// SWARM: Intercept /commands before forwarding to Gleam
		if mcpswarm.IsCommand(msgData.Text) && r.swarmCmdH != nil {
			reply := r.swarmCmdH.HandleCommand(msgData.Text, msgData.ChatID)
			if reply != "" {
				fmt.Fprintf(os.Stderr, "[SWARM] Command handled: %s\n", msgData.Text)
				// Send reply with ReplyKeyboardMarkup (bottom buttons)
				if r.botClient != nil {
					kb := mcpswarm.ReplyKeyboard()
					var buttons [][]botapi.ReplyButton
					for _, row := range kb {
						var btnRow []botapi.ReplyButton
						for _, text := range row {
							btnRow = append(btnRow, botapi.ReplyButton{Text: text})
						}
						buttons = append(buttons, btnRow)
					}
					markup := botapi.ReplyKeyboardMarkup{
						Keyboard:       buttons,
						ResizeKeyboard: true,
					}
					go r.botClient.SendWithReplyKeyboard(msgData.ChatID, reply, markup)
				}
				respondJSON(w, http.StatusOK, map[string]string{"status": "swarm_command"})
				return
			}
		}

		webhookDebugMu.Lock()
		lastWebhookDebug.Data = msgData.Text
		lastWebhookDebug.Error = "forwarding message to gleam..."
		webhookDebugMu.Unlock()

		// Forward message to Gleam asynchronously
		go func() {
			var forwardErr error
			for attempt := 1; attempt <= 3; attempt++ {
				ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
				forwardErr = r.botClient.ForwardMessageToGleam(ctx, msgData)
				cancel()

				if forwardErr == nil {
					fmt.Fprintf(os.Stderr, "[MESSAGE FWD] ✅ Forward succeeded on attempt %d\n", attempt)
					break
				}
				fmt.Fprintf(os.Stderr, "[MESSAGE FWD] ⚠️ Attempt %d failed: %v\n", attempt, forwardErr)
				if attempt < 3 {
					time.Sleep(time.Duration(attempt) * time.Second)
				}
			}

			webhookDebugMu.Lock()
			if forwardErr != nil {
				lastWebhookDebug.Error = "MESSAGE FORWARD ERROR: " + forwardErr.Error()
				fmt.Fprintf(os.Stderr, "[MESSAGE FWD] ❌ FORWARD FAILED: %v\n", forwardErr)
			} else {
				lastWebhookDebug.Error = "SUCCESS: message forwarded"
				fmt.Fprintf(os.Stderr, "[MESSAGE FWD] ✅ FORWARD SUCCESS\n")
			}
			webhookDebugMu.Unlock()
		}()

		elapsed := time.Since(startTime)
		fmt.Fprintf(os.Stderr, "[STEP 8] Responding OK (message), elapsed=%v\n", elapsed)
		respondJSON(w, http.StatusOK, msgData)
		return
	}

	// Shouldn't reach here
	fmt.Fprintf(os.Stderr, "========== WEBHOOK END (no action) ==========\n\n")
	respondJSON(w, http.StatusOK, map[string]string{"status": "no_action"})
}

// BotAnswerRequest is the request for /bot/answer
type BotAnswerRequest struct {
	QueryID   string `json:"query_id"`
	Text      string `json:"text"`
	ShowAlert bool   `json:"show_alert"`
}

// handleBotAnswer answers a callback query
// POST /api/v1/bot/answer
func (r *Router) handleBotAnswer(w http.ResponseWriter, req *http.Request) {
	fmt.Fprintf(os.Stderr, "[ANSWER] Received /bot/answer request\n")

	if req.Method != http.MethodPost {
		fmt.Fprintf(os.Stderr, "[ANSWER] ❌ Wrong method: %s\n", req.Method)
		respondError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	if r.botClient == nil {
		fmt.Fprintf(os.Stderr, "[ANSWER] ❌ botClient is nil\n")
		respondError(w, http.StatusServiceUnavailable, "Bot API not configured")
		return
	}

	var body BotAnswerRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		fmt.Fprintf(os.Stderr, "[ANSWER] ❌ JSON decode error: %v\n", err)
		respondError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	fmt.Fprintf(os.Stderr, "[ANSWER] query_id=%s, text=%s, show_alert=%v\n", body.QueryID, body.Text, body.ShowAlert)

	if body.QueryID == "" {
		fmt.Fprintf(os.Stderr, "[ANSWER] ❌ query_id is empty\n")
		respondError(w, http.StatusBadRequest, "query_id is required")
		return
	}

	if err := r.botClient.AnswerCallback(body.QueryID, body.Text, body.ShowAlert); err != nil {
		fmt.Fprintf(os.Stderr, "[ANSWER] ❌ AnswerCallback failed: %v\n", err)
		log.Printf("[BotAPI] AnswerCallback error: %v", err)
		respondError(w, http.StatusInternalServerError, "failed to answer: "+err.Error())
		return
	}

	fmt.Fprintf(os.Stderr, "[ANSWER] ✅ Callback answered successfully\n")
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
	})
}

// handleBotStatus returns Bot API client status
// GET /api/v1/bot/status
func (r *Router) handleBotStatus(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	if r.botClient == nil {
		respondJSON(w, http.StatusOK, map[string]interface{}{
			"configured": false,
			"message":    "Bot API not configured. Set TELEGRAM_BOT_TOKEN environment variable.",
		})
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"configured": true,
		"bot_id":     r.botClient.GetBotID(),
		"username":   r.botClient.GetBotUsername(),
	})
}

// handleBotWebhookInfo returns current webhook configuration
// GET /api/v1/bot/webhook-info
func (r *Router) handleBotWebhookInfo(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	if r.botClient == nil {
		respondError(w, http.StatusServiceUnavailable, "Bot API not configured")
		return
	}

	info, err := r.botClient.GetWebhookInfo()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "Failed to get webhook info: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"bot_id":                 r.botClient.GetBotID(),
		"bot_username":           r.botClient.GetBotUsername(),
		"url":                    info.URL,
		"has_custom_certificate": info.HasCustomCertificate,
		"pending_update_count":   info.PendingUpdateCount,
		"last_error_date":        info.LastErrorDate,
		"last_error_message":     info.LastErrorMessage,
		"max_connections":        info.MaxConnections,
		"ip_address":             info.IPAddress,
	})
}

// handleBotWebhookDebug returns debug info about last webhook call
// GET /api/v1/bot/webhook-debug
func (r *Router) handleBotWebhookDebug(w http.ResponseWriter, req *http.Request) {
	webhookDebugMu.Lock()
	debug := lastWebhookDebug
	webhookDebugMu.Unlock()

	respondJSON(w, http.StatusOK, debug)
}

// handleBotWebhookSetup registers webhook with Telegram
// POST /api/v1/bot/webhook-setup
func (r *Router) handleBotWebhookSetup(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		respondError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	if r.botClient == nil {
		respondError(w, http.StatusServiceUnavailable, "Bot API not configured")
		return
	}

	webhookURL := r.cfg.BotWebhookURL
	if webhookURL == "" {
		respondError(w, http.StatusBadRequest, "TELEGRAM_BOT_WEBHOOK_URL not configured")
		return
	}

	log.Printf("[BotAPI] Manual webhook setup requested, URL: %s", webhookURL)

	// First delete the webhook to clear any cached errors
	if err := r.botClient.DeleteWebhook(); err != nil {
		log.Printf("[BotAPI] ⚠️ Failed to delete webhook (continuing): %v", err)
	}

	if err := r.botClient.SetWebhook(webhookURL); err != nil {
		log.Printf("[BotAPI] ❌ Failed to set webhook: %v", err)
		respondError(w, http.StatusInternalServerError, "Failed to set webhook: "+err.Error())
		return
	}

	// Verify it was set
	info, _ := r.botClient.GetWebhookInfo()

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":      "ok",
		"webhook_url": webhookURL,
		"verified":    info.URL == webhookURL,
		"info": map[string]interface{}{
			"url":                  info.URL,
			"pending_update_count": info.PendingUpdateCount,
			"last_error_message":   info.LastErrorMessage,
		},
	})
}

// handleGetUserPhotos returns profile photos for a user
// GET /api/v1/user/photos/{user_id}
func (r *Router) handleGetUserPhotos(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	// Get session from header
	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		respondError(w, http.StatusBadRequest, "X-Session-ID header required")
		return
	}

	// Get user ID from path: /api/v1/user/photos/{user_id}
	path := strings.TrimPrefix(req.URL.Path, "/api/v1/user/photos/")
	userID, err := strconv.ParseInt(path, 10, 64)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid user_id")
		return
	}

	// Get client
	r.mu.RLock()
	client, exists := r.clients[sessionID]
	r.mu.RUnlock()

	if !exists {
		respondError(w, http.StatusNotFound, "session not found")
		return
	}

	// Get photos
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	photos, err := client.GetUserProfilePhotos(ctx, userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to get photos: "+err.Error())
		return
	}

	respondJSON(w, http.StatusOK, map[string]interface{}{
		"user_id": userID,
		"photos":  photos,
		"count":   len(photos),
	})
}

// handleDownloadUserPhoto downloads a user's profile photo
// GET /api/v1/user/photo/download/{user_id}
func (r *Router) handleDownloadUserPhoto(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		respondError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	// Get session from header
	sessionID := req.Header.Get("X-Session-ID")
	if sessionID == "" {
		respondError(w, http.StatusBadRequest, "X-Session-ID header required")
		return
	}

	// Get user ID from path: /api/v1/user/photo/download/{user_id}
	path := strings.TrimPrefix(req.URL.Path, "/api/v1/user/photo/download/")
	userID, err := strconv.ParseInt(path, 10, 64)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid user_id")
		return
	}

	// Get client
	r.mu.RLock()
	client, exists := r.clients[sessionID]
	r.mu.RUnlock()

	if !exists {
		respondError(w, http.StatusNotFound, "session not found")
		return
	}

	// Download photo
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	result, err := client.DownloadProfilePhoto(ctx, userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "failed to download: "+err.Error())
		return
	}

	if !result.Success {
		respondJSON(w, http.StatusOK, result)
		return
	}

	respondJSON(w, http.StatusOK, result)
}
