# QuickLog Automation (Full Auto UI Test)

macOS UI automation permissions are per-GUI-app. Clawdbot runs headless, so it can't be granted Accessibility directly.

Solution: run a small stay-open GUI agent app that has Accessibility permission and performs UI clicks on demand.

## 1) One-time setup (manual)

1. Open:
   `tools/QuickLogAutomationAgent.app`

2. macOS will prompt for permissions. Allow:
   - **Accessibility** (required)
   - **Automation** to control **System Events** (required)

3. Keep the agent running (recommended: add to Login Items).

## 2) Trigger a UI smoke test (from anywhere)

Write the project path to the command file:

```bash
printf %s "/Users/smile/Documents/coding/happy/QuickLog" > /tmp/QuickLogAutomationAgent.cmd
```

Within ~1s, the agent will:
- build QuickLogMVP
- launch it
- click the menu-bar icon twice (toggle)
- terminate it
- write the result file:

```bash
cat /tmp/QuickLogAutomationAgent.result.json
```

## 3) Log files

- `/tmp/QuickLogMVP.stdout.log`
- `/tmp/QuickLogMVP.stderr.log`
