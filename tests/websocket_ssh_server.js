/**
 * WebSocket SSH Server Proxy
 * Bridges WebSocket connections to SSH servers
 */

const WebSocket = require('ws');
const { Client } = require('ssh2');

const wss = new WebSocket.Server({ port: 8080 });

console.log('WebSocket SSH Server started on port 8080');

wss.on('connection', (ws, req) => {
  console.log('New client connected from', req.socket.remoteAddress);
  
  let sshClient = null;
  let sshStream = null;
  
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      
      // Handle SSH connection request
      if (data.type === 'connect') {
        console.log(`Connecting to SSH: ${data.host}:${data.port}`);
        
        sshClient = new Client();
        
        sshClient.on('ready', () => {
          console.log('SSH connection established');
          ws.send(JSON.stringify({ type: 'connected' }));
          
          // Open shell session
          sshClient.shell((err, stream) => {
            if (err) {
              console.error('Failed to open shell:', err);
              ws.send(JSON.stringify({ type: 'error', message: err.message }));
              return;
            }
            
            sshStream = stream;
            
            // Forward SSH output to WebSocket
            stream.on('data', (data) => {
              ws.send(JSON.stringify({ 
                type: 'data', 
                data: data.toString('base64') 
              }));
            });
            
            stream.on('close', () => {
              console.log('SSH stream closed');
              ws.send(JSON.stringify({ type: 'closed' }));
            });
            
            stream.stderr.on('data', (data) => {
              ws.send(JSON.stringify({ 
                type: 'error', 
                message: data.toString() 
              }));
            });
          });
        });
        
        sshClient.on('error', (err) => {
          console.error('SSH error:', err);
          ws.send(JSON.stringify({ type: 'error', message: err.message }));
        });
        
        sshClient.on('close', () => {
          console.log('SSH connection closed');
          ws.send(JSON.stringify({ type: 'disconnected' }));
        });
        
        // Connect to SSH server
        sshClient.connect({
          host: data.host,
          port: data.port || 22,
          username: data.username,
          password: data.password
        });
      }
      
      // Handle SSH input
      else if (data.type === 'input') {
        if (sshStream) {
          const input = Buffer.from(data.data, 'base64').toString();
          sshStream.write(input);
        }
      }
      
      // Handle disconnect
      else if (data.type === 'disconnect') {
        if (sshClient) {
          sshClient.end();
          sshClient = null;
        }
      }
      
    } catch (error) {
      console.error('Message processing error:', error);
      ws.send(JSON.stringify({ type: 'error', message: error.message }));
    }
  });
  
  ws.on('close', () => {
    console.log('WebSocket client disconnected');
    if (sshClient) {
      sshClient.end();
    }
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

wss.on('error', (error) => {
  console.error('WebSocket server error:', error);
});

console.log('WebSocket SSH Proxy is running. Connect to ws://localhost:8080');