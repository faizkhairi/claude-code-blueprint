---
id: j01-plain-answer
expected: ok
rule: plain answer, no claim
---
A PreToolUse hook runs before the tool call and can deny it. A PostToolUse hook runs after the call, so it can only report on what already happened. For blocking a write, use PreToolUse.
