# evey-setup

Bootstrapper for a hermes-agent autonomous AI stack. Sets up hermes-agent + LiteLLM + plugins with free models.

## Setup Phases
```bash
bash setup.sh              # Phase 1: prerequisites, scaffold, .env, clone hermes
bash setup-services.sh     # Phase 2: pick tier (base/services/full), start Docker
bash install-plugins.sh    # Phase 3: pick plugins from 42-evey/hermes-plugins
bash configure.sh          # Phase 4: brain model, compression, crons, SOUL.md
```

## Directory After Install
```
~/evey-stack/
├── config/litellm.yaml         # Model routing (edit to add models)
├── data/hermes/config.yaml     # Agent config
├── data/hermes/plugins/        # Installed plugins
├── data/hermes/skills/         # Skill definitions
├── data/hermes/SOUL.md         # Agent personality (customize this)
├── data/hermes/cron/           # Cron job configs
├── data/claude-bridge/         # Mother↔Agent bridge
├── docker-compose.yml          # Active services
├── .env                        # ALL secrets here (chmod 600)
└── .setup-state                # Tracks install dir + tier
```

## Key Commands
```bash
docker compose up -d                    # Start all services
docker compose ps                       # Check health
docker compose logs -f hermes-agent     # Watch agent logs
docker exec hermes-agent hermes cron list  # See cron jobs
```

## Security Rules
- ALL secrets in `.env` only — never hardcode in docker-compose or configs
- ALL ports bind to `127.0.0.1` — nothing exposed to network
- `.env` has `chmod 600` — owner-only read
- `.gitignore` excludes `.env`, `data/`, `backups/`
- Generated keys use `openssl rand` (cryptographically secure)

## Adding Plugins
```bash
bash install-plugins.sh    # Re-run to add more categories
# Or manually:
cp -r plugin-dir/ data/hermes/plugins/
docker compose restart hermes-agent
```

## Adding Services
Edit `docker-compose.yml` or re-run `bash setup-services.sh` with a higher tier.

## Updating
```bash
cd ~/evey-stack/src/hermes-agent && git pull
docker compose build hermes-agent
docker compose up -d --force-recreate hermes-agent
```

## Common Issues
- `Unknown provider 'litellm'` → use `provider: openrouter` with `base_url: http://hermes-litellm:4000/v1`
- Empty model responses → add `reasoning: { exclude: true }` to model config in litellm.yaml
- MQTT connect loop → ensure unique client_id per connection
