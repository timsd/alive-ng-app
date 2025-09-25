# ALIVE NG App Navigation Documentation

## Overview
This document provides a comprehensive overview of all navigation routes and screens available in the ALIVE NG Flutter application.

## Route Structure
The app uses GoRouter for navigation with a shell route structure that provides consistent navigation across screens.

## Route Categories

### 1. Core Application Routes

#### Splash & Authentication
- **Splash Route**: `/` - AnimatedSplashScreen
  - Initial loading screen with animated logo
  - Automatically redirects to home after animation

- **Authentication Route**: `/auth` - AuthScreen
  - Sign in/Sign up functionality
  - Uses ALIVE logo (recently updated from church icon)
  - Guest access option available

### 2. Main Navigation Routes (Shell Route)
All routes below are wrapped in MainNavigationScreen for consistent navigation:

#### Primary Features
- **Home Route**: `/home` - HomeScreen
  - Main dashboard and overview
  - Guest accessible

- **Study Route**: `/study` - StudyScreen
  - Bible study materials and programs
  - Guest accessible

- **Daily Route**: `/daily` - DailyScreen
  - Daily devotionals and verses
  - Guest accessible

- **Prayer Route**: `/prayer` - PrayerScreen
  - Prayer requests and community prayers
  - Authentication required for submissions

- **Profile Route**: `/profile` - ProfileScreen
  - User profile management
  - Authentication required

- **Health Route**: `/health` - HealthScreen
  - Basic health tracking and tips
  - Guest accessible

- **Missions Route**: `/missions` - MissionsScreen
  - Mission activities and tracking
  - Guest accessible

#### About & Information
- **About App Route**: `/about-app` - AboutAppScreen
  - Application information and features
  - Guest accessible

- **About ALIVE Route**: `/about-alive` - AboutAliveScreen
  - Organization information and mission
  - Guest accessible

#### Interactive Features
- **Bible Game Route**: `/bible-game` - BibleGameScreen
  - Memory verse games and challenges
  - Guest accessible

- **Chat Route**: `/chat` - ChatScreen
  - Community chat functionality
  - Supports channel-specific chats via query parameter
  - Authentication required

#### Enhanced Features (Authentication Required)
- **Chapters Route**: `/chapters` - ChapterScreen
  - Chapter management and activities
  - Authentication required

- **Enhanced Health Route**: `/enhanced-health` - EnhancedHealthScreen
  - Advanced health features including recipes
  - Authentication required

- **Recipe Submission Route**: `/recipe-submission` - RecipeSubmissionScreen
  - Submit meal and natural remedy recipes
  - Authentication required

### 3. Administrative Routes (Authentication Required)

- **Admin Dashboard Route**: `/admin` - AdminDashboardScreen
  - Main administrative interface
  - Role-based access control

- **BOD Trustees Route**: `/bod-trustees` - BodTrusteesScreen
  - Board of Directors and Trustees management
  - Administrative access required

- **User Archive Route**: `/user-archive` - UserArchiveScreen
  - User management and archiving
  - Administrative access required

- **Role Management Route**: `/role-management` - RoleManagementScreen
  - User role assignment and management
  - Administrative access required

- **Conference Route**: `/conference` - ConferencePlatformScreen
  - Virtual conference and meeting platform
  - Authentication required

## Access Control

### Guest Accessible Routes
The following routes are accessible to guest users (without authentication):
- `/home`
- `/study`
- `/daily`
- `/health`
- `/about-app`
- `/about-alive`
- `/bible-game`

### Authentication Required Routes
All other routes require user authentication, including:
- Chat functionality
- Chapter management
- Enhanced health features
- Recipe submission
- Administrative functions
- User profile management

## Navigation Flow

### Initial App Launch
1. **Splash Screen** (`/`) - Shows animated ALIVE logo
2. **Automatic Redirect** to Home (`/home`)
3. **Guest/Auth Check** - Users can browse as guest or authenticate

### Authentication Flow
1. **Auth Screen** (`/auth`) - Sign in/Sign up
2. **Redirect Logic**:
   - If authenticated and on auth route → redirect to home
   - If not authenticated and accessing protected route → redirect to auth
   - If guest mode and accessing guest-accessible route → allow access

### Error Handling
- **404 Error Page** - Custom error screen with "Go Home" button
- **Route Protection** - Automatic redirects for unauthorized access

## Query Parameters

### Chat Route
- **channelId**: Optional parameter to open specific chat channel
- Example: `/chat?channelId=general`

## Navigation Components

### MainNavigationScreen
- Wraps all main routes in a shell
- Provides consistent navigation UI
- Handles bottom navigation or drawer navigation

### Route Guards
- **Authentication Check**: Verifies user login status
- **Guest Mode Check**: Allows limited access for non-authenticated users
- **Role-based Access**: Restricts administrative routes

## Future Enhancements

### Potential New Routes
- Study guides detail pages
- Individual chapter pages
- User messaging/DM functionality
- Event management pages
- Resource library sections

### Navigation Improvements
- Deep linking support
- Route analytics
- Navigation history management
- Breadcrumb navigation for complex flows

## Technical Implementation

### Router Provider
- Uses `GoRouter` with Riverpod state management
- Reactive navigation based on authentication state
- Centralized route configuration

### Route Constants
- All routes defined in `AppConstants` class
- Consistent naming convention
- Easy maintenance and updates

---

*Last Updated: January 2025*
*Total Routes: 20+ screens with various access levels*