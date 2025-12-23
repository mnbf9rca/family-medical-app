# Security Policy

## Reporting Security Vulnerabilities

**Do not open public issues for security vulnerabilities.**

If you discover a security vulnerability in this project, please report it privately:

1. Go to the [Security tab](https://github.com/mnbf9rca/family-medical-app/security)
2. Click "Report a vulnerability"
3. Provide detailed information about the vulnerability

We will respond within 48 hours and work with you to address the issue.

## Automated Security Scanning

This project uses automated security scanning on every commit:

- **CodeQL**: Semantic code analysis (runs on push/PR + weekly)
- **SwiftLint**: Custom security rules (no hardcoded secrets, no crypto force-try, no key logging)
- **Pre-commit hooks**: Prevent committing secrets or broken code
- **Dependabot**: Automatic dependency vulnerability alerts

Results visible in the [Security tab](https://github.com/mnbf9rca/family-medical-app/security).

## Security Architecture

This app uses end-to-end encryption for medical data. See architectural decision records:

- [ADR-0001: Crypto Architecture](docs/adr/adr-0001-crypto-architecture-first.md) - AES-256-GCM, Argon2id
- [ADR-0002: Key Hierarchy](docs/adr/adr-0002-key-hierarchy.md) - Key management
- [ADR-0005: Access Revocation](docs/adr/adr-0005-access-revocation.md) - Security model

## Vulnerability Disclosure Timeline

When a security vulnerability is reported:

1. **Day 0**: Acknowledge receipt within 48 hours
2. **Day 1-7**: Investigate and validate the vulnerability
3. **Day 7-30**: Develop and test a fix
4. **Day 30**: Public disclosure with credit to reporter (if desired)

Critical vulnerabilities will be fast-tracked.

## Security Contacts

- **Primary**: Open a private vulnerability report via GitHub Security tab
- **Email**: See repository owner's GitHub profile for contact information

## Scope

**In scope**: iOS app code, cryptographic implementations, auth/authz, data handling

**Out of scope**: Social engineering, physical security, third-party deps (report upstream), iOS system bugs (report to Apple)

## Security Hall of Fame

Contributors who responsibly disclose security vulnerabilities will be credited here (with permission).

---

**Note**: This is a personal/family medical records app. The security measures are designed for individual/family use, not enterprise healthcare compliance (HIPAA, GDPR, etc.).
