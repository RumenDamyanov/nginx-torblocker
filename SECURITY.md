# Security Policy

## Supported Versions

Pre-release project; only `master` (main branch) receives fixes presently.

## Reporting a Vulnerability

Email: security@rumenx.com

Please include:

- Affected endpoints / functions
- Reproduction steps or proof-of-concept
- Impact assessment (confidentiality/integrity/availability)
- Any suggested remediation

You will receive acknowledgement within 72 hours with a tracking reference.

## Disclosure Process

1. Triage & reproduce.
2. Assign severity (CVSS style qualitative).
3. Prepare patch + tests.
4. Coordinate disclosure date (default 14 days after fix unless actively exploited).
5. Publish fix & brief advisory in repo (SECURITY-ADVISORIES if needed).

## Scope

In scope: engine rules leading to state forgery or cross-session data leakage, API authorization logic (future), denial-of-service vectors (excessive memory growth).

Out of scope (current design): transport encryption (terminate TLS upstream), multi-tenancy isolation (not implemented yet).

Thank you for helping keep the project secure.
