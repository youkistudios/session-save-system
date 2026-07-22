## Problem and data boundary

Describe the concrete failure and every user-owned path this change may touch.

## Change and recovery

Explain the smallest change and how a user recovers if it fails.

## Validation

- [ ] `./tests/run.sh`
- [ ] `python3 scripts/validate_repo.py`
- [ ] `python3 scripts/generate_manifest.py --check`
- [ ] No real session logs or secrets are included
- [ ] Ownership, index, or archive boundary changes include a decision record
