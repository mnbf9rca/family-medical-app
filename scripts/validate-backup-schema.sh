#!/bin/bash
set -euo pipefail

# Backup Schema Validator
# Validates that the backup JSON Schema is well-formed and self-consistent
#
# Usage: ./scripts/validate-backup-schema.sh
#
# Exit codes:
#   0 - Schema is valid
#   1 - Schema is invalid or error occurred

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Paths
SCHEMA_FILE="$PROJECT_ROOT/docs/schemas/backup-v1.json"

if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "Error: Schema file not found: $SCHEMA_FILE"
    exit 1
fi

# Validate JSON syntax
if ! python3 -c "import json; json.load(open('$SCHEMA_FILE'))" 2>/dev/null; then
    echo "Error: Schema file is not valid JSON"
    exit 1
fi

# Validate it's a valid JSON Schema (basic structural checks)
python3 << PYTHON_SCRIPT
import json
import sys

with open('$SCHEMA_FILE', 'r') as f:
    schema = json.load(f)

# Check required top-level fields for JSON Schema Draft 2020-12
required_fields = ['\$schema', 'type', 'properties']
missing = [f for f in required_fields if f not in schema]
if missing:
    print(f"Error: Missing required schema fields: {missing}")
    sys.exit(1)

# Verify it declares a valid JSON Schema dialect
valid_dialects = [
    'https://json-schema.org/draft/2020-12/schema',
    'https://json-schema.org/draft/2019-09/schema',
    'http://json-schema.org/draft-07/schema#'
]
if schema.get('\$schema') not in valid_dialects:
    print(f"Warning: Unrecognized schema dialect: {schema.get('\$schema')}")

# Check that all \$ref references are valid (point to existing definitions)
def find_refs(obj, path=''):
    """Find all \$ref values in the schema"""
    refs = []
    if isinstance(obj, dict):
        if '\$ref' in obj:
            refs.append((path, obj['\$ref']))
        for key, value in obj.items():
            refs.extend(find_refs(value, f"{path}/{key}"))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            refs.extend(find_refs(item, f"{path}[{i}]"))
    return refs

def resolve_ref(ref, schema):
    """Check if a \$ref can be resolved within the schema"""
    if not ref.startswith('#/'):
        return True  # External refs not checked
    parts = ref[2:].split('/')
    current = schema
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return False
    return True

refs = find_refs(schema)
invalid_refs = [(path, ref) for path, ref in refs if not resolve_ref(ref, schema)]
if invalid_refs:
    print("Error: Invalid \$ref references found:")
    for path, ref in invalid_refs:
        print(f"  {path}: {ref}")
    sys.exit(1)

print(f"Schema validation passed: {len(refs)} references resolved, schema is well-formed")
PYTHON_SCRIPT

echo "Schema is valid: $SCHEMA_FILE"
