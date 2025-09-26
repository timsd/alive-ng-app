-- ALIVE NG App - Row Level Security Policies
-- Clean version without inline comments to prevent syntax errors

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================================================

-- Core tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapter_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapter_activities ENABLE ROW LEVEL SECURITY;

-- Communication tables
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Prayer and spiritual tables
ALTER TABLE public.prayer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_prayers ENABLE ROW LEVEL SECURITY;

-- Study and education tables
ALTER TABLE public.study_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_guide_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_study_progress ENABLE ROW LEVEL SECURITY;

-- System tables
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Content management tables
ALTER TABLE public.content_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.featured_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_tag_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_content_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_analytics ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- HELPER FUNCTIONS FOR RLS POLICIES
-- ============================================================================

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = user_uuid 
    AND role = 'admin' 
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is chapter coordinator
CREATE OR REPLACE FUNCTION public.is_chapter_coordinator(user_uuid UUID DEFAULT auth.uid(), chapter_uuid UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
BEGIN
  IF chapter_uuid IS NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM public.user_roles 
      WHERE user_id = user_uuid 
      AND role = 'coordinator' 
      AND is_active = true
    );
  ELSE
    RETURN EXISTS (
      SELECT 1 FROM public.user_roles 
      WHERE user_id = user_uuid 
      AND role = 'coordinator' 
      AND chapter_id = chapter_uuid 
      AND is_active = true
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is member of a chapter
CREATE OR REPLACE FUNCTION public.is_chapter_member(user_uuid UUID DEFAULT auth.uid(), chapter_uuid UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.chapter_members 
    WHERE user_id = user_uuid 
    AND chapter_id = chapter_uuid 
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- USERS TABLE POLICIES
-- ============================================================================

-- Users can read all active users, update their own profile
CREATE POLICY "Users can view all active users" ON public.users
  FOR SELECT USING (is_active = true);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can manage all users" ON public.users
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- USER ROLES POLICIES
-- ============================================================================

-- Users can view roles, admins can manage
CREATE POLICY "Users can view roles" ON public.user_roles
  FOR SELECT USING (true);

CREATE POLICY "Users can view own roles" ON public.user_roles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage user roles" ON public.user_roles
  FOR ALL USING (public.is_admin());

CREATE POLICY "Coordinators can manage chapter roles" ON public.user_roles
  FOR ALL USING (
    public.is_chapter_coordinator(auth.uid(), chapter_id) 
    AND role != 'admin'
  );

-- ============================================================================
-- USER PROFILES POLICIES
-- ============================================================================

-- Users can view all profiles, update their own
CREATE POLICY "Users can view all profiles" ON public.user_profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all profiles" ON public.user_profiles
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- CHAPTERS POLICIES
-- ============================================================================

-- All users can view active chapters
CREATE POLICY "Users can view active chapters" ON public.chapters
  FOR SELECT USING (is_active = true);

CREATE POLICY "Coordinators can update their chapters" ON public.chapters
  FOR UPDATE USING (auth.uid() = coordinator_id);

CREATE POLICY "Admins can manage all chapters" ON public.chapters
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- CHAPTER MEMBERS POLICIES
-- ============================================================================

-- Users can view chapter members
CREATE POLICY "Users can view chapter members" ON public.chapter_members
  FOR SELECT USING (is_active = true);

CREATE POLICY "Users can join chapters" ON public.chapter_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave chapters" ON public.chapter_members
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Coordinators can manage chapter members" ON public.chapter_members
  FOR ALL USING (public.is_chapter_coordinator(auth.uid(), chapter_id));

CREATE POLICY "Admins can manage all chapter members" ON public.chapter_members
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- CHAPTER ACTIVITIES POLICIES
-- ============================================================================

-- Chapter members can view activities
CREATE POLICY "Chapter members can view activities" ON public.chapter_activities
  FOR SELECT USING (
    is_active = true 
    AND public.is_chapter_member(auth.uid(), chapter_id)
  );

CREATE POLICY "Coordinators can manage chapter activities" ON public.chapter_activities
  FOR ALL USING (public.is_chapter_coordinator(auth.uid(), chapter_id));

CREATE POLICY "Activity creators can update their activities" ON public.chapter_activities
  FOR UPDATE USING (auth.uid() = created_by);

CREATE POLICY "Admins can manage all activities" ON public.chapter_activities
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- CHANNELS POLICIES
-- ============================================================================

-- Channel members can view channels
CREATE POLICY "Channel members can view channels" ON public.channels
  FOR SELECT USING (
    is_active = true 
    AND (
      channel_type = 'public' 
      OR EXISTS (
        SELECT 1 FROM public.channel_members 
        WHERE channel_id = channels.id 
        AND user_id = auth.uid() 
        AND is_active = true
      )
    )
  );

CREATE POLICY "Users can create channels" ON public.channels
  FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Channel creators can update their channels" ON public.channels
  FOR UPDATE USING (auth.uid() = created_by);

CREATE POLICY "Admins can manage all channels" ON public.channels
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- CHANNEL MEMBERS POLICIES
-- ============================================================================

-- Channel members can view other members
CREATE POLICY "Channel members can view members" ON public.channel_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.channel_members cm 
      WHERE cm.channel_id = channel_members.channel_id 
      AND cm.user_id = auth.uid() 
      AND cm.is_active = true
    )
  );

CREATE POLICY "Users can join public channels" ON public.channel_members
  FOR INSERT WITH CHECK (
    auth.uid() = user_id 
    AND EXISTS (
      SELECT 1 FROM public.channels 
      WHERE id = channel_id 
      AND channel_type = 'public' 
      AND is_active = true
    )
  );

CREATE POLICY "Users can leave channels" ON public.channel_members
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage channel members" ON public.channel_members
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- CHAT MESSAGES POLICIES
-- ============================================================================

-- Channel members can view messages
CREATE POLICY "Channel members can view messages" ON public.chat_messages
  FOR SELECT USING (
    NOT is_deleted 
    AND EXISTS (
      SELECT 1 FROM public.channel_members 
      WHERE channel_id = chat_messages.channel_id 
      AND user_id = auth.uid() 
      AND is_active = true
    )
  );

CREATE POLICY "Channel members can send messages" ON public.chat_messages
  FOR INSERT WITH CHECK (
    auth.uid() = user_id 
    AND EXISTS (
      SELECT 1 FROM public.channel_members 
      WHERE channel_id = chat_messages.channel_id 
      AND user_id = auth.uid() 
      AND is_active = true
    )
  );

CREATE POLICY "Users can edit their own messages" ON public.chat_messages
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all messages" ON public.chat_messages
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- PRAYER REQUESTS POLICIES
-- ============================================================================

-- Users can view non-anonymous prayer requests
CREATE POLICY "Users can view prayer requests" ON public.prayer_requests
  FOR SELECT USING (NOT is_anonymous OR auth.uid() = user_id);

CREATE POLICY "Users can create prayer requests" ON public.prayer_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their prayer requests" ON public.prayer_requests
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all prayer requests" ON public.prayer_requests
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- USER PRAYERS POLICIES
-- ============================================================================

-- Users can view prayers for visible prayer requests
CREATE POLICY "Users can view prayers" ON public.user_prayers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.prayer_requests pr 
      WHERE pr.id = prayer_request_id 
      AND (NOT pr.is_anonymous OR pr.user_id = auth.uid())
    )
  );

CREATE POLICY "Users can pray for requests" ON public.user_prayers
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all prayers" ON public.user_prayers
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- STUDY MATERIALS POLICIES
-- ============================================================================

-- Users can view published materials
CREATE POLICY "Users can view published materials" ON public.study_materials
  FOR SELECT USING (is_published = true);

CREATE POLICY "Authors can manage their materials" ON public.study_materials
  FOR ALL USING (auth.uid() = author_id);

CREATE POLICY "Admins can manage all materials" ON public.study_materials
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- STUDY GUIDES POLICIES
-- ============================================================================

-- Users can view published guides
CREATE POLICY "Users can view published guides" ON public.study_guides
  FOR SELECT USING (is_published = true);

CREATE POLICY "Authors can manage their guides" ON public.study_guides
  FOR ALL USING (auth.uid() = author_id);

CREATE POLICY "Admins can manage all guides" ON public.study_guides
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- STUDY GUIDE QUESTIONS POLICIES
-- ============================================================================

-- Users can view questions for published guides
CREATE POLICY "Users can view guide questions" ON public.study_guide_questions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.study_guides 
      WHERE id = guide_id 
      AND is_published = true
    )
  );

CREATE POLICY "Guide authors can manage questions" ON public.study_guide_questions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.study_guides 
      WHERE id = guide_id 
      AND author_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all questions" ON public.study_guide_questions
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- USER STUDY PROGRESS POLICIES
-- ============================================================================

-- Users can view their own progress
CREATE POLICY "Users can view own progress" ON public.user_study_progress
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own progress" ON public.user_study_progress
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all progress" ON public.user_study_progress
  FOR SELECT USING (public.is_admin());

-- ============================================================================
-- NOTIFICATIONS POLICIES
-- ============================================================================

-- Users can view their own notifications
CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "System can create notifications" ON public.notifications
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can manage all notifications" ON public.notifications
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- NOTIFICATION SETTINGS POLICIES
-- ============================================================================

-- Users can manage their own settings
CREATE POLICY "Users can manage own settings" ON public.notification_settings
  FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- REPORTS POLICIES
-- ============================================================================

-- Users can view published reports
CREATE POLICY "Users can view published reports" ON public.reports
  FOR SELECT USING (is_published = true);

CREATE POLICY "Report creators can manage their reports" ON public.reports
  FOR ALL USING (auth.uid() = created_by);

CREATE POLICY "Chapter coordinators can view chapter reports" ON public.reports
  FOR SELECT USING (
    public.is_chapter_coordinator(auth.uid(), chapter_id)
  );

CREATE POLICY "Admins can manage all reports" ON public.reports
  FOR ALL USING (public.is_admin());

-- ============================================================================
-- CONTENT MANAGEMENT POLICIES
-- ============================================================================

-- Content Pages: Published pages are public, admins can manage all
CREATE POLICY "Users can view published pages" ON public.content_pages
  FOR SELECT USING (is_published = true);

CREATE POLICY "Page creators can manage their pages" ON public.content_pages
  FOR ALL USING (auth.uid() = created_by);

CREATE POLICY "Admins can manage all pages" ON public.content_pages
  FOR ALL USING (public.is_admin());

-- Dynamic Content: Active content is public, admins can manage
CREATE POLICY "Users can view active content" ON public.dynamic_content
  FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage dynamic content" ON public.dynamic_content
  FOR ALL USING (public.is_admin());

-- App Settings: Public settings are readable by all, admins can manage
CREATE POLICY "Users can view public settings" ON public.app_settings
  FOR SELECT USING (is_public = true);

CREATE POLICY "Admins can manage app settings" ON public.app_settings
  FOR ALL USING (public.is_admin());

-- Featured Content: Active content is public, admins can manage
CREATE POLICY "Users can view active featured content" ON public.featured_content
  FOR SELECT USING (
    is_active = true 
    AND (start_date IS NULL OR start_date <= NOW()) 
    AND (end_date IS NULL OR end_date >= NOW())
  );

CREATE POLICY "Content creators can manage their featured content" ON public.featured_content
  FOR ALL USING (auth.uid() = created_by);

CREATE POLICY "Admins can manage all featured content" ON public.featured_content
  FOR ALL USING (public.is_admin());

-- Announcements: Active announcements are public, admins can manage
CREATE POLICY "Users can view active announcements" ON public.announcements
  FOR SELECT USING (
    is_active = true 
    AND (start_date IS NULL OR start_date <= NOW()) 
    AND (end_date IS NULL OR end_date >= NOW())
    AND (
      target_audience = 'all' 
      OR (target_audience = 'members' AND auth.uid() IS NOT NULL)
      OR (target_chapter_id IS NOT NULL AND public.is_chapter_member(auth.uid(), target_chapter_id))
    )
  );

CREATE POLICY "Announcement creators can manage their announcements" ON public.announcements
  FOR ALL USING (auth.uid() = created_by);

CREATE POLICY "Admins can manage all announcements" ON public.announcements
  FOR ALL USING (public.is_admin());

-- Content Categories: Public read access
CREATE POLICY "Users can view active categories" ON public.content_categories
  FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage categories" ON public.content_categories
  FOR ALL USING (public.is_admin());

-- Content Tags: Public read access
CREATE POLICY "Users can view active tags" ON public.content_tags
  FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage tags" ON public.content_tags
  FOR ALL USING (public.is_admin());

-- Content Tag Relations: Public read access
CREATE POLICY "Users can view tag relations" ON public.content_tag_relations
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage tag relations" ON public.content_tag_relations
  FOR ALL USING (public.is_admin());

-- User Content Interactions: Users can manage their own interactions
CREATE POLICY "Users can view own interactions" ON public.user_content_interactions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own interactions" ON public.user_content_interactions
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all interactions" ON public.user_content_interactions
  FOR SELECT USING (public.is_admin());

-- Content Analytics: Admins only
CREATE POLICY "Admins can manage analytics" ON public.content_analytics
  FOR ALL USING (public.is_admin());

SELECT 'Row Level Security policies created successfully!' as status;