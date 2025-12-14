# Social Scribe - AI Coding Instructions

## Project Overview
Phoenix LiveView application that syncs Google Calendar meetings, sends AI notetaker bots (via Recall.ai), generates follow-up emails and social media content using Google Gemini, then posts to LinkedIn/Facebook.

## Architecture

### Context Boundaries (Phoenix Contexts)
- **Accounts** - User management, OAuth credentials (Google, LinkedIn, Facebook), session tokens
- **Calendar** - Calendar events synced from Google, linked to user credentials
- **Bots** - Recall.ai bot records, status tracking, lifecycle management
- **Meetings** - Meeting data, transcripts, participants (created after bot completes)
- **Automations** - User-defined AI content generation rules per platform

### Data Flow
1. User authenticates via OAuth (`AuthController` → Ueberauth)
2. `CalendarSyncronizer` fetches events via `GoogleCalendarApi`
3. User enables recording → `Bots.create_and_dispatch_bot/2` creates `RecallBot`
4. `BotStatusPoller` (Oban cron) polls Recall.ai until status is "done"
5. `AIContentGenerationWorker` generates follow-up email + automation results
6. `Poster` publishes to LinkedIn/Facebook via respective APIs

### External API Pattern
All external APIs use behaviour + implementation pattern for testability:
```elixir
# Behaviour definition (e.g., lib/social_scribe/recall_api.ex)
@callback create_bot(meeting_url, join_at) :: {:ok, Tesla.Env.t()} | {:error, any()}
def create_bot(url, join_at), do: impl().create_bot(url, join_at)
defp impl, do: Application.get_env(:social_scribe, :recall_api, SocialScribe.Recall)

# Real implementation (e.g., lib/social_scribe/recall.ex)
@behaviour SocialScribe.RecallApi
@impl SocialScribe.RecallApi
def create_bot(meeting_url, join_at) do ...
```
**APIs following this pattern:** `RecallApi`, `GoogleCalendarApi`, `TokenRefresherApi`, `AIContentGeneratorApi`, `LinkedInApi`, `FacebookApi`

## Developer Commands
```bash
mix setup              # Install deps, create DB, migrate, setup assets
mix test               # Run tests (creates DB, migrates automatically)
mix phx.server         # Start dev server at localhost:4000
mix ecto.reset         # Drop, create, migrate, seed
```

## Testing Patterns

### Mox for External APIs
Mocks defined in `test/test_helper.exs`. Use `import Mox` and set expectations:
```elixir
import Mox
setup :verify_on_exit!

test "example" do
  SocialScribe.RecallApiMock
  |> expect(:get_bot, fn _id -> {:ok, %Tesla.Env{body: %{status: "done"}}} end)
end
```

### Test Fixtures
Located in `test/support/fixtures/`. Use `<context>_fixture()` functions:
```elixir
import SocialScribe.AccountsFixtures
user = user_fixture()
credential = user_credential_fixture(%{user_id: user.id})
```

### Oban Testing
Configured with `testing: :manual` in test env. Use `Oban.Testing` helpers:
```elixir
use Oban.Testing, repo: SocialScribe.Repo
assert_enqueued worker: SocialScribe.Workers.AIContentGenerationWorker
```

## Background Jobs (Oban)
- **Queues:** `default`, `ai_content`, `polling`
- **Cron:** `BotStatusPoller` runs every 2 minutes to poll pending bots
- **Workers location:** `lib/social_scribe/workers/`

## LiveView Patterns
- Dashboard routes require authentication (`require_authenticated_user` plug)
- Use `SocialScribeWeb.LiveHooks` for cross-cutting concerns (e.g., `assign_current_path`)
- Layout: `:dashboard` for authenticated pages, `:root` for public

## Key Files
- [lib/social_scribe_web/router.ex](lib/social_scribe_web/router.ex) - All routes, auth pipelines
- [config/config.exs](config/config.exs) - Oban queues, Ueberauth providers
- [test/test_helper.exs](test/test_helper.exs) - Mox mock definitions
- [lib/social_scribe/workers/](lib/social_scribe/workers/) - Background job implementations

## Environment Variables (Runtime)
Required in `config/runtime.exs` for production:
- `RECALL_API_KEY`, `RECALL_REGION` - Recall.ai notetaker
- `GEMINI_API_KEY` - Google Gemini AI
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` - OAuth
- `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` - OAuth
- `FACEBOOK_CLIENT_ID`, `FACEBOOK_CLIENT_SECRET` - OAuth
- `DATABASE_URL`, `SECRET_KEY_BASE` - Standard Phoenix
