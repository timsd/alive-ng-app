# ALIVE NG App - Integration Guide for Live Information & APIs

## Overview

This guide will walk you through setting up all the necessary third-party services, APIs, and platforms needed to make the ALIVE NG app fully functional with live data and real-time features.

## Current Integrations

### 1. Supabase (Already Configured)
- **Purpose**: Backend database, authentication, real-time subscriptions
- **Status**: ✅ Already set up
- **Configuration**: Located in `lib/constants/app_constants.dart`
- **Features**: User management, data storage, real-time updates

### 2. Firebase (Partially Configured)
- **Purpose**: Push notifications, messaging
- **Status**: ⚠️ Needs completion
- **Current**: Firebase messaging service exists
- **Next Steps**: Complete Firebase project setup

## Required New Integrations

### 3. Payment Processing (For Donations)


#### Paystack (Nigeria-focused)
- **Website**: https://paystack.com
- **Purpose**: Local payment processing for Nigerian users
- **Setup Steps**:
  1. Create Paystack account
  2. Get API keys
  3. Install `flutter_paystack` package

### 4. Video Conferencing API

#### Jitsi Meet
- **Website**: https://jitsi.org
- **Purpose**: Open-source video conferencing
- **Setup Steps**:
  1. Use Jitsi Meet API
  2. Install `jitsi_meet_flutter_sdk` package

### 5. File Storage & CDN

#### Supabase Storage (Recommended)
- **Purpose**: Store downloadable materials, documents, images
- **Setup Steps**:
  1. Enable Storage in Supabase dashboard
  2. Create buckets for different content types
  3. Set up storage policies

### 6. Email Service

#### SendGrid
- **Website**: https://sendgrid.com
- **Purpose**: Send emails for notifications, reports, communications
- **Setup Steps**:
  1. Create SendGrid account
  2. Get API key
  3. Set up email templates
  4. Configure in backend


### 8. Analytics & Monitoring

#### Firebase Analytics
- **Purpose**: Track user engagement and app performance
- **Setup Steps**:
  1. Enable Analytics in Firebase project
  2. Install `firebase_analytics` package
  3. Add tracking events

#### Sentry (Error Monitoring)
- **Website**: https://sentry.io
- **Purpose**: Error tracking and performance monitoring
- **Setup Steps**:
  1. Create Sentry account
  2. Create Flutter project
  3. Install `sentry_flutter` package

## Step-by-Step Setup Guide

### Phase 1: Complete Firebase Setup

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Create/Access Project**: "alive-ng-app"
3. **Enable Services**:
   - Authentication (Email/Password, Google)
   - Cloud Messaging (FCM)
   - Analytics
   - Crashlytics
4. **Download Configuration Files**:
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)
5. **Add to Project**:
   - Place files in appropriate directories
   - Update `pubspec.yaml` with Firebase packages

### Phase 2: Payment Integration

1. **Choose Payment Provider** ( Paystack)
2. **Create Account and Get API Keys**
3. **Add Environment Variables**:
  
4. **Install Flutter Package**:
   ```yaml
   dependencies:
     
     
     flutter_paystack: ^1.0.7
   ```

### Phase 3: Video Conferencing



### Phase 4: Storage Setup

1. **Enable Supabase Storage**
2. **Create Buckets**:
   - `materials` (for downloadable content)
   - `tracts` (for tract files)
   - `avatars` (for user profile pictures)
   - `documents` (for organizational documents)
3. **Set Storage Policies**

### Phase 5: Email Service

1. **Create SendGrid Account**
2. **Get API Key**
3. **Create Email Templates**:
   - Welcome email
   - Password reset
   - Report notifications
   - Chapter communications

## Environment Configuration

Create a `.env` file in the project root:

```env
# Supabase (Already configured)
SUPABASE_URL=https://alavvcknoleddumqdxhv.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# Firebase
FIREBASE_PROJECT_ID=alive-ng-app

# Payment
PAYSTACK_PUBLISHABLE_KEY=pk_test_...
PAYSTACK_SECRET_KEY=sk_test_...

# Video Conferencing


# Email
SENDGRID_API_KEY=SG...


# Analytics
SENTRY_DSN=https://...
```

## Security Considerations

1. **Never commit API keys to version control**
2. **Use environment variables for sensitive data**
3. **Implement proper authentication checks**
4. **Set up proper database security rules**
5. **Use HTTPS for all API communications**
6. **Implement rate limiting for APIs**

## Testing Environments

### Development
- Use test API keys
- Separate Supabase project for development
- Local testing for video calls

### Production
- Production API keys
- Production Supabase project
- SSL certificates
- Domain setup

## Deployment Checklist

- [ ] All API keys configured
- [ ] Firebase project set up
- [ ] Payment processing tested
- [ ] Video conferencing tested
- [ ] Email service configured
- [ ] Storage buckets created
- [ ] Security rules implemented
- [ ] Analytics tracking added
- [ ] Error monitoring set up
- [ ] Performance monitoring enabled

## Cost Estimates (Monthly)

- **Supabase**: $0-25 (depending on usage)
- **Firebase**: $0-50 (depending on usage)
- **SendGrid**: $0-15 (up to 40,000 emails)
- **Sentry**: $0-26 (depending on events)

## Support & Documentation

- **Supabase Docs**: https://supabase.com/docs
- **Firebase Docs**: https://firebase.google.com/docs
- **Flutter Docs**: https://docs.flutter.dev


## Advanced Features Implementation

### 9. Chat & Messaging System with Tagging

#### Stream Chat (Recommended)
- **Website**: https://getstream.io/chat/
- **Purpose**: Real-time messaging with advanced features
- **Setup Steps**:
  1. Create Stream account
  2. Get API key and secret
  3. Install `stream_chat_flutter` package
  4. Implement tagging system (#bod, #director, @username)

#### Custom Tagging Implementation
- **Tag Types**:
  - `#bod` - Board of Directors visibility
  - `#director` - Directors visibility
  - `#chap_coor` - Chapter Coordinators visibility
  - `@username` - Individual user mentions
- **Database Schema**:
  ```sql
  CREATE TABLE message_tags (
    id UUID PRIMARY KEY,
    message_id UUID REFERENCES messages(id),
    tag_type VARCHAR(20), -- 'role' or 'user'
    tag_value VARCHAR(100), -- role name or username
    created_at TIMESTAMP DEFAULT NOW()
  );
  ```

### 10. Leadership Archive System

#### Database Setup
```sql
CREATE TABLE leadership_archive (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  position VARCHAR(100),
  start_date DATE,
  end_date DATE,
  year_of_service INTEGER,
  contact_email VARCHAR(255),
  contact_phone VARCHAR(20),
  achievements TEXT,
  archived_at TIMESTAMP DEFAULT NOW(),
  archived_by UUID REFERENCES users(id)
);
```

### 11. Donation System Integration

#### Minimum Donation Requirements
- **General Materials**: Optional donation
- **Tract Printing**: Minimum $12 USD
- **Premium Content**: Tiered pricing

#### Implementation Steps
1. **Create Donation Tiers**:
   ```dart
   enum DonationTier {
     optional(0),
     basic(5),
     tract(12),
     premium(25),
     supporter(50);
   }
   ```

2. **Payment Flow**:
   - User selects material
   - Check donation requirement
   - Process payment if required
   - Grant access to download

### 12. Nigerian Health Content Integration

#### Content Sources
- **Adventist Health Ministries**: Official SDA health resources
- **Nigerian Food Database**: Local ingredients and recipes
- **Regional Adaptation**: East, West, North Nigeria specifics

#### Implementation
1. **Meal Planning Database**:
   ```sql
   CREATE TABLE nigerian_meals (
     id UUID PRIMARY KEY,
     name VARCHAR(200),
     region VARCHAR(50), -- 'east', 'west', 'north'
     ingredients JSONB,
     instructions TEXT,
     health_principles TEXT[],
     bible_verse VARCHAR(500)
   );
   ```

2. **8 Natural Remedies Tracker**:
   - Nutrition tracking
   - Exercise logging
   - Water intake
   - Sunlight exposure
   - Temperance monitoring
   - Fresh air activities
   - Rest quality
   - Trust in God (spiritual practices)

## Platform-Specific Setup

### Android Configuration

1. **Update `android/app/build.gradle`**:
   ```gradle
   android {
     compileSdkVersion 34
     minSdkVersion 21
     targetSdkVersion 34
   }
   ```

2. **Add Permissions in `android/app/src/main/AndroidManifest.xml`**:
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
   ```

### iOS Configuration

1. **Update `ios/Runner/Info.plist`**:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>This app needs camera access for video conferencing</string>
   <key>NSMicrophoneUsageDescription</key>
   <string>This app needs microphone access for video conferencing</string>
   ```

2. **Set minimum iOS version in `ios/Podfile`**:
   ```ruby
   platform :ios, '12.0'
   ```

## Database Schema Updates

### Required Tables for New Features

```sql
-- Chat and Messaging
CREATE TABLE channels (
  id UUID PRIMARY KEY,
  name VARCHAR(100),
  type VARCHAR(20), -- 'public', 'private', 'direct'
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE messages (
  id UUID PRIMARY KEY,
  channel_id UUID REFERENCES channels(id),
  user_id UUID REFERENCES users(id),
  content TEXT,
  message_type VARCHAR(20) DEFAULT 'text',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Donations and Downloads
CREATE TABLE donations (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  amount DECIMAL(10,2),
  currency VARCHAR(3) DEFAULT 'USD',
  purpose VARCHAR(100),
  payment_method VARCHAR(50),
  transaction_id VARCHAR(255),
  status VARCHAR(20),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE material_downloads (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  material_id UUID,
  donation_id UUID REFERENCES donations(id),
  download_count INTEGER DEFAULT 0,
  last_downloaded TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Security Implementation

### Row Level Security (RLS) Policies

```sql
-- Messages visibility based on tags
CREATE POLICY "Users can see tagged messages" ON messages
  FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM message_tags mt
      JOIN user_roles ur ON ur.user_id = auth.uid()
      WHERE mt.message_id = messages.id
      AND (
        (mt.tag_type = 'role' AND mt.tag_value = ur.role) OR
        (mt.tag_type = 'user' AND mt.tag_value = (SELECT username FROM users WHERE id = auth.uid()))
      )
    )
  );

-- Leadership archive access
CREATE POLICY "Leaders can view archive" ON leadership_archive
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
      AND role IN ('admin', 'director', 'coordinator')
    )
  );
```

## Testing Strategy

### Unit Tests
- Payment processing
- Tagging system logic
- Archive functionality
- Health tracking calculations

### Integration Tests
- Video conferencing
- Real-time messaging
- File upload/download
- Database operations

### End-to-End Tests
- Complete user workflows
- Payment to download flow
- Conference creation and joining
- Message tagging and visibility

## Performance Optimization

### Caching Strategy
- **Redis**: Session management and real-time data
- **CDN**: Static assets and downloadable materials
- **Local Storage**: Offline content and user preferences

### Database Optimization
- Indexes on frequently queried columns
- Partitioning for large tables (messages, activities)
- Connection pooling for high concurrency

## Monitoring and Analytics

### Key Metrics to Track
- User engagement (daily/monthly active users)
- Feature adoption rates
- Donation conversion rates
- Video conference usage
- Message volume and engagement
- Health tracking compliance
- Study guide completion rates

### Alerting Setup
- Payment processing failures
- Video conference connection issues
- Database performance degradation
- High error rates
- Security incidents

## Next Steps

1. **Phase 1**: Complete Firebase and basic integrations
2. **Phase 2**: Implement payment processing and donation system
3. **Phase 3**: Set up video conferencing platform
4. **Phase 4**: Build comprehensive chat system with tagging
5. **Phase 5**: Add Nigerian health content and tracking
6. **Phase 6**: Implement leadership archive system
7. **Phase 7**: Set up monitoring and analytics
8. **Phase 8**: Comprehensive testing and optimization
9. **Phase 9**: Production deployment and scaling
10. **Phase 10**: User training and documentation

## Maintenance and Updates

- **Weekly**: Monitor system health and performance
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Review and update content (health tips, study guides)
- **Annually**: Major feature updates and platform upgrades

This guide will be updated as new integrations are added or existing ones are modified.