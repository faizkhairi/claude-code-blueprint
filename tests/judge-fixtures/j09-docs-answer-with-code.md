---
id: j09-docs-answer-with-code
expected: ok
rule: code sample in an explanation, no claim
---
You can read a JSON field in a hook like this:

```bash
FILE=$(python3 -c 'import sys, json; print(json.load(sys.stdin)["tool_input"]["file_path"])')
```

The hook gets the event as JSON on stdin.
