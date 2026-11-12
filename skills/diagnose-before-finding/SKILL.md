---
name: diagnose-before-finding
description: "Gate before calling a mismatch a bug, a review item a MUST FIX, or a guard something to remove or widen: four sourced lines, a repro command that can go red, and a cap on fix attempts. Triggers on: 'diagnose', 'debug', 'root cause', 'why is this wrong', 'data mismatch', 'is this a bug', 'this guard is blocking', 'review finding', 'must fix', 'relay this finding', 'propose a fix'. Not for: a typo, a rename, or implementing a rule the owner of the flow already stated."
user-invocable: true
argument-hint: "[the finding or symptom to diagnose]"
---

# Diagnose before the finding

Use this before a review verdict, before a "this is the cause" conclusion, before relaying a subagent's or reviewer's finding as real, and before any change that restores, removes or widens a guard. The failure it prevents: the evidence is real, but it was read as the wrong rule, and a confident fix ships for a bug that was not there.

A finding stays open until each of the four lines below has a source. "Not asked" is an allowed answer. It is not a pass.

## The four lines

1. **Writer and carrier.** Name the component that writes the value and the component that only passes it along. A successful response from the carrier proves the value arrived, not that it was the right value.
2. **Meaning at this step.** What does the owner of the flow say this value means at this point? A field can be a snapshot taken when the record was created, while a later field is the one this step must use.
3. **The other side.** What evidence would prove the other reading right? Run that check, or leave the finding open. Collecting only evidence that fits the leading guess is how a wrong diagnosis feels certain.
4. **Owner asked.** Before changing the behaviour of a flow, ask the person who owns it. A test updated in the same commit as the behaviour it covers is the author stating the new rule, not a test bent to hide a bug.

Write them down before the verdict, each with a source (file and line, a query, a command and its output, or "not asked"):

```
Writer / carrier:
Meaning at this step:
What would prove the other side:
Owner asked:
```

If any line says "not asked" or has no source, the finding is not final: do not post it as MUST FIX and do not ship the change.

## Repro loop

Before forming a theory, have one command you have already run (a test, a curl, a script, or a read-only query when no local repro exists) that shows the exact symptom, that would go red on this bug and green once it is fixed. "Runs without an error" is not that command.

- **Shrink it.** Remove inputs, callers, config and steps one at a time until removing any remaining one turns it green. What is left is the cause's neighbourhood.
- **One change at a time.** Test one hypothesis with the smallest change. Never stack a second fix on a failed one: revert the first.
- **Red first.** A regression test must fail on the code before the fix. A test that passes both before and after proves nothing about the fix.

## Fix-attempt cap

A failed attempt is a fix after which the repro command is still red, or that had to be reverted (count it once, revert included). A fix that turns the repro green but leaves a related gap is not a failed attempt.

- After **2** failed attempts, stop and question the design: re-run the four lines above before a third attempt.
- After **3**, stop and report to the user with the repro command, what each attempt changed, and why each failed. A fourth guess is flailing.
- An edit with no link to the defect is a sign of flailing too: back it out. The regression test, callers of the changed code, and sibling paths that share the state are linked; they are not stray edits.

## Debug logs

Tag every temporary log line with a unique marker, for example `[DEBUG-7f3a]` (4 random hex characters), and grep the tag to zero before calling the work done. An untagged debug line is how one ships.

## Guards

Do not remove, widen or restore a guard until lines 2 and 4 are answered. A guard that fires is the system reporting a condition: diagnose the condition before touching the guard. When the value the guard compares against is resolved at runtime (a config row, a flag, an environment variable), read the live value in every environment the finding covers; a value mocked in a test is not that environment's value.

## Source

Re-expressed in our own words from ideas in mattpocock/skills (`diagnosing-bugs`), obra/superpowers (`systematic-debugging`) and garrytan/gstack (`qa`), all MIT licensed.
