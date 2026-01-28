-- QuickLogAutomationAgent.applescript (stay-open)
-- Runs in the logged-in GUI session and performs UI automation when commanded.
--
-- Command mechanism:
-- Write a project path to /tmp/QuickLogAutomationAgent.cmd
-- The agent will consume it, run the UI toggle test, and write /tmp/QuickLogAutomationAgent.result.json

property cmdPath : "/tmp/QuickLogAutomationAgent.cmd"
property resultPath : "/tmp/QuickLogAutomationAgent.result.json"

on writeResult(ok, msg)
	set escMsg to my jsonEscape(msg)
	set json to "{\"ok\":" & ok & ",\"message\":\"" & escMsg & "\",\"ts\":" & (do shell script "date +%s") & "}"
	do shell script "printf %s " & quoted form of json & " > " & quoted form of resultPath
end writeResult

on jsonEscape(s)
	set t to s
	set t to my replaceText(t, "\\", "\\\\")
	set t to my replaceText(t, "\"", "\\\"")
	set t to my replaceText(t, return, "\\n")
	set t to my replaceText(t, linefeed, "\\n")
	return t
end jsonEscape

on replaceText(theText, findText, replaceWith)
	set AppleScript's text item delimiters to findText
	set textItems to every text item of theText
	set AppleScript's text item delimiters to replaceWith
	set theText to textItems as text
	set AppleScript's text item delimiters to ""
	return theText
end replaceText

on runTest(projectPath)
	try
		my writeResult("false", "STARTED")
		on error
		-- ignore
	end try

	try
		do shell script "cd " & quoted form of projectPath & " && swift build -c debug"
		set binRelPath to do shell script "cd " & quoted form of projectPath & " && /usr/bin/find .build -type f -path '*/debug/QuickLogMVP' -maxdepth 8 | /usr/bin/head -n 1"
		if binRelPath is "" then error "Built binary not found"
		-- Ensure it is executable from projectPath.
		if (count of characters of binRelPath) ≥ 5 then
			if (text 1 thru 5 of binRelPath) is ".build" then set binRelPath to "./" & binRelPath
		end if
		if (text 1 thru 1 of binRelPath) is not "." then set binRelPath to "./" & binRelPath

		set pid to do shell script "cd " & quoted form of projectPath & " && (" & binRelPath & " >/tmp/QuickLogMVP.stdout.log 2>/tmp/QuickLogMVP.stderr.log &) ; /bin/sleep 0.3; /usr/bin/pgrep -n QuickLogMVP"

		set tries to 0
		repeat while tries < 25
			tell application "System Events"
				if exists (application process "QuickLogMVP") then exit repeat
			end tell
			delay 0.2
			set tries to tries + 1
		end repeat

		tell application "System Events"
			if not (exists (application process "QuickLogMVP")) then error "QuickLogMVP did not appear in System Events"
			tell application process "QuickLogMVP"
				set frontmost to true
				delay 0.2
				click (first menu bar item of menu bar 1)
				delay 0.4
				click (first menu bar item of menu bar 1)
			end tell
		end tell

		try
			do shell script "/bin/kill " & pid
		on error
			-- ignore
		end try

		my writeResult("true", "UI click toggle OK")
	on error errMsg number errNum
		try
			my writeResult("false", errMsg & " (" & errNum & ")")
		on error
			try
				do shell script "echo FAIL > " & quoted form of resultPath
			on error
			end try
		end try
	end try
end runTest

on run
	-- Touch System Events once at launch to trigger any needed macOS permission prompts
	-- (Accessibility + Automation/AppleEvents). If permissions are missing, this will fail silently
	-- but should cause the OS to surface the prompt to the user.
	try
		tell application "System Events"
			get UI elements enabled
		end tell
	on error
		-- ignore
	end try
end run

on idle
	try
		set existsCmd to (do shell script "test -f " & quoted form of cmdPath & "; echo $?")
		if existsCmd is "0" then
			set projectPath to do shell script "cat " & quoted form of cmdPath
			do shell script "rm -f " & quoted form of cmdPath
			if projectPath is "" then set projectPath to "/Users/smile/Documents/coding/happy/QuickLog"
			my runTest(projectPath)
		end if
	on error
		-- ignore
	end try
	return 1
end idle
