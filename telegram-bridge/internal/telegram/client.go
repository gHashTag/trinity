package telegram

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/go-faster/errors"
	"github.com/gotd/td/crypto/srp"
	"github.com/gotd/td/session"
	"github.com/gotd/td/telegram"
	"github.com/gotd/td/telegram/downloader"
	"github.com/gotd/td/telegram/message"
	"github.com/gotd/td/telegram/updates"
	"github.com/gotd/td/tg"
	"github.com/gotd/td/tgerr"
)

// Client wraps gotd/td Telegram client
type Client struct {
	api       *telegram.Client
	sender    *message.Sender
	gaps      *updates.Manager
	sessionID string
	storage   session.Storage // Session storage for explicit persistence

	appID   int
	appHash string

	// Auth state
	authFlow    *authFlow
	isConnected bool
	isAuthed    bool

	// Connection ready signal
	connReady chan struct{}

	// Updates channel
	updatesCh chan Update

	mu sync.RWMutex
}

// Update represents a Telegram update
type Update struct {
	Type      string      `json:"type"`
	ChatID    int64       `json:"chat_id"`
	MessageID int         `json:"message_id"`
	Text      string      `json:"text,omitempty"`
	SenderID  int64       `json:"sender_id,omitempty"`
	Timestamp int64       `json:"timestamp"`
	Raw       interface{} `json:"-"`
}

// Dialog represents a Telegram dialog/chat
type Dialog struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Type        string `json:"type"`
	UnreadCount int    `json:"unread_count"`
	LastMessage string `json:"last_message,omitempty"`
}

// Message represents a Telegram message
type Message struct {
	ID        int    `json:"id"`
	Text      string `json:"text"`
	FromID    int64  `json:"from_id"`
	FromName  string `json:"from_name"`
	Username  string `json:"username"`              // Always include for Lead Card
	Phone     string `json:"phone"`                // User's phone number (if available)
	LangCode  string `json:"lang_code"`            // User's language code (ru, en, etc)
	Premium   bool   `json:"premium,omitempty"`   // Telegram Premium status
	Bot       bool   `json:"bot,omitempty"`       // Is user a bot
	Date      string `json:"date"`
	Out       bool   `json:"out"`
	ReplyToID int    `json:"reply_to_id,omitempty"`
	// Media fields
	MediaType     string `json:"media_type,omitempty"`      // photo, voice, video, document, audio, video_note, sticker
	MediaFileID   string `json:"media_file_id,omitempty"`   // Telegram file location reference
	MediaSize     int64  `json:"media_size,omitempty"`      // File size in bytes
	MediaMime     string `json:"media_mime,omitempty"`      // MIME type
	MediaWidth    int    `json:"media_width,omitempty"`     // For photos/videos
	MediaHeight   int    `json:"media_height,omitempty"`    // For photos/videos
	MediaDuration int    `json:"media_duration,omitempty"`  // For audio/video in seconds
	MediaFileName string `json:"media_file_name,omitempty"` // Original filename for documents
}

// MediaDownloadResult represents the result of downloading a media file
type MediaDownloadResult struct {
	Success  bool   `json:"success"`
	FilePath string `json:"file_path"`
	FileSize int64  `json:"file_size"`
	MimeType string `json:"mime_type"`
	Error    string `json:"error,omitempty"`
}

// User represents a Telegram user
type User struct {
	ID        int64  `json:"id"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name,omitempty"`
	Username  string `json:"username"`           // Always include
	Phone     string `json:"phone"`              // Always include
}

// ProfilePhoto represents a user's profile photo
type ProfilePhoto struct {
	PhotoID    int64  `json:"photo_id"`
	Width      int    `json:"width"`
	Height     int    `json:"height"`
	FileSize   int    `json:"file_size,omitempty"`
	DCId       int    `json:"dc_id"`
	AccessHash int64  `json:"access_hash"`
	// For download
	FileReference []byte `json:"-"`
}

// NewClient creates a new Telegram client
func NewClient(appID int, appHash string, sessionStorage session.Storage) (*Client, error) {
	c := &Client{
		appID:     appID,
		appHash:   appHash,
		storage:   sessionStorage, // Store reference for explicit saves
		updatesCh: make(chan Update, 100),
		connReady: make(chan struct{}),
		authFlow:  &authFlow{},
	}

	// Create updates manager for handling gaps
	dispatcher := tg.NewUpdateDispatcher()
	c.gaps = updates.New(updates.Config{
		Handler: dispatcher,
	})

	// Register update handlers
	dispatcher.OnNewMessage(c.onNewMessage)
	dispatcher.OnEditMessage(c.onEditMessage)
	dispatcher.OnDeleteMessages(c.onDeleteMessages)

	// Create client options with longer timeouts for DC migration
	opts := telegram.Options{
		SessionStorage:   sessionStorage,
		UpdateHandler:    c.gaps,
		MigrationTimeout: 120 * time.Second, // Allow more time for DC migration
	}

	// Create client
	c.api = telegram.NewClient(appID, appHash, opts)

	return c, nil
}

// Connect establishes connection to Telegram
func (c *Client) Connect(ctx context.Context) error {
	c.mu.Lock()
	if c.isConnected {
		c.mu.Unlock()
		return nil
	}
	c.mu.Unlock()

	// Start client in background
	go func() {
		err := c.api.Run(ctx, func(ctx context.Context) error {
			c.mu.Lock()
			c.isConnected = true
			c.sender = message.NewSender(c.api.API())
			c.mu.Unlock()

			// Check if already authorized
			status, err := c.api.Auth().Status(ctx)
			if err != nil {
				// Signal ready even on error (with isAuthed = false)
				c.mu.Lock()
				c.isAuthed = false
				c.mu.Unlock()
				close(c.connReady)
				return err
			}

			c.mu.Lock()
			c.isAuthed = status.Authorized
			c.mu.Unlock()

			// Signal that connection and auth check are complete
			close(c.connReady)

			// Keep running
			<-ctx.Done()
			return ctx.Err()
		})
		if err != nil {
			fmt.Printf("Client error: %v\n", err)
		}
	}()

	// Wait for connection with proper timeout
	select {
	case <-c.connReady:
		// Connection established and auth status checked
		return nil
	case <-time.After(10 * time.Second):
		// Timeout waiting for connection
		return fmt.Errorf("connection timeout")
	case <-ctx.Done():
		return ctx.Err()
	}
}

// SendCode sends authentication code to phone
func (c *Client) SendCode(ctx context.Context, phone string) (string, error) {
	c.mu.Lock()
	c.authFlow.phone = phone
	c.mu.Unlock()

	// Use raw API to send code
	sentCode, err := c.api.API().AuthSendCode(ctx, &tg.AuthSendCodeRequest{
		PhoneNumber: phone,
		APIID:       c.appID,
		APIHash:     c.appHash,
		Settings:    tg.CodeSettings{},
	})
	if err != nil {
		return "", fmt.Errorf("send code: %w", err)
	}

	// Extract phone code hash based on type
	var codeHash string
	switch v := sentCode.(type) {
	case *tg.AuthSentCode:
		codeHash = v.PhoneCodeHash
	case *tg.AuthSentCodeSuccess:
		// Already authorized
		c.mu.Lock()
		c.isAuthed = true
		c.mu.Unlock()
		return "", nil
	}

	c.mu.Lock()
	c.authFlow.codeHash = codeHash
	c.mu.Unlock()

	return codeHash, nil
}

// SignIn verifies code and signs in
func (c *Client) SignIn(ctx context.Context, code string) (*User, error) {
	c.mu.RLock()
	phone := c.authFlow.phone
	codeHash := c.authFlow.codeHash
	c.mu.RUnlock()

	if phone == "" || codeHash == "" {
		return nil, fmt.Errorf("send code first")
	}

	authResult, err := c.api.API().AuthSignIn(ctx, &tg.AuthSignInRequest{
		PhoneNumber:   phone,
		PhoneCodeHash: codeHash,
		PhoneCode:     code,
	})
	if err != nil {
		return nil, fmt.Errorf("sign in: %w", err)
	}

	// Handle different authorization results
	switch v := authResult.(type) {
	case *tg.AuthAuthorizationSignUpRequired:
		return nil, fmt.Errorf("sign up required")
	case *tg.AuthAuthorization:
		user, ok := v.User.(*tg.User)
		if !ok {
			return nil, fmt.Errorf("unexpected user type")
		}
		c.mu.Lock()
		c.isAuthed = true
		c.mu.Unlock()

		return &User{
			ID:        user.ID,
			FirstName: user.FirstName,
			LastName:  user.LastName,
			Username:  user.Username,
			Phone:     user.Phone,
		}, nil
	}

	return nil, fmt.Errorf("unexpected auth result")
}

// Check2FA checks if 2FA is required
func (c *Client) Check2FA(ctx context.Context, password string) (*User, error) {
	// Get password settings
	pwd, err := c.api.API().AccountGetPassword(ctx)
	if err != nil {
		return nil, fmt.Errorf("get password: %w", err)
	}

	// Compute SRP parameters
	srpAnswer, err := computeSRP(password, pwd)
	if err != nil {
		return nil, fmt.Errorf("compute srp: %w", err)
	}

	authResult, err := c.api.API().AuthCheckPassword(ctx, srpAnswer)
	if err != nil {
		return nil, fmt.Errorf("check password: %w", err)
	}

	// Handle different authorization results
	auth, ok := authResult.(*tg.AuthAuthorization)
	if !ok {
		return nil, fmt.Errorf("unexpected auth result type")
	}

	user, ok := auth.User.(*tg.User)
	if !ok {
		return nil, fmt.Errorf("unexpected user type")
	}

	c.mu.Lock()
	c.isAuthed = true
	c.mu.Unlock()

	return &User{
		ID:        user.ID,
		FirstName: user.FirstName,
		LastName:  user.LastName,
		Username:  user.Username,
		Phone:     user.Phone,
	}, nil
}

// SaveSession explicitly persists session to storage
// This ensures auth keys are written to disk after SignIn/2FA
func (c *Client) SaveSession() error {
	if c.storage == nil {
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Load and re-store to ensure data is flushed to disk
	data, err := c.storage.LoadSession(ctx)
	if err != nil {
		return fmt.Errorf("load session for save: %w", err)
	}
	if len(data) > 0 {
		if err := c.storage.StoreSession(ctx, data); err != nil {
			return fmt.Errorf("store session: %w", err)
		}
	}
	return nil
}

// GetMe returns current user info
func (c *Client) GetMe(ctx context.Context) (*User, error) {
	users, err := c.api.API().UsersGetUsers(ctx, []tg.InputUserClass{&tg.InputUserSelf{}})
	if err != nil {
		return nil, fmt.Errorf("get users: %w", err)
	}

	if len(users) == 0 {
		return nil, fmt.Errorf("no user found")
	}

	user, ok := users[0].(*tg.User)
	if !ok {
		return nil, fmt.Errorf("unexpected user type")
	}

	return &User{
		ID:        user.ID,
		FirstName: user.FirstName,
		LastName:  user.LastName,
		Username:  user.Username,
		Phone:     user.Phone,
	}, nil
}

// GetUserProfilePhotos returns profile photos for a user
func (c *Client) GetUserProfilePhotos(ctx context.Context, userID int64) ([]ProfilePhoto, error) {
	c.mu.RLock()
	api := c.api
	c.mu.RUnlock()

	if api == nil {
		return nil, fmt.Errorf("not connected")
	}

	// First, resolve the user to get access hash
	users, err := api.API().UsersGetUsers(ctx, []tg.InputUserClass{
		&tg.InputUser{UserID: userID},
	})
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}

	if len(users) == 0 {
		return nil, fmt.Errorf("user not found")
	}

	user, ok := users[0].(*tg.User)
	if !ok {
		return nil, fmt.Errorf("unexpected user type")
	}

	// Get user photos
	result, err := api.API().PhotosGetUserPhotos(ctx, &tg.PhotosGetUserPhotosRequest{
		UserID: &tg.InputUser{
			UserID:     user.ID,
			AccessHash: user.AccessHash,
		},
		Limit: 1, // We only need the latest profile photo
	})
	if err != nil {
		return nil, fmt.Errorf("get user photos: %w", err)
	}

	var photos []ProfilePhoto

	switch v := result.(type) {
	case *tg.PhotosPhotos:
		photos = c.parseProfilePhotos(v.Photos)
	case *tg.PhotosPhotosSlice:
		photos = c.parseProfilePhotos(v.Photos)
	default:
		return nil, fmt.Errorf("unexpected result type")
	}

	return photos, nil
}

// parseProfilePhotos extracts photo info from Telegram photos
func (c *Client) parseProfilePhotos(photoList []tg.PhotoClass) []ProfilePhoto {
	var result []ProfilePhoto

	for _, p := range photoList {
		photo, ok := p.(*tg.Photo)
		if !ok {
			continue
		}

		// Find largest size
		var bestSize *tg.PhotoSize
		for _, size := range photo.Sizes {
			if ps, ok := size.(*tg.PhotoSize); ok {
				if bestSize == nil || ps.Size > bestSize.Size {
					bestSize = ps
				}
			}
		}

		if bestSize == nil {
			continue
		}

		result = append(result, ProfilePhoto{
			PhotoID:       photo.ID,
			Width:         bestSize.W,
			Height:        bestSize.H,
			FileSize:      bestSize.Size,
			DCId:          photo.DCID,
			AccessHash:    photo.AccessHash,
			FileReference: photo.FileReference,
		})
	}

	return result
}

// DownloadProfilePhoto downloads a user's profile photo
func (c *Client) DownloadProfilePhoto(ctx context.Context, userID int64) (*MediaDownloadResult, error) {
	photos, err := c.GetUserProfilePhotos(ctx, userID)
	if err != nil {
		return &MediaDownloadResult{Success: false, Error: err.Error()}, nil
	}

	if len(photos) == 0 {
		return &MediaDownloadResult{Success: false, Error: "user has no profile photo"}, nil
	}

	photo := photos[0]

	// Create temp directory
	tmpDir := "/tmp/vibee/profile_photos"
	if err := os.MkdirAll(tmpDir, 0755); err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("create temp dir: %v", err)}, nil
	}

	// Create file
	filename := fmt.Sprintf("profile_%d_%d.jpg", userID, photo.PhotoID)
	filePath := filepath.Join(tmpDir, filename)

	file, err := os.Create(filePath)
	if err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("create file: %v", err)}, nil
	}
	defer file.Close()

	// Create location for download
	location := &tg.InputPeerPhotoFileLocation{
		Peer: &tg.InputPeerUser{
			UserID: userID,
		},
		PhotoID: photo.PhotoID,
		Big:     true, // Get high resolution
	}

	// Download
	d := downloader.NewDownloader()
	_, err = d.Download(c.api.API(), location).Stream(ctx, file)
	if err != nil {
		os.Remove(filePath)
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("download: %v", err)}, nil
	}

	// Get file size
	fileInfo, err := file.Stat()
	if err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("stat file: %v", err)}, nil
	}

	return &MediaDownloadResult{
		Success:  true,
		FilePath: filePath,
		FileSize: fileInfo.Size(),
		MimeType: "image/jpeg",
	}, nil
}

// GetDialogs returns list of dialogs with FLOOD_WAIT retry handling
func (c *Client) GetDialogs(ctx context.Context, limit int) ([]Dialog, error) {
	const maxRetries = 5

	for attempt := 0; attempt < maxRetries; attempt++ {
		result, err := c.api.API().MessagesGetDialogs(ctx, &tg.MessagesGetDialogsRequest{
			OffsetPeer: &tg.InputPeerEmpty{},
			Limit:      limit,
		})

		if err != nil {
			// Check for FLOOD_WAIT error
			if wait, ok := tgerr.AsFloodWait(err); ok {
				log.Printf("[TELEGRAM] GetDialogs FLOOD_WAIT: sleeping %v (attempt %d/%d)", wait, attempt+1, maxRetries)
				select {
				case <-ctx.Done():
					return nil, ctx.Err()
				case <-time.After(wait + time.Second): // Add 1 second buffer
					continue
				}
			}
			return nil, fmt.Errorf("get dialogs: %w", err)
		}

		var dialogs []Dialog

		switch v := result.(type) {
		case *tg.MessagesDialogs:
			dialogs = c.parseDialogs(v.Dialogs, v.Chats, v.Users)
		case *tg.MessagesDialogsSlice:
			dialogs = c.parseDialogs(v.Dialogs, v.Chats, v.Users)
		}

		return dialogs, nil
	}

	return nil, fmt.Errorf("get dialogs: max retries exceeded due to FLOOD_WAIT")
}

func (c *Client) parseDialogs(dialogList []tg.DialogClass, chats []tg.ChatClass, users []tg.UserClass) []Dialog {
	// Build lookup maps
	chatMap := make(map[int64]tg.ChatClass)
	userMap := make(map[int64]tg.UserClass)

	for _, chat := range chats {
		switch v := chat.(type) {
		case *tg.Chat:
			chatMap[v.ID] = v
		case *tg.Channel:
			chatMap[v.ID] = v
		}
	}

	for _, user := range users {
		if u, ok := user.(*tg.User); ok {
			userMap[u.ID] = u
		}
	}

	var result []Dialog

	for _, d := range dialogList {
		dialog, ok := d.(*tg.Dialog)
		if !ok {
			continue
		}

		var item Dialog
		item.UnreadCount = dialog.UnreadCount

		switch peer := dialog.Peer.(type) {
		case *tg.PeerUser:
			if user, ok := userMap[peer.UserID].(*tg.User); ok {
				item.ID = user.ID
				item.Title = user.FirstName
				if user.LastName != "" {
					item.Title += " " + user.LastName
				}
				item.Type = "user"
			}
		case *tg.PeerChat:
			if chat, ok := chatMap[peer.ChatID].(*tg.Chat); ok {
				item.ID = -chat.ID
				item.Title = chat.Title
				item.Type = "group"
			}
		case *tg.PeerChannel:
			if channel, ok := chatMap[peer.ChannelID].(*tg.Channel); ok {
				item.ID = -1000000000000 - channel.ID
				item.Title = channel.Title
				if channel.Broadcast {
					item.Type = "channel"
				} else {
					item.Type = "supergroup"
				}
			}
		}

		if item.ID != 0 {
			result = append(result, item)
		}
	}

	return result
}

// GetHistory returns chat history with optional offset_id for pagination
func (c *Client) GetHistory(ctx context.Context, chatID int64, limit int) ([]Message, error) {
	return c.GetHistoryWithOffset(ctx, chatID, limit, 0)
}

// GetHistoryWithOffset returns chat history starting from offset_id (for pagination) with FLOOD_WAIT retry handling
func (c *Client) GetHistoryWithOffset(ctx context.Context, chatID int64, limit int, offsetID int) ([]Message, error) {
	peer, err := c.resolvePeer(ctx, chatID)
	if err != nil {
		return nil, err
	}

	const maxRetries = 5

	for attempt := 0; attempt < maxRetries; attempt++ {
		result, err := c.api.API().MessagesGetHistory(ctx, &tg.MessagesGetHistoryRequest{
			Peer:     peer,
			Limit:    limit,
			OffsetID: offsetID,
		})

		if err != nil {
			// Check for FLOOD_WAIT error
			if wait, ok := tgerr.AsFloodWait(err); ok {
				log.Printf("[TELEGRAM] GetHistory FLOOD_WAIT: sleeping %v (attempt %d/%d)", wait, attempt+1, maxRetries)
				select {
				case <-ctx.Done():
					return nil, ctx.Err()
				case <-time.After(wait + time.Second): // Add 1 second buffer
					continue
				}
			}
			return nil, fmt.Errorf("get history: %w", err)
		}

		var messages []Message

		switch v := result.(type) {
		case *tg.MessagesMessages:
			messages = c.parseMessagesWithChatID(v.Messages, v.Users, chatID)
		case *tg.MessagesMessagesSlice:
			messages = c.parseMessagesWithChatID(v.Messages, v.Users, chatID)
		case *tg.MessagesChannelMessages:
			messages = c.parseMessagesWithChatID(v.Messages, v.Users, chatID)
		}

		return messages, nil
	}

	return nil, fmt.Errorf("get history: max retries exceeded due to FLOOD_WAIT")
}

func (c *Client) parseMessages(msgList []tg.MessageClass, users []tg.UserClass) []Message {
	return c.parseMessagesWithChatID(msgList, users, 0)
}

func (c *Client) parseMessagesWithChatID(msgList []tg.MessageClass, users []tg.UserClass, chatID int64) []Message {
	userMap := make(map[int64]*tg.User)
	for _, u := range users {
		if user, ok := u.(*tg.User); ok {
			userMap[user.ID] = user
		}
	}

	// DEBUG: Log userMap contents
	log.Printf("[DEBUG] parseMessagesWithChatID: userMap has %d users for chatID=%d", len(userMap), chatID)
	for id, u := range userMap {
		log.Printf("[DEBUG]   userMap[%d] = %s %s (@%s)", id, u.FirstName, u.LastName, u.Username)
	}

	var result []Message

	for _, m := range msgList {
		msg, ok := m.(*tg.Message)
		if !ok {
			continue
		}

		item := Message{
			ID:   msg.ID,
			Text: msg.Message,
			Date: time.Unix(int64(msg.Date), 0).Format(time.RFC3339),
			Out:  msg.Out,
		}

		if msg.ReplyTo != nil {
			if reply, ok := msg.ReplyTo.(*tg.MessageReplyHeader); ok {
				item.ReplyToID = reply.ReplyToMsgID
			}
		}

		if from := msg.FromID; from != nil {
			if peer, ok := from.(*tg.PeerUser); ok {
				item.FromID = peer.UserID
				if user, ok := userMap[peer.UserID]; ok {
					item.FromName = user.FirstName
					if user.LastName != "" {
						item.FromName += " " + user.LastName
					}
					item.Username = user.Username
					item.Phone = user.Phone
					item.LangCode = user.LangCode
					item.Premium = user.Premium
					item.Bot = user.Bot
					log.Printf("[DEBUG] MSG %d: Found user %d in map: name=%s username=%s", msg.ID, peer.UserID, item.FromName, item.Username)
				} else {
					log.Printf("[DEBUG] MSG %d: User %d NOT in userMap!", msg.ID, peer.UserID)
				}
			}
		} else if chatID > 0 && !msg.Out {
			// For private chats, if FromID is nil and message is incoming,
			// the sender is the peer (chatID)
			item.FromID = chatID
			if user, ok := userMap[chatID]; ok {
				item.FromName = user.FirstName
				if user.LastName != "" {
					item.FromName += " " + user.LastName
				}
				item.Username = user.Username
				item.Phone = user.Phone
				item.LangCode = user.LangCode
				item.Premium = user.Premium
				item.Bot = user.Bot
			}
		}

		// Extract media information
		if msg.Media != nil {
			c.extractMediaInfo(msg.Media, &item)
		}

		result = append(result, item)
	}

	return result
}

// extractMediaInfo extracts media information from a message
func (c *Client) extractMediaInfo(media tg.MessageMediaClass, item *Message) {
	switch m := media.(type) {
	case *tg.MessageMediaPhoto:
		item.MediaType = "photo"
		if photo, ok := m.Photo.(*tg.Photo); ok {
			// Get largest photo size
			for _, size := range photo.Sizes {
				if photoSize, ok := size.(*tg.PhotoSize); ok {
					item.MediaWidth = photoSize.W
					item.MediaHeight = photoSize.H
					item.MediaSize = int64(photoSize.Size)
				}
			}
			// Store photo ID for download reference
			item.MediaFileID = fmt.Sprintf("photo_%d_%d", photo.ID, photo.AccessHash)
		}

	case *tg.MessageMediaDocument:
		if doc, ok := m.Document.(*tg.Document); ok {
			item.MediaMime = doc.MimeType
			item.MediaSize = doc.Size
			item.MediaFileID = fmt.Sprintf("doc_%d_%d", doc.ID, doc.AccessHash)

			// Determine media type from attributes
			for _, attr := range doc.Attributes {
				switch a := attr.(type) {
				case *tg.DocumentAttributeVideo:
					if a.RoundMessage {
						item.MediaType = "video_note"
					} else {
						item.MediaType = "video"
					}
					item.MediaWidth = a.W
					item.MediaHeight = a.H
					item.MediaDuration = int(a.Duration)
				case *tg.DocumentAttributeAudio:
					if a.Voice {
						item.MediaType = "voice"
					} else {
						item.MediaType = "audio"
					}
					item.MediaDuration = int(a.Duration)
				case *tg.DocumentAttributeSticker:
					item.MediaType = "sticker"
				case *tg.DocumentAttributeFilename:
					item.MediaFileName = a.FileName
				case *tg.DocumentAttributeImageSize:
					item.MediaWidth = a.W
					item.MediaHeight = a.H
				}
			}
			// If no specific type found, it's a document
			if item.MediaType == "" {
				item.MediaType = "document"
			}
		}

	case *tg.MessageMediaGeo:
		item.MediaType = "geo"

	case *tg.MessageMediaContact:
		item.MediaType = "contact"

	case *tg.MessageMediaPoll:
		item.MediaType = "poll"

	case *tg.MessageMediaWebPage:
		item.MediaType = "webpage"
	}
}

// SendMessage sends a message to chat
func (c *Client) SendMessage(ctx context.Context, chatID int64, text string, replyTo int) (int, error) {
	c.mu.RLock()
	sender := c.sender
	c.mu.RUnlock()

	if sender == nil {
		return 0, fmt.Errorf("not connected")
	}

	peer, err := c.resolvePeer(ctx, chatID)
	if err != nil {
		return 0, err
	}

	var upd tg.UpdatesClass
	var sendErr error

	if replyTo > 0 {
		upd, sendErr = sender.To(peer).Reply(replyTo).Text(ctx, text)
	} else {
		upd, sendErr = sender.To(peer).Text(ctx, text)
	}

	if sendErr != nil {
		return 0, fmt.Errorf("send message: %w", sendErr)
	}

	// Extract message ID from updates
	switch u := upd.(type) {
	case *tg.Updates:
		for _, update := range u.Updates {
			switch upd := update.(type) {
			case *tg.UpdateNewMessage:
				if msg, ok := upd.Message.(*tg.Message); ok {
					return msg.ID, nil
				}
			case *tg.UpdateNewChannelMessage:
				if msg, ok := upd.Message.(*tg.Message); ok {
					return msg.ID, nil
				}
			}
		}
	case *tg.UpdateShortSentMessage:
		return u.ID, nil
	}

	return 0, nil
}

// SendPhoto sends a photo from URL to chat
func (c *Client) SendPhoto(ctx context.Context, chatID int64, photoURL string, caption string) (int, error) {
	c.mu.RLock()
	api := c.api
	c.mu.RUnlock()

	if api == nil {
		return 0, fmt.Errorf("not connected")
	}

	peer, err := c.resolvePeer(ctx, chatID)
	if err != nil {
		return 0, err
	}

	// Generate random ID for the message
	randomID := make([]byte, 8)
	rand.Read(randomID)
	var randInt int64
	for i, b := range randomID {
		randInt |= int64(b) << (8 * i)
	}

	// Use InputMediaPhotoExternal to send photo from URL
	upd, err := api.API().MessagesSendMedia(ctx, &tg.MessagesSendMediaRequest{
		Peer:     peer,
		Message:  caption,
		RandomID: randInt,
		Media: &tg.InputMediaPhotoExternal{
			URL: photoURL,
		},
	})
	if err != nil {
		return 0, fmt.Errorf("send photo: %w", err)
	}

	// Extract message ID from updates
	switch u := upd.(type) {
	case *tg.Updates:
		for _, update := range u.Updates {
			switch upd := update.(type) {
			case *tg.UpdateNewMessage:
				if msg, ok := upd.Message.(*tg.Message); ok {
					return msg.ID, nil
				}
			case *tg.UpdateNewChannelMessage:
				if msg, ok := upd.Message.(*tg.Message); ok {
					return msg.ID, nil
				}
			}
		}
	case *tg.UpdateShortSentMessage:
		return u.ID, nil
	}

	return 0, nil
}

// ResolveUsername resolves a username to peer info
func (c *Client) ResolveUsername(ctx context.Context, username string) (map[string]interface{}, error) {
	c.mu.RLock()
	api := c.api
	c.mu.RUnlock()

	if api == nil {
		return nil, fmt.Errorf("not connected")
	}

	result, err := api.API().ContactsResolveUsername(ctx, &tg.ContactsResolveUsernameRequest{
		Username: username,
	})
	if err != nil {
		return nil, fmt.Errorf("resolve username: %w", err)
	}

	response := map[string]interface{}{
		"username": username,
	}

	// Extract peer info
	switch peer := result.Peer.(type) {
	case *tg.PeerUser:
		response["type"] = "user"
		response["id"] = peer.UserID
		// Find user details
		for _, user := range result.Users {
			if u, ok := user.(*tg.User); ok && u.ID == peer.UserID {
				response["first_name"] = u.FirstName
				response["last_name"] = u.LastName
				response["username"] = u.Username
				response["bot"] = u.Bot
				response["access_hash"] = u.AccessHash
				break
			}
		}
	case *tg.PeerChat:
		response["type"] = "chat"
		response["id"] = -peer.ChatID
	case *tg.PeerChannel:
		response["type"] = "channel"
		response["id"] = -1000000000000 - peer.ChannelID
		// Find channel details
		for _, chat := range result.Chats {
			if ch, ok := chat.(*tg.Channel); ok && ch.ID == peer.ChannelID {
				response["title"] = ch.Title
				response["username"] = ch.Username
				response["access_hash"] = ch.AccessHash
				break
			}
		}
	}

	return response, nil
}

func (c *Client) resolvePeer(ctx context.Context, chatID int64) (tg.InputPeerClass, error) {
	log.Printf("[resolvePeer] ═══════════════════════════════════════")
	log.Printf("[resolvePeer] chatID=%d", chatID)

	if chatID > 0 {
		// User
		log.Printf("[resolvePeer] Type=User, UserID=%d", chatID)
		return &tg.InputPeerUser{UserID: chatID}, nil
	}

	if chatID > -1000000000000 {
		// Group chat
		groupID := -chatID
		log.Printf("[resolvePeer] Type=Group, GroupID=%d", groupID)
		return &tg.InputPeerChat{ChatID: groupID}, nil
	}

	// Channel/Supergroup
	channelID := -chatID - 1000000000000
	log.Printf("[resolvePeer] Type=Channel/Supergroup, channelID=%d", channelID)

	// First try to get from dialogs to get access hash
	log.Printf("[resolvePeer] Searching in dialogs...")
	dialogs, err := c.api.API().MessagesGetDialogs(ctx, &tg.MessagesGetDialogsRequest{
		OffsetPeer: &tg.InputPeerEmpty{},
		Limit:      100,
	})
	if err == nil {
		if d, ok := dialogs.(*tg.MessagesDialogsSlice); ok {
			log.Printf("[resolvePeer] Got DialogsSlice with %d chats", len(d.Chats))
			for _, chat := range d.Chats {
				if ch, ok := chat.(*tg.Channel); ok {
					log.Printf("[resolvePeer] Found channel: ID=%d, Title=%s", ch.ID, ch.Title)
					if ch.ID == channelID {
						log.Printf("[resolvePeer] ✅ Match found! AccessHash=%d", ch.AccessHash)
						return &tg.InputPeerChannel{
							ChannelID:  ch.ID,
							AccessHash: ch.AccessHash,
						}, nil
					}
				}
			}
		}
		if d, ok := dialogs.(*tg.MessagesDialogs); ok {
			log.Printf("[resolvePeer] Got Dialogs with %d chats", len(d.Chats))
			for _, chat := range d.Chats {
				if ch, ok := chat.(*tg.Channel); ok {
					log.Printf("[resolvePeer] Found channel: ID=%d, Title=%s", ch.ID, ch.Title)
					if ch.ID == channelID {
						log.Printf("[resolvePeer] ✅ Match found! AccessHash=%d", ch.AccessHash)
						return &tg.InputPeerChannel{
							ChannelID:  ch.ID,
							AccessHash: ch.AccessHash,
						}, nil
					}
				}
			}
		}
	} else {
		log.Printf("[resolvePeer] ⚠️ Error getting dialogs: %v", err)
	}

	// Fallback: try ChannelsGetChannels (works for public channels)
	log.Printf("[resolvePeer] Channel not in dialogs, trying ChannelsGetChannels...")
	channels, err := c.api.API().ChannelsGetChannels(ctx, []tg.InputChannelClass{
		&tg.InputChannel{ChannelID: channelID},
	})
	if err != nil {
		log.Printf("[resolvePeer] ❌ ChannelsGetChannels error: %v", err)
		return nil, fmt.Errorf("resolve channel: %w", err)
	}

	if chats, ok := channels.(*tg.MessagesChats); ok && len(chats.Chats) > 0 {
		if ch, ok := chats.Chats[0].(*tg.Channel); ok {
			log.Printf("[resolvePeer] ✅ Found via ChannelsGetChannels: ID=%d, AccessHash=%d", ch.ID, ch.AccessHash)
			return &tg.InputPeerChannel{
				ChannelID:  ch.ID,
				AccessHash: ch.AccessHash,
			}, nil
		}
	}

	log.Printf("[resolvePeer] ❌ Channel not found: %d", channelID)
	return nil, fmt.Errorf("channel not found: %d", channelID)
}

// Updates returns channel for receiving updates
func (c *Client) Updates() <-chan Update {
	return c.updatesCh
}

// IsAuthorized returns authorization status
func (c *Client) IsAuthorized() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.isAuthed
}

// Update handlers
func (c *Client) onNewMessage(ctx context.Context, e tg.Entities, update *tg.UpdateNewMessage) error {
	msg, ok := update.Message.(*tg.Message)
	if !ok {
		return nil
	}

	chatID := c.extractChatID(msg.PeerID)
	senderID := int64(0)
	if from := msg.FromID; from != nil {
		if peer, ok := from.(*tg.PeerUser); ok {
			senderID = peer.UserID
		}
	}

	c.updatesCh <- Update{
		Type:      "new_message",
		ChatID:    chatID,
		MessageID: msg.ID,
		Text:      msg.Message,
		SenderID:  senderID,
		Timestamp: int64(msg.Date),
		Raw:       msg,
	}

	return nil
}

func (c *Client) onEditMessage(ctx context.Context, e tg.Entities, update *tg.UpdateEditMessage) error {
	msg, ok := update.Message.(*tg.Message)
	if !ok {
		return nil
	}

	c.updatesCh <- Update{
		Type:      "edit_message",
		ChatID:    c.extractChatID(msg.PeerID),
		MessageID: msg.ID,
		Text:      msg.Message,
		Timestamp: int64(msg.EditDate),
		Raw:       msg,
	}

	return nil
}

func (c *Client) onDeleteMessages(ctx context.Context, e tg.Entities, update *tg.UpdateDeleteMessages) error {
	for _, msgID := range update.Messages {
		c.updatesCh <- Update{
			Type:      "delete_message",
			MessageID: msgID,
			Timestamp: time.Now().Unix(),
		}
	}

	return nil
}

func (c *Client) extractChatID(peer tg.PeerClass) int64 {
	switch p := peer.(type) {
	case *tg.PeerUser:
		return p.UserID
	case *tg.PeerChat:
		return -p.ChatID
	case *tg.PeerChannel:
		return -1000000000000 - p.ChannelID
	}
	return 0
}

// authFlow holds auth state
type authFlow struct {
	phone    string
	codeHash string
}

// computeSRP computes SRP parameters for 2FA using gotd/td crypto/srp package
func computeSRP(password string, accountPassword *tg.AccountPassword) (*tg.InputCheckPasswordSRP, error) {
	if accountPassword.CurrentAlgo == nil {
		return nil, errors.New("no password set")
	}

	algo, ok := accountPassword.CurrentAlgo.(*tg.PasswordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow)
	if !ok {
		return nil, errors.Errorf("unsupported algo type: %T", accountPassword.CurrentAlgo)
	}

	// Create SRP client with crypto/rand as random source
	srpClient := srp.NewSRP(rand.Reader)

	// Prepare input parameters
	input := srp.Input{
		Salt1: algo.Salt1,
		Salt2: algo.Salt2,
		G:     algo.G,
		P:     algo.P,
	}

	// Generate random bytes for SRP
	random := make([]byte, 256)
	if _, err := rand.Read(random); err != nil {
		return nil, errors.Wrap(err, "generate random")
	}

	// Compute SRP hash
	answer, err := srpClient.Hash([]byte(password), accountPassword.SRPB, random, input)
	if err != nil {
		return nil, errors.Wrap(err, "srp hash")
	}

	return &tg.InputCheckPasswordSRP{
		SRPID: accountPassword.SRPID,
		A:     answer.A,
		M1:    answer.M1,
	}, nil
}

// DownloadMedia downloads a media file from a message
func (c *Client) DownloadMedia(ctx context.Context, chatID int64, messageID int) (*MediaDownloadResult, error) {
	c.mu.RLock()
	api := c.api
	c.mu.RUnlock()

	if api == nil {
		return &MediaDownloadResult{Success: false, Error: "not connected"}, nil
	}

	// Get the message to find media
	peer, err := c.resolvePeer(ctx, chatID)
	if err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("resolve peer: %v", err)}, nil
	}

	// Get single message
	result, err := api.API().MessagesGetMessages(ctx, []tg.InputMessageClass{
		&tg.InputMessageID{ID: messageID},
	})
	if err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("get message: %v", err)}, nil
	}

	// For channels/supergroups, use different API
	var msgs []tg.MessageClass
	switch r := result.(type) {
	case *tg.MessagesMessages:
		msgs = r.Messages
	case *tg.MessagesMessagesSlice:
		msgs = r.Messages
	case *tg.MessagesChannelMessages:
		msgs = r.Messages
	default:
		// Try channel messages API
		inputChannel, ok := peer.(*tg.InputPeerChannel)
		if ok {
			channelResult, err := api.API().ChannelsGetMessages(ctx, &tg.ChannelsGetMessagesRequest{
				Channel: &tg.InputChannel{
					ChannelID:  inputChannel.ChannelID,
					AccessHash: inputChannel.AccessHash,
				},
				ID: []tg.InputMessageClass{&tg.InputMessageID{ID: messageID}},
			})
			if err != nil {
				return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("get channel message: %v", err)}, nil
			}
			if cm, ok := channelResult.(*tg.MessagesChannelMessages); ok {
				msgs = cm.Messages
			}
		}
	}

	if len(msgs) == 0 {
		return &MediaDownloadResult{Success: false, Error: "message not found"}, nil
	}

	msg, ok := msgs[0].(*tg.Message)
	if !ok {
		return &MediaDownloadResult{Success: false, Error: "invalid message type"}, nil
	}

	if msg.Media == nil {
		return &MediaDownloadResult{Success: false, Error: "message has no media"}, nil
	}

	// Create temp directory
	tmpDir := "/tmp/vibee/media"
	if err := os.MkdirAll(tmpDir, 0755); err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("create temp dir: %v", err)}, nil
	}

	// Download based on media type
	d := downloader.NewDownloader()

	var location tg.InputFileLocationClass
	var filename string
	var mimeType string

	switch m := msg.Media.(type) {
	case *tg.MessageMediaPhoto:
		photo, ok := m.Photo.(*tg.Photo)
		if !ok {
			return &MediaDownloadResult{Success: false, Error: "invalid photo"}, nil
		}

		// Find largest photo size
		var bestSize *tg.PhotoSize
		for _, size := range photo.Sizes {
			if ps, ok := size.(*tg.PhotoSize); ok {
				if bestSize == nil || ps.Size > bestSize.Size {
					bestSize = ps
				}
			}
		}

		if bestSize == nil {
			return &MediaDownloadResult{Success: false, Error: "no photo sizes found"}, nil
		}

		location = &tg.InputPhotoFileLocation{
			ID:            photo.ID,
			AccessHash:    photo.AccessHash,
			FileReference: photo.FileReference,
			ThumbSize:     bestSize.Type,
		}
		filename = fmt.Sprintf("photo_%d.jpg", photo.ID)
		mimeType = "image/jpeg"

	case *tg.MessageMediaDocument:
		doc, ok := m.Document.(*tg.Document)
		if !ok {
			return &MediaDownloadResult{Success: false, Error: "invalid document"}, nil
		}

		location = &tg.InputDocumentFileLocation{
			ID:            doc.ID,
			AccessHash:    doc.AccessHash,
			FileReference: doc.FileReference,
		}

		// Get filename from attributes or generate one
		filename = fmt.Sprintf("doc_%d", doc.ID)
		for _, attr := range doc.Attributes {
			if fn, ok := attr.(*tg.DocumentAttributeFilename); ok {
				filename = fn.FileName
				break
			}
		}
		mimeType = doc.MimeType

		// Add extension if missing
		if !strings.Contains(filename, ".") {
			ext := mimeToExt(mimeType)
			filename = filename + ext
		}

	default:
		return &MediaDownloadResult{Success: false, Error: "unsupported media type"}, nil
	}

	// Full path for the file
	filePath := filepath.Join(tmpDir, filename)

	// Create file
	file, err := os.Create(filePath)
	if err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("create file: %v", err)}, nil
	}
	defer file.Close()

	// Download
	_, err = d.Download(api.API(), location).Stream(ctx, file)
	if err != nil {
		os.Remove(filePath)
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("download: %v", err)}, nil
	}

	// Get file size
	fileInfo, err := file.Stat()
	if err != nil {
		return &MediaDownloadResult{Success: false, Error: fmt.Sprintf("stat file: %v", err)}, nil
	}

	return &MediaDownloadResult{
		Success:  true,
		FilePath: filePath,
		FileSize: fileInfo.Size(),
		MimeType: mimeType,
	}, nil
}

// GetMessageWithMedia gets a single message with media info
func (c *Client) GetMessageWithMedia(ctx context.Context, chatID int64, messageID int) (*Message, error) {
	c.mu.RLock()
	api := c.api
	c.mu.RUnlock()

	if api == nil {
		return nil, fmt.Errorf("not connected")
	}

	peer, err := c.resolvePeer(ctx, chatID)
	if err != nil {
		return nil, errors.Wrap(err, "resolve peer")
	}

	// Try channel API first for channels/supergroups
	if inputChannel, ok := peer.(*tg.InputPeerChannel); ok {
		result, err := api.API().ChannelsGetMessages(ctx, &tg.ChannelsGetMessagesRequest{
			Channel: &tg.InputChannel{
				ChannelID:  inputChannel.ChannelID,
				AccessHash: inputChannel.AccessHash,
			},
			ID: []tg.InputMessageClass{&tg.InputMessageID{ID: messageID}},
		})
		if err == nil {
			if cm, ok := result.(*tg.MessagesChannelMessages); ok && len(cm.Messages) > 0 {
				msgs := c.parseMessages(cm.Messages, cm.Users)
				if len(msgs) > 0 {
					return &msgs[0], nil
				}
			}
		}
	}

	// Fallback to regular messages API
	result, err := api.API().MessagesGetMessages(ctx, []tg.InputMessageClass{
		&tg.InputMessageID{ID: messageID},
	})
	if err != nil {
		return nil, errors.Wrap(err, "get messages")
	}

	var msgs []tg.MessageClass
	var users []tg.UserClass
	switch r := result.(type) {
	case *tg.MessagesMessages:
		msgs = r.Messages
		users = r.Users
	case *tg.MessagesMessagesSlice:
		msgs = r.Messages
		users = r.Users
	case *tg.MessagesChannelMessages:
		msgs = r.Messages
		users = r.Users
	}

	if len(msgs) == 0 {
		return nil, fmt.Errorf("message not found")
	}

	parsed := c.parseMessages(msgs, users)
	if len(parsed) == 0 {
		return nil, fmt.Errorf("failed to parse message")
	}

	return &parsed[0], nil
}

// ClickButton clicks an inline keyboard button (callback query)
func (c *Client) ClickButton(ctx context.Context, chatID int64, msgID int, callbackData string) (string, error) {
	c.mu.RLock()
	api := c.api
	c.mu.RUnlock()

	if api == nil {
		return "", fmt.Errorf("not connected")
	}

	peer, err := c.resolvePeer(ctx, chatID)
	if err != nil {
		return "", fmt.Errorf("resolve peer: %w", err)
	}

	// Convert InputPeerClass to InputUserClass for bot
	var botPeer tg.InputUserClass
	switch p := peer.(type) {
	case *tg.InputPeerUser:
		botPeer = &tg.InputUser{UserID: p.UserID, AccessHash: p.AccessHash}
	default:
		// For bots, we typically have user peer
		botPeer = &tg.InputUser{UserID: chatID}
	}

	// Call MessagesGetBotCallbackAnswer to simulate button click
	result, err := api.API().MessagesGetBotCallbackAnswer(ctx, &tg.MessagesGetBotCallbackAnswerRequest{
		Peer:  peer,
		MsgID: msgID,
		Data:  []byte(callbackData),
	})
	if err != nil {
		return "", fmt.Errorf("callback answer: %w", err)
	}

	// Return the callback message if any
	_ = botPeer // unused, but kept for potential future use
	return result.Message, nil
}

// mimeToExt returns file extension for MIME type
func mimeToExt(mime string) string {
	switch mime {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	case "video/mp4":
		return ".mp4"
	case "video/webm":
		return ".webm"
	case "audio/ogg":
		return ".ogg"
	case "audio/mpeg":
		return ".mp3"
	case "audio/mp4":
		return ".m4a"
	case "application/pdf":
		return ".pdf"
	default:
		return ""
	}
}

