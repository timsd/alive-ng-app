# ALIVE NG App - Complete Database Deployment Guide

## Overview
This guide provides step-by-step instructions to deploy the complete database schema to your Supabase project. The files have been cleaned and arranged in the correct execution order to prevent syntax errors and dependency issues.

## Files Created
1. `01_drop_existing_tables.sql` - Drops existing tables in correct order
2. `02_database_schema_clean.sql` - Main database schema (cleaned)
3. `03_content_management_clean.sql` - Content management tables (cleaned)
4. `04_rls_policies_clean.sql` - Row Level Security policies (cleaned)

## Execution Order

### Step 1: Drop Existing Tables (Optional but Recommended)
**File:** `01_drop_existing_tables.sql`

This step is **HIGHLY RECOMMENDED** to avoid conflicts with existing tables. It will:
- Drop all existing tables in reverse dependency order
- Remove functions and triggers
- Clean the database for fresh deployment

**Execute this in Supabase SQL Editor:**
```sql
-- Copy and paste the entire content of 01_drop_existing_tables.sql
```

### Step 2: Create Main Database Schema
**File:** `02_database_schema_clean.sql`

This creates the core database structure including:
- User management tables
- Chapter and organization tables
- Communication (channels, messages)
- Prayer and spiritual features
- Study materials and progress tracking
- Notifications and sessions
- Reports and analytics

**Execute this in Supabase SQL Editor:**
```sql
-- Copy and paste the entire content of 02_database_schema_clean.sql
```

**Expected Results:**
- 19+ tables created
- Functions and triggers installed
- Sample data inserted
- Views created

### Step 3: Add Content Management System
**File:** `03_content_management_clean.sql`

This adds advanced content management features:
- Dynamic content pages
- App settings management
- Featured content and announcements
- Content categorization and tagging
- User interaction tracking
- Content analytics

**Execute this in Supabase SQL Editor:**
```sql
-- Copy and paste the entire content of 03_content_management_clean.sql
```

**Expected Results:**
- 10+ additional tables created
- Content management triggers installed
- Sample content data inserted

### Step 4: Apply Row Level Security Policies
**File:** `04_rls_policies_clean.sql`

This secures your database with comprehensive RLS policies:
- Enables RLS on all tables
- Creates helper functions for role checking
- Implements granular access control
- Protects user data and privacy

**Execute this in Supabase SQL Editor:**
```sql
-- Copy and paste the entire content of 04_rls_policies_clean.sql
```

**Expected Results:**
- RLS enabled on all tables
- Security policies created
- Helper functions installed

## Key Improvements Made

### 1. Syntax Error Fixes
- **Removed all inline comments** that were causing `ERROR: 42601: syntax error at or near "CREATE"`
- **Cleaned up CREATE TABLE statements** to use proper PostgreSQL syntax
- **Standardized formatting** for consistency

### 2. Dependency Management
- **Proper execution order** to avoid foreign key constraint errors
- **Optional table dropping** to ensure clean deployment
- **Dependency-aware table creation** sequence

### 3. Enhanced Security
- **Comprehensive RLS policies** for all tables
- **Role-based access control** with helper functions
- **Privacy protection** for sensitive data

## Verification Steps

After executing all files, verify the deployment:

### 1. Check Table Creation
```sql
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

**Expected:** 30+ tables should be listed

### 2. Check RLS Status
```sql
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = true;
```

**Expected:** All tables should have `rowsecurity = true`

### 3. Check Functions
```sql
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public';
```

**Expected:** Multiple functions including `is_admin`, `is_chapter_coordinator`, etc.

### 4. Test Sample Data
```sql
SELECT COUNT(*) as user_count FROM public.users;
SELECT COUNT(*) as chapter_count FROM public.chapters;
SELECT COUNT(*) as content_count FROM public.content_pages;
```

**Expected:** Sample data should be present in various tables

## Troubleshooting

### Common Issues and Solutions

1. **Foreign Key Constraint Errors**
   - **Solution:** Execute `01_drop_existing_tables.sql` first
   - **Reason:** Existing tables may have conflicting constraints

2. **Permission Errors**
   - **Solution:** Ensure you're using the service role key in Supabase
   - **Reason:** Some operations require elevated permissions

3. **Duplicate Object Errors**
   - **Solution:** Use `DROP TABLE IF EXISTS` or run the drop script first
   - **Reason:** Tables already exist from previous attempts

4. **RLS Policy Conflicts**
   - **Solution:** Drop existing policies before creating new ones
   - **Reason:** Policy names must be unique per table

### If You Encounter Errors

1. **Stop execution** at the first error
2. **Note the error message** and line number
3. **Check the troubleshooting section** above
4. **Consider running the drop script** to start fresh
5. **Execute files one by one** instead of all at once

## Database Schema Summary

After successful deployment, your database will include:

### Core Features
- **User Management:** Registration, profiles, roles, authentication
- **Chapter System:** Organizations, memberships, activities
- **Communication:** Channels, messaging, notifications
- **Prayer System:** Requests, prayers, spiritual tracking
- **Study Materials:** Guides, questions, progress tracking

### Advanced Features
- **Content Management:** Dynamic pages, settings, announcements
- **Analytics:** User interactions, content performance
- **Security:** Comprehensive RLS policies, role-based access
- **Scalability:** Optimized indexes, efficient queries

### Total Tables: 30+
### Total Functions: 10+
### Total Policies: 50+

## Next Steps

After successful deployment:

1. **Update your application** to use the new schema
2. **Test authentication** and user registration
3. **Verify RLS policies** are working correctly
4. **Import existing data** if migrating from another system
5. **Configure your frontend** to match the new database structure

## Support

If you encounter issues during deployment:
1. Check the Supabase logs for detailed error messages
2. Verify your service role key has the necessary permissions
3. Ensure you're executing the files in the correct order
4. Consider reaching out for additional assistance

---

**Important:** Always backup your existing data before running these scripts, especially the drop table script.