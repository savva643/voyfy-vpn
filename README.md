# Voyfy VPN

Cross-platform VPN client with Xray VLESS+REALITY support, built with Flutter.

## Features

- **Multi-Platform**: iOS, Android, Windows, macOS, Linux
- **Protocol Support**: VLESS + XTLS Reality
- **Test Authentication**: Email/password with JWT tokens
- **External Auth Ready**: Placeholder for OAuth/SSO integration
- **Subscription Management**: Auto-refresh, multiple servers
- **Kill Switch**: Protects against connection drops
- **Split Tunneling**: Route specific apps through VPN
- **Real-time Stats**: Connection duration, data usage

## Technologies

### Frontend
- Flutter 3.x
- Provider (state management)
- flutter_vpnengine (VPN client engine)
- easy_localization (i18n)

### Backend
- Node.js + Express
- PostgreSQL
- JWT Authentication
- Xray-core (VLESS+REALITY)

### Infrastructure
- Docker + Docker Compose
- Nginx reverse proxy (optional)

## Project Structure

```
voyfy-vpn/
├── voyfy-flutter/          # Flutter application
│   ├── lib/
│   │   ├── models/        # Data models
│   │   ├── providers/     # State management
│   │   ├── services/      # API & VPN services
│   │   ├── screens/       # UI screens
│   │   └── main.dart      # Entry point
│   └── pubspec.yaml
├── backend/                # Node.js API
│   ├── src/
│   │   ├── config/        # Configuration
│   │   ├── controllers/   # Route controllers
│   │   ├── db/            # Database
│   │   ├── middleware/    # Auth middleware
│   │   ├── utils/         # Utilities
│   │   └── index.js       # Entry point
│   ├── Dockerfile
│   └── package.json
└── docker/                 # Docker setup
    ├── docker-compose.yml
    ├── xray/              # Xray config & scripts
    └── nginx/             # Nginx config
```

## Quick Start

### Prerequisites

- Flutter SDK 3.x
- Node.js 18+
- Docker & Docker Compose
- PostgreSQL (or use Docker)

### 1. Backend Setup

```bash
cd backend
npm install

# Create .env file
cat > .env << EOF
PORT=4000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=voyfy_vpn
DB_USER=voyfy
DB_PASSWORD=voyfy_secret
JWT_SECRET=your-super-secret-jwt-key
JWT_REFRESH_SECRET=your-refresh-secret
XRAY_PUBLIC_KEY=your-xray-public-key
XRAY_PRIVATE_KEY=your-xray-private-key
XRAY_SERVER_NAME=www.microsoft.com
XRAY_SHORT_ID=0123456789abcdef
EOF

# Initialize database
npm run init-db

# Start dev server
npm run dev
```

### 2. Docker Setup (Full Stack)

```bash
cd docker

# Create .env file
cat > .env << EOF
DB_USER=voyfy
DB_PASSWORD=voyfy_secret
DB_NAME=voyfy_vpn
JWT_SECRET=your-super-secret-jwt-key
JWT_REFRESH_SECRET=your-refresh-secret
XRAY_PUBLIC_KEY=your-xray-public-key
XRAY_PRIVATE_KEY=your-xray-private-key
XRAY_SERVER_NAME=www.microsoft.com
XRAY_SHORT_ID=0123456789abcdef
XRAY_PORT=443
EOF

# Generate Xray keys (on server)
docker run --rm teddysun/xray xray x25519

# Start all services
docker-compose up -d
```

### 3. Flutter App

```bash
cd voyfy-flutter

# Install dependencies
flutter pub get

# Update API URL in code (lib/services/api_service.dart)
# Or set via settings in the app

# Run on your device
flutter run
```

## Building for Production

### Android

```bash
cd voyfy-flutter
flutter build apk --release
flutter build appbundle --release
```

**Requirements:**
- minSdkVersion: 21
- Permissions in `AndroidManifest.xml`:
  - `INTERNET`
  - `ACCESS_NETWORK_STATE`
  - `FOREGROUND_SERVICE`

### iOS

```bash
cd voyfy-flutter
flutter build ios --release
```

**Requirements:**
- macOS with Xcode
- Apple Developer account
- Personal VPN capability in entitlements

### Windows

```bash
cd voyfy-flutter
flutter build windows --release
```

**Requirements:**
- Administrator privileges for VPN
- Windows 10/11

### macOS

```bash
cd voyfy-flutter
flutter build macos --release
```

**Requirements:**
- Network Extension capability
- Code signing

### Linux

```bash
cd voyfy-flutter
flutter build linux --release
```

**Requirements:**
- Administrator privileges for VPN

## API Endpoints

### Authentication (Test Mode)
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `POST /api/auth/refresh` - Refresh token
- `POST /api/auth/logout` - Logout
- `GET /api/auth/validate` - Validate session
- `POST /api/auth/oauth/login` - External OAuth (placeholder)

### User
- `GET /api/user/profile` - Get profile

### Servers
- `GET /api/servers` - List servers
- `GET /api/servers/:id` - Get server details

### Subscription
- `GET /api/subscription` - Get subscription (authenticated)
- `GET /api/subscription/json` - Get subscription with VLESS URLs
- `GET /api/subscription/:uuid` - Get subscription by UUID (for clients)

### Admin (requires admin role)
- `POST /api/admin/servers` - Add server
- `PUT /api/admin/servers/:id` - Update server
- `DELETE /api/admin/servers/:id` - Delete server
- `GET /api/admin/users` - List users
- `PUT /api/admin/users/:id` - Update user

## Environment Variables

### Backend
- `PORT` - API port (default: 4000)
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` - PostgreSQL
- `JWT_SECRET`, `JWT_REFRESH_SECRET` - JWT signing keys
- `XRAY_PUBLIC_KEY`, `XRAY_PRIVATE_KEY` - Xray Reality keys
- `XRAY_SERVER_NAME` - Reality server name (e.g., www.microsoft.com)
- `XRAY_SHORT_ID` - Reality short ID
- `XRAY_PORT` - Xray listening port (default: 443)

## Future Integration: External Auth

The app includes placeholders for external OAuth/SSO:

1. **Backend**: `POST /api/auth/oauth/login` endpoint ready
2. **Flutter**: `AuthProvider.externalLogin()` method ready
3. **JWT Support**: Full JWT token handling implemented

To connect your existing ecosystem:
1. Implement token validation in `authController.externalLogin()`
2. Map external user ID to local user record
3. Use the same JWT infrastructure

## License

GPL v3 - See LICENSE file

## Support

For server setup instructions, see [SERVER_SETUP.md](./SERVER_SETUP.md)
