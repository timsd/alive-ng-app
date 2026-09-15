# Paystack Webhook Function (ALIVE NG)

Updates the `donation_records` collection when Paystack confirms a payment.
The Flutter app deliberately does **not** trust client-side payment results —
only this webhook flips a donation to `completed`.

## Events handled
| Event | Action |
|---|---|
| `charge.success` | `donation_records[reference].status = completed` + `transaction_id`, `paid_at`, `amount_kobo`, `channel` |
| `charge.failed` | `donation_records[reference].status = failed` + `failure_reason` |

The donation row is created **by the app** at checkout time with
`rowId = reference`, so the webhook updates by document ID = Paystack reference.

## Deploy (Appwrite CLI)
```bash
cd functions/paystack_webhook
appwrite push function
# then in the Appwrite Console → Functions → paystack_webhook → Settings:
#   Runtime: Node 18+
#   Variables:
#     PAYSTACK_SECRET_KEY = sk_live_...            (same key as in .env)
#     APPWRITE_DATABASE_ID = 6a089307002e54291a32
#     DONATION_COLLECTION_ID = donation_records
```
`APPWRITE_FUNCTION_API_ENDPOINT`, `APPWRITE_FUNCTION_PROJECT_ID` and
`APPWRITE_FUNCTION_API_KEY` are injected automatically by Appwrite.

## Exposing a PUBLIC HTTPS URL for Paystack

Appwrite functions are not directly reachable without an API key, so put a
tiny proxy in front. On the Coolify/nginx box that serves
`api.alivenigeria.org`, add:

```nginx
location = /webhooks/paystack {
    proxy_pass https://appwrite.internal/v1/functions/paystack_webhook/executions;
    proxy_set_header Content-Type application/json;
    # Server-side API key — Paystack only sends POST, signature already verified
    # inside the function, so the key never reaches the client.
    proxy_set_header X-Appwrite-Project <PROJECT_ID>;
    proxy_set_header X-Appwrite-Key <SERVER_API_KEY>;
    proxy_set_header X-Appwrite-Response-Format 1.7.0;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_ssl_server_name on;
}
```

Your **webhook URL** is then:

```
https://api.alivenigeria.org/webhooks/paystack
```

## Register the webhook
1. **Paystack Dashboard** → Settings → API Keys & Webhooks → Webhook URL:
   `https://api.alivenigeria.org/webhooks/paystack` (live mode).
2. Test with Paystack's "Test your webhook" button — expect a 200 and the
   donation row flipping to `completed`.
