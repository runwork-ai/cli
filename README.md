# runwork

The CLI for [Runwork](https://www.runwork.ai) -- develop, preview, and deploy Runwork apps from your local machine using any editor or AI coding tool.

## The Runwork Platform

Runwork is an AI workspace that brings AI agents, custom apps, and human teams into one place. Teams talk to the workspace to get quick answers, automate recurring work, or spin up full custom tools -- without switching between dozens of SaaS products.

This CLI is the local development interface to the platform. You write TypeScript, and the platform handles deployment, infrastructure, AI, and integrations:

- **Full-stack apps, zero infrastructure** -- Data storage, file hosting, background jobs, durable workflows, AI, and thousands of third-party integrations are all built into the platform. You write application code; Runwork runs it.
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
| `runwork spaces` | Spaces: containers for one kind of work |
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

Preview data lives inside the sandbox. Every entity starts empty again after the sandbox is
replaced, which a restart or a recycled container can both do. Your production data is untouched.

### `runwork spaces`

A space is a container for one kind of work: its files, AI instructions, skills, apps, automations
and conversations. `runwork spaces map` keeps a local folder in a space, so what you share is
uploaded for members of the space to read and conversations you run there are filed under the space
on this machine.

| Subcommand | Description |
|------------|-------------|
| `spaces suggest` | Propose spaces and things to keep in them from your local conversations (nothing is uploaded) |
| `spaces list` | Spaces in the workspace, with the folders on this machine mapped to each |
| `spaces map <folder>` | Keep a folder in a space: everything in it waits in Changes for you to share, and what you share is uploaded for members of the space to read. Conversations you run there are filed under the space on this machine, not uploaded |
| `spaces scope <folder>` | What a folder would share with a space, before you map it. Maps nothing and writes nothing |
| `spaces create <name>` | Create a space |
| `spaces default-folder [space]` | Where this space's folder would go on this machine if nobody chose. Creates nothing and maps nothing. |
| `spaces contents [space]` | What is filed under a space: its apps, skills, chats, workflows and endpoints |
| `spaces ls [space] [path]` | The files a space holds, as a teammate on another machine would see them |
| `spaces cat [space] <path>` | Print a file the space holds, as it is now or as it was at an earlier commit |
| `spaces history [space] <path>` | Who changed a file in a space and when, newest first, with the commit each version can be read at |
| `spaces put [space] <path> [file]` | Write any file into a space, from a local file or from stdin |
| `spaces rm [space] <path>` | Take a file out of a space. Its history stays, so a teammate can still see what it was. |
| `spaces instructions [space] [file]` | Read a space's `AGENTS.md`, or replace it from a local file or stdin |
| `spaces files [path]` | What is in a mapped folder, and which of it the space shares |
| `spaces include <path>` | Share a file or folder from a mapped folder with its space |
| `spaces exclude <path...>` | Stop sharing a file or folder, and take it out of the space |
| `spaces pause <folder>` | Stop this folder sharing on its own: its changes wait for runwork spaces share. Teammates' changes still arrive |
| `spaces resume <folder>` | Let this folder share its changes on its own, as each file stops changing |
| `spaces changes [folder]` | What this folder would send to its space next, and what is holding each of it back |
| `spaces sync [folder]` | Bring mapped folders and their spaces together: commit local changes, push, and pull what teammates added (no system git needed). With no folder named it syncs the mapped folder you are standing in; `--all` syncs every one of them |
| `spaces share [folder] [path...]` | Share what is waiting in a mapped folder now, without waiting for files to settle. Name any number of paths to share exactly those |
| `spaces launched <folder>` | Record that a conversation was just opened from this folder's space, so a cloud session with several space folders connected knows which one this is about |
| `spaces unmap <folder>` | Stop filing a folder under a space (this machine only) |
| `spaces reset <folder>` | Throw away this machine's copy of a mapped folder's space history, so the next sync rebuilds it from the space |
| `spaces prune` | Remove space histories on this machine that no folder maps to any more |
| `spaces mappings` | Folder-to-space mappings on this machine, the one you are standing in first |

`spaces rm` is also available as `spaces delete`. A mapped folder shares nothing until you ask for
it: run `spaces changes` to see what is waiting and `spaces share` to send it. Pass `--auto` to
`spaces map`, or run `spaces resume`, to have a folder share each file on its own once the file
stops changing.

Anything that files something under a space takes that space from the folder you are in when it is
mapped to one: `init`, `skills push`, `skills install`, `save-convo` and `share-convo`. `--space`
always wins, and each of them says which space it chose and why.

The verbs above that act on a space take it the same way, so inside a mapped folder `spaces ls`,
`spaces cat notes/plan.md` and `spaces contents` are about that folder's space. Naming the space
still works everywhere and still wins. How many arguments you give decides what they mean, so an
existing command keeps meaning what it always did: one argument to `ls` and `instructions` is the
space, and two to `put` are the space and the path. `cat`, `history` and `rm` read a single argument
as the path, and `put` takes the space from the folder when it is given a path alone, with the
content piped in (`runwork spaces put notes/plan.md < ./plan.md`). Reading falls back to your
personal space when the folder is mapped to nothing; `put`, `rm` and `instructions` ask you to name
one instead, because a write must not land somewhere nobody pointed at.

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
- **Third-party integrations** -- OAuth-managed connections to third-party services

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