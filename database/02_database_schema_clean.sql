-- ALIVE NG App - Clean Database Schema
-- This file contains all database tables and schemas for the ALIVE NG Flutter application
-- Compatible with Supabase PostgreSQL
-- Clean version without inline comments to prevent syntax errors

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE USER MANAGEMENT TABLES (Create these first)
-- ============================================================================

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- User profiles extended information
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  baptism_date DATE,
  church_membership VARCHAR(255),
  spiritual_gifts TEXT[],
  ministry_interests TEXT[],
  availability TEXT,
  emergency_contact_name VARCHAR(255),
  emergency_contact_phone VARCHAR(20),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- User roles and permissions
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role VARCHAR(50) NOT NULL,
  chapter_id UUID,
  region VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP DEFAULT NOW(),
  assigned_by UUID REFERENCES public.users(id),
  UNIQUE(user_id, role, chapter_id)
);

-- ============================================================================
-- CHAPTERS AND ORGANIZATIONAL STRUCTURE
-- ============================================================================

-- Chapters table
CREATE TABLE IF NOT EXISTS public.chapters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  chapter_type VARCHAR(50) NOT NULL,
  region VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100) DEFAULT 'Nigeria',
  coordinator_id UUID REFERENCES public.users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Chapter members
CREATE TABLE IF NOT EXISTS public.chapter_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role VARCHAR(50) DEFAULT 'member',
  joined_at TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE(chapter_id, user_id)
);

-- Chapter activities
CREATE TABLE IF NOT EXISTS public.chapter_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  activity_type VARCHAR(50) NOT NULL,
  scheduled_date TIMESTAMP,
  location TEXT,
  created_by UUID NOT NULL REFERENCES public.users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- COMMUNICATION CHANNELS AND MESSAGING
-- ============================================================================

-- Channels for communication
CREATE TABLE IF NOT EXISTS public.channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  channel_type VARCHAR(20) NOT NULL DEFAULT 'public',
  chapter_id UUID REFERENCES public.chapters(id),
  created_by UUID NOT NULL REFERENCES public.users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Channel members
CREATE TABLE IF NOT EXISTS public.channel_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'member',
  joined_at TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE(channel_id, user_id)
);

-- Chat messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  message_type VARCHAR(20) DEFAULT 'text',
  reply_to UUID REFERENCES public.chat_messages(id),
  attachments JSONB,
  is_edited BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- PRAYER REQUESTS AND SPIRITUAL SUPPORT
-- ============================================================================

-- Prayer requests
CREATE TABLE IF NOT EXISTS public.prayer_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(50),
  is_anonymous BOOLEAN DEFAULT false,
  is_urgent BOOLEAN DEFAULT false,
  is_answered BOOLEAN DEFAULT false,
  answered_at TIMESTAMP,
  testimony TEXT,
  prayer_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- User prayers (who prayed for what)
CREATE TABLE IF NOT EXISTS public.user_prayers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prayer_request_id UUID NOT NULL REFERENCES public.prayer_requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  prayed_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(prayer_request_id, user_id)
);

-- ============================================================================
-- STUDY MATERIALS AND EDUCATIONAL CONTENT
-- ============================================================================

-- Study materials
CREATE TABLE IF NOT EXISTS public.study_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  content TEXT,
  material_type VARCHAR(50) NOT NULL,
  category VARCHAR(100),
  author_id UUID REFERENCES public.users(id),
  file_url TEXT,
  thumbnail_url TEXT,
  duration INTEGER,
  difficulty_level VARCHAR(20) DEFAULT 'beginner',
  tags TEXT[],
  is_featured BOOLEAN DEFAULT false,
  is_published BOOLEAN DEFAULT true,
  view_count INTEGER DEFAULT 0,
  download_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Study guides
CREATE TABLE IF NOT EXISTS public.study_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  guide_type VARCHAR(50) NOT NULL,
  difficulty_level VARCHAR(20) DEFAULT 'beginner',
  estimated_duration INTEGER,
  author_id UUID REFERENCES public.users(id),
  is_published BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Study guide questions
CREATE TABLE IF NOT EXISTS public.study_guide_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guide_id UUID NOT NULL REFERENCES public.study_guides(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  question_type VARCHAR(20) NOT NULL,
  options JSONB,
  correct_answer TEXT,
  explanation TEXT,
  order_index INTEGER NOT NULL,
  points INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW()
);

-- User study progress
CREATE TABLE IF NOT EXISTS public.user_study_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  guide_id UUID NOT NULL REFERENCES public.study_guides(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'not_started',
  score INTEGER DEFAULT 0,
  total_questions INTEGER DEFAULT 0,
  correct_answers INTEGER DEFAULT 0,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, guide_id)
);

-- ============================================================================
-- USER SESSIONS AND AUTHENTICATION
-- ============================================================================

-- User sessions
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  device_info JSONB,
  ip_address INET,
  user_agent TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP,
  last_activity TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- NOTIFICATIONS SYSTEM
-- ============================================================================

-- Notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  notification_type VARCHAR(50),
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Notification settings
CREATE TABLE IF NOT EXISTS public.notification_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  push_notifications BOOLEAN DEFAULT true,
  email_notifications BOOLEAN DEFAULT true,
  sms_notifications BOOLEAN DEFAULT false,
  prayer_reminders BOOLEAN DEFAULT true,
  study_reminders BOOLEAN DEFAULT true,
  chapter_updates BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id)
);

-- ============================================================================
-- REPORTS AND DOCUMENTATION
-- ============================================================================

-- Reports
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  report_type VARCHAR(50),
  chapter_id UUID REFERENCES public.chapters(id),
  created_by UUID NOT NULL REFERENCES public.users(id),
  file_url TEXT,
  is_published BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at columns
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_chapters_updated_at ON public.chapters;
CREATE TRIGGER update_chapters_updated_at
  BEFORE UPDATE ON public.chapters
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_chapter_activities_updated_at ON public.chapter_activities;
CREATE TRIGGER update_chapter_activities_updated_at
  BEFORE UPDATE ON public.chapter_activities
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_channels_updated_at ON public.channels;
CREATE TRIGGER update_channels_updated_at
  BEFORE UPDATE ON public.channels
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_chat_messages_updated_at ON public.chat_messages;
CREATE TRIGGER update_chat_messages_updated_at
  BEFORE UPDATE ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_prayer_requests_updated_at ON public.prayer_requests;
CREATE TRIGGER update_prayer_requests_updated_at
  BEFORE UPDATE ON public.prayer_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_study_materials_updated_at ON public.study_materials;
CREATE TRIGGER update_study_materials_updated_at
  BEFORE UPDATE ON public.study_materials
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_study_guides_updated_at ON public.study_guides;
CREATE TRIGGER update_study_guides_updated_at
  BEFORE UPDATE ON public.study_guides
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_study_progress_updated_at ON public.user_study_progress;
CREATE TRIGGER update_user_study_progress_updated_at
  BEFORE UPDATE ON public.user_study_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_notification_settings_updated_at ON public.notification_settings;
CREATE TRIGGER update_notification_settings_updated_at
  BEFORE UPDATE ON public.notification_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_reports_updated_at ON public.reports;
CREATE TRIGGER update_reports_updated_at
  BEFORE UPDATE ON public.reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- User indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);

-- Chapter indexes
CREATE INDEX IF NOT EXISTS idx_chapters_type ON public.chapters(chapter_type);
CREATE INDEX IF NOT EXISTS idx_chapters_region ON public.chapters(region);
CREATE INDEX IF NOT EXISTS idx_chapters_coordinator ON public.chapters(coordinator_id);

-- Chat message indexes
CREATE INDEX IF NOT EXISTS idx_chat_messages_channel ON public.chat_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user ON public.chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON public.chat_messages(created_at);

-- Prayer request indexes
CREATE INDEX IF NOT EXISTS idx_prayer_requests_user ON public.prayer_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_category ON public.prayer_requests(category);
CREATE INDEX IF NOT EXISTS idx_prayer_requests_created ON public.prayer_requests(created_at);

-- Study material indexes
CREATE INDEX IF NOT EXISTS idx_study_materials_type ON public.study_materials(material_type);
CREATE INDEX IF NOT EXISTS idx_study_materials_category ON public.study_materials(category);

-- Study guide indexes
CREATE INDEX IF NOT EXISTS idx_study_guides_type ON public.study_guides(guide_type);

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- Insert sample study materials
INSERT INTO public.study_materials (title, description, material_type, category, difficulty_level)
VALUES 
  ('Introduction to Evangelism', 'Basic principles of sharing the gospel', 'study', 'evangelism', 'beginner'),
  ('Prayer and Fasting Guide', 'Comprehensive guide to effective prayer', 'study', 'prayer', 'intermediate'),
  ('Discipleship Fundamentals', 'Building strong disciples of Christ', 'study', 'discipleship', 'beginner')
ON CONFLICT DO NOTHING;

-- Insert sample study guides
INSERT INTO public.study_guides (title, description, guide_type, difficulty_level, estimated_duration)
VALUES 
  ('Salvation Basics', 'Understanding salvation through Christ', 'doctrine', 'beginner', 30),
  ('Effective Witnessing', 'How to share your faith confidently', 'evangelism', 'intermediate', 45),
  ('Christian Living', 'Practical Christian lifestyle principles', 'lifestyle', 'beginner', 60)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- VIEWS FOR REPORTING
-- ============================================================================

-- Chapter summary view
CREATE OR REPLACE VIEW public.chapter_summary AS
SELECT 
  c.id,
  c.name,
  c.chapter_type,
  c.region,
  COUNT(DISTINCT cm.user_id) as member_count,
  COUNT(DISTINCT ca.id) as activity_count,
  c.created_at
FROM public.chapters c
LEFT JOIN public.chapter_members cm ON c.id = cm.chapter_id AND cm.is_active = true
LEFT JOIN public.chapter_activities ca ON c.id = ca.chapter_id AND ca.is_active = true
WHERE c.is_active = true
GROUP BY c.id, c.name, c.chapter_type, c.region, c.created_at;

-- User activity summary view
CREATE OR REPLACE VIEW public.user_activity_summary AS
SELECT 
  u.id,
  u.full_name,
  u.email,
  COUNT(DISTINCT pr.id) as prayer_requests_count,
  COUNT(DISTINCT up.prayer_request_id) as prayers_offered_count,
  COUNT(DISTINCT cm.id) as messages_sent_count,
  u.last_seen,
  u.created_at
FROM public.users u
LEFT JOIN public.prayer_requests pr ON u.id = pr.user_id
LEFT JOIN public.user_prayers up ON u.id = up.user_id
LEFT JOIN public.chat_messages cm ON u.id = cm.user_id AND cm.is_deleted = false
WHERE u.is_active = true
GROUP BY u.id, u.full_name, u.email, u.last_seen, u.created_at;

-- ============================================================================
-- FOREIGN KEY CONSTRAINTS (Add after tables are created)
-- ============================================================================

-- Add foreign key constraint for user_roles.chapter_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'fk_user_roles_chapter' 
    AND table_name = 'user_roles' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.user_roles 
    ADD CONSTRAINT fk_user_roles_chapter 
    FOREIGN KEY (chapter_id) REFERENCES public.chapters(id);
  END IF;
END $$;

-- Link to Supabase auth.users if available
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'auth' AND table_name = 'users'
  ) THEN
    -- Only add the foreign key constraint if it doesn't already exist
    -- Do not drop the primary key as it has dependencies
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'fk_users_auth'
      AND table_name = 'users'
      AND table_schema = 'public'
    ) THEN
      ALTER TABLE public.users 
      ADD CONSTRAINT fk_users_auth 
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

SELECT 'Database schema created successfully!' as status;