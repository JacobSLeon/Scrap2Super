const { spawn } = require('child_process');
const readline = require('readline');

const STUDIO_MCP_PATH = "C:\\Users\\yojac\\AppData\\Local\\Roblox\\Versions\\version-9fe94fb0e9d84c25\\StudioMCP.exe";

const child = spawn(STUDIO_MCP_PATH, process.argv.slice(2), {
    stdio: ['pipe', 'pipe', 'inherit']
});

child.stdout.on('data', (data) => {
    process.stdout.write(data);
});

child.on('exit', (code) => {
    process.exit(code || 0);
});

child.on('error', (err) => {
    console.error('Failed to start StudioMCP:', err);
    process.exit(1);
});

const rl = readline.createInterface({
    input: process.stdin,
    terminal: false
});

rl.on('line', (line) => {
    const trimmed = line.trim();
    if (!trimmed) return;

    try {
        const msg = JSON.parse(trimmed);
        if (msg && msg.method === 'server/discover') {
            if (msg.id !== undefined) {
                const response = JSON.stringify({
                    jsonrpc: "2.0",
                    id: msg.id,
                    error: {
                        code: -32601,
                        message: "Method not found"
                    }
                }) + "\n";
                process.stdout.write(response);
            }
            return;
        }
    } catch (e) {
        // Pass through
    }

    child.stdin.write(line + "\n");
});
