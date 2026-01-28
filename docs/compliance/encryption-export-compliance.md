# Encryption Export Compliance

This document explains the app's encryption usage and why it qualifies for U.S. export compliance exemptions under App Store distribution.

## Summary

| Setting | Value |
|---------|-------|
| `ITSAppUsesNonExemptEncryption` | `NO` |
| Documentation Required | None |
| France Distribution | Excluded (requires ANSSI declaration) |

## Encryption Usage Inventory

### Apple CryptoKit (Built into iOS)

| Algorithm | Standard | Usage |
|-----------|----------|-------|
| AES-256-GCM | NIST | Record and attachment encryption |
| HKDF-SHA256 | RFC 5869 | Key derivation from OPAQUE export key |
| HMAC-SHA256 | RFC 2104 | Content deduplication hashing |
| SHA256 | FIPS 180-4 | Client identifier generation |
| Curve25519 ECDH | RFC 7748 | Identity key agreement |
| AES Key Wrap | RFC 3394 | Family Member Key wrapping |

### Third-Party Libraries (Standard Algorithms)

| Library | Algorithm | Standard | Usage |
|---------|-----------|----------|-------|
| Swift-Sodium (libsodium) | Argon2id | RFC 9106 | Password-based key derivation |
| OpaqueSwift (opaque-ke) | OPAQUE | RFC 9497 | Zero-knowledge authentication |

### Transport Security

| Protocol | Usage |
|----------|-------|
| HTTPS/TLS 1.3 | All network communication via URLSession |

## Why Exempt

The app qualifies for export compliance exemptions under two categories from [EAR Category 5, Part 2, Note 4](https://www.bis.doc.gov/index.php/policy-guidance/encryption):

### Exemption (a): Medical End-Use

This is a personal health records management application specially designed for medical end-use. The encryption protects sensitive health data, not as a feature sold to users, but as a security measure for medical information.

### Exemption (c): Authentication and Data Protection

All encryption in the app is limited to:

- **Authentication** - OPAQUE protocol authenticates users without transmitting passwords
- **Data protection** - AES-256-GCM encrypts stored health records

The app does not provide encryption as a service or feature to end users. Encryption is solely a security mechanism.

## Algorithm Classification

**All algorithms are standard and publicly available:**

- AES-256-GCM: NIST standard, implemented via Apple CryptoKit
- Argon2id: RFC 9106, winner of Password Hashing Competition (2015)
- OPAQUE: RFC 9497, IETF standard for asymmetric PAKE
- HKDF: RFC 5869, IETF standard
- Curve25519: RFC 7748, IETF standard

**No proprietary algorithms are used.**

## App Store Connect Questionnaire Responses

When submitting to App Store Connect, the following responses were provided:

1. **Does your app use encryption?**
   → Yes (uses standard encryption for auth and data protection)

2. **Which encryption algorithms does your app implement?**
   → "Standard encryption algorithms instead of, or in addition to, using or accessing the encryption within Apple's operating system"

   (Selected because libsodium and OpaqueSwift are third-party, even though they implement standard algorithms)

3. **Is your app going to be available for distribution in France?**
   → No

   (France requires ANSSI declaration for apps with secure storage features; can be added later if needed)

4. **Outcome:**
   → "Based on your answers, you don't need to upload any documents."

## France Distribution

France is currently excluded from distribution because:

1. French ANSSI (Agence Nationale de la Sécurité des Systèmes d'Information) requires a declaration for apps with "Secure Storage" features
2. While medical apps may qualify for an exemption, this requires direct confirmation from ANSSI
3. The declaration process takes 1-6 months

**To add France later:**

1. Submit declaration to ANSSI at `controle@ssi.gouv.fr`
2. Portal: <https://cyber.gouv.fr/controle-reglementaire-sur-la-cryptographie-les-formulaires>
3. Once approved, update App Store Connect distribution territories

## Annual Reporting

Since the app uses **exempt** encryption and Apple handles distribution, the annual BIS self-classification report is likely not required. Per Apple's documentation:

> "If you use non-exempt encryption and provide documentation to Apple, the self-classification report isn't necessary."

Since no documentation was required (exempt encryption), and Apple distributes the app, Apple handles export compliance on behalf of developers.

However, if uncertain, an optional self-classification report can be filed by February 1st each year to BIS:

- Email: `crypt-supp8@bis.doc.gov` and `enc@nsa.gov`
- Template: <https://www.bis.doc.gov/index.php/documents/new-encryption/1675-sample-annual-self-classification-report>

## References

- [Apple: Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
- [Apple: Export Compliance Overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [BIS: Encryption Policy Guidance](https://www.bis.doc.gov/index.php/policy-guidance/encryption)
- [EAR Category 5, Part 2](https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-774/supplement-No.%201%20to%20part%20774/category-5/section-774.Cat5.Pt2)
- [ANSSI Crypto Portal](https://cyber.gouv.fr/en/crypto)

## Document History

| Date | Change |
|------|--------|
| 2026-01-28 | Initial analysis and exemption determination |
