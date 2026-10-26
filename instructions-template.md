# Project Instructions template

Paste the block below into the host's project instructions, or add a compatible pointer to an existing `AGENTS.md` / `CLAUDE.md`. Copy `workflow-playbook.md` into the consuming project as `PLAYBOOK.md`, together with `autonomous-team.md` and `checks/`. Record the source revision. Preserve existing project rules; do not overwrite the bootstrap blindly.

```text
Read PLAYBOOK.md, LEARNINGS.md, REQUIREMENTS.md, MILESTONES.md and todo.md.
Read autonomous-team.md before team work. Initialize missing planning records only when needed.
Use autonomous mode for implementation unless I explicitly request guided mode.
Record the goal, success criteria, authorized actions and delivery boundary.
Continue ready tasks within that contract. Reuse authorization already given.
Assign exclusive write paths. Require review independent of the author when available.
Verify the final integrated revision. Track target acceptance separately.
A reviewable branch/PR is the default boundary; merge, release and deployment need authorization for that action.
The project files are durable state; reconcile them with Git and live workers after interruption.
```

To request step approvals, add `Use guided mode; stop at each agreed approval boundary.` To authorize a different delivery boundary, state it explicitly. Do not treat silence as permission.

The host must support the requested tools and agent operations. This template installs no background service and creates no model subscriptions. If the project has no independent reviewer, record that limitation and follow the fallback rule in `autonomous-team.md`.
