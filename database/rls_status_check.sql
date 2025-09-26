-- RLS Status Check Query
-- Run this in Supabase SQL Editor to check RLS policies and identify issues

-- 1. Check RLS status for all tables
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN 'RLS Enabled' 
        ELSE 'RLS Disabled' 
    END as status
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- 2. Check all RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 3. Check for tables without RLS policies but with RLS enabled
SELECT 
    t.tablename,
    t.rowsecurity as rls_enabled,
    COUNT(p.policyname) as policy_count
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
GROUP BY t.tablename, t.rowsecurity
HAVING t.rowsecurity = true AND COUNT(p.policyname) = 0
ORDER BY t.tablename;

-- 4. Check for potential RLS issues
SELECT 
    'Missing RLS on table: ' || tablename as issue_type,
    tablename as table_name,
    'Table exists but RLS is disabled' as description
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = false
AND tablename NOT IN ('app_settings') -- Exclude tables that shouldn't have RLS

UNION ALL

SELECT 
    'RLS enabled but no policies: ' || tablename as issue_type,
    tablename as table_name,
    'RLS is enabled but no policies defined' as description
FROM pg_tables t
WHERE t.schemaname = 'public'
AND t.rowsecurity = true
AND NOT EXISTS (
    SELECT 1 FROM pg_policies p 
    WHERE p.tablename = t.tablename 
    AND p.schemaname = t.schemaname
)
ORDER BY issue_type, table_name;

-- 5. Check auth.users integration
SELECT 
    'auth.users' as table_name,
    COUNT(*) as user_count
FROM auth.users

UNION ALL

SELECT 
    'public.users' as table_name,
    COUNT(*) as user_count
FROM public.users;