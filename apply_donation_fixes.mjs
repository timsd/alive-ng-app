const fs = require('fs');
const path = require('path');
const root = 'C:/Users/Timothy Olodude/Documents/ZavTech Projects/alive-ng-app';

const paymentsPath = path.join(root, 'appwrite_functions/paystackPayments/src/main.js');
const donationHtmlPath = path.join(root, 'web/donation.html');
const paymentSvcPath = path.join(root, 'lib/services/payment_service.dart');
const donateScreenPath = path.join(root, 'lib/screens/donation/donation_screen.dart');

let changes = [];

// === 1. paystackPayments: currency validation + per-currency minimums ===
try {
  let payments = fs.readFileSync(paymentsPath, 'utf8');
  if (!payments.includes('ALLOWED_CURRENCIES')) {
    payments = payments.replace(
      /const Paystack = require\(['"]paystack-sdk['"]\);/,
      "const Paystack = require('paystack-sdk');\nconst ALLOWED_CURRENCIES = ['NGN', 'USD'];\nconst CURRENCY_MINIMUMS = { NGN: 20000, USD: 5 };"
    );
    changes.push('payments: added ALLOWED_CURRENCIES + CURRENCY_MINIMUMS');
  }
  if (!payments.includes('ALLOWED_CURRENCIES.includes')) {
    payments = payments.replace(
      /if \(amount <= 0\)\s*\{[^}]*\}/,
      (match) => {
        return "if (!currency || !ALLOWED_CURRENCIES.includes(currency)) {\n    return res.json({ error: 'Invalid currency. Allowed: NGN, USD' }, 400);\n  }\n  const minAmount = CURRENCY_MINIMUMS[currency] || 5;\n  if (amount < minAmount) {\n    return res.json({ error: 'Minimum donation is ' + minAmount + ' ' + currency }, 400);\n  }\n  " + match;
      }
    );
    changes.push('payments: added currency + minimum validation');
  }
  fs.writeFileSync(paymentsPath, payments);
  console.log('1. paystackPayments updated');
} catch (e) {
  console.error('payments error:', e.message);
}

// === 2. web/donation.html: NGN/USD toggle ===
try {
  let html = fs.readFileSync(donationHtmlPath, 'utf8');
  if (!html.includes('currency-selector') && !html.includes('data-currency')) {
    // Add currency selector before amount selector
    const currencyToggle = `
    <!-- Currency Selector -->
    <div class="form-group">
      <label>Currency</label>
      <div class="currency-toggle" id="currencySelector">
        <button type="button" class="currency-btn active" data-currency="USD">USD ($)</button>
        <button type="button" class="currency-btn" data-currency="NGN">NGN (₦)</button>
      </div>
    </div>
`;
    html = html.replace(
      /(<div class="form-group">\s*<label>Amount)/i,
      currencyToggle + '    $1'
    );
    changes.push('donation.html: added currency toggle HTML');
  }
  // Add per-currency minimums in JS
  if (!html.includes('CURRENCY_MINIMUMS')) {
    html = html.replace(
      /(<script>)/,
      "$1\nconst CURRENCY_MINIMUMS = { USD: 5, NGN: 20000 };\nconst DONATION_AMOUNTS = {\n  USD: [25, 50, 100],\n  NGN: [20000, 50000, 100000]\n};\nlet selectedCurrency = 'USD';"
    );
    changes.push('donation.html: added currency config JS');
  }
  fs.writeFileSync(donationHtmlPath, html);
  console.log('2. donation.html updated');
} catch (e) {
  console.error('donation.html error:', e.message);
}

// === 3. payment_service.dart: ensure currency flows through ===
try {
  let svc = fs.readFileSync(paymentSvcPath, 'utf8');
  if (!svc.includes('currency') || !svc.toLowerCase().includes('currency')) {
    // Add currency parameter to initializePaystackPayment
    svc = svc.replace(
      /Future<Map<String, dynamic>>\s+initializePaystackPayment\s*\(\s*\{([^}]*)\}/,
      (match, params) => {
        if (!params.includes('currency')) {
          return match.replace(params, params + "\n    required String currency,");
        }
        return match;
      }
    );
    changes.push('payment_service.dart: added currency parameter');
  }
  fs.writeFileSync(paymentSvcPath, svc);
  console.log('3. payment_service.dart updated');
} catch (e) {
  console.error('payment_service.dart error:', e.message);
}

// === 4. donation_screen.dart: ensure currency passed to payment ===
try {
  let screen = fs.readFileSync(donateScreenPath, 'utf8');
  if (!screen.includes('currency: _selectedCurrency') && !screen.includes("currency: _selectedCurrency")) {
    // Find the payment initialization call and add currency
    screen = screen.replace(
      /(initializePaystackPayment\s*\(\s*[^)]*amount\s*:\s*)_selectedAmount/,
      "$1_selectedAmount,\n          currency: _selectedCurrency"
    );
    changes.push('donation_screen.dart: added currency to payment call');
  }
  fs.writeFileSync(donateScreenPath, screen);
  console.log('4. donation_screen.dart updated');
} catch (e) {
  console.error('donation_screen.dart error:', e.message);
}

console.log('\n=== Changes applied ===');
changes.forEach(c => console.log('- ' + c));
if (changes.length === 0) console.log('No changes needed (already applied)');
