# Firebase Deployment Instructions

## Current Status
✅ Firebase Admin SDK integrated  
✅ Firebase hosting configured for `alive-ng-legal` site  
✅ GitHub Actions workflow created  
✅ Service account key added to GitHub secrets  

## Issues Encountered
❌ Local Flutter SDK installation blocked by disk space  
❌ Node.js/npm not available for Firebase CLI  

## Solution: GitHub Actions Deployment

Since local installation is blocked, we've set up automated deployment through GitHub Actions.

### What's Already Done:
1. **Firebase Configuration**: Updated `firebase.json` to target `alive-ng-legal` site
2. **GitHub Actions**: Created `.github/workflows/firebase-deploy.yml` for automated deployment
3. **Service Account**: You've added the Firebase service account key to GitHub secrets

### Next Steps:

#### Option 1: GitHub Actions Deployment (Recommended)
1. **Commit and push the workflow file**:
   ```bash
   git add .github/workflows/firebase-deploy.yml
   git add firebase.json
   git add DEPLOYMENT_INSTRUCTIONS.md
   git commit -m "Add GitHub Actions workflow for Firebase deployment"
   git push origin master
   ```

2. **Set up GitHub Secrets** (if not already done):
   - Go to your GitHub repository settings
   - Navigate to "Secrets and variables" → "Actions"
   - Add these secrets:
     - `FIREBASE_SERVICE_ACCOUNT_ALIVE_NG_LEGAL`: Your service account JSON content
     - `FIREBASE_TOKEN`: Generate with `firebase login:ci` (if you have Firebase CLI)

3. **Trigger Deployment**:
   - Push any commit to master branch, or
   - Go to Actions tab and manually trigger "Deploy to Firebase Hosting"

#### Option 2: Local Installation (If disk space becomes available)
1. **Install Flutter SDK**:
   ```powershell
   # Download and extract Flutter SDK to C:\flutter
   # Add C:\flutter\bin to PATH environment variable
   ```

2. **Install Node.js and Firebase CLI**:
   ```powershell
   # Download Node.js from nodejs.org
   npm install -g firebase-tools
   firebase login
   ```

3. **Build and Deploy**:
   ```bash
   flutter build web --release
   firebase deploy --only hosting:alive-ng-legal
   ```

## Firebase Hosting Configuration

Your `firebase.json` is configured to:
- Target the `alive-ng-legal` hosting site
- Serve files from the `web` directory (Flutter web build output)
- Route all requests to `index.html` for SPA behavior

## Troubleshooting

### If GitHub Actions fails:
1. Check that the service account key is correctly added to secrets
2. Verify the Firebase project ID matches `alive-ng-legal`
3. Ensure the hosting site exists in Firebase Console

### If local deployment fails:
1. Free up disk space for Flutter SDK installation
2. Install Node.js from official website
3. Use `firebase login` to authenticate

## Expected Result
Once deployed, your app will be available at:
`https://alive-ng-legal.web.app` or `https://alive-ng-legal.firebaseapp.com`

## Google Play Store Preparation
For Play Store deployment, you'll need:
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

This requires local Flutter SDK installation or can be added to GitHub Actions workflow.