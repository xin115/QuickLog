# QuickLog Full Automation Agent (Swift)

This is a small background `.app` (no window) that:
- **prompts for Accessibility** using `AXIsProcessTrustedWithOptions(prompt: true)`
- polls `/tmp/QuickLogAutomationAgent.cmd`
- builds + runs `QuickLogMVP`
- uses AppleScript **from inside the app process** to control `System Events` (menu bar click)
- writes results to `/tmp/QuickLogAutomationAgent.result.json`

## Start
Open:
`tools/QuickLogAutomationAgentSwift.app`

You should get an Accessibility prompt (or it will appear in System Settings → Privacy & Security → Accessibility).
Also allow Automation/Apple Events prompts for controlling **System Events**.

## Trigger test
```bash
printf %s "/Users/smile/Documents/coding/happy/QuickLog" > /tmp/QuickLogAutomationAgent.cmd
sleep 8
cat /tmp/QuickLogAutomationAgent.result.json
```

## Logs
- `/tmp/QuickLogMVP.stdout.log`
- `/tmp/QuickLogMVP.stderr.log`
