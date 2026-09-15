# Monthly Donation Reminder Function

## Overview
Sends monthly push notifications to users on the 1st of each month, encouraging ministry support with multilingual content (English, Yoruba, Igbo, Hausa).

## Environment Variables Required

| Variable | Description | Example |
|---|---|---|
| `APPWRITE_ENDPOINT` | Appwrite API endpoint | `https://api.alivenigeria.org/v1` |
| `APPWRITE_PROJECT_ID` | Appwrite project ID | `6a3bef53002f5090dedf` |
| `APPWRITE_DATABASE_ID` | Appwrite database ID | `6a089307002e54291a32` |
| `APPWRITE_USERS_COLLECTION_ID` | Users collection ID | `6a089307002e54291a32` |
| `APPWRITE_FUNCTION_API_KEY` | Function API key with users.read scope | `your-api-key` |
| `DONATE_DEEP_LINK` | Deep link to donation screen | `alivenigeria://donate` |

## Function ID
`monthly_donation_reminder`

## Scopes Needed
- `users.read`

## Cron Schedule
Monthly on the 1st day:
```
0 0 1 * *
```

## Message Flow
1. Runs on the 1st of each month (checked via `getDate() === 1`)
2. Fetches all users from the users collection
3. Filters for active users (email verified, status active)
4. Groups users by preferred language
5. Sends push notification in each user's preferred language
6. Notification click opens the donation screen via deep link

## Supported Languages
| Code | Language |
|---|---|
| `en` | English |
| `yo` | Yoruba |
| `ig` | Igbo |
| `ha` | Hausa |

## Push Notification Payload
Each user receives a notification with:
- Title: Ministry Support Reminder
- Body: Localized message (~160 characters)
- Data: `{ "route": "donate" }` for deep linking

Tapping the notification opens the donation screen in the app.