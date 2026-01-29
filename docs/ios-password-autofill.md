# iOS Password AutoFill

## Overview

iOS Password AutoFill allows the system to automatically save and fill passwords for the app.

## Configuration

### 1. Associated Domains

- **Domain**: `recordwell.app`
- **Entitlements**: `FamilyMedicalApp/FamilyMedicalApp.entitlements`
- **Team ID**: `BU7526J4QY`
- **Bundle ID**: `com.cynexia.FamilyMedicalApp`

### 2. Domain Association File

The `apple-app-site-association` file is hosted at:

```
https://recordwell.app/.well-known/apple-app-site-association
```

Requirements:

- Must use HTTPS
- Must return `Content-Type: application/json`
- Must be publicly accessible (no authentication)

### 3. View Configuration

- Username field: `.textContentType(.username)`
- Password setup: `.textContentType(.newPassword)`
- Password unlock: `.textContentType(.password)`
- Submit handlers configured for automatic password saving

## Testing

1. Build and install on a physical iOS device (AutoFill doesn't work in Simulator)
2. Complete password setup - iOS will prompt to save the password
3. Lock the app and unlock - iOS will offer to fill the password

## Troubleshooting

- Verify the association file is accessible: `curl https://recordwell.app/.well-known/apple-app-site-association`
- Wait 10-15 minutes after hosting for Apple's CDN to cache the file
- Delete and reinstall the app if needed

## References

- [Apple Password AutoFill Documentation](https://developer.apple.com/documentation/security/password_autofill)
- [WWDC20: AutoFill Everywhere](https://developer.apple.com/videos/play/wwdc2020/10115/)
