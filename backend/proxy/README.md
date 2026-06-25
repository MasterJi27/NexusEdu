# NexusEdu Secure API Proxy

## Setup

1. Install dependencies:
```bash
cd backend/proxy
npm install
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your keys
```

3. Start server:
```bash
npm start
```

## API Endpoints

### Auth
- `POST /api/auth/signup` - Create account
- `POST /api/auth/login` - Login
- `POST /api/auth/refresh` - Refresh token
- `POST /api/auth/logout` - Logout

### AI (Requires Authentication)
- `POST /api/ai/chat` - Chat with AI
- `POST /api/ai/solve-doubt` - Solve a doubt
- `POST /api/ai/generate-quiz` - Generate quiz
- `POST /api/ai/generate-notes` - Generate notes
- `POST /api/ai/solve-math` - Solve math

### User (Requires Authentication)
- `GET /api/user/profile` - Get profile
- `PUT /api/user/profile` - Update profile

### Admin (Requires Admin Role)
- `GET /api/admin/stats` - Get statistics
- `GET /api/admin/users` - Get all users

## Security Features

- JWT Authentication
- Rate Limiting (10 AI requests/minute)
- Input Sanitization
- Prompt Injection Protection
- CORS Protection
- Helmet Security Headers
- Request Logging
- Password Hashing (bcrypt)

## Deploy to Railway/Render

1. Create account on Railway or Render
2. Connect GitHub repo
3. Set environment variables
4. Deploy

## Flutter App Configuration

Update `lib/core/services/secure_api_service.dart`:
```dart
static const String _baseUrl = 'https://your-proxy-url.railway.app';
```
