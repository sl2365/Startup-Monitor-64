=========================================
Startup Monitor 64 - Guided User Test
=========================================

Test-suite revision: 5

[PURPOSE]
This is a guided, real-world acceptance test for the RELEASED
StartupMonitor64.exe.

It uses the same EXE that the user normally runs, but copies that EXE into a
temporary isolated test installation. The user's normal Startup Monitor App
folder, Settings.ini, Allowed.ini, Denied.ini, baselines and Log.ini are not
modified.

[HOW TO USE]
1. Put this Test_Suite folder beside StartupMonitor64.exe.

   Example:

   StartupMonitor64.exe
   App\
   Test_Suite\
       RUN_TEST.bat
       SM64_UserTest.ps1
       README.txt

2. Exit the normal Startup Monitor 64 from its tray icon.

3. Double-click:

   RUN_TEST.bat

4. Accept the Administrator/UAC prompt.

5. Follow the plain-English instructions shown by the test.

6. When finished, Results.log is created in this Test_Suite folder.

7. If reporting a problem, send Results.log.

[WHAT THE USER HAS TO DO]
Only normal Startup Monitor actions are requested:

- open Settings from the tray;
- Pause/Resume Monitoring;
- use Move to Denied on clearly named test items;
- use the normal Review window;
- leave an Allow item checked;
- untick a Deny item;
- click Apply;
- exit from the tray.

The tester does not ask the user to edit INI files, understand fingerprints,
run Python, compile the application, or use developer tools.

[WHAT IS TESTED]
The current test covers:

- isolated launch of the real release EXE;
- first-run Startup folder baseline creation;
- first-run HKCU Run Registry baseline creation;
- first-run Scheduled Task baseline creation;
- Base Startup multi-item Move to Denied;
- Base Tasks multi-item Move to Denied;
- Pause Monitoring;
- Resume Monitoring;
- Startup-folder detection;
- Review Allow persistence;
- Review Deny persistence;
- denied file removal;
- HKCU Run Registry detection and removal;
- Scheduled Task detection and removal;
- expected Log.ini evidence;
- normal tray Exit and clean worker shutdown;
- cleanup of all temporary test objects.

[SAFETY]
A genuine monitor test must temporarily create real things for Startup Monitor
to detect. This suite limits those objects to harmless disposable fixtures.

It temporarily creates only:

- harmless .txt files in the current user's Startup folder;
- uniquely named temporary values in:
    HKCU\Software\Microsoft\Windows\CurrentVersion\Run
- uniquely named harmless Scheduled Tasks whose command is:
    cmd.exe /c exit /b 0

Every test object begins with:

    SM64_USER_TEST_9D7A3C21

The suite records its objects in a temporary manifest and removes them at the
end. If a previous test was interrupted, the next run first cleans the objects
recorded by that manifest.

If an object already uses one of the reserved test names but there is no valid
test manifest, the suite STOPS rather than deleting or overwriting it.

The normal Startup Monitor installation must be closed before the test. The
test suite never force-closes the user's normal copy.

[TEST CONFIGURATION]
The isolated copy uses its own App folder and shortened scan intervals so the
test does not take several minutes.

For safety and clarity, its Locations.ini monitors only:

- the current user's real Startup folder;
- HKCU Run.

Scheduled Task monitoring remains enabled.

The user's own Locations.ini and settings are untouched.

[RESULTS]
Results.log distinguishes:

PASS
    The expected behaviour and observable evidence were found.

FAIL
    The expected behaviour was not produced. The report includes a failure stage
    such as Detection, Review/Persistence, Removal, Logging, Shutdown or Cleanup.

INCOMPLETE
    The requested branch was not actually exercised, for example if the test
    asked the user to Deny an item but it was Allowed instead.

The report also includes relevant test entries from the isolated INI files and
relevant Log.ini lines to make failures easier to diagnose.


[IMPORTANT INTERACTION RULE]
The tester never asks the user to press ENTER after clicking Apply in a Review
window. It watches the isolated Allowed.ini and Denied.ini itself and continues
only after Startup Monitor has saved the decision.

ENTER is used only BEFORE creating the next test object, when the user has had a
chance to read the next test instructions.

If a Review does not complete within the timeout, the tester stops at that test
and asks whether to wait longer or fail/stop. It does not continue into the next
test while an earlier Review may still be open.


[END OF TEST]
When the test finishes, Results.log opens automatically in Notepad and the
Command Prompt closes. There is no final key press.
