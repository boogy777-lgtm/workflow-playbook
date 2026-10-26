# Workflow Playbook repository

Read `workflow-playbook.md` before changing this repository. Read `autonomous-team.md` for team operation. The user's current instructions and the host's permission rules take precedence.

This repository ships the workflow itself. Its canonical playbook is `workflow-playbook.md`; do not create a duplicate `PLAYBOOK.md` here. The project file layout described in the product is created in consuming projects, not automatically when maintaining these documents. Preserve existing project bootstrap files when installing the workflow elsewhere.

Use the established repository location. Keep the core rules, team protocol, README and instruction template consistent. Record product changes in the README changelog. Validate Markdown links, code fences and `git diff --check`. For executable changes, run a regression that proves the corrected behavior. Run the secret checker before publishing.

Use existing authorization. A branch and reviewable PR are the default delivery boundary; do not infer merge or release permission. Report what ran in the available environment and what remains untested on the target.
