#!/usr/bin/env node
const { spawn } = require('child_process');
const readline = require('readline');

const n8nMcp = spawn('/home/steve/.local/bin/n8n-mcp', [], {
  env: {
    ...process.env,
    N8N_API_URL: 'https://n8n-150285098361.europe-west2.run.app/',
    N8N_API_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmODYwYWNmYy1hMTY1LTRiNzYtOTI0NC0xNTk5NTc5YzJiYTYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiODRlMjRiODQtYTA3Mi00MzdlLWE2NDctNWUzMTQ1YmQ2MzIxIiwiaWF0IjoxNzczMTU2ODE3fQ.G-9DxmJK38ugzKwilbtaKc4fQqefSAEK3Icf2ke_U2U'
  }
});

const rl = readline.createInterface({ input: n8nMcp.stdout, crlfDelay: Infinity });
const stdin = n8nMcp.stdin;

let sessionId = null;
let id = 1;

function send(method, params = {}) {
  return new Promise((resolve) => {
    const msg = JSON.stringify({ jsonrpc: '2.0', id: id++, method, params });
    stdin.write(msg + '\n');
    
    const handler = (line) => {
      try {
        const data = JSON.parse(line);
        if (data.id === id - 1) {
          rl.removeListener('line', handler);
          resolve(data);
        }
      } catch (e) {}
    };
    rl.on('line', handler);
    
    setTimeout(() => {
      rl.removeListener('line', handler);
      resolve(null);
    }, 10000);
  });
}

async function main() {
  // Initialize
  const init = await send('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'workflow-deployer', version: '1.0' }
  });
  console.log('Initialized:', JSON.stringify(init?.result?.serverInfo, null, 2));
  
  // List tools
  const tools = await send('tools/list');
  console.log('\nAvailable tools:');
  if (tools?.result?.tools) {
    tools.result.tools.forEach(t => console.log(`  - ${t.name}: ${t.description?.substring(0, 60)}...`));
  }
  
  // Shutdown
  await send('shutdown');
  n8nMcp.kill();
}

main().catch(console.error);
