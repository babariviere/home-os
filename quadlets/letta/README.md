# Letta

Letta AI agent server with LettaBot Discord integration.

## Setup

### 1. Start the services

```bash
sudo systemctl daemon-reload
sudo systemctl start letta.service letta-bot.service
```

### 2. Register AI provider

The Letta server requires providers to be registered via its API.

To register the Mistral provider:

```bash
curl -X POST http://localhost:8283/v1/providers/ \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "mistral",
    "provider_type": "mistral",
    "api_key": "<YOUR_MISTRAL_API_KEY>"
  }'
```

Verify models are available:

```bash
curl -s http://localhost:8283/v1/models/ | python3 -m json.tool
```

You should see models like `mistral/mistral-large-latest` in the list.

### 3. Restart lettabot

After registering the provider, restart the bot so it can create agents:

```bash
sudo systemctl restart letta-bot.service
```

## Troubleshooting

Check service logs:

```bash
sudo journalctl -u letta -f
sudo journalctl -u letta-bot -f
```

Common errors:

- **"Handle anthropic/claude-sonnet-4-6 not found, must be one of []"** - No provider
  is registered. Follow step 3 above.
- **"Failed to initialize session - no init message received"** - The underlying agent
  creation failed. Check `letta` server logs for the root cause.

List registered providers:

```bash
curl -s http://localhost:8283/v1/providers/
```
