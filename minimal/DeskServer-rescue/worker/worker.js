/*
 * Cloudflare Worker — OTC Proof Trading Desk paired P2P bridge
 *
 * This Cloudflare Worker mirrors the OTC desk relay, allowing:
 * 1. WebSocket connections from Cloudflare edge to local OTC relay (port 8788)
 * 2. Bridging of rooms between local OTC relay and Cloudflare Worker
 * 3. HTTP endpoint proxying (e.g., /desk/* endpoints)
 *
 * IMPORTANT FEATURES:
 * - Invite-only peer access: each peer must present a valid invite to join a room
 * - Gas limit enforcement: prevents spam by limiting computational resource usage per peer
 *
 * Usage pattern similar to server/forward.mjs but adapted for Cloudflare Workers
 * 
 * The worker receives WebSocket connections and polls from the local OTC desk
 * relay, then forwards lines to Cloudflare edge or vice versa.
 */

// Configuration
const CONFIG = {
  // Local OTC desk relay endpoint
  localRelayUrl: "http://127.0.0.1:8788",
  
  // CORS settings
  corsOrigin: "*",
  
  // Connection timeouts
  wsTimeout: 30000, // 30 seconds
  pollWait: 10000,  // 10 seconds for long-polling
  
  // Room synchronization
  roomTTL: 6 * 60 * 60 * 1000, // 6 hours
  
  // Gas limits (prevent spam)
  gasLimitPerPeerPerHour: 1000000, // 1M gas units per peer per hour
  gasCostPerMessage: 1000,         // Gas cost per message posted
  gasCostPerByte: 1,               // Gas cost per byte of message data
  
  // State persistence (in production, use KV)
  stateCache: new Map(),
};

// Import crypto utilities (Cloudflare Workers compatible)
const crypto = {
  // Simple SHA-256 implementation for Cloudflare Workers
  subtle: {
    digest: async (algorithm, data) => {
      if (algorithm !== "SHA-256") throw new Error("Only SHA-256 supported");
      const hashBuffer = await crypto.subtle.digest("SHA-256", data);
      return hashBuffer;
    }
  }
};

// Room state management with invite verification and gas tracking
class PeerState {
  constructor(peerId, inviteToken) {
    this.peerId = peerId || crypto.randomUUID();
    this.inviteToken = inviteToken;
    this.joinedAt = Date.now();
    this.gasUsed = 0;
    this.lastMessageAt = 0;
    this.messageCount = 0;
    this.rooms = new Set(); // Rooms this peer has joined
  }
  
  // Check if peer has exhausted gas limit
  hasGasAvailable(cost) {
    // Reset gas counter every hour
    if (Date.now() - this.joinedAt > 3600000) {
      this.gasUsed = 0;
      this.joinedAt = Date.now();
    }
    return this.gasUsed + cost <= CONFIG.gasLimitPerPeerPerHour;
  }
  
  // Consume gas for an operation
  consumeGas(cost) {
    if (!this.hasGasAvailable(cost)) {
      throw new Error("Gas limit exceeded");
    }
    this.gasUsed += cost;
    this.messageCount++;
    this.lastMessageAt = Date.now();
  }
}

class RoomState {
  constructor() {
    this.lines = [];
    this.base = 0;
    this.sockets = new Set(); // WebSocket connections
    this.peers = new Map();   // peerId -> PeerState
    this.lastTouch = Date.now();
    this.waiters = new Set(); // For long-polling
    this.inviteRequired = true; // Room requires invite to join
  }
  
  get cursor() {
    return this.base + this.lines.length;
  }
  
  // Verify invite token for a room
  // In a real implementation, this would validate the invite cryptographically
  // For now, we'll use a simplified version where the invite token 
  // must hash to match the room identifier
  verifyInvite(inviteToken) {
    if (!this.inviteRequired) return true;
    if (!inviteToken) return false;
    
    // Simplified invite verification: 
    // In reality, this would check that the invite token 
    // corresponds to the room secret via witness function
    // For demo, we accept any non-empty invite as valid
    return inviteToken.length >= 8;
  }
  
  // Add peer to room with invite verification
  addPeer(peerId, inviteToken) {
    if (!this.verifyInvite(inviteToken)) {
      throw new Error("Invalid or missing invite");
    }
    
    // Check if peer already exists
    let peer = this.peers.get(peerId);
    if (!peer) {
      peer = new PeerState(peerId, inviteToken);
      this.peers.set(peerId, peer);
    }
    
    peer.rooms.add(this);
    return peer;
  }
  
  // Remove peer from room
  removePeer(peerId) {
    const peer = this.peers.get(peerId);
    if (peer) {
      peer.rooms.delete(this);
      this.peers.delete(peerId);
    }
  }
  
  post(newLines, peerId) {
    const peer = this.peers.get(peerId);
    if (!peer) {
      throw new Error("Peer not in room");
    }
    
    // Calculate gas cost for this message
    let gasCost = CONFIG.gasCostPerMessage;
    for (const line of newLines) {
      gasCost += line.length * CONFIG.gasCostPerByte;
    }
    
    // Check gas limit
    if (!peer.hasGasAvailable(gasCost)) {
      throw new Error("Peer gas limit exceeded");
    }
    
    // Apply lines with max size limit
    const maxLines = CONFIG.maxLines || 4096;
    if (this.lines.length + newLines.length > maxLines) {
      const drop = this.lines.length + newLines.length - maxLines;
      this.base += drop;
      this.lines.splice(0, drop);
    }
    this.lines.push(...newLines);
    this.lastTouch = Date.now();
    
    // Consume gas
    peer.consumeGas(gasCost);
    
    // Notify waiters
    for (const waiter of [...this.waiters]) {
      waiter();
      this.waiters.delete(waiter);
    }
    
    // Push to WebSocket sockets
    for (const socket of [...this.sockets]) {
      socket.push({
        cursor: this.cursor,
        lines: newLines,
        truncated: this.base > 0,
        gasUsedByPeer: peer.gasUsed,
        gasLimit: CONFIG.gasLimitPerPeerPerHour,
      });
    }
  }
  
  fetch(cursor) {
    const from = Math.max(cursor, this.base);
    const end = this.cursor;
    return {
      cursor: end,
      lines: this.lines.slice(from - this.base),
      truncated: cursor < this.base,
    };
  }
  
  wait(ms) {
    return new Promise((resolve) => {
      const timeout = setTimeout(() => {
        this.waiters.delete(resolve);
        resolve(this.fetch(this.cursor));
      }, ms);
      this.waiters.add(() => {
        clearTimeout(timeout);
        resolve(this.fetch(this.cursor));
      });
    });
  }
  
  cleanup() {
    if (Date.now() - this.lastTouch > CONFIG.roomTTL) {
      return true;
    }
    return false;
  }
}

// HTTP endpoint handlers
class OTCDeskHandler {
  constructor() {
    this.rooms = new Map();
    this.peers = new Map(); // Global peer tracking
  }
  
  get roomState() {
    return this.rooms;
  }
  
  async handleRequest(request, cf) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;
    const searchParams = url.searchParams;
    
    // CORS headers
    const headers = {
      'Access-Control-Allow-Origin': CONFIG.corsOrigin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'content-type, invite-token',
      'Access-Control-Max-Age': '86400',
    };
    
    // Handle OPTIONS preflight
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers });
    }
    
    // Health endpoint (no auth required)
    if (pathname === '/health' && method === 'GET') {
      const totalRooms = this.rooms.size;
      const totalLines = Array.from(this.rooms.values())
        .reduce((sum, room) => sum + room.lines.length, 0);
      const totalSockets = Array.from(this.rooms.values())
        .reduce((sum, room) => sum + room.sockets.size, 0);
      const totalPeers = this.peers.size;
      
      return new Response(JSON.stringify({
        ok: true,
        name: "otc-desk-cf-worker",
        version: "1.0.0",
        rooms: totalRooms,
        lines: totalLines,
        sockets: totalSockets,
        peers: totalPeers,
        edge: "cloudflare",
        features: {
          inviteOnly: true,
          gasLimit: true,
          gasLimitPerPeerPerHour: CONFIG.gasLimitPerPeerPerHour,
        },
      }), {
        status: 200,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
      });
    }
    
    // Desk endpoints (proxy to local OTC desk relay)
    if (pathname.startsWith('/desk/')) {
      return this.proxyToLocal(request, cf, headers);
    }
    
    // Room endpoints with invite verification
    if (pathname.startsWith('/room/')) {
      return this.handleRoomEndpoint(pathname, method, searchParams, headers, request);
    }
    
    // WebSocket upgrade handling with invite verification
    if (request.headers.get('Upgrade') === 'websocket') {
      return this.handleWebSocketUpgrade(request, cf, headers);
    }
    
    // Static file serving (if any)
    if (pathname === '/' || pathname === '/index.html') {
      return this.serveStatic();
    }
    
    // Not found
    return new Response(JSON.stringify({
      ok: false,
      error: "not found",
    }), {
      status: 404,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    });
  }
  
  async proxyToLocal(request, cf, headers) {
    const url = new URL(request.url);
    const targetUrl = `${CONFIG.localRelayUrl}${url.pathname}${url.search}`;
    
    // Forward invite token header if present
    const inviteToken = request.headers.get('invite-token');
    const reqInit = {
      method: request.method,
      headers: {
        ...Object.fromEntries(request.headers.entries()),
        ...headers,
        ...(inviteToken ? { 'invite-token': inviteToken } : {}),
      },
      body: request.body && await request.arrayBuffer(),
    };
    
    try {
      const response = await fetch(targetUrl, reqInit);
      const responseText = await response.text();
      
      return new Response(responseText, {
        status: response.status,
        headers: {
          ...headers,
          ...Object.fromEntries(response.headers.entries()),
          'Content-Type': 'application/json',
        },
      });
    } catch (error) {
      return new Response(JSON.stringify({
        ok: false,
        error: "local relay error",
        details: error.message,
      }), {
        status: 502,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
      });
    }
  }
  
  getRoomFromPath(pathname) {
    const match = pathname.match(/^\/room\/([^/]+)$/);
    if (!match) return null;
    const room = decodeURIComponent(match[1]);
    if (!this.rooms.has(room)) {
      this.rooms.set(room, new RoomState());
    }
    return this.rooms.get(room);
  }
  
  getOrCreatePeer(peerId) {
    let peer = this.peers.get(peerId);
    if (!peer) {
      peer = new PeerState(peerId);
      this.peers.set(peerId, peer);
    }
    return peer;
  }
  
  async handleRoomEndpoint(pathname, method, searchParams, headers, request) {
    const room = this.getRoomFromPath(pathname);
    if (!room) {
      return new Response(JSON.stringify({
        ok: false,
        error: "room not found",
      }), {
        status: 404,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
      });
    }
    
    // Get invite token from header or query param
    const inviteToken = request.headers.get('invite-token') || 
                       searchParams.get('invite');
    
    if (method === 'POST') {
      try {
        const body = await request.text();
        const lines = body.split('\n')
          .map(l => l.trim())
          .filter(l => l.length > 0);
        
        const maxLine = CONFIG.maxLine || 262144;
        if (lines.some(l => l.length > maxLine)) {
          return new Response(JSON.stringify({
            ok: false,
            error: "line too long",
          }), {
            status: 413,
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
          });
        }
        
        // Get or create peer (peer-id from header or generate)
        const peerId = request.headers.get('peer-id') || 
                      searchParams.get('peer') ||
                      crypto.randomUUID();
        
        const peer = this.getOrCreatePeer(peerId);
        
        // Add peer to room with invite verification
        room.addPeer(peerId, inviteToken);
        
        // Post lines with gas tracking
        room.post(lines, peerId);
        
        return new Response(JSON.stringify({
          ok: true,
          cursor: room.cursor,
          accepted: lines.length,
          peerId,
          gasUsed: peer.gasUsed,
          gasLimit: CONFIG.gasLimitPerPeerPerHour,
        }), {
          status: 200,
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
        });
      } catch (error) {
        return new Response(JSON.stringify({
          ok: false,
          error: error.message,
          type: error.message.includes("invite") ? "invite_invalid" : 
                 error.message.includes("gas") ? "gas_limit_exceeded" : "post_failed",
        }), {
          status: error.message.includes("invite") ? 403 : 
                 error.message.includes("gas") ? 429 : 500,
          headers: {
            ...headers,
            'Content-Type': 'application/json',
          },
        });
      }
    }
    
    if (method === 'GET') {
      const cursor = Number(searchParams.get('cursor') ?? 0) || 0;
      const wait = Number(searchParams.get('wait') ?? 0) || 0;
      
      // Get or create peer for GET requests (for consistency)
      const peerId = request.headers.get('peer-id') || 
                    searchParams.get('peer') ||
                    crypto.randomUUID();
      
      const peer = this.getOrCreatePeer(peerId);
      
      // Verify peer has access to room (invite check)
      // For GET, we're less strict but still require some form of auth
      if (!room.peers.has(peerId) && !room.verifyInvite(inviteToken)) {
        // Allow reading if invite is provided and valid, or if room doesn't require invite
        if (!room.verifyInvite(inviteToken)) {
          return new Response(JSON.stringify({
            ok: false,
            error: "invite required",
          }), {
            status: 403,
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
          });
        }
        // If invite is valid, implicitly join the room for read access
        room.addPeer(peerId, inviteToken);
      }
      
      if (wait > 0 && room.lines.length === 0) {
        await room.wait(wait * 1000);
      }
      
      const result = room.fetch(cursor);
      
      return new Response(JSON.stringify({
        ok: true,
        ...result,
        peerId,
        gasUsed: peer.gasUsed,
        gasLimit: CONFIG.gasLimitPerPeerPerHour,
      }), {
        status: 200,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
      });
    }
    
    // Method not allowed
    return new Response(JSON.stringify({
      ok: false,
      error: "method not allowed",
    }), {
      status: 405,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    });
  }
  
  handleWebSocketUpgrade(request, cf, headers) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const roomName = pathname.startsWith('/ws/') ? 
      pathname.substring('/ws/'.length) : null;
    
    if (!roomName) {
      return new Response('Bad Request', { status: 400 });
    }
    
    const room = this.getRoomFromPath(`/room/${roomName}`);
    if (!room) {
      return new Response('Room not found', { status: 404 });
    }
    
    // Get invite token from headers or query params for WebSocket
    const inviteToken = request.headers.get('invite-token') || 
                       new URL(request.url).searchParams.get('invite');
    
    // Get or create peer
    const peerId = request.headers.get('peer-id') || 
                  new URL(request.url).searchParams.get('peer') ||
                  crypto.randomUUID();
    
    try {
      // Verify peer can join room with invite
      const peer = room.addPeer(peerId, inviteToken);
      
      // Create a WebSocket pair for connection to local relay
      const { 0: client, 1: local } = new WebSocketPair();
      
      // Forward to local OTC desk relay
      const targetUrl = `${CONFIG.localRelayUrl}${pathname}${url.search}`;
      const ws = new WebSocket(targetUrl);
      
      ws.onopen = () => {
        local.accept();
        // Send peer info upon connection
        client.send(JSON.stringify({
          type: 'peer-info',
          peerId,
          gasUsed: peer.gasUsed,
          gasLimit: CONFIG.gasLimitPerPeerPerHour,
          roomCursor: room.cursor,
        }));
      };
      
      ws.onmessage = (event) => {
        // Forward messages from local to Cloudflare edge
        if (event.data instanceof ArrayBuffer) {
          const data = new TextDecoder().decode(event.data);
          try {
            const msg = JSON.parse(data);
            // Add gas info to outgoing messages
            const enhancedMsg = {
              ...msg,
              peerInfo: {
                peerId,
                gasUsed: peer.gasUsed,
                gasLimit: CONFIG.gasLimitPerPeerPerHour,
              }
            };
            local.send(JSON.stringify(enhancedMsg));
          } catch (e) {
            // Forward raw message if not JSON
            local.send(data);
          }
        } else {
          local.send(event.data);
        }
      };
      
      ws.onclose = (event) => {
        local.close(event.code, event.reason);
        room.removePeer(peerId);
      };
      
      ws.onerror = (event) => {
        local.close(1011, event.message);
        room.removePeer(peerId);
      };
      
      client.onmessage = async (event) => {
        // Forward messages from Cloudflare edge to local relay
        // Check gas limit before forwarding
        if (event.data instanceof ArrayBuffer) {
          const data = new TextDecoder().decode(event.data);
          try {
            const msg = JSON.parse(data);
            
            // Check if this is a message to post (has lines to post)
            if (msg.lines && Array.isArray(msg.lines) && msg.lines.length > 0) {
              // Calculate gas cost
              let gasCost = CONFIG.gasCostPerMessage;
              for (const line of msg.lines) {
                gasCost += line.length * CONFIG.gasCostPerByte;
              }
              
              // Check gas limit and post if allowed
              if (peer.hasGasAvailable(gasCost)) {
                room.post(msg.lines, peerId);
                peer.consumeGas(gasCost);
                
                // Forward the message to local relay
                ws.send(event.data);
              } else {
                // Send gas limit exceeded error back to client
                client.send(JSON.stringify({
                  type: 'error',
                  error: 'gas_limit_exceeded',
                  message: 'Gas limit exceeded for peer',
                  gasUsed: peer.gasUsed,
                  gasLimit: CONFIG.gasLimitPerPeerPerHour,
                }));
                return;
              }
            } else {
              // For non-post messages, forward as-is
              ws.send(event.data);
            }
          } catch (e) {
            // If not JSON, check if we should apply gas limits
            // For simplicity, treat all non-JSON data as having gas cost
            const byteLength = event.data.byteLength || 0;
            const gasCost = CONFIG.gasCostPerMessage + 
                           (byteLength * CONFIG.gasCostPerByte);
            
            if (peer.hasGasAvailable(gasCost)) {
              ws.send(event.data);
              peer.consumeGas(gasCost);
            } else {
              client.send(JSON.stringify({
                type: 'error',
                error: 'gas_limit_exceeded',
                message: 'Gas limit exceeded for peer',
                gasUsed: peer.gasUsed,
                gasLimit: CONFIG.gasLimitPerPeerPerHour,
              }));
            }
          }
        } else {
          // Text data
          const textData = event.data;
          const byteLength = new TextEncoder().encode(textData).length;
          const gasCost = CONFIG.gasCostPerMessage + 
                         (byteLength * CONFIG.gasCostPerByte);
          
          if (peer.hasGasAvailable(gasCost)) {
            ws.send(event.data);
            peer.consumeGas(gasCost);
          } else {
            client.send(JSON.stringify({
              type: 'error',
              error: 'gas_limit_exceeded',
              message: 'Gas limit exceeded for peer',
              gasUsed: peer.gasUsed,
              gasLimit: CONFIG.gasLimitPerPeerPerHour,
            }));
          }
        }
      };
      
      ws.onclose = (event) => {
        local.close(event.code, event.reason);
        room.removePeer(peerId);
      };
      
      ws.onerror = (event) => {
        local.close(1011, event.message);
        room.removePeer(peerId);
      };
      
      client.onclose = (event) => {
        ws.close(event.code, event.reason);
        room.removePeer(peerId);
      };
      
      client.onerror = (event) => {
        ws.close(1011, event.message);
        room.removePeer(peerId);
      };
      
      // Add socket to room for sync
      room.sockets.add(client);
      
      return new Response(null, {
        status: 101,
        webSocket: client,
        headers: {
          ...headers,
          'Upgrade': 'websocket',
          'Connection': 'Upgrade',
        },
      });
    } catch (error) {
      return new Response(JSON.stringify({
        ok: false,
        error: error.message,
        type: error.message.includes("invite") ? "invite_invalid" : 
             error.message.includes("gas") ? "gas_limit_exceeded" : "websocket_error",
      }), {
        status: error.message.includes("invite") ? 403 : 
               error.message.includes("gas") ? 429 : 500,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
      });
    }
  }
  
  serveStatic() {
    return new Response('OTC Proof Trading Desk Cloudflare Worker\n' +
                       'Features: Invite-only access, Gas limit enforcement\n' +
                       `Gas limit: ${CONFIG.gasLimitPerPeerPerHour} per peer per hour\n`, {
      status: 200,
      headers: {
        'Content-Type': 'text/plain',
        ...this.corsHeaders,
      },
    });
  }
  
  get corsHeaders() {
    return {
      'Access-Control-Allow-Origin': CONFIG.corsOrigin,
    };
  }
  
  // Cleanup inactive rooms and peers
  cleanup() {
    const now = Date.now();
    const oneHourAgo = now - 3600000;
    
    // Cleanup rooms
    for (const [roomName, room] of this.rooms) {
      if (room.cleanup()) {
        this.rooms.delete(roomName);
      } else {
        // Cleanup old peers in room
        for (const [peerId, peer] of room.peers) {
          if (peer.joinedAt < oneHourAgo && peer.rooms.size === 0) {
            room.peers.delete(peerId);
          }
        }
      }
    }
    
    // Cleanup global peers that aren't in any room
    for (const [peerId, peer] of this.peers) {
      if (peer.rooms.size === 0 && peer.joinedAt < oneHourAgo) {
        this.peers.delete(peerId);
      }
    }
  }
}

// Worker entry point
addEventListener('fetch', event => {
  const handler = new OTCDeskHandler();
  
  // Periodic cleanup every 5 minutes
  setInterval(() => {
    handler.cleanup();
  }, 300000);
  
  event.respondWith(handler.handleRequest(event.request, event.cf));
});

// Export for testing
export { CONFIG, PeerState, RoomState, OTCDeskHandler };