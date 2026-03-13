Initialize a Saturn workspace session. The session name is: `$ARGUMENTS`

Usage: `/init <session-name>` (e.g. `/init coplanner`, `/init prod-3327`)

## Step 1: Read Session Files

Read both files:
- `/Users/irfanshaikh/Documents/saturn/workspace/sessions/$ARGUMENTS/.info` — description, todo, log
- `/Users/irfanshaikh/Documents/saturn/workspace/sessions/$ARGUMENTS/config.yaml` — branch config

Parse from `.info`:
- **description** — what this session is for
- **todo** — outstanding tasks
- **log** — recent activity

Parse from `config.yaml`:
- **branches** — which branch each service is on

If `.info` doesn't exist, run `ls /Users/irfanshaikh/Documents/saturn/workspace/sessions/` and ask the user which session to use.

## Step 2: Establish Working Context

Hold this for the entire conversation — all code edits go into the **session's code root**, not the master `workspace/code/`:

- **Session root**: `/Users/irfanshaikh/Documents/saturn/workspace/sessions/$ARGUMENTS/`
- **Code root**: `/Users/irfanshaikh/Documents/saturn/workspace/sessions/$ARGUMENTS/code/`

Service paths within the session:

| Service | Path |
|---------|------|
| jupiter | `code/jupiter/` |
| saturn-fe | `code/saturn-fe/` |
| saturn-backend | `code/saturn-backend/` |
| mars | `code/mars/` |
| shuttle | `code/shuttle/` |
| abe | `code/abe/` |
| chat | `code/chat/` |
| area51 | `code/area51/` |

## Step 3: Print Init Summary

Output in this format:

```
Session: <name>
Root:    /Users/irfanshaikh/Documents/saturn/workspace/sessions/<name>/

Branches:
  mars             <branch>
  shuttle          <branch>
  chat             <branch>
  jupiter          <branch>
  saturn-backend   <branch>
  saturn-fe        <branch>
  abe              <branch>
  area51           <branch>

Description: <description or "(none)">

Todos:
  - <todo items or "(none)">

Ready — all code edits go to sessions/<name>/code/<service>/
```

## Rules for This Session

- **All file edits go inside `sessions/<name>/code/`** — never `workspace/code/` unless explicitly asked
- **Git ops**: `cd` into the specific service dir first — each service is its own git repo on its own branch
- **Start services**: `make start session=<name>` from the workspace root
- **Logs**: `make errors-<svc>` (non-blocking, last 50 lines) or `make logs-<svc>` (live stream)
- **Env vars**: live at `workspace/envs/<service>.env` — shared, not inside session folders
