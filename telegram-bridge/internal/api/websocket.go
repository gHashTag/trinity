package api

import (
	"log"
	"time"

	"github.com/gorilla/websocket"
)

const (
	// Time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Send pings to peer with this period. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer.
	maxMessageSize = 512
)

// WSMessage represents a WebSocket message with session context
type WSMessage struct {
	SessionID string
	Data      []byte
}

// WSHub maintains the set of active clients and broadcasts messages
type WSHub struct {
	// Registered clients by session
	clients map[string]map[*WSClient]bool

	// Inbound messages from clients
	broadcast chan WSMessage

	// Register requests from clients
	register chan *WSClient

	// Unregister requests from clients
	unregister chan *WSClient
}

// NewWSHub creates a new WebSocket hub
func NewWSHub() *WSHub {
	return &WSHub{
		clients:    make(map[string]map[*WSClient]bool),
		broadcast:  make(chan WSMessage),
		register:   make(chan *WSClient),
		unregister: make(chan *WSClient),
	}
}

// Run starts the hub's main loop
func (h *WSHub) Run() {
	for {
		select {
		case client := <-h.register:
			if h.clients[client.sessionID] == nil {
				h.clients[client.sessionID] = make(map[*WSClient]bool)
			}
			h.clients[client.sessionID][client] = true
			log.Printf("WebSocket client registered for session %s", client.sessionID)

		case client := <-h.unregister:
			if clients, ok := h.clients[client.sessionID]; ok {
				if _, ok := clients[client]; ok {
					delete(clients, client)
					close(client.send)
					log.Printf("WebSocket client unregistered for session %s", client.sessionID)
				}
			}

		case message := <-h.broadcast:
			if clients, ok := h.clients[message.SessionID]; ok {
				for client := range clients {
					select {
					case client.send <- message.Data:
					default:
						close(client.send)
						delete(clients, client)
					}
				}
			}
		}
	}
}

// WSClient represents a WebSocket client
type WSClient struct {
	hub       *WSHub
	conn      *websocket.Conn
	send      chan []byte
	sessionID string
}

// readPump pumps messages from the WebSocket connection
func (c *WSClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}
		// We don't process incoming messages for now
		// This channel is primarily for receiving updates from Telegram
	}
}

// writePump pumps messages from the hub to the WebSocket connection
func (c *WSClient) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel.
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued messages to the current websocket message.
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
