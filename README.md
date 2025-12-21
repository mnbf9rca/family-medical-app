# Family Medical App

A privacy-first iOS app for securely storing and sharing vaccine records and medical data across devices and family members. Your health data belongs to you alone—even we can't access it.

## Core Principles

- **Security & Privacy First**: End-to-end encryption, zero-knowledge architecture
- **KISS**: Avoid unnecessary complexity
- **Open Source**: Vetted libraries with active security maintenance

## Key Features

- **End-to-End Encrypted**: All data encrypted on device; server cannot decrypt
- **Offline-First**: Full functionality without internet
- **Cross-Device Sync**: Seamless synchronization across your devices
- **Family Sharing**: Share specific family members' data with granular permissions
- **Revocable Access**: Cryptographically enforce access removal
- **Age-Based Control**: Automatically adjust access as children mature
- **Biometric Auth**: Face ID / Touch ID support
- **Data Export**: Standard formats for portability
- **GDPR-Ready**: Data portability, right to deletion

## Architecture

Native iOS app (Swift/SwiftUI) with end-to-end encryption. Zero-knowledge sync backend stores encrypted blobs only.

**See `docs/adr/` for detailed architecture decisions** (key hierarchy, sharing model, encryption boundaries).

## Roadmap

- **Phase 0** (Complete): Cryptographic architecture design (see ADRs)
- **Phase 1** (Next): Local-only foundation with encryption
- **Phase 2**: Cross-device sync
- **Phase 3**: Family sharing
- **Phase 4**: Polish & compliance

Track progress in GitHub Issues and Projects.

## Security

**Threat Model**: Trust device when locked. Don't trust network, server, or cloud backups.

**Automated Security**: CodeQL, SwiftLint security rules, pre-commit hooks, Dependabot

**Report Vulnerabilities**: See [SECURITY.md](SECURITY.md)

## Contributing

Hobby project. Contributions and security reviews welcome. Open an issue before submitting PRs.

**Security vulnerabilities**: Report privately via [SECURITY.md](SECURITY.md), not public issues.

## License

MIT (see [LICENSE](LICENSE))

## Disclaimer

Hobby project, not a replacement for professional medical record systems. Not HIPAA-compliant in the full legal sense. Does not provide medical advice—consult healthcare professionals for medical decisions.
