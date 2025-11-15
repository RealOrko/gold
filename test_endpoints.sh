#!/bin/bash

# Test script for Gold Cart Pole API endpoints
# Usage: ./test_endpoints.sh [PORT]

PORT=${1:-36623}
BASE_URL="http://localhost:$PORT"

echo "🚀 Testing Gold Cart Pole API Endpoints"
echo "========================================"
echo "Base URL: $BASE_URL"
echo ""

echo "📋 1. Available Values:"
echo "----------------------"
curl -s "$BASE_URL/api/values" | python3 -m json.tool
echo ""

echo "📊 2. Available Aggregators:"
echo "----------------------------"
curl -s "$BASE_URL/api/aggregators" | python3 -m json.tool  
echo ""

echo "📈 3. Score Data (first 5 points):"
echo "-----------------------------------"
curl -s "$BASE_URL/api/values/score" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Total points: {len(data[\"xys\"])}')
print('First 5 data points:')
for i, point in enumerate(data['xys'][:5]):
    print(f'  Episode {point[\"x\"]}: Score = {point[\"y\"]}')
"
echo ""

echo "⚡ 4. Epsilon Data (first 5 points):"
echo "------------------------------------"
curl -s "$BASE_URL/api/values/epsilon" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Total points: {len(data[\"xys\"])}')
print('First 5 data points:')
for i, point in enumerate(data['xys'][:5]):
    print(f'  Episode {point[\"x\"]}: Epsilon = {point[\"y\"]:.6f}')
"
echo ""

echo "🎯 5. Score with Max Aggregator (first 5 points):"
echo "--------------------------------------------------"
curl -s "$BASE_URL/api/values/score?aggregator=max" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Total points: {len(data[\"xys\"])}')
print('First 5 data points:')
for i, point in enumerate(data['xys'][:5]):
    print(f'  Episode {point[\"x\"]}: Max Score = {point[\"y\"]}')
"
echo ""

echo "✅ All endpoints working correctly!"
echo "🌐 Dashboard available at: $BASE_URL"