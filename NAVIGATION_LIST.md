# ALIVE NG App - Complete Navigation & Pages List

## Overview
This document provides a comprehensive list of all pages, routes, and navigation paths available in the ALIVE NG Flutter application.

## Main Navigation Structure

### 1. Authentication & Onboarding
- **Splash Screen** (`/`) - Animated splash screen with app logo
- **Authentication Screen** (`/auth`) - Login/Register functionality

### 2. Core Navigation (Bottom Navigation Bar)
- **Home Screen** (`/home`) - Dashboard with quick actions and overview
- **Study Screen** (`/study`) - Bible study materials and resources
- **Daily Screen** (`/daily`) - Daily devotionals and verses
- **Prayer Screen** (`/prayer`) - Prayer requests and tracking
- **Profile Screen** (`/profile`) - User profile and settings

### 3. Feature Screens

#### Health & Wellness
- **Health Screen** (`/health`) - Basic health tracking
- **Enhanced Health Screen** - Comprehensive health features including:
  - Nigerian meal plans and recipes
  - Wholesome living tips
  - Lifestyle tracker (8 natural remedies)
  - Health insights and statistics

#### Study & Learning
- **Study Guides Screen** - One-on-one evangelism study guides
  - Browse study guides
  - Track progress
  - View statistics
  - Take interactive lessons
- **Bible Reader Screen** - Bible reading interface
- **Bible Game Screen** (`/bible-game`) - Interactive Bible games

#### Communication & Community
- **Chat Screen** - Messaging system with:
  - Channel-based communication
  - Tagging system (#bod, #director, @username)
  - Message input and display
  - Real-time messaging
- **Chapters Screen** - Chapter/group management:
  - Browse chapters
  - Manage memberships
  - Track activities and tasks
  - Chapter reporting

#### Discipleship & Ministry
- **Discipleship Screen** - Disciple tracking system:
  - Contact management
  - Progress tracking
  - Prayer requests
  - Activity logging
  - Report generation
- **Missions Screen** (`/missions`) - Mission activities and tracking

#### Materials & Resources
- **Materials Screen** - Downloadable content with:
  - Donation-based access
  - Tract printing ($12 minimum donation)
  - Resource library
  - Download management

#### Conference & Meetings
- **Conference Platform Screen** (`/conference`) - Video conferencing:
  - Zoom-like functionality
  - Meeting management
  - Participant controls
  - Screen sharing capabilities

### 4. Administrative Screens

#### Admin Dashboard
- **Admin Dashboard Screen** (`/admin`) - Main admin control panel
- **Role Management Screen** (`/role-management`) - User role assignment
- **User Archive Screen** (`/user-archive`) - Archived user management
- **Leadership Archive Screen** - Leadership position history

#### Board & Leadership
- **BOD Trustees Screen** (`/bod-trustees`) - Board of Directors interface:
  - Board member management
  - Decision tracking
  - Document management
  - Meeting scheduling
- **Board Decisions Screen** - Decision tracking and voting
- **Board Documents Screen** - Document repository
- **Board Reports Screen** - Report management

### 5. Information & About
- **About App Screen** (`/about-app`) - Application information
- **About ALIVE Screen** (`/about-alive`) - Organization information

## Feature-Specific Navigation

### Health Module Navigation
- Overview Tab - Health statistics and quick actions
- Meal Plans Tab - Nigerian-specific vegetarian recipes
- Tips Tab - Wholesome living guidance
- Tracker Tab - 8 natural remedies tracking
- Insights Tab - Health analytics and progress

### Study Guides Navigation
- Overview Tab - Featured guides and recent activity
- Browse Tab - All available study guides with filters
- Progress Tab - User's study progress tracking
- Statistics Tab - Learning analytics

### Discipleship Navigation
- Overview Tab - Dashboard with key metrics
- Contacts Tab - Disciple/prospect management
- Activities Tab - Study sessions and interactions
- Prayer Tab - Prayer request management
- Reports Tab - Progress reporting

### Chapters Navigation
- Overview Tab - Chapter statistics and activity
- Browse Tab - Available chapters to join
- My Chapters Tab - User's chapter memberships
- Activities Tab - Chapter events and programs
- Tasks Tab - Assigned tasks and responsibilities

### Chat Navigation
- Channel List - Available communication channels
- Direct Messages - One-on-one conversations
- Tagged Messages - Messages with specific tags
- Group Chats - Chapter and team communications

### Admin Navigation
- User Management - User accounts and permissions
- Content Management - App content and materials
- System Settings - Application configuration
- Analytics Dashboard - Usage statistics
- Archive Management - Archived users and leadership

## Access Control & Permissions

### Public Access
- Splash Screen
- Authentication Screen
- About screens

### Authenticated Users
- All core navigation screens
- Basic feature screens
- Profile management

### Role-Based Access

#### Leaders/Coordinators
- Chapter management
- Report submission
- Team member management
- Conference platform access

#### Directors
- Advanced reporting
- Multi-chapter oversight
- Leadership tools
- Conference hosting

#### Board Members (BOD/Trustees)
- Board-specific screens
- Decision making tools
- Confidential documents
- Executive reporting

#### Administrators
- All admin screens
- User management
- System configuration
- Archive access

## Navigation Patterns

### Bottom Navigation
- Home, Study, Daily, Prayer, Profile
- Always visible on main screens
- Quick access to core features

### Tab Navigation
- Used within feature screens
- Organizes related functionality
- Maintains context within features

### Drawer Navigation
- Administrative functions
- Secondary features
- Settings and configuration

### Modal Navigation
- Forms and data entry
- Detailed views
- Confirmation dialogs

## Deep Linking Support

All routes support deep linking for:
- Direct access to specific features
- Sharing specific content
- Push notification navigation
- External app integration

## Mobile Responsiveness

All screens are designed to be:
- Mobile-first responsive
- Auto-fit for different screen sizes
- Optimized for Android and iOS
- Touch-friendly interface elements

## Real-time Features

Screens with real-time updates:
- Chat Screen - Live messaging
- Conference Platform - Live video/audio
- Discipleship tracking - Progress updates
- Health tracking - Live statistics
- Chapter activities - Real-time notifications

## Offline Capabilities

Screens with offline support:
- Bible Reader - Cached content
- Study Guides - Downloaded lessons
- Daily devotionals - Pre-loaded content
- Health tracking - Local storage

This navigation structure provides a comprehensive user experience covering all aspects of church ministry, personal growth, health tracking, and organizational management within the ALIVE NG application.