// reCAPTCHA Backend Verification for ALIVE NG
// This file provides server-side verification for reCAPTCHA tokens

const RECAPTCHA_SECRET_KEY = '6LcKstkrAAAAAOUUAP3MQhXKuzKa2yhpku4Q69KG';
const RECAPTCHA_VERIFY_URL = 'https://www.google.com/recaptcha/api/siteverify';

/**
 * Verify reCAPTCHA token with Google's servers
 * @param {string} token - The reCAPTCHA token from the client
 * @param {string} remoteip - The user's IP address (optional)
 * @returns {Promise<Object>} Verification result
 */
async function verifyRecaptchaToken(token, remoteip = null) {
    try {
        const params = new URLSearchParams({
            secret: RECAPTCHA_SECRET_KEY,
            response: token
        });
        
        if (remoteip) {
            params.append('remoteip', remoteip);
        }

        const response = await fetch(RECAPTCHA_VERIFY_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: params
        });

        const result = await response.json();
        
        return {
            success: result.success,
            score: result.score || 0,
            action: result.action,
            challenge_ts: result.challenge_ts,
            hostname: result.hostname,
            error_codes: result['error-codes'] || []
        };
    } catch (error) {
        console.error('reCAPTCHA verification error:', error);
        return {
            success: false,
            error: error.message,
            score: 0
        };
    }
}

/**
 * Express.js middleware for reCAPTCHA verification
 * @param {number} minScore - Minimum score threshold (0.0 to 1.0)
 * @param {string} expectedAction - Expected action name
 */
function recaptchaMiddleware(minScore = 0.5, expectedAction = null) {
    return async (req, res, next) => {
        const token = req.body['g-recaptcha-response'] || req.body.recaptchaToken;
        
        if (!token) {
            return res.status(400).json({
                success: false,
                error: 'reCAPTCHA token is required'
            });
        }

        const clientIP = req.ip || req.connection.remoteAddress;
        const verification = await verifyRecaptchaToken(token, clientIP);

        if (!verification.success) {
            return res.status(400).json({
                success: false,
                error: 'reCAPTCHA verification failed',
                details: verification.error_codes
            });
        }

        // Check score threshold
        if (verification.score < minScore) {
            return res.status(400).json({
                success: false,
                error: 'reCAPTCHA score too low',
                score: verification.score,
                threshold: minScore
            });
        }

        // Check expected action
        if (expectedAction && verification.action !== expectedAction) {
            return res.status(400).json({
                success: false,
                error: 'reCAPTCHA action mismatch',
                expected: expectedAction,
                received: verification.action
            });
        }

        // Add verification result to request object
        req.recaptcha = verification;
        next();
    };
}

/**
 * Example Express.js route handlers
 */

// Contact form submission with reCAPTCHA
async function handleContactForm(req, res) {
    try {
        const { name, email, message } = req.body;
        
        // Validate required fields
        if (!name || !email || !message) {
            return res.status(400).json({
                success: false,
                error: 'All fields are required'
            });
        }

        // Process the contact form (save to database, send email, etc.)
        console.log('Contact form submission:', {
            name,
            email,
            message,
            recaptchaScore: req.recaptcha.score,
            timestamp: new Date().toISOString()
        });

        res.json({
            success: true,
            message: 'Contact form submitted successfully',
            recaptchaScore: req.recaptcha.score
        });
    } catch (error) {
        console.error('Contact form error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
}

// User registration with reCAPTCHA
async function handleUserRegistration(req, res) {
    try {
        const { username, email, password } = req.body;
        
        // Validate required fields
        if (!username || !email || !password) {
            return res.status(400).json({
                success: false,
                error: 'All fields are required'
            });
        }

        // Process user registration
        console.log('User registration:', {
            username,
            email,
            recaptchaScore: req.recaptcha.score,
            timestamp: new Date().toISOString()
        });

        res.json({
            success: true,
            message: 'User registered successfully',
            recaptchaScore: req.recaptcha.score
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
}

// Export functions for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        verifyRecaptchaToken,
        recaptchaMiddleware,
        handleContactForm,
        handleUserRegistration
    };
}

// Example Express.js server setup
/*
const express = require('express');
const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Contact form route with reCAPTCHA verification
app.post('/submit-contact', 
    recaptchaMiddleware(0.5, 'submit'), 
    handleContactForm
);

// User registration route with reCAPTCHA verification
app.post('/api/register', 
    recaptchaMiddleware(0.7, 'register'), 
    handleUserRegistration
);

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
*/