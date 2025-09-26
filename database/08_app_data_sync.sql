-- ALIVE NG App - App Data Synchronization
-- This file syncs all app constants and data from the Flutter codebase to Supabase
-- Run this after the main schema deployment to populate app-specific data

-- ============================================================================
-- CHAPTER DATA SYNCHRONIZATION
-- ============================================================================

-- Insert chapters from chapters.dart
INSERT INTO public.chapters (name, description, location, is_active, created_at) VALUES
('Ibadan', 'ALIVE Nigeria Ibadan Chapter', 'Ibadan, Oyo State', true, NOW()),
('Ife', 'ALIVE Nigeria Ife Chapter', 'Ile-Ife, Osun State', true, NOW()),
('Abuja', 'ALIVE Nigeria Abuja Chapter', 'Abuja, FCT', true, NOW()),
('Lagos', 'ALIVE Nigeria Lagos Chapter', 'Lagos State', true, NOW()),
('Benin', 'ALIVE Nigeria Benin Chapter', 'Benin City, Edo State', true, NOW()),
('Diaspora', 'ALIVE Nigeria Diaspora Chapter', 'International', true, NOW()),
('Kaduna', 'ALIVE Nigeria Kaduna Chapter', 'Kaduna State', true, NOW()),
('Port Harcourt', 'ALIVE Nigeria Port Harcourt Chapter', 'Port Harcourt, Rivers State', true, NOW()),
('Lagos 1', 'ALIVE Nigeria Lagos 1 Chapter', 'Lagos State - Zone 1', true, NOW()),
('Lagos 2', 'ALIVE Nigeria Lagos 2 Chapter', 'Lagos State - Zone 2', true, NOW()),
('Lagos 3', 'ALIVE Nigeria Lagos 3 Chapter', 'Lagos State - Zone 3', true, NOW()),
('Babcock', 'ALIVE Nigeria Babcock Chapter', 'Babcock University, Ogun State', true, NOW()),
('Abia', 'ALIVE Nigeria Abia Chapter', 'Abia State', true, NOW()),
('Jos', 'ALIVE Nigeria Jos Chapter', 'Jos, Plateau State', true, NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  location = EXCLUDED.location,
  updated_at = NOW();

-- ============================================================================
-- TEAM TYPES DATA
-- ============================================================================

-- Insert team types
INSERT INTO public.team_types (name, description, created_at) VALUES
('Field Workers', 'Community outreach and evangelism team', NOW()),
('Campus Missionary Team', 'University and college campus ministry team', NOW()),
('AMTC Team', 'ALIVE Missionary Training Center team', NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = NOW();

-- ============================================================================
-- BIBLE VERSES AND MEMORY VERSES
-- ============================================================================

-- Insert daily verses (sample data - extend as needed)
INSERT INTO public.daily_verses (verse_text, reference, date, created_at) VALUES
('For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.', 'John 3:16', CURRENT_DATE, NOW()),
('Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.', 'Proverbs 3:5-6', CURRENT_DATE + INTERVAL '1 day', NOW()),
('I can do all this through him who gives me strength.', 'Philippians 4:13', CURRENT_DATE + INTERVAL '2 days', NOW()),
('And we know that in all things God works for the good of those who love him, who have been called according to his purpose.', 'Romans 8:28', CURRENT_DATE + INTERVAL '3 days', NOW()),
('Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.', 'Joshua 1:9', CURRENT_DATE + INTERVAL '4 days', NOW())
ON CONFLICT (reference, date) DO NOTHING;

-- ============================================================================
-- STUDY PROGRAMS AND MATERIALS
-- ============================================================================

-- Insert study programs
INSERT INTO public.study_programs (title, description, duration_weeks, difficulty_level, is_active, created_at) VALUES
('New Believer Foundation', 'Essential teachings for new Christians', 8, 'beginner', true, NOW()),
('Discipleship Training', 'Comprehensive discipleship program', 12, 'intermediate', true, NOW()),
('Leadership Development', 'Training for ministry leaders', 16, 'advanced', true, NOW()),
('Evangelism Mastery', 'Effective evangelism techniques and strategies', 10, 'intermediate', true, NOW()),
('Bible Study Methods', 'Learn various approaches to studying Scripture', 6, 'beginner', true, NOW())
ON CONFLICT (title) DO UPDATE SET
  description = EXCLUDED.description,
  duration_weeks = EXCLUDED.duration_weeks,
  difficulty_level = EXCLUDED.difficulty_level,
  updated_at = NOW();

-- ============================================================================
-- PRAYER CATEGORIES
-- ============================================================================

-- Insert prayer request categories
INSERT INTO public.prayer_categories (name, description, icon, color, created_at) VALUES
('Personal', 'Personal prayer requests', 'person', '#4CAF50', NOW()),
('Family', 'Family-related prayer needs', 'family', '#2196F3', NOW()),
('Health', 'Health and healing prayers', 'health', '#FF9800', NOW()),
('Ministry', 'Ministry and evangelism prayers', 'church', '#9C27B0', NOW()),
('Financial', 'Financial provision and wisdom', 'money', '#795548', NOW()),
('Guidance', 'Direction and decision-making', 'compass', '#607D8B', NOW()),
('Thanksgiving', 'Praise and thanksgiving', 'celebration', '#FFC107', NOW()),
('Emergency', 'Urgent prayer requests', 'emergency', '#F44336', NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  color = EXCLUDED.color,
  updated_at = NOW();

-- ============================================================================
-- APP SETTINGS AND CONFIGURATION
-- ============================================================================

-- Insert app settings
INSERT INTO public.app_settings (key, value, description, category, created_at) VALUES
('app_name', 'ALIVE NG', 'Application name', 'general', NOW()),
('app_version', '1.0.0', 'Current app version', 'general', NOW()),
('maintenance_mode', 'false', 'Enable/disable maintenance mode', 'general', NOW()),
('max_prayer_requests_per_user', '10', 'Maximum prayer requests per user per day', 'prayer', NOW()),
('enable_push_notifications', 'true', 'Enable push notifications', 'notifications', NOW()),
('default_theme', 'light', 'Default app theme', 'ui', NOW()),
('supported_languages', '["en", "yo", "ig", "ha"]', 'Supported app languages', 'localization', NOW()),
('bible_default_version', 'KJV', 'Default Bible version', 'bible', NOW()),
('enable_offline_mode', 'true', 'Enable offline functionality', 'general', NOW()),
('max_file_upload_size', '10485760', 'Maximum file upload size in bytes (10MB)', 'uploads', NOW())
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = NOW();

-- ============================================================================
-- CONTENT PAGES
-- ============================================================================

-- Insert static content pages
INSERT INTO public.content_pages (slug, title, content, is_published, created_at) VALUES
('about-alive', 'About ALIVE Nigeria', 
'<h1>About ALIVE Nigeria</h1>
<p>ALIVE Nigeria is a Christian organization dedicated to spreading the Gospel and making disciples across Nigeria and beyond.</p>
<h2>Our Mission</h2>
<p>To reach every soul with the Gospel of Jesus Christ and train them to become effective disciples.</p>
<h2>Our Vision</h2>
<p>A Nigeria where every person has heard the Gospel and has the opportunity to accept Jesus Christ as their personal Savior.</p>', 
true, NOW()),

('privacy-policy', 'Privacy Policy', 
'<h1>Privacy Policy for ALIVE Nigeria App</h1>
<p>Last updated: ' || TO_CHAR(NOW(), 'Month DD, YYYY') || '</p>

<h2>1. Introduction</h2>
<p>ALIVE Nigeria ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services.</p>

<h2>2. Information We Collect</h2>
<h3>2.1 Personal Information</h3>
<ul>
<li>Name, email address, phone number</li>
<li>Profile information and preferences</li>
<li>Chapter membership and ministry involvement</li>
<li>Prayer requests and testimonies</li>
</ul>

<h3>2.2 Usage Information</h3>
<ul>
<li>App usage statistics and analytics</li>
<li>Device information and identifiers</li>
<li>Location data (with your consent)</li>
<li>Study progress and completion data</li>
</ul>

<h2>3. How We Use Your Information</h2>
<ul>
<li>Provide and maintain our services</li>
<li>Personalize your spiritual journey</li>
<li>Send prayer updates and notifications</li>
<li>Facilitate chapter activities and connections</li>
<li>Improve our app and services</li>
<li>Ensure security and prevent fraud</li>
</ul>

<h2>4. Information Sharing and Disclosure</h2>
<p>We do not sell your personal information. We may share information in these circumstances:</p>
<ul>
<li>With your consent</li>
<li>With chapter leaders for ministry purposes</li>
<li>To comply with legal obligations</li>
<li>To protect our rights and safety</li>
<li>With service providers under strict confidentiality</li>
</ul>

<h2>5. Data Security</h2>
<p>We implement appropriate security measures to protect your information, including encryption, secure servers, and access controls. However, no method of transmission over the internet is 100% secure.</p>

<h2>6. Your Rights and Choices</h2>
<ul>
<li>Access and update your personal information</li>
<li>Delete your account and associated data</li>
<li>Opt-out of non-essential communications</li>
<li>Control location sharing and notifications</li>
</ul>

<h2>7. Children''s Privacy</h2>
<p>Our app is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected such information, please contact us immediately.</p>

<h2>8. International Data Transfers</h2>
<p>Your information may be transferred to and processed in countries other than Nigeria. We ensure appropriate safeguards are in place for such transfers.</p>

<h2>9. Changes to This Policy</h2>
<p>We may update this Privacy Policy periodically. We will notify you of significant changes through the app or email.</p>

<h2>10. Contact Us</h2>
<p>For questions about this Privacy Policy, contact us at:</p>
<ul>
<li>Email: privacy@alivenigeria.org</li>
<li>Phone: +234-XXX-XXX-XXXX</li>
<li>Address: ALIVE Nigeria Headquarters, Nigeria</li>
</ul>', 
true, NOW()),

('terms-conditions', 'Terms and Conditions', 
'<h1>Terms and Conditions for ALIVE Nigeria App</h1>
<p>Last updated: ' || TO_CHAR(NOW(), 'Month DD, YYYY') || '</p>

<h2>1. Acceptance of Terms</h2>
<p>By downloading, accessing, or using the ALIVE Nigeria mobile application, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use our app.</p>

<h2>2. Description of Service</h2>
<p>The ALIVE Nigeria app provides:</p>
<ul>
<li>Spiritual growth and discipleship resources</li>
<li>Bible study materials and daily verses</li>
<li>Prayer request and testimony sharing</li>
<li>Chapter activities and community features</li>
<li>Health and wellness tracking with biblical principles</li>
<li>Donation and giving platforms</li>
</ul>

<h2>3. User Accounts and Responsibilities</h2>
<h3>3.1 Account Creation</h3>
<ul>
<li>You must provide accurate and complete information</li>
<li>You are responsible for maintaining account security</li>
<li>You must be at least 13 years old to create an account</li>
</ul>

<h3>3.2 User Conduct</h3>
<p>You agree not to:</p>
<ul>
<li>Use the app for any unlawful purpose</li>
<li>Share inappropriate or offensive content</li>
<li>Harass or harm other users</li>
<li>Attempt to gain unauthorized access to our systems</li>
<li>Distribute spam or malicious content</li>
</ul>

<h2>4. Content and Intellectual Property</h2>
<h3>4.1 Our Content</h3>
<p>All content provided by ALIVE Nigeria, including text, graphics, logos, and software, is our property and protected by copyright and other intellectual property laws.</p>

<h3>4.2 User-Generated Content</h3>
<p>By submitting content (prayer requests, testimonies, etc.), you grant us a non-exclusive license to use, modify, and display such content for service provision purposes.</p>

<h2>5. Privacy and Data Protection</h2>
<p>Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.</p>

<h2>6. Donations and Financial Transactions</h2>
<ul>
<li>All donations are voluntary and non-refundable</li>
<li>We use secure payment processors (Paystack)</li>
<li>You are responsible for any applicable taxes</li>
<li>Donation receipts will be provided for tax purposes</li>
</ul>

<h2>7. Disclaimers and Limitations</h2>
<h3>7.1 Service Availability</h3>
<p>We strive to maintain service availability but do not guarantee uninterrupted access. We may suspend service for maintenance or other reasons.</p>

<h3>7.2 Content Accuracy</h3>
<p>While we strive for accuracy, we do not warrant that all content is error-free or complete. Users should verify important information independently.</p>

<h3>7.3 Health Information</h3>
<p>Health and wellness features are for informational purposes only and do not constitute medical advice. Consult healthcare professionals for medical concerns.</p>

<h2>8. Limitation of Liability</h2>
<p>To the maximum extent permitted by law, ALIVE Nigeria shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the app.</p>

<h2>9. Indemnification</h2>
<p>You agree to indemnify and hold harmless ALIVE Nigeria from any claims, damages, or expenses arising from your use of the app or violation of these terms.</p>

<h2>10. Termination</h2>
<p>We may terminate or suspend your account at any time for violation of these terms. You may also delete your account at any time through the app settings.</p>

<h2>11. Governing Law</h2>
<p>These terms are governed by the laws of the Federal Republic of Nigeria. Any disputes will be resolved in Nigerian courts.</p>

<h2>12. Changes to Terms</h2>
<p>We may modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.</p>

<h2>13. Contact Information</h2>
<p>For questions about these Terms and Conditions, contact us at:</p>
<ul>
<li>Email: legal@alivenigeria.org</li>
<li>Phone: +234-XXX-XXX-XXXX</li>
<li>Address: ALIVE Nigeria Headquarters, Nigeria</li>
</ul>

<h2>14. Severability</h2>
<p>If any provision of these terms is found to be unenforceable, the remaining provisions will continue in full force and effect.</p>', 
true, NOW())

ON CONFLICT (slug) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();

-- ============================================================================
-- BIBLE VERSIONS
-- ============================================================================

-- Insert Bible versions
INSERT INTO public.bible_versions (abbreviation, name, language, description, is_active, created_at) VALUES
('NIV', 'New International Version', 'English', 'A contemporary English translation', true, NOW()),
('KJV', 'King James Version', 'English', 'Traditional English translation', true, NOW()),
('ESV', 'English Standard Version', 'English', 'Literal English translation', true, NOW()),
('NLT', 'New Living Translation', 'English', 'Easy-to-read English translation', true, NOW()),
('YOR', 'Yoruba Bible', 'Yoruba', 'Bible in Yoruba language', true, NOW()),
('IGB', 'Igbo Bible', 'Igbo', 'Bible in Igbo language', true, NOW()),
('HAU', 'Hausa Bible', 'Hausa', 'Bible in Hausa language', true, NOW())
ON CONFLICT (abbreviation) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  updated_at = NOW();

-- ============================================================================
-- NOTIFICATION TEMPLATES
-- ============================================================================

-- Insert notification templates
INSERT INTO public.notification_templates (name, title, body, type, is_active, created_at) VALUES
('welcome_user', 'Welcome to ALIVE NG!', 'Thank you for joining our community. Start your spiritual journey today!', 'welcome', true, NOW()),
('prayer_request_created', 'Prayer Request Submitted', 'Your prayer request has been submitted and will be prayed for by our community.', 'prayer', true, NOW()),
('study_reminder', 'Study Reminder', 'Don''t forget to continue your study program today!', 'study', true, NOW()),
('daily_verse', 'Daily Verse', 'Here''s your daily verse for spiritual encouragement.', 'verse', true, NOW()),
('chapter_activity', 'Chapter Activity', 'New activity in your chapter. Check it out!', 'chapter', true, NOW())
ON CONFLICT (name) DO UPDATE SET
  title = EXCLUDED.title,
  body = EXCLUDED.body,
  updated_at = NOW();

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

SELECT 'App data synchronization completed successfully!' as status,
       'Chapters, study programs, prayer categories, app settings, and other app data have been synced.' as details;