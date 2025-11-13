/**
 * Simple WebSocket server for testing WebSocket client implementation
 * This server echoes back any message it receives
 */

const WebSocket = require('ws');

// Create WebSocket server on port 8080
const wss = new WebSocket.Server({ port: 8080 });

console.log('WebSocket server started on port 8080');

// Handle new connections
wss.on('connection', (ws, req) => {
  console.log('New client connected from', req.socket.remoteAddress);
  
  // Send welcome message
  ws.send('Welcome to the WebSocket server!');
  
  // Handle incoming messages
  ws.on('message', (message) => {
    console.log('Received message:', message.toString());
    
    // Echo the message back to the client
    ws.send(`Echo: ${message.toString()}`);
    
    // Special handling for ping messages
    if (message.toString() === 'ping') {
      ws.send('pong');
    }
  });
  
  // Handle client disconnect
  ws.on('close', () => {
    console.log('Client disconnected');
  });
  
  // Handle errors
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Handle server errors
wss.on('error', (error) => {
  console.error('WebSocket server error:', error);
});

console.log('WebSocket server is running. Connect to ws://localhost:8080');