# Server Test Script Fixes (v0.0.18)

**Date**: 2026-02-11
**File**: `server/scripts/test.sh`

## Issues Found from Hardware Testing

Hardware test results revealed two critical bugs in the test script that caused false failures and false skips.

---

## Bug 1: Timing Calculation Error

### Problem
Elapsed times were displayed as absurdly large values (e.g., 369,523,000 seconds = 4,277 days) due to incorrect nanosecond/second detection logic.

### Root Cause
```bash
# OLD (BROKEN) - Lines 225-229
if [[ "$START_TIME" =~ N ]]; then
    ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
else
    ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
fi
```

**Issue**: The condition `=~ N` checks if the string contains letter "N":
- When `date +%s%N` succeeds: returns nanoseconds (e.g., `1770768236123456789`) → no "N" → goes to `else` → multiplies by 1000 ❌
- When `date +%s%N` fails: returns literal `1770768236N` → contains "N" → divides by 1000000 ❌
- **Both branches are wrong!**

### Fix Applied
```bash
# NEW (FIXED)
if [[ ${#START_TIME} -gt 12 ]]; then
    # Nanoseconds (19 digits) - convert to milliseconds
    ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
else
    # Seconds (10 digits) - convert to milliseconds
    ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
fi
```

**Solution**: Check the length of the timestamp string:
- Nanoseconds: 19 digits (seconds + 9-digit nanoseconds) → divide by 1,000,000
- Seconds: 10 digits → multiply by 1,000

### Tests Fixed
- Test 7: POST /v1/chat/completions (non-streaming)
- Test 8: POST /v1/chat/completions (streaming)
- Test 9: POST /v1/chat/completions (stream_options.include_usage)
- Test 10: POST /v1/chat/completions (JSON mode)
- Test 11: POST /v1/responses (experimental)
- Test 21: POST /v1/messages (non-streaming)
- Test 22: POST /v1/messages (streaming SSE)
- Test 23: POST /v1/messages (system prompt)
- Test 25: POST /v1/messages (multi-turn conversation)
- Test 26: POST /v1/messages (streaming with usage)

---

## Bug 2: Anthropic Endpoint Detection Error

### Problem
Tests 12, 14, and 16 marked as "SKIP - endpoint not available" despite receiving valid HTTP 200 responses with proper Anthropic-formatted JSON.

### Root Cause
```bash
# Verbose mode mixes curl debug output with JSON response
ANTHROPIC_RESPONSE=$(curl -v http://localhost:11434/v1/messages \
    -H "Content-Type: application/json" \
    -d '...' \
    2>&1 || echo "FAILED")

# Trying to parse mixed output as JSON fails
if echo "$ANTHROPIC_RESPONSE" | jq -e '.type == "message"' &> /dev/null; then
```

**Issue**: The `2>&1` redirects stderr (curl's verbose output) to stdout, so `$ANTHROPIC_RESPONSE` contains:
```
> POST /v1/messages HTTP/1.1
> Host: localhost:11434
...
< HTTP/1.1 200 OK
...
{"id":"msg_...","type":"message",...}
```

`jq` cannot parse this mixed output, causing the test to incorrectly skip.

### Fix Applied
```bash
# Extract JSON from verbose output (last line is the actual response)
JSON_ONLY=$(echo "$ANTHROPIC_RESPONSE" | tail -n 1)
if echo "$JSON_ONLY" | jq -e '.type == "message"' &> /dev/null; then
```

**Solution**: Extract the last line (the actual JSON response) before parsing with `jq`.

### Tests Fixed
- Test 7: POST /v1/chat/completions (non-streaming) - added JSON extraction
- Test 10: POST /v1/chat/completions (JSON mode) - added JSON extraction
- Test 11: POST /v1/responses (experimental) - added JSON extraction
- Test 21: POST /v1/messages (non-streaming) - added JSON extraction
- Test 23: POST /v1/messages (system prompt) - added JSON extraction
- Test 25: POST /v1/messages (multi-turn conversation) - added JSON extraction

---

## Impact Assessment

### Before Fix
- **Test 7**: FAIL (timing: 369,523,000 seconds)
- **Test 10**: FAIL (timing: 1,713,920,000 seconds)
- **Test 12**: SKIP (false negative - endpoint actually works)
- **Test 14**: SKIP (false negative - endpoint actually works)
- **Test 16**: SKIP (false negative - endpoint actually works)
- **Results**: 20 passed, 2 failed, 4 skipped

### After Fix (Expected)
- **Test 7**: PASS (timing: ~1000-2000ms)
- **Test 10**: PASS (timing: ~1000-2000ms)
- **Test 12**: PASS (Anthropic non-streaming endpoint confirmed working)
- **Test 14**: PASS (Anthropic system prompt endpoint confirmed working)
- **Test 16**: PASS (Anthropic multi-turn endpoint confirmed working)
- **Expected Results**: 25 passed, 0 failed, 1 skipped (only Test 11 /v1/responses may still skip)

---

## Verification Steps

To verify the fixes:

1. **Syntax validation** (completed):
   ```bash
   bash -n server/scripts/test.sh
   ```

2. **Hardware test run** (pending):
   ```bash
   cd server/scripts
   ./test.sh --verbose
   ```

3. **Check timing values**: Should now show realistic millisecond values (typically 500-5000ms)

4. **Check Anthropic tests**: Tests 12, 14, 16 should now PASS instead of SKIP

---

## Files Modified

- `/Users/henriquefalconer/private-ai-api/server/scripts/test.sh`
  - 10 timing calculation fixes
  - 6 JSON extraction fixes (for verbose mode parsing)
  - Total: 16 bug fixes across 11 tests

---

## Next Steps

1. ✅ Syntax validation completed
2. ⏳ Re-run hardware tests to confirm fixes
3. ⏳ Update IMPLEMENTATION_PLAN.md with results
4. ⏳ Commit changes with proper versioning (v0.0.18)

---

## Credits

- Bug discovery: Hardware testing on Apple Silicon server (2026-02-11)
- Analysis and fix: Claude Sonnet 4.5
- Test results file: `server-test-result.txt`
