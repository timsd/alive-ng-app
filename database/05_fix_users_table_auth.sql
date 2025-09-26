-- ALIVE NG App - Fix Users Table Auth Integration
-- This file handles the proper integration with Supabase auth.users
-- Run this AFTER the main schema deployment if you encounter auth integration issues

-- ============================================================================
-- OPTION 1: CREATE USERS TABLE WITH DIRECT AUTH REFERENCE (RECOMMENDED)
-- ============================================================================

-- Drop the existing users table and recreate with proper auth reference
-- WARNING: This will delete all existing user data in public.users
-- Only run this if you're starting fresh or can afford to lose user data

/*
-- Uncomment this section if you want to start fresh with proper auth integration

-- Drop dependent views first
DROP VIEW IF EXISTS public.user_activity_summary CASCADE;
DROP VIEW IF EXISTS public.chapter_summary CASCADE;

-- Drop the existing users table (this will cascade to all dependent tables)
DROP TABLE IF EXISTS public.users CASCADE;

-- Recreate users table with proper auth reference
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username VARCHAR(50) UNIQUE,
  full_name VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(20),
  avatar_url TEXT,
  bio TEXT,
  date_of_birth DATE,
  gender VARCHAR(10),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100) DEFAULT 'Nigeria',
  is_active BOOLEAN DEFAULT true,
  last_seen TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Recreate all dependent tables (you'll need to run the main schema again)
-- This is why Option 2 below is recommended for existing deployments
*/

-- ============================================================================
-- OPTION 2: ADD AUTH CONSTRAINT TO EXISTING USERS TABLE (SAFER)
-- ============================================================================

-- This approach keeps your existing data and just adds the auth constraint
-- Run this if you already have data and want to preserve it

DO $$ 
BEGIN
    -- Check if auth schema and users table exist
    IF EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = 'auth'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'auth' 
        AND table_name = 'users'
    ) THEN
        
        -- Only add the foreign key constraint if it doesn't already exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_users_auth'
            AND table_name = 'users'
            AND table_schema = 'public'
        ) THEN
            
            -- First, ensure all user IDs in public.users exist in auth.users
            -- Delete any orphaned records (optional - comment out if you want to keep them)
            /*
            DELETE FROM public.users 
            WHERE id NOT IN (SELECT id FROM auth.users);
            */
            
            -- Add the foreign key constraint
            ALTER TABLE public.users 
            ADD CONSTRAINT fk_users_auth 
            FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
            
            RAISE NOTICE 'Successfully added auth.users foreign key constraint to public.users';
            
        ELSE
            RAISE NOTICE 'Foreign key constraint fk_users_auth already exists';
        END IF;
        
    ELSE
        RAISE NOTICE 'Auth schema or auth.users table not found - skipping auth integration';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error adding auth constraint: %', SQLERRM;
END $$;

-- ============================================================================
-- OPTION 3: MANUAL USER SYNC FUNCTION (ALTERNATIVE)
-- ============================================================================

-- If you can't add the foreign key constraint, you can use this function
-- to manually sync users between auth.users and public.users

CREATE OR REPLACE FUNCTION public.sync_auth_users()
RETURNS TRIGGER AS $$
BEGIN
    -- When a new user is created in auth.users, create corresponding record in public.users
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.users (id, email, full_name, created_at)
        VALUES (
            NEW.id, 
            NEW.email, 
            COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
            NEW.created_at
        )
        ON CONFLICT (id) DO NOTHING;
        RETURN NEW;
    END IF;
    
    -- When a user is deleted from auth.users, delete from public.users
    IF TG_OP = 'DELETE' THEN
        DELETE FROM public.users WHERE id = OLD.id;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for automatic sync (only if you can't use foreign keys)
-- Uncomment these if you're using Option 3

/*
DROP TRIGGER IF EXISTS sync_auth_users_insert ON auth.users;
CREATE TRIGGER sync_auth_users_insert
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.sync_auth_users();

DROP TRIGGER IF EXISTS sync_auth_users_delete ON auth.users;
CREATE TRIGGER sync_auth_users_delete
    AFTER DELETE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.sync_auth_users();
*/

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check if the foreign key constraint exists
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'users'
    AND tc.table_schema = 'public'
    AND ccu.table_name = 'users'
    AND ccu.table_schema = 'auth';

-- Check for orphaned users (users in public.users but not in auth.users)
SELECT 
    COUNT(*) as orphaned_users_count,
    'Users in public.users but not in auth.users' as description
FROM public.users u
WHERE NOT EXISTS (
    SELECT 1 FROM auth.users au WHERE au.id = u.id
);

SELECT 'Auth integration check completed!' as status;