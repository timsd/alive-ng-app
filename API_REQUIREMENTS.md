# API Requirements and Configuration Guide

## Overview
This document outlines all the external services, APIs, and configuration requirements needed to run the ALIVE NG Flutter application.

## Required Services

### 1. Supabase (Backend-as-a-Service)
**Status**: ✅ Configured
- **URL**: `https://alavvcknoleddumqdxhv.supabase.co`
- **Anonymous Key**: Already configured in `lib/utils/app_constants.dart`
- **Purpose**: Database, authentication, real-time subscriptions, storage

#### Supabase Database Tables Required:
- `profiles` - User profiles
- `study_guides` - Study materials
- `study_lessons` - Individual lessons
- `study_questions` - Study questions
- `user_study_progress` - User progress tracking
- `user_lesson_progress` - Lesson-specific progress
- `study_sessions` - Study session records
- `prayer_requests` - Prayer request management
- `discipleship_contacts` - Discipleship contacts
- `contact_interactions` - Interaction history
- `progress_milestones` - Progress tracking
- `discipleship_reports` - Reporting system
- `chat_channels` - Chat functionality
- `channel_members` - Chat membership
- `message_reads` - Message read status
- `chapters` - Chapter management
- `chapter_members` - Chapter membership
- `chapter_activities` - Chapter activities
- `chapter_tasks` - Task management
- `chapter_reports` - Chapter reporting
- `health_tracking` - Health data
- `nigerian_meal_plans` - Meal planning
- `wholesome_living_tips` - Health tips
- `notification_settings` - User preferences
- `push_tokens` - FCM token storage
- `transactions` - Payment records

### 2. Firebase Services
**Status**: ✅ Configured
- **Configuration Files**:
  - Android: `android/app/google-services.json`
  - iOS: `ios/Runner/GoogleService-Info.plist`

#### Firebase Services Used:
- **Firebase Auth**: User authentication
- **Firebase Messaging**: Push notifications
- **Firebase Storage**: File storage
- **Firebase Analytics**: App analytics
- **Firebase Crashlytics**: Crash reporting

### 3. GetStream Chat (Optional)
**Status**: ⚠️ Requires API Key
- **Purpose**: Enhanced chat functionality
- **Configuration**: `lib/config/chat_config.dart`
- **Required**: Stream Chat API key and secret

### 4. Paystack (Payment Processing)
**Status**: ⚠️ Currently Commented Out
- **Purpose**: Payment processing for donations
- **File**: `lib/services/paystack_service.dart`
- **Required**: Paystack public and secret keys
- **Note**: Currently disabled in `pubspec.yaml`

## Environment Setup

### Required Environment Variables
Create a `.env` file in the project root (optional, as values are currently hardcoded):

```env
# Supabase Configuration
SUPABASE_URL=https://alavvcknoleddumqdxhv.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYXZ2Y2tub2xlZGR1bXFkeGh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5MDM2NDIsImV4cCI6MjA3MTQ3OTY0Mn0.5zV86kAD7rRYiso6oXYZNmN1C5c-1aaV3qqdF48bLu8

# GetStream Chat (if enabled)
STREAM_CHAT_API_KEY=your_stream_chat_api_key
STREAM_CHAT_SECRET=your_stream_chat_secret

# Paystack (if enabled)
PAYSTACK_PUBLIC_KEY=your_paystack_public_key
PAYSTACK_SECRET_KEY=your_paystack_secret_key
```

## Platform-Specific Requirements

### Android
1. **Minimum SDK**: 21 (Android 5.0)
2. **Target SDK**: 34
3. **Permissions** (in `android/app/src/main/AndroidManifest.xml`):
   - Internet access
   - Camera access
   - Storage access
   - Notification permissions

### iOS
1. **Minimum iOS Version**: 12.0
2. **Permissions** (in `ios/Runner/Info.plist`):
   - Camera usage
   - Photo library access
   - Notification permissions

### Windows Desktop
1. **Requirements**: Developer Mode enabled for symlink support
2. **Firebase**: Limited support for some Firebase services

## Development Setup Checklist

### ✅ Already Configured
- [x] Supabase URL and anonymous key
- [x] Firebase configuration files
- [x] Flutter dependencies
- [x] Basic app structure

### ⚠️ Optional/Additional Setup
- [ ] GetStream Chat API keys (for enhanced chat)
- [ ] Paystack keys (for payment processing)
- [ ] Environment variables file
- [ ] Production Firebase project
- [ ] Production Supabase project

## Running the Application

### Prerequisites
1. **Flutter SDK**: Latest stable version
2. **Android Studio**: For Android development
3. **Xcode**: For iOS development (macOS only)
4. **Visual Studio**: For Windows development

### Quick Start
1. Clone the repository
2. Run `flutter pub get`
3. Choose your platform:
   - **Android**: `flutter run -d <device_id>`
   - **iOS**: `flutter run -d <device_id>`
   - **Web**: `flutter run -d chrome`
   - **Windows**: `flutter run -d windows` (requires Developer Mode)

## Troubleshooting

### Common Issues
1. **Firebase compilation errors**: Ensure configuration files are in correct locations
2. **Supabase connection issues**: Verify URL and API key
3. **Windows symlink errors**: Enable Developer Mode in Windows settings
4. **Web compilation errors**: Some Firebase services have limited web support

### Support
- **Supabase**: [Documentation](https://supabase.com/docs)
- **Firebase**: [Documentation](https://firebase.google.com/docs)
- **Flutter**: [Documentation](https://flutter.dev/docs)

## Security Notes

⚠️ **Important**: The current configuration includes hardcoded API keys in the source code. For production deployment:

1. Move sensitive keys to environment variables
2. Use Firebase App Check for additional security
3. Implement proper Supabase Row Level Security (RLS)
4. Rotate API keys regularly
5. Use different projects for development and production

## Next Steps

1. **For Development**: The app should run with current configuration
2. **For Production**: Set up separate Firebase and Supabase projects
3. **For Enhanced Features**: Configure GetStream Chat and Paystack
4. **For Security**: Implement proper environment variable management