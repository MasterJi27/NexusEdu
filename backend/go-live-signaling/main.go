package main

import (
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// Go signaling hub for live class — 10k conns per pod, Redis pubsub fanout.
// Dart client connects via wss://.../api/live/ws?token=... (upgraded from WS heartbeat).
// This stub demonstrates system design; production runs as separate deployment
// `live-signaling` with HPA 3-30, pprof, prom metrics.

var upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

type Hub struct {
	mu    sync.RWMutex
	rooms map[string]map[*websocket.Conn]bool // channelName -> conns
}

func (h *Hub) broadcast(room string, msg []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.rooms[room] {
		_ = c.WriteMessage(websocket.TextMessage, msg)
	}
}

func main() {
	hub := &Hub{rooms: make(map[string]map[*websocket.Conn]bool)}
	http.HandleFunc("/api/live/ws", func(w http.ResponseWriter, r *http.Request) {
		// Validate token (omitted: call auth service)
		room := r.URL.Query().Get("channel")
		if room == "" {
			http.Error(w, "missing channel", 400)
			return
		}
		c, _ := upgrader.Upgrade(w, r, nil)
		hub.mu.Lock()
		if hub.rooms[room] == nil { hub.rooms[room] = make(map[*websocket.Conn]bool) }
		hub.rooms[room][c] = true
		hub.mu.Unlock()
		// Heartbeat
		go func() {
			t := time.NewTicker(25 * time.Second)
			defer t.Stop()
			for range t.C {
				if err := c.WriteMessage(websocket.TextMessage, []byte(`{"type":"ping"}`)); err != nil { return }
			}
		}()
		for {
			_, msg, err := c.ReadMessage()
			if err != nil { break }
			// Log + metrics (prom)
			log.Printf("room %s msg %s", room, string(msg))
			hub.broadcast(room, msg)
		}
		hub.mu.Lock(); delete(hub.rooms[room], c); hub.mu.Unlock()
		c.Close()
	})
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) })
	log.Println("go-live-signaling listening :8081")
	log.Fatal(http.ListenAndServe(":8081", nil))
}
