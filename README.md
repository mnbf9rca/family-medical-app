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

> **⚠️ IMPORTANT**: The cryptographic architecture must be designed **before** implementing local storage, sync, or sharing features. The choice of database technology (Core Data vs SQLCipher) is downstream from the crypto architecture design, as the sharing model and key hierarchy fundamentally affect how encrypted data is structured and stored.

### Cryptographic Architecture (Design Required - See Issue #2)

The following cryptographic components require detailed design before implementation:

#### Key Hierarchy
- **User Master Key**: Derived from user password using strong KDF (PBKDF2-HMAC-SHA256 with 100k+ iterations or Argon2id)
- **Data Encryption Keys**: Strategy TBD (per-record, per-family-member, or hybrid approach)
- **Sharing Keys**: Mechanism TBD (symmetric key wrapping, public-key encryption, or per-family-member keys)
- **Key Rotation**: Strategy for updating encryption keys without data loss

#### Sharing Model
Design decisions required:
- **Key Distribution**: How are data encryption keys shared with authorized family members?
- **Access Revocation**: How to cryptographically enforce removal of access (key rotation, re-encryption)?
- **Multi-User Encryption**: Each record accessible by multiple authorized users without server decryption
- **Ownership Model**: How children's data remains accessible when ownership transfers (age-based access control)

#### Sync Encryption
- **Blob Packaging**: How to package encrypted data for server storage
- **Metadata Encryption**: What sync metadata must be encrypted vs can be plaintext
- **Conflict Resolution**: How to merge conflicts in encrypted data
- **Delta Sync**: How to efficiently sync encrypted changes (especially for large attachments)

**Status**: Cryptographic architecture design is prerequisite for implementation. See `docs/adr/` for architectural decisions.

---

### Client-Side (iOS)
- **Swift/SwiftUI**: Native iOS development
- **Cryptography**: CryptoKit (AES-256-GCM) per AGENTS.md requirements
- **Local Database**: Core Data with manual field-level encryption (decision pending crypto architecture design)
- **Keychain**: Secure key storage using iOS Keychain Services
- **Sync Engine**: Handles data synchronization including conflict resolution (design TBD)

### Server-Side (Sync Backend - Phase 2)
- **Purpose**: Encrypted blob storage and synchronization only
- **No Access**: Cannot decrypt user data (zero-knowledge architecture)
- **Minimal Metadata**: Only essential sync metadata (timestamps, device IDs, encrypted payloads)
- **Technology**: TBD - potentially simple REST API or cloud storage (evaluated for privacy)
- **Scalability**: Designed to handle multiple users and family groups efficiently
- **Efficient Sync Protocol**: Delta sync to minimize data transfer, particularly for large attachments

### Transport Security
- **TLS 1.3+**: All network communication over TLS 1.3 or higher
- **Certificate Pinning**: URLSession with certificate pinning to prevent MITM attacks

## Technology Stack (Proposed)

### iOS Client
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum iOS**: iOS 16.0+ (per AGENTS.md)
- **Cryptography**:
  - **Primary**: Apple CryptoKit (AES-256-GCM mandatory per AGENTS.md)
  - **KDF**: PBKDF2-HMAC-SHA256 (min 100k iterations) or Argon2id
  - **NO custom crypto implementations** - CryptoKit only
- **Local Storage**: Core Data with manual field-level encryption using CryptoKit (pending crypto architecture design)
- **Networking**: URLSession with certificate pinning
- **Authentication**: LocalAuthentication framework (Face ID / Touch ID)

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

### Phase 0: Cryptographic Architecture Design (Current)
**Prerequisites for all implementation work**
- Design complete key hierarchy (master key → data keys → sharing keys)
- Design sharing model (how multiple users decrypt same data)
- Design sync encryption (how to package encrypted blobs for server)
- Design access revocation mechanism
- Document in ADRs before any implementation begins

### Phase 1: Local-Only Foundation
**Depends on**: Phase 0 complete
- Implement key derivation and management (Keychain integration)
- Implement Core Data model with field-level encryption (CryptoKit)
- Basic UI for single-user medical record entry
- Biometric authentication (Face ID / Touch ID)
- Local data export/import (encrypted backups)

### Phase 2: Cross-Device Sync
**Depends on**: Phase 1 complete
- Implement sync backend (encrypted blob storage)
- Sync protocol implementation (conflict resolution)
- Multi-device key management
- Delta sync for efficient data transfer

### Phase 3: Family Sharing
**Depends on**: Phase 2 complete
- Implement cryptographic sharing model from Phase 0 design
- Family member management UI
- Granular permission system
- Access revocation and key rotation
- Age-based access control

### Phase 4: Polish & Compliance
**Depends on**: Phase 3 complete
- UX refinement and accessibility
- Comprehensive testing and security audit
- Privacy policy and compliance documentation (GDPR, HIPAA-aware)
- Performance optimization
- Beta testing

Detailed user stories and tasks will be tracked as GitHub Issues.

**Current Status**: Phase 0 - Researching cryptographic architecture decisions (see Issue #2)

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
