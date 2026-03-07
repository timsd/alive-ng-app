-- Drop existing tables script
-- This will clean up the current database to avoid conflicts
-- Execute this FIRST before running the schema files

-- Drop tables in reverse dependency order to avoid foreign key constraint errors

-- Drop views first
DROP VIEW IF EXISTS public.chapter_summary CASCADE;
DROP VIEW IF EXISTS public.user_activity_summary CASCADE;

-- Drop tables with foreign key dependencies first
DROP TABLE IF EXISTS public.user_content_interactions CASCADE;
DROP TABLE IF EXISTS public.content_analytics CASCADE;
DROP TABLE IF EXISTS public.content_tag_relations CASCADE;
DROP TABLE IF EXISTS public.featured_content CASCADE;
DROP TABLE IF EXISTS public.announcements CASCADE;
DROP TABLE IF EXISTS public.content_pages CASCADE;
DROP TABLE IF EXISTS public.dynamic_content CASCADE;
DROP TABLE IF EXISTS public.app_settings CASCADE;
DROP TABLE IF EXISTS public.content_categories CASCADE;
DROP TABLE IF EXISTS public.content_tags CASCADE;
DROP TABLE IF EXISTS public.reports CASCADE;
DROP TABLE IF EXISTS public.notification_settings CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.user_sessions CASCADE;
DROP TABLE IF EXISTS public.user_study_progress CASCADE;
DROP TABLE IF EXISTS public.study_guide_questions CASCADE;
DROP TABLE IF EXISTS public.study_guides CASCADE;
DROP TABLE IF EXISTS public.study_materials CASCADE;
DROP TABLE IF EXISTS public.user_prayers CASCADE;
DROP TABLE IF EXISTS public.prayer_requests CASCADE;
DROP TABLE IF EXISTS public.chat_messages CASCADE;
DROP TABLE IF EXISTS public.channel_members CASCADE;
DROP TABLE IF EXISTS public.channels CASCADE;
DROP TABLE IF EXISTS public.chapter_activities CASCADE;
DROP TABLE IF EXISTS public.chapter_members CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.chapters CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop any remaining tables that might exist
DROP TABLE IF EXISTS public.push_tokens CASCADE;
DROP TABLE IF EXISTS public.mission_completions CASCADE;
DROP TABLE IF EXISTS public.study_progress CASCADE;
DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.archived_users CASCADE;
DROP TABLE IF EXISTS public.user_missions CASCADE;
DROP TABLE IF EXISTS public.missions CASCADE;
DROP TABLE IF EXISTS public.memory_verses CASCADE;
DROP TABLE IF EXISTS public.user_memory_verses CASCADE;
DROP TABLE IF EXISTS public.memory_verse_sessions CASCADE;
DROP TABLE IF EXISTS public.progress_milestones CASCADE;
DROP TABLE IF EXISTS public.discipleship_reports CASCADE;
DROP TABLE IF EXISTS public.study_questions CASCADE;
DROP TABLE IF EXISTS public.user_lesson_progress CASCADE;
DROP TABLE IF EXISTS public.notification_logs CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Drop extensions (optional - only if you want to completely clean up)
-- DROP EXTENSION IF EXISTS "uuid-ossp";

SELECT 'All existing tables have been dropped successfully!' as status;