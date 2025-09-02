-- ALIVE NG App - Complete Database Schema
-- This file contains all database tables and schemas for the ALIVE NG Flutter application
-- Compatible with Supabase PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE USER MANAGEMENT TABLES
-- ============================================================================

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
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

-- ============================================================================
-- AUTHENTICATION AND SECURITY
-- ============================================================================

-- User sessions tracking
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
-- CHAT AND MESSAGING SYSTEM
-- ============================================================================

-- Chat channels
CREATE TABLE IF NOT EXISTS public.channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  type VARCHAR(20) NOT NULL DEFAULT 'public', -- 'public', 'private', 'direct'
  chapter_id UUID,
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
  role VARCHAR(20) DEFAULT 'member', -- 'admin', 'moderator', 'member'
  joined_at TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  
  UNIQUE(channel_id, user_id)
);

-- Messages
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  message_type VARCHAR(20) DEFAULT 'text', -- 'text', 'image', 'file', 'system'
  reply_to UUID REFERENCES public.messages(id),
  attachments JSONB,
  is_edited BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Message tags for Discord-like tagging system
CREATE TABLE IF NOT EXISTS public.message_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  tag_type VARCHAR(20) NOT NULL, -- 'role', 'user', 'special', 'chapter'
  tag_value VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Tag visibility rules
CREATE TABLE IF NOT EXISTS public.tag_visibility_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag_pattern VARCHAR(100) NOT NULL,
  required_role VARCHAR(50),
  required_permission VARCHAR(50),
  hierarchy_level INTEGER,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- CHAPTERS AND GROUPS MANAGEMENT
-- ============================================================================

-- Chapters
CREATE TABLE IF NOT EXISTS public.chapters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  type VARCHAR(50) NOT NULL, -- 'field_work', 'campus_mission', 'amtc', 'programming', 'evangelism'
  location VARCHAR(255),
  region VARCHAR(50),
  coordinator_id UUID REFERENCES public.users(id),
  is_active BOOLEAN DEFAULT true,
  tags TEXT[],
  contact_email VARCHAR(255),
  contact_phone VARCHAR(20),
  meeting_schedule JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Chapter members
CREATE TABLE IF NOT EXISTS public.chapter_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role VARCHAR(50) NOT NULL, -- 'coordinator', 'assistant', 'member', 'trainee'
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
  type VARCHAR(50) NOT NULL, -- 'meeting', 'outreach', 'training', 'social', 'service'
  status VARCHAR(20) DEFAULT 'planned', -- 'planned', 'ongoing', 'completed', 'cancelled'
  start_date TIMESTAMP,
  end_date TIMESTAMP,
  location VARCHAR(255),
  organizer_id UUID REFERENCES public.users(id),
  max_participants INTEGER,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Chapter tasks
CREATE TABLE IF NOT EXISTS public.chapter_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  assigned_to UUID REFERENCES public.users(id),
  assigned_by UUID REFERENCES public.users(id),
  status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'cancelled'
  priority VARCHAR(10) DEFAULT 'medium', -- 'low', 'medium', 'high', 'urgent'
  due_date TIMESTAMP,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Chapter reports
CREATE TABLE IF NOT EXISTS public.chapter_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  report_type VARCHAR(50) NOT NULL, -- 'monthly', 'quarterly', 'annual', 'activity', 'financial'
  status VARCHAR(20) DEFAULT 'draft', -- 'draft', 'submitted', 'reviewed', 'approved'
  period_start DATE,
  period_end DATE,
  submitted_by UUID REFERENCES public.users(id),
  reviewed_by UUID REFERENCES public.users(id),
  submitted_at TIMESTAMP,
  reviewed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- DISCIPLESHIP TRACKING SYSTEM
-- ============================================================================

-- Discipleship contacts
CREATE TABLE IF NOT EXISTS public.discipleship_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  address TEXT,
  level VARCHAR(50) NOT NULL, -- 'prospect', 'interested', 'studying', 'baptized', 'discipling'
  contact_method VARCHAR(50), -- 'phone', 'email', 'visit', 'social_media'
  notes TEXT,
  last_contact DATE,
  next_contact DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Contact interactions
CREATE TABLE IF NOT EXISTS public.contact_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID NOT NULL REFERENCES public.discipleship_contacts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- 'call', 'visit', 'email', 'study', 'prayer'
  description TEXT,
  outcome VARCHAR(100),
  next_steps TEXT,
  interaction_date TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Study sessions
CREATE TABLE IF NOT EXISTS public.study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID NOT NULL REFERENCES public.discipleship_contacts(id) ON DELETE CASCADE,
  facilitator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  study_guide_id UUID,
  lesson_number INTEGER,
  topic VARCHAR(255),
  duration INTEGER, -- in minutes
  attendance TEXT[],
  notes TEXT,
  next_lesson_date DATE,
  status VARCHAR(20) DEFAULT 'completed', -- 'scheduled', 'completed', 'cancelled'
  session_date TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Prayer requests
CREATE TABLE IF NOT EXISTS public.prayer_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID REFERENCES public.discipleship_contacts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(50), -- 'health', 'family', 'work', 'spiritual', 'financial', 'other'
  status VARCHAR(20) DEFAULT 'active', -- 'active', 'answered', 'ongoing', 'closed'
  is_private BOOLEAN DEFAULT false,
  answered_at TIMESTAMP,
  answer_description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Progress milestones
CREATE TABLE IF NOT EXISTS public.progress_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id UUID NOT NULL REFERENCES public.discipleship_contacts(id) ON DELETE CASCADE,
  milestone VARCHAR(100) NOT NULL,
  description TEXT,
  achieved_date DATE,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Discipleship reports
CREATE TABLE IF NOT EXISTS public.discipleship_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  content TEXT,
  report_type VARCHAR(50), -- 'weekly', 'monthly', 'quarterly'
  period_start DATE,
  period_end DATE,
  statistics JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- STUDY GUIDES SYSTEM
-- ============================================================================

-- Study guides
CREATE TABLE IF NOT EXISTS public.study_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  type VARCHAR(50) NOT NULL, -- 'evangelism', 'discipleship', 'doctrine', 'prophecy', 'lifestyle'
  difficulty VARCHAR(20) DEFAULT 'beginner', -- 'beginner', 'intermediate', 'advanced'
  estimated_duration INTEGER, -- in minutes
  author_id UUID REFERENCES public.users(id),
  is_featured BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  tags TEXT[],
  cover_image_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Study lessons
CREATE TABLE IF NOT EXISTS public.study_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  study_guide_id UUID NOT NULL REFERENCES public.study_guides(id) ON DELETE CASCADE,
  lesson_number INTEGER NOT NULL,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  objectives TEXT[],
  bible_verses TEXT[],
  estimated_duration INTEGER, -- in minutes
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(study_guide_id, lesson_number)
);

-- Study questions
CREATE TABLE IF NOT EXISTS public.study_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES public.study_lessons(id) ON DELETE CASCADE,
  question_number INTEGER NOT NULL,
  question_text TEXT NOT NULL,
  question_type VARCHAR(20) DEFAULT 'multiple_choice', -- 'multiple_choice', 'true_false', 'short_answer', 'essay'
  options JSONB, -- for multiple choice questions
  correct_answer TEXT,
  explanation TEXT,
  points INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(lesson_id, question_number)
);

-- User study progress
CREATE TABLE IF NOT EXISTS public.user_study_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  study_guide_id UUID NOT NULL REFERENCES public.study_guides(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'not_started', -- 'not_started', 'in_progress', 'completed'
  progress_percentage DECIMAL(5,2) DEFAULT 0,
  current_lesson_id UUID REFERENCES public.study_lessons(id),
  total_time_spent INTEGER DEFAULT 0, -- in minutes
  score DECIMAL(5,2),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  last_accessed TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, study_guide_id)
);

-- User lesson progress
CREATE TABLE IF NOT EXISTS public.user_lesson_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES public.study_lessons(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'not_started', -- 'not_started', 'in_progress', 'completed'
  time_spent INTEGER DEFAULT 0, -- in minutes
  score DECIMAL(5,2),
  answers JSONB, -- user's answers to questions
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, lesson_id)
);

-- ============================================================================
-- HEALTH AND WELLNESS SYSTEM
-- ============================================================================

-- Nigerian meal plans
CREATE TABLE IF NOT EXISTS public.nigerian_meals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  description TEXT,
  region VARCHAR(50), -- 'north', 'south', 'east', 'west', 'central'
  meal_type VARCHAR(20), -- 'breakfast', 'lunch', 'dinner', 'snack'
  ingredients JSONB NOT NULL,
  instructions TEXT NOT NULL,
  prep_time INTEGER, -- in minutes
  cook_time INTEGER, -- in minutes
  servings INTEGER DEFAULT 4,
  health_principles TEXT[],
  bible_verse VARCHAR(500),
  nutritional_info JSONB,
  is_vegetarian BOOLEAN DEFAULT true,
  is_vegan BOOLEAN DEFAULT false,
  difficulty_level VARCHAR(20) DEFAULT 'easy', -- 'easy', 'medium', 'hard'
  created_by UUID REFERENCES public.users(id),
  is_approved BOOLEAN DEFAULT false,
  approved_by UUID REFERENCES public.users(id),
  approved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Natural remedies
CREATE TABLE IF NOT EXISTS public.natural_remedies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  description TEXT,
  category VARCHAR(50), -- 'nutrition', 'exercise', 'water', 'sunlight', 'temperance', 'air', 'rest', 'trust'
  ingredients JSONB,
  preparation TEXT,
  usage_instructions TEXT,
  benefits TEXT[],
  precautions TEXT[],
  bible_verse VARCHAR(500),
  scientific_backing TEXT,
  created_by UUID REFERENCES public.users(id),
  is_approved BOOLEAN DEFAULT false,
  approved_by UUID REFERENCES public.users(id),
  approved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Health tracking
CREATE TABLE IF NOT EXISTS public.health_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  tracking_date DATE NOT NULL,
  nutrition_score INTEGER CHECK (nutrition_score >= 0 AND nutrition_score <= 10),
  exercise_minutes INTEGER DEFAULT 0,
  water_glasses INTEGER DEFAULT 0,
  sunlight_minutes INTEGER DEFAULT 0,
  temperance_score INTEGER CHECK (temperance_score >= 0 AND temperance_score <= 10),
  fresh_air_minutes INTEGER DEFAULT 0,
  sleep_hours DECIMAL(3,1) DEFAULT 0,
  spiritual_time_minutes INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, tracking_date)
);

-- Health tips
CREATE TABLE IF NOT EXISTS public.health_tips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  category VARCHAR(50), -- 'nutrition', 'exercise', 'mental_health', 'spiritual', 'lifestyle'
  tags TEXT[],
  bible_verse VARCHAR(500),
  is_featured BOOLEAN DEFAULT false,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- MATERIALS AND DOWNLOADS SYSTEM
-- ============================================================================

-- Materials
CREATE TABLE IF NOT EXISTS public.materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(50), -- 'tract', 'book', 'audio', 'video', 'document'
  file_url TEXT,
  file_size BIGINT, -- in bytes
  file_type VARCHAR(20),
  thumbnail_url TEXT,
  donation_required BOOLEAN DEFAULT false,
  minimum_donation DECIMAL(10,2) DEFAULT 0,
  download_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  tags TEXT[],
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Donations
CREATE TABLE IF NOT EXISTS public.donations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'USD',
  purpose VARCHAR(100),
  payment_method VARCHAR(50), -- 'stripe', 'paystack', 'bank_transfer'
  transaction_id VARCHAR(255),
  status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'completed', 'failed', 'refunded'
  payment_data JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Material downloads
CREATE TABLE IF NOT EXISTS public.material_downloads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  material_id UUID NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
  donation_id UUID REFERENCES public.donations(id),
  download_count INTEGER DEFAULT 1,
  last_downloaded TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- LEADERSHIP ARCHIVE SYSTEM
-- ============================================================================

-- Leadership archive
CREATE TABLE IF NOT EXISTS public.leadership_archive (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  position VARCHAR(100) NOT NULL,
  department VARCHAR(100),
  chapter_id UUID REFERENCES public.chapters(id),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  year_of_service INTEGER,
  contact_email VARCHAR(255),
  contact_phone VARCHAR(20),
  achievements TEXT,
  responsibilities TEXT[],
  successor_id UUID REFERENCES public.users(id),
  archived_at TIMESTAMP DEFAULT NOW(),
  archived_by UUID NOT NULL REFERENCES public.users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- CONFERENCE AND MEETINGS SYSTEM
-- ============================================================================

-- Conferences
CREATE TABLE IF NOT EXISTS public.conferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  type VARCHAR(50), -- 'board_meeting', 'chapter_meeting', 'training', 'general'
  status VARCHAR(20) DEFAULT 'scheduled', -- 'scheduled', 'ongoing', 'completed', 'cancelled'
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP,
  timezone VARCHAR(50) DEFAULT 'Africa/Lagos',
  meeting_url TEXT,
  meeting_id VARCHAR(100),
  passcode VARCHAR(50),
  max_participants INTEGER,
  host_id UUID NOT NULL REFERENCES public.users(id),
  is_recorded BOOLEAN DEFAULT false,
  recording_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Conference participants
CREATE TABLE IF NOT EXISTS public.conference_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conference_id UUID NOT NULL REFERENCES public.conferences(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'participant', -- 'host', 'co_host', 'participant'
  joined_at TIMESTAMP,
  left_at TIMESTAMP,
  duration INTEGER, -- in minutes
  is_invited BOOLEAN DEFAULT true,
  invitation_sent_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(conference_id, user_id)
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
  type VARCHAR(50), -- 'info', 'warning', 'success', 'error', 'reminder'
  category VARCHAR(50), -- 'system', 'chat', 'discipleship', 'health', 'study', 'chapter'
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Push notification tokens
CREATE TABLE IF NOT EXISTS public.push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform VARCHAR(20), -- 'android', 'ios', 'web'
  device_info JSONB,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, token)
);

-- ============================================================================
-- ANALYTICS AND LOGGING
-- ============================================================================

-- User activity logs
CREATE TABLE IF NOT EXISTS public.user_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(50),
  resource_id UUID,
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- App usage statistics
CREATE TABLE IF NOT EXISTS public.app_usage_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  feature VARCHAR(50) NOT NULL,
  usage_count INTEGER DEFAULT 1,
  total_time_spent INTEGER DEFAULT 0, -- in seconds
  last_used TIMESTAMP DEFAULT NOW(),
  date DATE DEFAULT CURRENT_DATE,
  
  UNIQUE(user_id, feature, date)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- User indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_last_seen ON public.users(last_seen);

-- User roles indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON public.user_roles(role);
CREATE INDEX IF NOT EXISTS idx_user_roles_chapter_id ON public.user_roles(chapter_id);

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_messages_channel_id ON public.messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_messages_user_id ON public.messages(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_is_deleted ON public.messages(is_deleted);

-- Message tags indexes
CREATE INDEX IF NOT EXISTS idx_message_tags_message_id ON public.message_tags(message_id);
CREATE INDEX IF NOT EXISTS idx_message_tags_type_value ON public.message_tags(tag_type, tag_value);

-- Chapters indexes
CREATE INDEX IF NOT EXISTS idx_chapters_type ON public.chapters(type);
CREATE INDEX IF NOT EXISTS idx_chapters_region ON public.chapters(region);
CREATE INDEX IF NOT EXISTS idx_chapters_is_active ON public.chapters(is_active);
CREATE INDEX IF NOT EXISTS idx_chapters_coordinator_id ON public.chapters(coordinator_id);

-- Chapter members indexes
CREATE INDEX IF NOT EXISTS idx_chapter_members_chapter_id ON public.chapter_members(chapter_id);
CREATE INDEX IF NOT EXISTS idx_chapter_members_user_id ON public.chapter_members(user_id);
CREATE INDEX IF NOT EXISTS idx_chapter_members_role ON public.chapter_members(role);

-- Discipleship contacts indexes
CREATE INDEX IF NOT EXISTS idx_discipleship_contacts_user_id ON public.discipleship_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_discipleship_contacts_level ON public.discipleship_contacts(level);
CREATE INDEX IF NOT EXISTS idx_discipleship_contacts_is_active ON public.discipleship_contacts(is_active);

-- Study guides indexes
CREATE INDEX IF NOT EXISTS idx_study_guides_type ON public.study_guides(type);
CREATE INDEX IF NOT EXISTS idx_study_guides_difficulty ON public.study_guides(difficulty);
CREATE INDEX IF NOT EXISTS idx_study_guides_is_active ON public.study_guides(is_active);
CREATE INDEX IF NOT EXISTS idx_study_guides_is_featured ON public.study_guides(is_featured);

-- Health tracking indexes
CREATE INDEX IF NOT EXISTS idx_health_tracking_user_id ON public.health_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_health_tracking_date ON public.health_tracking(tracking_date DESC);

-- Materials indexes
CREATE INDEX IF NOT EXISTS idx_materials_category ON public.materials(category);
CREATE INDEX IF NOT EXISTS idx_materials_is_active ON public.materials(is_active);
CREATE INDEX IF NOT EXISTS idx_materials_donation_required ON public.materials(donation_required);

-- Donations indexes
CREATE INDEX IF NOT EXISTS idx_donations_user_id ON public.donations(user_id);
CREATE INDEX IF NOT EXISTS idx_donations_status ON public.donations(status);
CREATE INDEX IF NOT EXISTS idx_donations_created_at ON public.donations(created_at DESC);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapter_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapter_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapter_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapter_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discipleship_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prayer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discipleship_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_study_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nigerian_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.natural_remedies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_tips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_downloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leadership_archive ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conference_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_usage_stats ENABLE ROW LEVEL SECURITY;

-- Basic user policies
CREATE POLICY "Users can view their own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Messages visibility based on tags
CREATE POLICY "Users can see tagged messages" ON public.messages
  FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.message_tags mt
      JOIN public.user_roles ur ON ur.user_id = auth.uid()
      WHERE mt.message_id = messages.id
      AND (
        (mt.tag_type = 'role' AND mt.tag_value = ur.role) OR
        (mt.tag_type = 'user' AND mt.tag_value = (SELECT username FROM public.users WHERE id = auth.uid()))
      )
    ) OR
    EXISTS (
      SELECT 1 FROM public.channel_members cm
      WHERE cm.channel_id = messages.channel_id
      AND cm.user_id = auth.uid()
      AND cm.is_active = true
    )
  );

-- Leadership archive access
CREATE POLICY "Leaders can view archive" ON public.leadership_archive
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
      AND role IN ('admin', 'director', 'coordinator')
      AND is_active = true
    )
  );

-- Health data privacy
CREATE POLICY "Users can manage their health data" ON public.health_tracking
  FOR ALL USING (user_id = auth.uid());

-- Discipleship contacts privacy
CREATE POLICY "Users can manage their discipleship contacts" ON public.discipleship_contacts
  FOR ALL USING (user_id = auth.uid());

-- Study progress privacy
CREATE POLICY "Users can view their study progress" ON public.user_study_progress
  FOR ALL USING (user_id = auth.uid());

-- Donations privacy
CREATE POLICY "Users can view their donations" ON public.donations
  FOR SELECT USING (user_id = auth.uid());

-- Notifications privacy
CREATE POLICY "Users can view their notifications" ON public.notifications
  FOR ALL USING (user_id = auth.uid());

-- Chapter access based on membership
CREATE POLICY "Chapter members can view chapter data" ON public.chapters
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chapter_members cm
      WHERE cm.chapter_id = chapters.id
      AND cm.user_id = auth.uid()
      AND cm.is_active = true
    ) OR
    EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid()
      AND ur.role IN ('admin', 'director')
      AND ur.is_active = true
    )
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
$$ language 'plpgsql';

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_channels_updated_at BEFORE UPDATE ON public.channels FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chapters_updated_at BEFORE UPDATE ON public.chapters FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chapter_activities_updated_at BEFORE UPDATE ON public.chapter_activities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chapter_tasks_updated_at BEFORE UPDATE ON public.chapter_tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chapter_reports_updated_at BEFORE UPDATE ON public.chapter_reports FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_discipleship_contacts_updated_at BEFORE UPDATE ON public.discipleship_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_prayer_requests_updated_at BEFORE UPDATE ON public.prayer_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_study_guides_updated_at BEFORE UPDATE ON public.study_guides FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_study_lessons_updated_at BEFORE UPDATE ON public.study_lessons FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_study_progress_updated_at BEFORE UPDATE ON public.user_study_progress FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_lesson_progress_updated_at BEFORE UPDATE ON public.user_lesson_progress FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_nigerian_meals_updated_at BEFORE UPDATE ON public.nigerian_meals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_natural_remedies_updated_at BEFORE UPDATE ON public.natural_remedies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_health_tips_updated_at BEFORE UPDATE ON public.health_tips FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_materials_updated_at BEFORE UPDATE ON public.materials FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_donations_updated_at BEFORE UPDATE ON public.donations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_conferences_updated_at BEFORE UPDATE ON public.conferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_push_tokens_updated_at BEFORE UPDATE ON public.push_tokens FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to handle user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- INITIAL DATA SEEDING
-- ============================================================================

-- Insert default tag visibility rules
INSERT INTO public.tag_visibility_rules (tag_pattern, required_role, hierarchy_level) VALUES
('#bod', 'bod', 1),
('#trustees', 'trustees', 1),
('#director', 'director', 2),
('#chap_coor', 'coordinator', 3),
('#admin', 'admin', 1),
('@*', NULL, 999) -- Individual tags visible to tagged user
ON CONFLICT DO NOTHING;

-- Insert default health tips
INSERT INTO public.health_tips (title, content, category, bible_verse) VALUES
('Start Your Day with Water', 'Drinking water first thing in the morning helps kickstart your metabolism and flush out toxins from your body.', 'nutrition', 'And he said unto me, It is done. I am Alpha and Omega, the beginning and the end. I will give unto him that is athirst of the fountain of the water of life freely. - Revelation 21:6'),
('Exercise as Worship', 'Physical exercise can be a form of worship when we use our bodies to glorify God and maintain the temple He has given us.', 'exercise', 'What? know ye not that your body is the temple of the Holy Ghost which is in you, which ye have of God, and ye are not your own? - 1 Corinthians 6:19'),
('Rest in God''s Peace', 'Quality sleep is essential for physical and spiritual health. Create a peaceful environment for rest.', 'lifestyle', 'Come unto me, all ye that labour and are heavy laden, and I will give you rest. - Matthew 11:28')
ON CONFLICT DO NOTHING;

-- Insert sample Nigerian meals
INSERT INTO public.nigerian_meals (name, description, region, meal_type, ingredients, instructions, prep_time, cook_time, health_principles, bible_verse, is_approved) VALUES
('Vegetable Soup (Edikang Ikong)', 'A nutritious Nigerian vegetable soup rich in vitamins and minerals', 'south', 'lunch', 
 '{"ugu_leaves": "2 cups chopped", "waterleaf": "1 cup chopped", "palm_oil": "3 tbsp", "onions": "1 medium diced", "garlic": "3 cloves minced", "ginger": "1 tsp grated", "vegetable_stock": "2 cups", "salt": "to taste", "pepper": "to taste"}',
 'Heat palm oil in pot. Sauté onions, garlic, and ginger. Add vegetable stock and bring to boil. Add ugu leaves and waterleaf. Season with salt and pepper. Simmer for 10 minutes.',
 15, 20, 
 '{"nutrition", "fresh_air", "temperance"}',
 'And God said, Behold, I have given you every herb bearing seed, which is upon the face of all the earth, and every tree, in the which is the fruit of a tree yielding seed; to you it shall be for meat. - Genesis 1:29',
 true),
('Moi Moi (Bean Pudding)', 'Steamed bean pudding packed with protein and nutrients', 'west', 'lunch',
 '{"black_eyed_peas": "2 cups", "bell_peppers": "2 medium", "onions": "1 large", "palm_oil": "4 tbsp", "vegetable_stock": "1 cup", "salt": "to taste", "curry_powder": "1 tsp", "thyme": "1 tsp"}',
 'Soak and peel beans. Blend with peppers and onions. Mix in palm oil, stock, and seasonings. Steam in containers for 45 minutes.',
 30, 45,
 '{"nutrition", "water", "temperance"}',
 'Every moving thing that liveth shall be meat for you; even as the green herb have I given you all things. - Genesis 9:3',
 true)
ON CONFLICT DO NOTHING;

-- Insert sample natural remedies
INSERT INTO public.natural_remedies (name, description, category, ingredients, preparation, usage_instructions, benefits, bible_verse, is_approved) VALUES
('Ginger and Lemon Tea', 'A warming tea that aids digestion and boosts immunity', 'nutrition',
 '{"fresh_ginger": "1 inch piece", "lemon": "1 medium", "honey": "1 tbsp optional", "water": "2 cups"}',
 'Slice ginger thinly. Boil water and add ginger. Simmer for 10 minutes. Add lemon juice and honey if desired.',
 'Drink 1-2 cups daily, preferably in the morning or when feeling unwell.',
 '{"Aids digestion", "Boosts immunity", "Reduces inflammation", "Provides vitamin C"}',
 'He causeth the grass to grow for the cattle, and herb for the service of man: that he may bring forth food out of the earth. - Psalm 104:14',
 true),
('Morning Sunlight Therapy', 'Natural vitamin D synthesis through safe sun exposure', 'sunlight',
 '{"morning_sunlight": "15-30 minutes", "comfortable_clothing": "light colored"}',
 'Find a safe outdoor space with morning sunlight (before 10 AM). Expose arms and legs to sunlight.',
 'Spend 15-30 minutes in morning sunlight daily. Avoid peak hours (10 AM - 4 PM).',
 '{"Vitamin D synthesis", "Improved mood", "Better sleep regulation", "Stronger bones"}',
 'The light of the eyes rejoiceth the heart: and a good report maketh the bones fat. - Proverbs 15:30',
 true)
ON CONFLICT DO NOTHING;

-- Create admin user role (this should be done after first user registration)
-- INSERT INTO public.user_roles (user_id, role) 
-- SELECT id, 'admin' FROM public.users WHERE email = 'admin@alive-ng.org' LIMIT 1;

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- User profile view with roles
CREATE OR REPLACE VIEW public.user_profile_view AS
SELECT 
  u.id,
  u.username,
  u.full_name,
  u.email,
  u.phone,
  u.avatar_url,
  u.bio,
  u.city,
  u.state,
  u.is_active,
  u.last_seen,
  u.created_at,
  ARRAY_AGG(DISTINCT ur.role) FILTER (WHERE ur.role IS NOT NULL) as roles,
  ARRAY_AGG(DISTINCT c.name) FILTER (WHERE c.name IS NOT NULL) as chapters
FROM public.users u
LEFT JOIN public.user_roles ur ON u.id = ur.user_id AND ur.is_active = true
LEFT JOIN public.chapter_members cm ON u.id = cm.user_id AND cm.is_active = true
LEFT JOIN public.chapters c ON cm.chapter_id = c.id
GROUP BY u.id, u.username, u.full_name, u.email, u.phone, u.avatar_url, u.bio, u.city, u.state, u.is_active, u.last_seen, u.created_at;

-- Chapter statistics view
CREATE OR REPLACE VIEW public.chapter_stats_view AS
SELECT 
  c.id,
  c.name,
  c.type,
  c.region,
  COUNT(DISTINCT cm.user_id) FILTER (WHERE cm.is_active = true) as member_count,
  COUNT(DISTINCT ca.id) FILTER (WHERE ca.status = 'completed' AND ca.start_date >= CURRENT_DATE - INTERVAL '30 days') as activities_last_30_days,
  COUNT(DISTINCT ct.id) FILTER (WHERE ct.status = 'pending') as pending_tasks,
  COUNT(DISTINCT cr.id) FILTER (WHERE cr.status = 'submitted' AND cr.created_at >= CURRENT_DATE - INTERVAL '30 days') as reports_last_30_days
FROM public.chapters c
LEFT JOIN public.chapter_members cm ON c.id = cm.chapter_id
LEFT JOIN public.chapter_activities ca ON c.id = ca.chapter_id
LEFT JOIN public.chapter_tasks ct ON c.id = ct.chapter_id
LEFT JOIN public.chapter_reports cr ON c.id = cr.chapter_id
WHERE c.is_active = true
GROUP BY c.id, c.name, c.type, c.region;

-- Health tracking summary view
CREATE OR REPLACE VIEW public.health_summary_view AS
SELECT 
  user_id,
  DATE_TRUNC('week', tracking_date) as week_start,
  AVG(nutrition_score) as avg_nutrition,
  AVG(exercise_minutes) as avg_exercise,
  AVG(water_glasses) as avg_water,
  AVG(sunlight_minutes) as avg_sunlight,
  AVG(temperance_score) as avg_temperance,
  AVG(fresh_air_minutes) as avg_fresh_air,
  AVG(sleep_hours) as avg_sleep,
  AVG(spiritual_time_minutes) as avg_spiritual_time,
  COUNT(*) as tracking_days
FROM public.health_tracking
WHERE tracking_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY user_id, DATE_TRUNC('week', tracking_date);

-- Study progress summary view
CREATE OR REPLACE VIEW public.study_progress_summary AS
SELECT 
  u.id as user_id,
  u.full_name,
  COUNT(DISTINCT usp.study_guide_id) as total_studies,
  COUNT(DISTINCT usp.study_guide_id) FILTER (WHERE usp.status = 'completed') as completed_studies,
  COUNT(DISTINCT usp.study_guide_id) FILTER (WHERE usp.status = 'in_progress') as in_progress_studies,
  SUM(usp.total_time_spent) as total_time_spent,
  AVG(usp.score) FILTER (WHERE usp.status = 'completed') as avg_score
FROM public.users u
LEFT JOIN public.user_study_progress usp ON u.id = usp.user_id
GROUP BY u.id, u.full_name;

-- ============================================================================
-- COMMENTS AND DOCUMENTATION
-- ============================================================================

-- This schema supports:
-- 1. User management with roles and permissions
-- 2. Real-time chat with Discord-like tagging
-- 3. Chapter/group management with activities and reporting
-- 4. Discipleship tracking with contacts and progress
-- 5. Study guides with progress tracking
-- 6. Health and wellness tracking with Nigerian content
-- 7. Materials and donation system
-- 8. Leadership archive system
-- 9. Conference and meeting management
-- 10. Comprehensive notification system
-- 11. Analytics and usage tracking
-- 12. Row-level security for data protection
-- 13. Performance optimization with indexes
-- 14. Automated triggers for data consistency

-- To deploy this schema:
-- 1. Run this script in your Supabase SQL editor
-- 2. Verify all tables are created successfully
-- 3. Test RLS policies with different user roles
-- 4. Populate with initial data as needed
-- 5. Monitor performance and adjust indexes as required

-- For maintenance:
-- 1. Regularly analyze query performance
-- 2. Update RLS policies as roles change
-- 3. Archive old data to maintain performance
-- 4. Backup critical data regularly
-- 5. Monitor storage usage and optimize as needed