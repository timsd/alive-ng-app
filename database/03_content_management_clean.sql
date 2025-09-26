-- ALIVE NG App - Content Management Tables
-- Clean version without inline comments to prevent syntax errors

-- Content pages for static content management
CREATE TABLE IF NOT EXISTS public.content_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  content TEXT,
  meta_description TEXT,
  content_type VARCHAR(50) DEFAULT 'page',
  language VARCHAR(10) DEFAULT 'en',
  is_published BOOLEAN DEFAULT false,
  publish_date TIMESTAMP,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Dynamic content for app configuration
CREATE TABLE IF NOT EXISTS public.dynamic_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_key VARCHAR(100) UNIQUE NOT NULL,
  content_value TEXT,
  content_type VARCHAR(50) DEFAULT 'text',
  category VARCHAR(50),
  language VARCHAR(10) DEFAULT 'en',
  is_active BOOLEAN DEFAULT true,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- App settings for configuration
CREATE TABLE IF NOT EXISTS public.app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT,
  setting_type VARCHAR(50) DEFAULT 'string',
  category VARCHAR(50),
  description TEXT,
  is_public BOOLEAN DEFAULT false,
  requires_restart BOOLEAN DEFAULT false,
  updated_by UUID REFERENCES public.users(id),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Featured content for home screen
CREATE TABLE IF NOT EXISTS public.featured_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type VARCHAR(50) NOT NULL,
  content_id UUID,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  image_url TEXT,
  action_url TEXT,
  priority INTEGER DEFAULT 0,
  target_audience VARCHAR(50) DEFAULT 'all',
  is_active BOOLEAN DEFAULT true,
  start_date TIMESTAMP DEFAULT NOW(),
  end_date TIMESTAMP,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Announcements system
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  priority VARCHAR(20) DEFAULT 'normal',
  announcement_type VARCHAR(50) DEFAULT 'general',
  target_audience VARCHAR(50) DEFAULT 'all',
  target_chapter_id UUID REFERENCES public.chapters(id),
  action_button_text VARCHAR(100),
  action_url TEXT,
  is_active BOOLEAN DEFAULT true,
  is_dismissible BOOLEAN DEFAULT true,
  start_date TIMESTAMP DEFAULT NOW(),
  end_date TIMESTAMP,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Content categories for organization
CREATE TABLE IF NOT EXISTS public.content_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  icon VARCHAR(50),
  color VARCHAR(20),
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Content tags for flexible categorization
CREATE TABLE IF NOT EXISTS public.content_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  color VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Many-to-many relationship for content and tags
CREATE TABLE IF NOT EXISTS public.content_tag_relations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type VARCHAR(50) NOT NULL,
  content_id UUID NOT NULL,
  tag_id UUID REFERENCES public.content_tags(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(content_type, content_id, tag_id)
);

-- User interactions with content
CREATE TABLE IF NOT EXISTS public.user_content_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  content_type VARCHAR(50) NOT NULL,
  content_id UUID NOT NULL,
  interaction_type VARCHAR(50) NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, content_type, content_id, interaction_type)
);

-- Content analytics for tracking
CREATE TABLE IF NOT EXISTS public.content_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type VARCHAR(50) NOT NULL,
  content_id UUID NOT NULL,
  metric_name VARCHAR(50) NOT NULL,
  metric_value INTEGER DEFAULT 0,
  date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(content_type, content_id, metric_name, date)
);

-- ============================================================================
-- TRIGGERS FOR CONTENT MANAGEMENT
-- ============================================================================

-- Triggers for updated_at columns
DROP TRIGGER IF EXISTS update_content_pages_updated_at ON public.content_pages;
CREATE TRIGGER update_content_pages_updated_at
  BEFORE UPDATE ON public.content_pages
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_dynamic_content_updated_at ON public.dynamic_content;
CREATE TRIGGER update_dynamic_content_updated_at
  BEFORE UPDATE ON public.dynamic_content
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_featured_content_updated_at ON public.featured_content;
CREATE TRIGGER update_featured_content_updated_at
  BEFORE UPDATE ON public.featured_content
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_announcements_updated_at ON public.announcements;
CREATE TRIGGER update_announcements_updated_at
  BEFORE UPDATE ON public.announcements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INDEXES FOR CONTENT MANAGEMENT
-- ============================================================================

-- Content pages indexes
CREATE INDEX IF NOT EXISTS idx_content_pages_slug ON public.content_pages(slug);
CREATE INDEX IF NOT EXISTS idx_content_pages_type ON public.content_pages(content_type);
CREATE INDEX IF NOT EXISTS idx_content_pages_published ON public.content_pages(is_published);

-- Dynamic content indexes
CREATE INDEX IF NOT EXISTS idx_dynamic_content_key ON public.dynamic_content(content_key);
CREATE INDEX IF NOT EXISTS idx_dynamic_content_category ON public.dynamic_content(category);
CREATE INDEX IF NOT EXISTS idx_dynamic_content_active ON public.dynamic_content(is_active);

-- App settings indexes
CREATE INDEX IF NOT EXISTS idx_app_settings_key ON public.app_settings(setting_key);
CREATE INDEX IF NOT EXISTS idx_app_settings_category ON public.app_settings(category);
CREATE INDEX IF NOT EXISTS idx_app_settings_public ON public.app_settings(is_public);

-- Featured content indexes
CREATE INDEX IF NOT EXISTS idx_featured_content_type ON public.featured_content(content_type);
CREATE INDEX IF NOT EXISTS idx_featured_content_active ON public.featured_content(is_active);
CREATE INDEX IF NOT EXISTS idx_featured_content_priority ON public.featured_content(priority);

-- Announcements indexes
CREATE INDEX IF NOT EXISTS idx_announcements_type ON public.announcements(announcement_type);
CREATE INDEX IF NOT EXISTS idx_announcements_active ON public.announcements(is_active);
CREATE INDEX IF NOT EXISTS idx_announcements_audience ON public.announcements(target_audience);

-- Content categories indexes
CREATE INDEX IF NOT EXISTS idx_content_categories_slug ON public.content_categories(slug);
CREATE INDEX IF NOT EXISTS idx_content_categories_active ON public.content_categories(is_active);

-- Content tags indexes
CREATE INDEX IF NOT EXISTS idx_content_tags_slug ON public.content_tags(slug);
CREATE INDEX IF NOT EXISTS idx_content_tags_active ON public.content_tags(is_active);

-- User interactions indexes
CREATE INDEX IF NOT EXISTS idx_user_interactions_user ON public.user_content_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_content ON public.user_content_interactions(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_type ON public.user_content_interactions(interaction_type);

-- Analytics indexes
CREATE INDEX IF NOT EXISTS idx_content_analytics_content ON public.content_analytics(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_content_analytics_metric ON public.content_analytics(metric_name);
CREATE INDEX IF NOT EXISTS idx_content_analytics_date ON public.content_analytics(date);

-- ============================================================================
-- SAMPLE DATA FOR CONTENT MANAGEMENT
-- ============================================================================

-- Insert sample content categories
INSERT INTO public.content_categories (name, slug, description, icon, color, sort_order)
VALUES 
  ('Health', 'health', 'Health and wellness content', 'health', '#4CAF50', 1),
  ('Study', 'study', 'Bible study and educational content', 'book', '#2196F3', 2),
  ('Prayer', 'prayer', 'Prayer requests and spiritual content', 'pray', '#9C27B0', 3),
  ('Announcements', 'announcements', 'General announcements and news', 'announcement', '#FF9800', 4)
ON CONFLICT (slug) DO NOTHING;

-- Insert sample content tags
INSERT INTO public.content_tags (name, slug, description, color)
VALUES 
  ('Featured', 'featured', 'Featured content for homepage', '#E91E63'),
  ('Beginner', 'beginner', 'Content suitable for beginners', '#4CAF50'),
  ('Advanced', 'advanced', 'Advanced level content', '#F44336'),
  ('Popular', 'popular', 'Popular and trending content', '#FF9800')
ON CONFLICT (slug) DO NOTHING;

-- Insert sample app settings
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, category, description, is_public)
VALUES 
  ('app_name', 'ALIVE NG', 'string', 'general', 'Application name', true),
  ('app_version', '1.0.0', 'string', 'general', 'Current app version', true),
  ('maintenance_mode', 'false', 'boolean', 'general', 'Enable maintenance mode', false),
  ('max_prayer_requests_per_day', '5', 'number', 'features', 'Maximum prayer requests per user per day', false)
ON CONFLICT (setting_key) DO NOTHING;

-- Insert sample dynamic content
INSERT INTO public.dynamic_content (content_key, content_value, content_type, category, description, is_active)
VALUES 
  ('welcome_message', 'Welcome to ALIVE NG! Start your spiritual journey today.', 'text', 'home', 'Welcome message for new users', true),
  ('daily_verse', 'For God so loved the world that he gave his one and only Son...', 'text', 'home', 'Daily Bible verse', true),
  ('health_tip', 'Drink at least 8 glasses of water daily for optimal health.', 'text', 'health', 'Daily health tip', true)
ON CONFLICT (content_key) DO NOTHING;

SELECT 'Content management tables created successfully!' as status;