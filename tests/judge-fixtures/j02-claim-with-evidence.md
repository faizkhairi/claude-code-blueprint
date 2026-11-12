---
id: j02-claim-with-evidence
expected: ok
rule: claim carries its evidence
---
Fixed the off-by-one in `paginate()`: the last page now includes the final item.

Verified:
- `npm test -- paginate` before the fix: 1 failed (`expected 3 items, got 2`); after: 14 passed, 0 failed, exit 0.
- Re-read `src/paginate.ts` lines 40-52: the loop bound is now `<= lastIndex`.
