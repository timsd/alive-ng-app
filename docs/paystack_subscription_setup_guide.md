# Paystack Multi-Account & Subscription Configuration Guide

## Overview
This guide provides the complete setup instructions for configuring Paystack recurring subscriptions, multi-business accounts, and automated donation tracking for **ALIVE Nigeria Ministries** across both Flutter and Web platforms.

---

## 1. Multiple Business Accounts Configuration

If you maintain separate Paystack business accounts (for example, one for ALIVE Nigeria operations and another for dedicated capital projects or medical missions):

### A. Environment Variable Setup
Each Paystack business account has its own API keys:
- **Secret Key**: `sk_live_...` (used by Appwrite server-side functions)
- **Public Key**: `pk_live_...` (used in Flutter/Web frontend checkouts)

In your Appwrite project functions and `.env`:
```env
# Primary Business Account (ALIVE Nigeria General & Missions)
PAYSTACK_SECRET_KEY=sk_live_xxxxxxxxx
PAYSTACK_PUBLIC_KEY=pk_live_xxxxxxxxx

# Optional: Dedicated Secondary Account Keys
PAYSTACK_PROJECTS_SECRET_KEY=sk_live_yyyyyyyyy
PAYSTACK_PROJECTS_PUBLIC_KEY=pk_live_yyyyyyyyy
```

> [!TIP]
> If you collect all funds into one Paystack account but want separate internal bookkeeping, you do **not** need separate Paystack accounts: the ALIVE-NG system automatically tags every transaction with the `project_id` and `fund_designation` metadata!

---

## 2. Subscription Plans for the 8 Mission Categories

To enable recurring monthly support under **"Your Gift Will:"**, create corresponding plans on your [Paystack Dashboard](https://dashboard.paystack.com/#/plans):

### Recommended Plan Setup:
| Category | Plan Name | Recommended Amounts | Interval | Paystack Plan Code Format |
|---|---|---|---|---|
| **Rural Missions** | ALIVE Rural Missions Support | ₦10,000 / ₦25,000 / ₦50,000 | Monthly | `PLN_rural_xxxx` |
| **Campus/City Missions** | ALIVE Campus & City Missions | ₦10,000 / ₦25,000 / ₦50,000 | Monthly | `PLN_campus_xxxx` |
| **Missionary Training 🎓** | Missionary & Groundbreakers Training | ₦20,000 / ₦50,000 / ₦100,000 | Monthly | `PLN_training_xxxx` |
| **Health Evangelism 🏥** | Health Evangelism & Medical Outreach | ₦15,000 / ₦30,000 / ₦75,000 | Monthly | `PLN_health_xxxx` |
| **Digital Ministry 📱** | Digital Ministry & Content Outreach | ₦5,000 / ₦15,000 / ₦30,000 | Monthly | `PLN_digital_xxxx` |
| **LTMs Stipends** | Long-Term Missionaries Monthly Upkeep | ₦25,000 / ₦50,000 / ₦100,000 | Monthly | `PLN_ltm_xxxx` |
| **STMs Stipends** | Short-Term Missionaries Monthly Upkeep | ₦15,000 / ₦30,000 / ₦60,000 | Monthly | `PLN_stm_xxxx` |
| **Volunteers** | Mission Field Volunteers Support | ₦10,000 / ₦20,000 / ₦40,000 | Monthly | `PLN_volunteers_xxxx` |
| **General Support** | ALIVE Nigeria General Mission Fund | Any Custom Amount | Monthly | `PLN_general_xxxx` |

### Steps to Create a Plan on Paystack:
1. Log in to [Paystack Dashboard](https://dashboard.paystack.com).
2. Navigate to **Recurring** &rarr; **Plans**.
3. Click **Create Plan**.
4. Enter the **Plan Name** (e.g., `ALIVE Rural Missions Monthly`).
5. Set the **Amount** in NGN (or USD).
6. Set **Interval** to `Monthly`.
7. Copy the generated **Plan Code** (e.g., `PLN_abc123xyz`).

---

## 3. Webhook Configuration for Automatic Tracking

Paystack automatically notifies your Appwrite backend whenever a donation or subscription charge occurs.

### A. Webhook URL
Configure this in your [Paystack Settings &rarr; Preferences &rarr; Webhooks](https://dashboard.paystack.com/#/settings/preferences):

```
https://api.alivenigeria.org/v1/functions/paystack_webhook/executions
```
*(Or your Coolify custom webhook domain route, if proxied).*

### B. Events to Enable on Paystack:
- `charge.success` &mdash; Fired on one-time donations and subscription renewals.
- `subscription.create` &mdash; Fired when a donor starts a recurring gift.
- `subscription.disable` &mdash; Fired if a donor cancels.
- `invoice.create` & `invoice.payment_failed` &mdash; Fired for subscription charge attempts.

### C. Secret Key Matching
Your Appwrite function verifies the HMAC signature using:
```
X-Paystack-Signature = HMAC_SHA512(raw_body, PAYSTACK_SECRET_KEY)
```
Ensure `PAYSTACK_SECRET_KEY` in your Appwrite function environment variables matches the secret key of the business account sending the webhook.

---

## 4. How Donations Are Automatically Tracked

When a donor submits a gift in either the Flutter app or Web app:

1. **Frontend Metadata**: The app sends:
   ```json
   {
     "project_id": "impact_hub_center",
     "project_title": "Impact Hub Center",
     "fund_designation": "Rural Missions",
     "donor_name": "John Doe",
     "recurring": true
   }
   ```
2. **Paystack Charge**: Paystack charges the card/bank account.
3. **Webhook Processing** (`appwrite_functions/paystackWebhook`):
   - Updates `donation_records` with status `completed` and transaction ID.
   - If `project_id` is present: Automatically increments `raised` and `amount_raised` in the `projects` table!
   - If `fund_designation` is present: Logs the designated mission fund for internal allocation without requiring project goal limits.
   - Dispatches an automated HTML tax-deductible receipt to the donor's email via Resend (`sendDonationReceipt`).
