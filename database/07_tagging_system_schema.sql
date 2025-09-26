-- ALIVE NG App - Tagging System Database Schema
-- This file contains database tables for the Discord-like tagging system
-- Compatible with Supabase PostgreSQL

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TAGGING SYSTEM TABLES
-- ============================================================================

-- Message tags table - stores tag associations with messages
CREATE TABLE IF NOT EXISTS public.message_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL, -- References chat_messages.id
  tag_type VARCHAR(20) NOT NULL CHECK (tag_type IN ('user', 'role', 'group', 'special')),
  tag_value VARCHAR(100) NOT NULL,
  display_name VARCHAR(255),
  user_id UUID REFERENCES public.users(id), -- For user tags
  role_id UUID, -- For role tags
  created_at TIMESTAMP DEFAULT NOW()
);

-- User roles table (enhanced version for tagging system)
-- Note: This extends the existing user_roles table with additional fields
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS role_name VARCHAR(100);
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS role_level INTEGER DEFAULT 1;
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS can_tag_roles TEXT[] DEFAULT '{}';
ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS can_see_roles TEXT[] DEFAULT '{}';

-- Tag visibility rules - controls who can see what tags
CREATE TABLE IF NOT EXISTS public.tag_visibility_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag_type VARCHAR(20) NOT NULL,
  tag_value VARCHAR(100) NOT NULL,
  required_role VARCHAR(100),
  required_level INTEGER DEFAULT 1,
  visibility_scope VARCHAR(50) DEFAULT 'role', -- 'role', 'hierarchy', 'peer', 'team', 'public'
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(tag_type, tag_value, required_role)
);

-- User groups table - for group-based tagging
CREATE TABLE IF NOT EXISTS public.user_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  group_name VARCHAR(100) NOT NULL,
  group_type VARCHAR(50) DEFAULT 'custom', -- 'chapter', 'region', 'ministry', 'custom'
  is_active BOOLEAN DEFAULT true,
  joined_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, group_name)
);

-- User presence table - for online/active status tracking
CREATE TABLE IF NOT EXISTS public.user_presence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  is_online BOOLEAN DEFAULT false,
  last_seen TIMESTAMP DEFAULT NOW(),
  status VARCHAR(50) DEFAULT 'offline', -- 'online', 'away', 'busy', 'offline'
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Event participants table - for event-based tagging
CREATE TABLE IF NOT EXISTS public.event_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type VARCHAR(100) NOT NULL, -- 'meeting', 'conference', 'training', etc.
  event_name VARCHAR(255),
  event_date TIMESTAMP,
  participation_status VARCHAR(50) DEFAULT 'registered', -- 'registered', 'attended', 'completed'
  created_at TIMESTAMP DEFAULT NOW()
);

-- User chapters table - for chapter-based tagging (if not exists)
CREATE TABLE IF NOT EXISTS public.user_chapters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  chapter_name VARCHAR(100) NOT NULL,
  chapter_id UUID REFERENCES public.chapters(id),
  role VARCHAR(50) DEFAULT 'member',
  is_active BOOLEAN DEFAULT true,
  joined_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, chapter_name)
);

-- User regions table - for regional tagging
CREATE TABLE IF NOT EXISTS public.user_regions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  region VARCHAR(50) NOT NULL, -- 'north', 'south', 'east', 'west', 'central'
  is_primary BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, region)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Indexes for message_tags table
CREATE INDEX IF NOT EXISTS idx_message_tags_message_id ON public.message_tags(message_id);
CREATE INDEX IF NOT EXISTS idx_message_tags_type_value ON public.message_tags(tag_type, tag_value);
CREATE INDEX IF NOT EXISTS idx_message_tags_user_id ON public.message_tags(user_id);

-- Indexes for user_roles table
CREATE INDEX IF NOT EXISTS idx_user_roles_user_role ON public.user_roles(user_id, role);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_level ON public.user_roles(role, role_level);

-- Indexes for tag_visibility_rules table
CREATE INDEX IF NOT EXISTS idx_tag_visibility_type_value ON public.tag_visibility_rules(tag_type, tag_value);
CREATE INDEX IF NOT EXISTS idx_tag_visibility_role ON public.tag_visibility_rules(required_role);

-- Indexes for user_groups table
CREATE INDEX IF NOT EXISTS idx_user_groups_user_group ON public.user_groups(user_id, group_name);
CREATE INDEX IF NOT EXISTS idx_user_groups_group_type ON public.user_groups(group_name, group_type);

-- Indexes for user_presence table
CREATE INDEX IF NOT EXISTS idx_user_presence_user_id ON public.user_presence(user_id);
CREATE INDEX IF NOT EXISTS idx_user_presence_online ON public.user_presence(is_online);
CREATE INDEX IF NOT EXISTS idx_user_presence_last_seen ON public.user_presence(last_seen);

-- ============================================================================
-- DEFAULT DATA FOR TAGGING SYSTEM
-- ============================================================================

-- Insert default tag visibility rules
INSERT INTO public.tag_visibility_rules (tag_type, tag_value, required_role, required_level, visibility_scope) VALUES
-- Role-based tags
('role', 'bod', 'bod', 10, 'hierarchy'),
('role', 'trustees', 'trustees', 9, 'hierarchy'),
('role', 'executive', 'executive', 8, 'hierarchy'),
('role', 'leadership', 'leadership', 7, 'hierarchy'),
('role', 'director', 'director', 6, 'peer'),
('role', 'field_director', 'director', 6, 'peer'),
('role', 'campus_director', 'director', 6, 'peer'),
('role', 'program_director', 'director', 6, 'peer'),
('role', 'evangelism_director', 'director', 6, 'peer'),
('role', 'amtc_director', 'director', 6, 'peer'),
('role', 'chap_coor', 'coordinator', 5, 'peer'),
('role', 'field_coor', 'coordinator', 5, 'peer'),
('role', 'campus_coor', 'coordinator', 5, 'peer'),
('role', 'program_coor', 'coordinator', 5, 'peer'),
('role', 'evangelism_coor', 'coordinator', 5, 'peer'),
('role', 'amtc_coor', 'coordinator', 5, 'peer'),
('role', 'admin', 'admin', 4, 'team'),
('role', 'treasurer', 'treasurer', 3, 'team'),
('role', 'secretary', 'secretary', 3, 'team'),
('role', 'media', 'media', 2, 'team'),
('role', 'tech', 'tech', 2, 'team'),
('role', 'health', 'health', 2, 'team'),

-- Special tags
('special', 'all', 'member', 1, 'public'),
('special', 'online', 'member', 1, 'public'),
('special', 'active', 'member', 1, 'public'),
('special', 'new', 'member', 1, 'public'),
('special', 'meeting', 'coordinator', 5, 'team'),
('special', 'conference', 'coordinator', 5, 'team'),
('special', 'training', 'coordinator', 5, 'team'),

-- Group tags
('group', 'fieldwork', 'field_coor', 5, 'team'),
('group', 'campus_mission', 'campus_coor', 5, 'team'),
('group', 'amtc', 'amtc_coor', 5, 'team'),
('group', 'youth', 'coordinator', 5, 'team'),
('group', 'women', 'coordinator', 5, 'team'),
('group', 'men', 'coordinator', 5, 'team'),

-- Regional tags
('group', 'north', 'coordinator', 5, 'team'),
('group', 'south', 'coordinator', 5, 'team'),
('group', 'east', 'coordinator', 5, 'team'),
('group', 'west', 'coordinator', 5, 'team'),
('group', 'central', 'coordinator', 5, 'team')

ON CONFLICT (tag_type, tag_value, required_role) DO NOTHING;

-- ============================================================================
-- FUNCTIONS FOR TAGGING SYSTEM
-- ============================================================================

-- Function to check if user can see a tag
CREATE OR REPLACE FUNCTION can_user_see_tag(
  p_user_id UUID,
  p_tag_type VARCHAR,
  p_tag_value VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
  user_roles TEXT[];
  user_level INTEGER;
  rule_record RECORD;
BEGIN
  -- Get user roles and highest level
  SELECT ARRAY_AGG(role), MAX(role_level) 
  INTO user_roles, user_level
  FROM public.user_roles 
  WHERE user_id = p_user_id AND is_active = true;
  
  -- If no roles, user can only see public tags
  IF user_roles IS NULL THEN
    SELECT * INTO rule_record
    FROM public.tag_visibility_rules
    WHERE tag_type = p_tag_type 
      AND tag_value = p_tag_value 
      AND visibility_scope = 'public';
    
    RETURN rule_record IS NOT NULL;
  END IF;
  
  -- Check visibility rules
  FOR rule_record IN 
    SELECT * FROM public.tag_visibility_rules
    WHERE tag_type = p_tag_type AND tag_value = p_tag_value
  LOOP
    -- Check hierarchy access
    IF rule_record.visibility_scope = 'hierarchy' AND user_level >= rule_record.required_level THEN
      RETURN true;
    END IF;
    
    -- Check role access
    IF rule_record.required_role = ANY(user_roles) THEN
      RETURN true;
    END IF;
    
    -- Check public access
    IF rule_record.visibility_scope = 'public' THEN
      RETURN true;
    END IF;
  END LOOP;
  
  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's visible tags
CREATE OR REPLACE FUNCTION get_user_visible_tags(p_user_id UUID)
RETURNS TABLE(tag_type VARCHAR, tag_value VARCHAR, display_name VARCHAR) AS $$
BEGIN
  RETURN QUERY
  SELECT tvr.tag_type, tvr.tag_value, 
         CASE 
           WHEN tvr.tag_type = 'role' THEN tvr.tag_value
           WHEN tvr.tag_type = 'special' THEN tvr.tag_value
           ELSE tvr.tag_value
         END as display_name
  FROM public.tag_visibility_rules tvr
  WHERE can_user_see_tag(p_user_id, tvr.tag_type, tvr.tag_value) = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Update user presence on activity
CREATE OR REPLACE FUNCTION update_user_presence()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_presence (user_id, is_online, last_seen, updated_at)
  VALUES (NEW.user_id, true, NOW(), NOW())
  ON CONFLICT (user_id) 
  DO UPDATE SET 
    is_online = true,
    last_seen = NOW(),
    updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for chat messages to update presence
-- Note: This assumes chat_messages table exists
-- CREATE TRIGGER trigger_update_presence_on_message
--   AFTER INSERT ON public.chat_messages
--   FOR EACH ROW
--   EXECUTE FUNCTION update_user_presence();

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.message_tags IS 'Stores tag associations with chat messages for the Discord-like tagging system';
COMMENT ON TABLE public.tag_visibility_rules IS 'Controls who can see what tags based on roles and hierarchy';
COMMENT ON TABLE public.user_groups IS 'Groups that users belong to for group-based tagging';
COMMENT ON TABLE public.user_presence IS 'Tracks user online status and last seen for presence-based tags';
COMMENT ON TABLE public.event_participants IS 'Tracks event participation for event-based tagging';
COMMENT ON TABLE public.user_chapters IS 'Maps users to chapters for chapter-based tagging';
COMMENT ON TABLE public.user_regions IS 'Maps users to regions for regional tagging';

COMMENT ON FUNCTION can_user_see_tag IS 'Checks if a user has permission to see a specific tag';
COMMENT ON FUNCTION get_user_visible_tags IS 'Returns all tags that a user has permission to see';
COMMENT ON FUNCTION update_user_presence IS 'Updates user presence when they perform activities';