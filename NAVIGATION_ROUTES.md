# ALIVE NG App - Navigation Routes & Pages

## Current Navigation Structure

### Main Routes

| Route Path | Screen/Page | Description |
|------------|-------------|-------------|
| `/` | AnimatedSplashScreen | Initial splash screen with animation |
| `/auth` | AuthScreen | Authentication (login/register) |
| `/home` | HomeScreen | Main dashboard/home page |
| `/study` | StudyScreen | Bible study materials and resources |
| `/daily` | DailyScreen | Daily devotionals and verses |
| `/prayer` | PrayerScreen | Prayer requests and tracking |
| `/profile` | ProfileScreen | User profile management |
| `/health` | HealthScreen | Health and wellness features |
| `/missions` | MissionsScreen | Mission activities and tracking |

### About & Information Routes

| Route Path | Screen/Page | Description |
|------------|-------------|-------------|
| `/about-app` | AboutAppScreen | Information about the app |
| `/about-alive` | AboutAliveScreen | Information about ALIVE organization |

### Administrative Routes

| Route Path | Screen/Page | Description |
|------------|-------------|-------------|
| `/admin` | AdminDashboardScreen | Admin control panel |
| `/bod-trustees` | BodTrusteesScreen | Board of Directors and Trustees page |
| `/user-archive` | UserArchiveScreen | Archived user management |
| `/role-management` | RoleManagementScreen | User role and permission management |

### Communication & Conference Routes

| Route Path | Screen/Page | Description |
|------------|-------------|-------------|
| `/conference` | ConferencePlatformScreen | Video conferencing platform |

### Entertainment & Engagement Routes

| Route Path | Screen/Page | Description |
|------------|-------------|-------------|
| `/bible-game` | BibleGameScreen | Bible-based games and quizzes |

## Navigation Structure

The app uses **GoRouter** with a **ShellRoute** pattern:

- **Splash Route**: Initial entry point
- **Auth Route**: Standalone authentication
- **Main Shell**: Contains all main app screens with bottom navigation

## Authentication Flow

1. App starts at `/` (splash screen)
2. Redirects to `/auth` if not authenticated
3. Redirects to `/home` if authenticated
4. All main routes require authentication

## Missing Features to Implement

Based on user requirements, the following routes/pages need to be added:

### Chat & Communication
- `/chat` - Main chat/messaging interface
- `/chat/channels` - Channel-based messaging
- `/chat/direct` - Direct messages

### Leadership & Archive
- `/leadership-archive` - Archive of past leadership positions
- `/leadership-management` - Current leadership management

### Materials & Downloads
- `/materials` - Downloadable materials with donation system
- `/tracts` - Tract printing with donation requirement

### Health & Lifestyle
- `/meal-plans` - Nigerian vegetarian meal plans
- `/lifestyle-tracker` - 8 natural remedies tracker
- `/living-tips` - Wholesome living tips

### Discipleship & Evangelism
- `/discipleship-tracker` - Track disciples and prospects
- `/study-guides` - One-on-one evangelism guides

### Chapter Management
- `/chapters` - Chapter groups and management
- `/chapter-reports` - Chapter activity reporting
- `/team-management` - Field workers, campus missionaries, AMTC teams

### Enhanced Admin Features
- `/admin/content-management` - Content editing and updates
- `/admin/user-promotion` - User promotion/demotion
- `/admin/organization-settings` - Organization-wide settings

## Current App Constants

### Supported Features
- **Bible Versions**: KJV, NKJV, NIV
- **Languages**: English, Yoruba, Igbo, Hausa
- **Health Categories**: Nutrition, Exercise, Water, Sunlight, Temperance, Fresh Air
- **Prayer Categories**: Personal, Family, Health, Work, Ministry, Others
- **Study Levels**: Beginner, Intermediate, Advanced
- **Mission Categories**: Evangelism, Community Service, Education, Health, Youth

### Notification Types
- Daily verse notifications
- Prayer reminders
- Study reminders
- Health tracking reminders
- Mission reminders

## Technical Implementation

- **Router**: GoRouter with Provider pattern
- **State Management**: Flutter Riverpod
- **Authentication**: Supabase Auth
- **Database**: Supabase
- **Navigation**: Bottom navigation with shell routing
- **Error Handling**: Custom error pages with navigation back to home

This documentation will be updated as new features are implemented.