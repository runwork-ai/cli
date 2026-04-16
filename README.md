# runwork

The CLI for [Runwork](https://www.runwork.ai) -- develop, preview, and deploy Runwork apps from your local machine using any editor or AI coding tool.

## The Runwork Platform

Runwork is an AI workspace that brings AI agents, custom apps, and human teams into one place. Teams talk to the workspace to get quick answers, automate recurring work, or spin up full custom tools -- without switching between dozens of SaaS products.

This CLI is the local development interface to the platform. You write TypeScript, and the platform handles deployment, infrastructure, AI, and integrations:

- **Full-stack apps, zero infrastructure** -- Data storage, file hosting, background jobs, durable workflows, AI, and 3,200+ third-party integrations are all built into the platform. You write application code; Runwork runs it.
- **Zero to app in seconds** -- Describe what you need and Runwork generates it. Developers customize with code using the [`@runworkai/framework`](https://www.npmjs.com/package/@runworkai/framework).
- **Instant deployments** -- Push code and get a live URL. Preview environments while you develop, production at the edge.
- **Built-in AI agents** -- Conversational agents that read data, take actions, and coordinate across apps. No API keys or model configuration to manage.
- **Connected apps** -- Apps in a workspace share entities, call each other's APIs, communicate through channels, and present a unified experience.
- **Every app is an MCP server and a skill** -- Deploy an app, and it automatically becomes an MCP server and a callable skill. Your AI tools and workspace agents can use your apps directly -- completing the loop from development to AI consumption.
- **AI-native local development** -- Every scaffolded project includes `CLAUDE.md`, `AGENTS.md`, and full framework type definitions in `.runwork/types/`. AI coding tools (Claude Code, Cursor, Codex, or any editor) understand the Runwork framework out of the box -- no setup, no guessing. The CLI keeps code and preview in sync while you or your AI agent write code.

## Install

### macOS / Linux (recommended)

```bash
curl -fsSL https://runwork.ai/install.sh | sh
```

### macOS (Homebrew)

```bash
brew install runwork-ai/tap/runwork
```

### npm

```bash
npm install -g runwork
```

### Direct download

Download from [GitHub Releases](https://github.com/runwork-ai/cli/releases).

## Quick Start

```bash
runwork login          # Authenticate with Runwork
runwork init           # Create a new app
runwork dev            # Start developing with live preview
```

## Commands

| Command | Description |
|---------|-------------|
| `runwork login` | Authenticate with the Runwork platform via browser OAuth |
| `runwork init` | Create a new app -- prompts for name and workspace, scaffolds the project |
| `runwork clone` | Clone an existing Runwork app to your machine |
| `runwork dev` | Start local development with live preview and auto-sync |
| `runwork deploy` | Deploy to production |
| `runwork logout` | Remove stored credentials |

### `runwork dev`

The main development command. When you run `runwork dev`:

1. Pulls the latest code from the Runwork git remote
2. Starts a cloud preview sandbox
3. Watches local files for changes
4. Auto-commits and pushes changes to sync with the preview
5. Prints the preview URL for browser access
6. Populates `.runwork/types/` with framework type definitions for AI coding tools

Edit files in your editor, and changes appear in the preview automatically.

## How It Works

Runwork apps are full-stack TypeScript projects built with the [`@runworkai/framework`](https://www.npmjs.com/package/@runworkai/framework). The CLI handles the development lifecycle:

- **Git-based sync** -- Your app is backed by a git repository on the Runwork platform. The CLI uses git push/pull to sync code between your machine and the cloud.
- **Cloud preview** -- `runwork dev` spins up a live preview sandbox. Changes sync automatically as you edit files.
- **Framework types** -- The CLI populates `.runwork/types/` with framework type definitions so AI coding tools can understand the full API without needing `node_modules`.
- **Zero config** -- Project settings live in `.runwork.json`. No deployment scripts to manage locally.

## What You Can Build

Every Runwork app gets built-in access to:

- **Data storage** -- Persistent entities with search, sort, filter, and pagination
- **AI agents** -- Conversational agents with tool use, memory, and integration access
- **Backend AI** -- `generateText`, `generateObject`, `streamText` for routes, workflows, and jobs
- **Durable workflows** -- Multi-step processes that survive failures, with retries and event waiting
- **Scheduled jobs** -- Cron-based background tasks
- **File storage** -- Upload and manage files and media
- **Public endpoints** -- Authenticated APIs for external consumers
- **Cross-app workspaces** -- Shared entities, channels, and notifications between apps
- **3,200+ integrations** -- OAuth-managed connections to third-party services

## Project Structure

After `runwork init`, your project looks like this:

```
my-app/
  .runwork.json          # App config (app ID, workspace, remote URL)
  .runwork/
    blueprint.json       # App feature blueprint (entities, agents, etc.)
    types/               # Framework type definitions (auto-populated)
  worker/                # Backend code
    entities.ts          # Data entities
    routes.ts            # API routes
    agents.ts            # AI agents
    workflows.ts         # Durable workflows
    schedules.ts         # Scheduled jobs
    endpoints.ts         # Public API endpoints
  src/                   # Frontend React code
    pages/               # Page components
    components/          # UI components
  shared/types.ts        # Shared types between frontend and backend
```

## Requirements

- Git
- A [Runwork](https://www.runwork.ai) account
- Node.js 18+ (only required when installing via npm)

## Links

- [Runwork Platform](https://www.runwork.ai)
- [`@runworkai/framework`](https://www.npmjs.com/package/@runworkai/framework) -- The TypeScript framework for building Runwork apps

## License

MIT