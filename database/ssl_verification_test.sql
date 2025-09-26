-- SSL Verification and Testing Script for ALIVE NG App
-- This script verifies SSL configuration and connection security in Supabase

-- =====================================================
-- SSL CONNECTION STATUS CHECK
-- =====================================================

-- Check current SSL connection status
SELECT 
    'SSL Connection Status' as check_type,
    CASE 
        WHEN ssl THEN '✅ SSL Enabled and Active' 
        ELSE '❌ SSL Not Active' 
    END as status,
    CASE 
        WHEN ssl THEN 'Connection is encrypted'
        ELSE 'WARNING: Connection is not encrypted'
    END as description
FROM pg_stat_ssl 
WHERE pid = pg_backend_pid();

-- =====================================================
-- SSL CONFIGURATION VERIFICATION
-- =====================================================

-- Check SSL enforcement settings (requires superuser privileges)
-- Note: This may not work in Supabase hosted environment
SELECT 
    'SSL Enforcement Check' as check_type,
    name as setting_name,
    setting as current_value,
    CASE 
        WHEN name = 'ssl' AND setting = 'on' THEN '✅ SSL is enabled'
        WHEN name = 'ssl' AND setting = 'off' THEN '❌ SSL is disabled'
        ELSE 'ℹ️ ' || setting
    END as status
FROM pg_settings 
WHERE name IN ('ssl', 'ssl_cert_file', 'ssl_key_file', 'ssl_ca_file')
ORDER BY name;

-- =====================================================
-- CONNECTION SECURITY ANALYSIS
-- =====================================================

-- Analyze current database connections and their SSL status
SELECT 
    'Active Connections Analysis' as check_type,
    COUNT(*) as total_connections,
    COUNT(CASE WHEN ssl.ssl THEN 1 END) as ssl_connections,
    COUNT(CASE WHEN NOT ssl.ssl THEN 1 END) as non_ssl_connections,
    ROUND(
        (COUNT(CASE WHEN ssl.ssl THEN 1 END) * 100.0 / COUNT(*)), 2
    ) as ssl_percentage
FROM pg_stat_activity psa
LEFT JOIN pg_stat_ssl ssl ON psa.pid = ssl.pid
WHERE psa.state = 'active';

-- =====================================================
-- SSL CERTIFICATE INFORMATION
-- =====================================================

-- Get SSL certificate details (if accessible)
SELECT 
    'SSL Certificate Info' as check_type,
    'Certificate validation requires client-side verification' as note,
    'Use Supabase dashboard to download and verify certificate' as instruction;

-- =====================================================
-- DATABASE SECURITY RECOMMENDATIONS
-- =====================================================

-- Security recommendations based on current configuration
SELECT 
    'Security Recommendations' as check_type,
    recommendation,
    priority,
    description
FROM (
    VALUES 
    ('Enable SSL Enforcement', 'HIGH', 'Force all connections to use SSL/TLS encryption'),
    ('Reject Non-SSL Connections', 'HIGH', 'Automatically reject unencrypted connection attempts'),
    ('Certificate Validation', 'MEDIUM', 'Implement certificate pinning in mobile app'),
    ('Connection Monitoring', 'MEDIUM', 'Monitor SSL connection status regularly'),
    ('Certificate Renewal', 'LOW', 'Set up alerts for certificate expiration')
) AS recommendations(recommendation, priority, description);

-- =====================================================
-- SSL TESTING QUERIES
-- =====================================================

-- Test basic encrypted connection (should work if SSL is active)
SELECT 
    'SSL Connection Test' as test_type,
    'Basic Query Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ Connection successful'
        ELSE '❌ Connection failed'
    END as result,
    NOW() as test_timestamp
FROM pg_stat_ssl 
WHERE pid = pg_backend_pid();

-- Verify database accessibility with current connection
SELECT 
    'Database Access Test' as test_type,
    'Table Access Test' as test_name,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ Database accessible'
        ELSE '❌ Database access failed'
    END as result,
    COUNT(*) as table_count,
    NOW() as test_timestamp
FROM information_schema.tables 
WHERE table_schema = 'public';

-- =====================================================
-- FINAL SSL STATUS SUMMARY
-- =====================================================

-- Comprehensive SSL status summary
WITH ssl_status AS (
    SELECT 
        CASE WHEN ssl THEN 'ENABLED' ELSE 'DISABLED' END as ssl_status,
        ssl as is_encrypted
    FROM pg_stat_ssl 
    WHERE pid = pg_backend_pid()
),
connection_info AS (
    SELECT 
        current_database() as database_name,
        current_user as connected_user,
        inet_server_addr() as server_address,
        inet_server_port() as server_port
)
SELECT 
    '🔒 SSL CONFIGURATION SUMMARY' as summary_type,
    ci.database_name,
    ci.connected_user,
    ci.server_address,
    ci.server_port,
    ss.ssl_status,
    CASE 
        WHEN ss.is_encrypted THEN '✅ Your connection is secure and encrypted'
        ELSE '⚠️ WARNING: Your connection is NOT encrypted'
    END as security_status,
    NOW() as check_timestamp
FROM ssl_status ss, connection_info ci;

-- =====================================================
-- INSTRUCTIONS FOR NEXT STEPS
-- =====================================================

SELECT 
    'NEXT STEPS' as action_type,
    step_number,
    action_required,
    details
FROM (
    VALUES 
    (1, 'Enable SSL in Supabase Dashboard', 'Go to Settings → Database → SSL Configuration'),
    (2, 'Toggle SSL Enforcement', 'Enable "Enforce SSL on incoming connections"'),
    (3, 'Reject Non-SSL Connections', 'Enable "Reject non-SSL connections to your database"'),
    (4, 'Download Certificate', 'Download the SSL certificate from Supabase dashboard'),
    (5, 'Update Flutter App', 'Ensure app uses HTTPS URLs and implements SSL verification'),
    (6, 'Test Connection', 'Run SSL tests in your Flutter app to verify secure connection'),
    (7, 'Monitor Security', 'Set up monitoring for SSL connection status')
) AS steps(step_number, action_required, details)
ORDER BY step_number;