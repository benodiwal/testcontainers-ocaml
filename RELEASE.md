# Release Process

## Branch Strategy

We maintain two branches:

- `main` - development branch with tests
- `opam-release` - release branch without tests

### Why a separate release branch?

OPAM CI runs tests during package validation, but our integration tests require Docker (specifically `/var/run/docker.sock`). Docker isn't available in OPAM's CI environment, so tests fail.

Rather than stubbing out tests or adding CI skip flags, we keep a clean `opam-release` branch with test code removed entirely.

## Publishing to OPAM

1. Ensure `main` has the correct version in `dune-project`

2. Sync changes to `opam-release`:
   ```bash
   git checkout opam-release
   git merge main --no-commit
   # Remove test directories if any were added
   rm -rf test/ modules/*/test/
   # Remove test dependencies from dune-project if any were added
   git add -A
   git commit -m "Sync from main for release"
   ```

3. Tag the release on `opam-release`:
   ```bash
   git tag v<version>
   git push origin opam-release --tags
   ```

4. Publish to OPAM:
   ```bash
   opam publish
   ```

5. Wait for OPAM CI to pass and maintainers to merge

## Version Bumping

After a release, bump the version on `main`:

```bash
git checkout main
# Update version in dune-project
dune build  # Regenerates .opam files
git add dune-project *.opam
git commit -m "Bump version to <next-version>"
```

## Known Issues

- **OPAM 2.0 solver**: May show cyclic dependency errors unrelated to our packages. These are ecosystem issues with the old solver. OPAM 2.1+ handles them fine.
