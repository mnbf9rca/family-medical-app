# Family Medical App

A privacy-first iOS application for securely storing and syncing vaccine records and medical data across devices and family members using end-to-end encryption and zero-trust architecture.

## Project Vision

This hobby project aims to provide families with a secure, private, and intuitive way to manage medical records—particularly vaccine data—without compromising on security or privacy. Built on the principle that your health data belongs to you alone, this app ensures that even the service provider cannot access your information.

## Core Principles

- **Security & Privacy First**: All design and implementation decisions prioritize user data security and privacy
- **Zero-Trust Architecture**: Never trust the server, network, or any intermediary with unencrypted data
- **KISS (Keep It Simple, Stupid)**: Avoid unnecessary complexity
- **DRY (Don't Repeat Yourself)**: Write maintainable, reusable code
- **YAGNI (You Aren't Gonna Need It)**: Build only what's needed now, not what might be needed later
- **Open Source When Possible**: Leverage vetted open-source libraries with active security maintenance

## Key Features

### Security & Privacy
- **End-to-End Encryption (E2EE)**: All data encrypted on device before sync
- **Zero-Knowledge Architecture**: Server cannot decrypt user data
- **Biometric Authentication**: Face ID / Touch ID support
- **Password/Passphrase Protection**: Strong password requirements
- **Secure Key Management**: Keys derived from user credentials, never transmitted

### Data Management
- **Offline-First**: Full functionality without internet connection
- **Cross-Device Sync**: Seamless synchronization across user's devices
- **Data Export/Import**: Standard formats for portability
- **Backup & Recovery**: Secure backup with recovery options
- **Audit Trail**: Track data changes for security and compliance

### Family Sharing
- **Granular Permissions**: Share specific family members' data, not everything
- **Role-Based Access**: Owner, read-write, read-only roles
- **Multi-Adult Support**: Multiple adults can manage shared family members
- **Flexible Sharing Topology**:
  - Adult A shares Child 1 & 2 with Adults B & C
  - Adult A also shares Child 1 with Adult D
  - Adult A's personal data remains private
  - Adult B shares their own data with Adult A
  - etc.
- **Flexible ownership**: children's data is independent of any single adult
- **Privacy-Preserving Sharing**: Shared data remains encrypted end-to-end
- **Age-Based Access Control**: Automatically adjust access as children reach certain ages. For example, in UK children gain more control over their medical data at various ages (https://www.nhs.uk/nhs-services/gps/gp-services-for-someone-else-proxy-access/information-for-under-16s-parent-guardian-accessing-your-doctors-services/).
- **Periodic Access Reviews**: Prompt users to review shared access periodically
- **Revocable Access**: Easily remove shared access, including ensuring data is no longer accessible

### User Experience
- **Intuitive Interface**: Clean, accessible design following iOS HIG
- **Quick Access**: Biometric unlock for fast access
- **Search & Filter**: Find records quickly
- **Store Various Data Types**:
  - **Vaccine Records**: Dates, types, providers
  - **Medical History**: Conditions, medications, allergies
  - **Appointments**: Upcoming and past visits
- **Documents**: Upload and view PDFs, images of medical records

### Compliance Considerations
- **GDPR-Ready**: Data portability, right to deletion, transparency
- **HIPAA-Aware**: PHI protection best practices (note: full compliance requires broader organizational controls)
- **Data Minimization**: Collect only necessary information
- **Transparency**: Clear privacy policy and data handling explanations

## Architecture Overview

### Client-Side (iOS)
- **Swift/SwiftUI**: Native iOS development
- **Local Database**: Encrypted local storage (initial thoughts: SQLite + SQLCipher or Core Data + encryption - but TBD)
- **Cryptography**: Industry-standard libraries (CryptoKit, potentially libsodium)
- **Keychain**: Secure key storage using iOS Keychain Services
- **Sync Engine**: Handles data synchronization including conflict resolution

### Server-Side (Sync Backend)
- **Purpose**: Encrypted blob storage and synchronization only
- **No Access**: Cannot decrypt user data
- **Minimal Metadata**: Only essential sync metadata (timestamps, device IDs, encrypted payloads)
- **Technology**: TBD - potentially simple REST API or cloud storage (evaluated for privacy)
- **Scalability**: Designed to handle multiple users and family groups efficiently
- **efficient Sync Protocol**: Delta sync to minimize data transfer, particularly for large with e.g. attachments

### Encryption Model
- **User Master Key**: Derived from user password using strong KDF (e.g., Argon2)
- **Data Encryption Keys**: Per-record or per-family-member encryption keys
- **Sharing Keys**: Encrypted copies of data keys for authorized family members
- **Transport Security**: TLS 1.3+ for all network communication

## Technology Stack (Proposed)

### iOS Client
- **Language**: Swift 5.x+
- **UI Framework**: SwiftUI
- **Minimum iOS**: iOS 15+ (TBD based on feature requirements)
- **Cryptography**:
  - Apple CryptoKit (primary)
  - libsodium (if additional algorithms needed)
- **Local Storage**: Core Data with encryption or SQLCipher
- **Networking**: URLSession with certificate pinning

### Backend (TBD)
Options under consideration:
- Custom backend (FastAPI/Flask, Node.js)
- Cloud storage with E2EE (evaluated carefully)
- Self-hosted solution

### Open Source Libraries (Candidates)
All libraries must be:
- Actively maintained
- Security-audited or widely peer-reviewed
- Minimal dependencies
- Compatible with App Store requirements

## Project Status

**Current Phase**: Planning & Architecture

This project is in initial planning. The roadmap will be managed through GitHub Issues and Projects.

## Development Roadmap

The project will be developed in phases:

1. **Foundation**: Core encryption, local storage, basic UI
2. **Sync**: Cross-device synchronization
3. **Sharing**: Family member management and selective sharing
4. **Polish**: UX refinement, documentation, testing
5. **Compliance**: Privacy policy, security audit, compliance review

Detailed user stories and tasks will be tracked as GitHub Issues.

## Security Considerations

### Threat Model
- **Trusted**: User's device when locked, iOS Keychain
- **Untrusted**: Network, server/cloud storage, backups in cloud
- **Attack Vectors**: Device theft, network interception, server compromise, malicious sharing

### Security Practices
- Regular security reviews
- Dependency vulnerability scanning
- Penetration testing (when feasible)
- Responsible disclosure policy
- Security-focused code reviews

## Privacy by Design

- **Data Minimization**: Only collect what's necessary
- **User Control**: Users control their data and sharing
- **Transparency**: Clear explanations of data handling
- **Local-First**: Data stays on device unless user enables sync
- **Deletion**: Permanent deletion when requested

## Contributing

This is currently a hobby project. Contributions, suggestions, and security reviews are welcome. Please open an issue for discussion before submitting PRs.

### Security Issues
If you discover a security vulnerability, please email [SECURITY EMAIL TBD] instead of opening a public issue.

## License

[TBD - likely MIT or GPL for hobby project]

## Disclaimer

This application is a personal hobby project and is NOT intended to replace professional medical record systems. It is not HIPAA-compliant in the full legal sense (which requires organizational, physical, and technical safeguards beyond the app itself). Users are responsible for compliance with applicable laws in their jurisdiction.

**This app does not provide medical advice. Always consult healthcare professionals for medical decisions.**

---

**Status**: Planning Phase
**Last Updated**: 2025-12-19
**Contact**: [TBD]
