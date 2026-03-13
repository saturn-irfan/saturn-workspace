Pick a todo from the Saturn todo list and work on it end-to-end.

If the user provides a specific todo description as `$ARGUMENTS`, use that to find the matching todo. Otherwise, read the todo file and present the highest priority items for the user to pick from.

## Step 1: Read the Todo File

Find and read the latest `saturn-todos-YYYY-MM-DD.md` in `~/Documents/personal/Obsidian/CURRENT_TODOS/`.

If `$ARGUMENTS` is provided, find the matching `- [ ]` todo line. If not, present the `🚨 Highest Priority` section and ask the user which one to work on.

## Step 2: Gather Context use subagents

Once a todo is selected:

1. **Check for a Slack source link** — look for `[source](https://saturn-fintech.slack.com/...)` at the end of the todo line
2. **If a source link exists**, extract the channel ID and thread timestamp from the URL and read the Slack thread using the Slack MCP tool (`slack_read_thread`) to get full context — what was reported, who reported it, any screenshots or details. Slack URL format: `https://saturn-fintech.slack.com/archives/<channel_id>/p<timestamp>` where `p1771581904306199` becomes thread_ts `1771581904.306199`
3. **If no source link**, skip Slack and work with whatever context is in the todo line itself
4. **Read any related fixes/** documentation if it exists
5. **Identify which service(s) are affected** based on the context

## Step 3: Mark Todo as In-Progress

Update the todo file — change `- [ ]` to `- [→]` for the selected item and append `| status: investigating` at the end of the line.

## Step 4: Create a Session

Create a session for this work:

```bash
scripts/create-session <todo-slug> \
  --claude-id <current-claude-session-id> \
  --description "<short description of the bug/task>" \
  --todo "<todo line text>"
```

The session name should be a short slug derived from the todo (e.g., `adam-rawling-name-bug`, `speaker-side-blank`).

**Get the Claude session ID:** Run `echo $CLAUDE_SESSION_ID` or check the current session context.

## Step 5: Investigate

Working in the session's code:

1. **Explore the relevant service(s)** — understand the code flow related to the bug
2. **Identify the root cause** — trace through the logic, find where things break
3. **Document findings** — append to the session's `.info` file:
   ```
   - <timestamp> | investigating: <what you found>
   ```

Update the todo file: change `| status: investigating` to `| status: root-cause-found`

## Step 6: Fix

1. **Apply the fix** in the session's code
2. **Verify** the fix makes sense (read surrounding code, check edge cases)
3. **Update `.info`**:
   ```
   - <timestamp> | fix applied: <what was changed>
   ```

Update the todo file: change `| status: root-cause-found` to `| status: fixing`

After the fix is applied, update the todo file: change `| status: fixing` to `| status: human_review_pending`

## Step 7: Present Fix for Human Review

**STOP and wait for human approval before committing anything.**

Present a clear summary to the user:

```
## Fix Summary

**Bug:** <todo description>
**Root Cause:** <what was wrong>
**Fix:** <what was changed and why>

**Files changed:**
- <service>/<path/to/file> — <what changed>
- ...

**How to verify:**
- <steps to test the fix>
```

Then show the actual code diff — run `git diff` in each modified service directory so the user can review the exact changes.

Ask the user: **"Does this fix look correct? Should I commit and raise a draft PR?"**

- If the user approves, proceed to Step 8
- If the user requests changes, apply them and re-present for review
- If the user rejects, update todo status to `| status: fix-rejected` and stop

## Step 8: Commit, Push, and Draft PR

Only after human approval:

For each service that was modified:

1. `cd` into the session's service directory
2. Create a new branch: `fix/<todo-slug>` (branching from whatever branch was cloned)
3. Stage the changed files
4. Create a commit with a clear message describing the fix
5. Push the branch to origin
6. **Raise a draft PR** using `gh pr create --draft` with:
   - Title: short description of the fix
   - Body: root cause, what changed, how to verify

Update `.info`:
```
- <timestamp> | pushed: <branch-name> on <service>
- <timestamp> | draft PR: <pr-url>
```

## Step 9: Update Todo Status

Update the todo file:
- Change `- [→]` to `- [x]`
- Change `| status: human_review_pending` to `| status: draft-pr — <pr-url>`

Update the session `.info`:
```
status: completed
- <timestamp> | completed — draft PR raised
```

## Important Notes

- **Always update the `.info` file** at each step so progress is tracked
- **Always update the todo file** status so it reflects current state
- **If you get stuck**, update status to `| status: blocked — <reason>` and tell the user
- **If the fix spans multiple services**, commit and push each one separately
- **Only read Slack if the todo has a `[source]` link** — not all todos have one. If there's no link, work with the todo description alone
- The session uses `CODE_ROOT` pointing to the session dir, so all scripts work against the session's code, not `code/`
