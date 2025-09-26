# Firebase Hosting Deployment Guide

This guide explains how to deploy your ALIVE NG legal pages to Firebase Hosting using GitHub Actions.

## 🚀 Quick Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project" or use existing project
3. Project name: `alive-ng-legal` (or your preferred name)
4. Enable Google Analytics (optional)

### 2. Enable Firebase Hosting
1. In Firebase Console, go to "Hosting" in the left sidebar
2. Click "Get started"
3. Follow the setup instructions

### 3. Set up GitHub Repository
1. Push your code to GitHub repository
2. Make sure the repository contains:
   - `web/` folder with HTML files
   - `firebase.json` configuration
   - `.firebaserc` project configuration
   - `.github/workflows/` deployment workflows

### 4. Configure GitHub Actions
1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add the following secret:
   - `FIREBASE_SERVICE_ACCOUNT_ALIVE_NG_LEGAL`: Firebase service account key

#### Getting Firebase Service Account Key:
1. Go to Firebase Console → Project Settings
2. Click "Service accounts" tab
3. Click "Generate new private key"
4. Download the JSON file
5. Copy the entire JSON content and paste it as the GitHub secret value

### 5. Deploy
Once configured, deployments happen automatically:
- **Production**: Push to `main` or `master` branch
- **Preview**: Create a pull request

## 📁 File Structure

```
alive-ng-app/
├── web/
│   ├── index.html              # Flutter web app
│   ├── legal.html              # Legal documents index
│   ├── privacy-policy.html     # Privacy policy page
│   └── terms-conditions.html   # Terms & conditions page
├── firebase.json               # Firebase configuration
├── .firebaserc                 # Firebase project config
└── .github/workflows/
    ├── firebase-hosting-merge.yml        # Production deployment
    └── firebase-hosting-pull-request.yml # Preview deployment
```

## 🌐 URLs After Deployment

Once deployed, your legal pages will be available at:
- **Privacy Policy**: `https://alive-ng-legal.web.app/privacy-policy.html`
- **Terms & Conditions**: `https://alive-ng-legal.web.app/terms-conditions.html`
- **Legal Index**: `https://alive-ng-legal.web.app/legal.html`

## 🔧 Manual Deployment (Alternative)

If you prefer manual deployment:

1. Install Node.js and Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Deploy:
   ```bash
   firebase deploy --only hosting
   ```

## 📱 App Integration

The ALIVE NG app has been updated to use the Firebase Hosting URLs:
- Privacy Policy screen now shares: `https://alive-ng-legal.web.app/privacy-policy.html`
- Terms & Conditions screen now shares: `https://alive-ng-legal.web.app/terms-conditions.html`

## 🛠️ Customization

### Updating Legal Pages
1. Edit HTML files in the `web/` folder
2. Commit and push changes to GitHub
3. GitHub Actions will automatically deploy updates

### Styling
The HTML pages use inline CSS for simplicity. You can:
- Modify styles directly in the HTML files
- Add external CSS files in the `web/` folder
- Update the responsive design as needed

## 🔒 Security Features

- **HTTPS**: Automatic SSL certificates
- **CDN**: Global content delivery network
- **DDoS Protection**: Built-in protection
- **Custom Domain**: Can be configured in Firebase Console

## 📊 Analytics

Firebase Hosting provides:
- Traffic analytics
- Performance monitoring
- Error tracking
- Usage statistics

Access these in the Firebase Console under Hosting section.

## 🆘 Troubleshooting

### Common Issues:
1. **Build fails**: Check GitHub Actions logs
2. **Wrong URLs**: Verify project ID in `.firebaserc`
3. **Permission errors**: Check service account permissions
4. **404 errors**: Ensure files exist in `web/` folder

### Support:
- Firebase Documentation: https://firebase.google.com/docs/hosting
- GitHub Actions Documentation: https://docs.github.com/en/actions
- Contact: alivenigeria2011@gmail.com

---

**Note**: Replace `alive-ng-legal` with your actual Firebase project ID throughout this guide if different.