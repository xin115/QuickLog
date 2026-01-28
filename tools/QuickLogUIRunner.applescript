-- QuickLogUIRunner.applescript
-- Purpose: fully-automated UI smoke test for QuickLogMVP.
-- It will:
-- 1) build QuickLogMVP (debug)
-- 2) launch the built binary
-- 3) click the menu bar status item twice (toggle show/hide)
-- 4) write a result file to /tmp/QuickLogUIRunner.result.json
-- 5) terminate QuickLogMVP

on writeResult(ok, msg)
	set resultPath to "/tmp/QuickLogUIRunner.result.json"
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

on run argv
	set projectPath to "/Users/smile/Documents/coding/happy/QuickLog"	-- default
	if (count of argv) >= 1 then set projectPath to item 1 of argv

	-- Always write a "started" marker first.
	try
		my writeResult("false", "STARTED")
	on error
		-- ignore
	end try

	try
		-- Build
		do shell script "cd " & quoted form of projectPath & " && swift build -c debug"

		-- Find binary
		set binPath to do shell script "cd " & quoted form of projectPath & " && /usr/bin/find .build -type f -path '*/debug/QuickLogMVP' -maxdepth 6 | /usr/bin/head -n 1"
		if binPath is "" then error "Built binary not found"

		-- Launch in background, record pid
		set pid to do shell script "(" & quoted form of binPath & " >/tmp/QuickLogMVP.stdout.log 2>/tmp/QuickLogMVP.stderr.log &) ; /bin/sleep 0.2; /usr/bin/pgrep -n QuickLogMVP"

		-- Wait up to ~5s for process to appear to System Events
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
				-- Click the first menu bar item twice to toggle show/hide
				click (first menu bar item of menu bar 1)
				delay 0.4
				click (first menu bar item of menu bar 1)
			end tell
		end tell

		-- Terminate
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
			-- last resort: attempt to write something minimal
			try
				do shell script "echo FAIL > /tmp/QuickLogUIRunner.result.json"
			on error
				-- ignore
			end try
		end try
	end try
end run
