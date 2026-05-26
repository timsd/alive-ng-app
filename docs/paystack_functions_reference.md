# Paystack Appwrite Functions Reference

Paystack is now handled server-side through Appwrite Functions, not Firebase
Cloud Functions. The app and any project server must never read, log, store, or
proxy a raw card number, CVV/CVC, or card expiry. Card entry belongs inside
Paystack Checkout or Paystack-managed SDK surfaces only.

## Functions

- `paystack_payments`: initializes Paystack transactions for authenticated app
  users and returns the Paystack authorization URL/access code/reference.
- `paystack_webhook`: receives Paystack server-to-server events, verifies the
  `x-paystack-signature` HMAC-SHA512 signature with `PAYSTACK_SECRET_KEY`, and
  updates Appwrite donation records/payment logs.

## Required Variables

Configure these in the Appwrite function environment, not in Flutter:

- `PAYSTACK_SECRET_KEY`
- `APPWRITE_ENDPOINT` or `APPWRITE_FUNCTION_API_ENDPOINT`
- `APPWRITE_PROJECT_ID` or `APPWRITE_FUNCTION_PROJECT_ID`
- `APPWRITE_API_KEY` or `APPWRITE_FUNCTION_API_KEY`
- `APPWRITE_DATABASE_ID`

Flutter should receive only public build values such as `PAYSTACK_PUBLIC_KEY`
through `--dart-define` / Coolify `FLUTTER_BUILD_ARGS`.

## Webhook Setup

In the Paystack dashboard, set the webhook URL to the deployed Appwrite
function domain for `paystack_webhook`. Use the generated public function
domain/URL that accepts Paystack's normal HTTPS POST request. Do not use an SDK
execution endpoint that requires Appwrite project headers unless that route has
been explicitly configured to accept Paystack.

## Status Mapping

- `charge.success` -> `completed`
- `charge.failed` / `charge.abandoned` -> `failed`
- initialization / checkout opened -> `processing`

## Verification

Before production:

1. Confirm the function rejects requests without a valid Paystack signature.
2. Confirm successful Paystack test payments update `donation_records`.
3. Confirm failed/abandoned events do not unlock paid downloads.
4. Confirm Appwrite payment logs do not contain raw card data.
