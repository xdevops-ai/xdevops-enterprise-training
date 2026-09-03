# Synthetic DLP fixture

The public repository deliberately does **not** commit credential-shaped sample secrets because public secret-scanning systems can flag them and because secret-like values do not belong in Git history.

For a training-only DLP/redaction exercise, generate an ephemeral fixture outside the repository:

```bash
./scripts/generate-dlp-fixture.sh
```

The default output is `/tmp/xdevops-training-dlp-fixture.txt` with mode `0600`. The generated values are synthetic and unusable. Delete the file after the exercise and never replace the fixture with real credentials.
