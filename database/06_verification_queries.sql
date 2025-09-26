-- ============================================
-- DATABASE DEPLOYMENT VERIFICATION QUERIES
-- ============================================
-- Run these queries in Supabase SQL Editor to verify successful deployment

-- 1. CHECK ALL TABLES CREATED
-- Expected: Should show 50+ tables
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- 2. COUNT TABLES BY CATEGORY
SELECT 
    CASE 
        WHEN tablename LIKE '%user%' THEN 'User Management'
        WHEN tablename LIKE '%chat%' OR tablename LIKE '%channel%' OR tablename LIKE '%message%' THEN 'Communication'
        WHEN tablename LIKE '%prayer%' THEN 'Prayer System'
        WHEN tablename LIKE '%study%' THEN 'Study System'
        WHEN tablename LIKE '%chapter%' THEN 'Chapter Management'
        WHEN tablename LIKE '%content%' OR tablename LIKE '%page%' OR tablename LIKE '%announcement%' THEN 'Content Management'
        WHEN tablename LIKE '%notification%' THEN 'Notifications'
        ELSE 'Other'
    END as category,
    COUNT(*) as table_count
FROM pg_tables 
WHERE schemaname = 'public'
GROUP BY category
ORDER BY table_count DESC;

-- 3. CHECK FOREIGN KEY CONSTRAINTS
-- Expected: Should show multiple FK relationships
SELECT 
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- 4. CHECK RLS POLICIES
-- Expected: Should show policies for all main tables
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 5. CHECK FUNCTIONS CREATED
-- Expected: Should show helper functions like is_admin, is_chapter_coordinator, etc.
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name NOT LIKE 'pg_%'
ORDER BY routine_name;

-- 6. CHECK TRIGGERS
-- Expected: Should show triggers for updated_at timestamps
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 7. CHECK INDEXES
-- Expected: Should show indexes for performance optimization
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND indexname NOT LIKE '%_pkey'
ORDER BY tablename, indexname;

-- 8. CHECK RLS STATUS
-- Expected: All main tables should have RLS enabled (true)
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
    AND rowsecurity = true
ORDER BY tablename;

-- 9. SAMPLE DATA CHECK
-- Check if sample data was inserted
SELECT 'users' as table_name, COUNT(*) as record_count FROM public.users
UNION ALL
SELECT 'chapters', COUNT(*) FROM public.chapters
UNION ALL
SELECT 'user_roles', COUNT(*) FROM public.user_roles
UNION ALL
SELECT 'content_pages', COUNT(*) FROM public.content_pages
UNION ALL
SELECT 'app_settings', COUNT(*) FROM public.app_settings
ORDER BY table_name;

-- 10. AUTH INTEGRATION CHECK
-- Verify auth.users integration
SELECT 
    au.id as auth_id,
    au.email,
    pu.id as public_user_id,
    pu.username,
    pu.created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
LIMIT 5;

-- ============================================
-- EXPECTED RESULTS SUMMARY:
-- ============================================
-- Query 1: Should show 50+ tables including users, chapters, chat_messages, etc.
-- Query 2: Should show categories like User Management (5-8 tables), Communication (3-5 tables), etc.
-- Query 3: Should show FK relationships between tables
-- Query 4: Should show RLS policies for each table (read, write, update policies)
-- Query 5: Should show functions like is_admin, is_chapter_coordinator, etc.
-- Query 6: Should show updated_at triggers on most tables
-- Query 7: Should show performance indexes
-- Query 8: Should show all main tables with RLS enabled
-- Query 9: Should show sample data counts
-- Query 10: Should show auth.users integration (may be empty if no users created yet)