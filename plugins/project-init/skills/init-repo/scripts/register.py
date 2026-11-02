# /// script
# requires-python = ">=3.9"
# dependencies = ["pyyaml"]
# ///
"""Print a project-init register (.project-init.yml) as JSON, for jq.

Usage: uv run --quiet --script register.py <file>
"""

import json
import sys

import yaml

with open(sys.argv[1], encoding="utf-8") as f:
    json.dump(yaml.safe_load(f), sys.stdout)
