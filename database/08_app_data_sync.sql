-- ALIVE NG App - App Data Synchronization
-- This file syncs all app constants and data from the Flutter codebase to Supabase
-- Run this after the main schema deployment to populate app-specific data

-- ============================================================================
-- CHAPTER DATA SYNCHRONIZATION
-- ============================================================================

-- Insert chapters from chapters.dart
INSERT INTO public.chapters (name, description, chapter_type, region, state, is_active, created_at) VALUES
('Ibadan', 'ALIVE Nigeria Ibadan Chapter', 'regional', 'Southwest', 'Oyo', true, NOW()),
('Ife', 'ALIVE Nigeria Ife Chapter', 'regional', 'Southwest', 'Osun', true, NOW()),
('Abuja', 'ALIVE Nigeria Abuja Chapter', 'regional', 'North Central', 'FCT', true, NOW()),
('Lagos', 'ALIVE Nigeria Lagos Chapter', 'regional', 'Southwest', 'Lagos', true, NOW()),
('Benin', 'ALIVE Nigeria Benin Chapter', 'regional', 'South South', 'Edo', true, NOW()),
('Diaspora', 'ALIVE Nigeria Diaspora Chapter', 'international', 'International', 'International', true, NOW()),
('Kaduna', 'ALIVE Nigeria Kaduna Chapter', 'regional', 'Northwest', 'Kaduna', true, NOW()),
('Port Harcourt', 'ALIVE Nigeria Port Harcourt Chapter', 'regional', 'South South', 'Rivers', true, NOW()),
('Lagos 1', 'ALIVE Nigeria Lagos 1 Chapter', 'zonal', 'Southwest', 'Lagos', true, NOW()),
('Lagos 2', 'ALIVE Nigeria Lagos 2 Chapter', 'zonal', 'Southwest', 'Lagos', true, NOW()),
('Lagos 3', 'ALIVE Nigeria Lagos 3 Chapter', 'zonal', 'Southwest', 'Lagos', true, NOW()),
('Babcock', 'ALIVE Nigeria Babcock Chapter', 'campus', 'Southwest', 'Ogun', true, NOW()),
('Abia', 'ALIVE Nigeria Abia Chapter', 'regional', 'Southeast', 'Abia', true, NOW()),
('Jos', 'ALIVE Nigeria Jos Chapter', 'regional', 'North Central', 'Plateau', true, NOW()),
('Calabar', 'ALIVE Nigeria Calabar Chapter', 'regional', 'South South', 'Cross River', true, NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  chapter_type = EXCLUDED.chapter_type,
  region = EXCLUDED.region,
  state = EXCLUDED.state,
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
-- NIGERIAN MEAL PLANS AND HEALTH DATA
-- ============================================================================

-- Insert Nigerian meal plan categories
INSERT INTO public.meal_plan_categories (name, description, region, created_at) VALUES
('Northern Nigerian', 'Traditional meals from Northern Nigeria', 'North', NOW()),
('Southern Nigerian', 'Traditional meals from Southern Nigeria', 'South', NOW()),
('Middle Belt', 'Traditional meals from Middle Belt region', 'Middle Belt', NOW()),
('Coastal', 'Seafood and coastal region meals', 'Coastal', NOW()),
('Vegetarian Nigerian', 'Plant-based Nigerian meals', 'All Regions', NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  region = EXCLUDED.region,
  updated_at = NOW();

-- ============================================================================
-- DONATION TYPES AND PAYMENT METHODS
-- ============================================================================

-- Insert donation types
INSERT INTO public.donation_types (name, description, is_recurring, created_at) VALUES
('Mission Support', 'Support for missionary activities', true, NOW()),
('Charity', 'Charitable giving for community needs', false, NOW()),
('Special Project', 'Specific ministry projects', false, NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  is_recurring = EXCLUDED.is_recurring,
  updated_at = NOW();

-- Insert payment methods
INSERT INTO public.payment_methods (name, description, is_active, created_at) VALUES
('Bank Transfer', 'Direct bank transfer', true, NOW()),
('Mobile Money', 'Mobile money transfer (MTN, Airtel, etc.)', true, NOW()),
('Card Payment', 'Credit/Debit card payment', true, NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
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
<p>Last updated: September 2025</p>

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

<h2>7. International Data Transfers</h2>
<p>Your information may be transferred to and processed in countries other than Nigeria. We ensure appropriate safeguards are in place for such transfers.</p>

<h2>8. Changes to This Policy</h2>
<p>We may update this Privacy Policy periodically. We will notify you of significant changes through the app or email.</p>

<h2>9. Donations and Financial Information</h2>
<p>When you make donations through our app:</p>
<ul>
<li>We collect necessary payment information through secure third-party processors</li>
<li>We do not store your complete payment card details</li>
<li>Donation records are maintained for tax and legal compliance</li>
<li>You may request donation history for your records</li>
</ul>

<h2>10. Third-Party Services</h2>
<p>Our app may integrate with third-party services including:</p>
<ul>
<li>Payment processors (Paystack) for donations</li>
<li>Analytics services for app improvement</li>
<li>Cloud storage for data backup and synchronization</li>
<li>Social media platforms for content sharing</li>
</ul>
<p>These services have their own privacy policies, and we encourage you to review them.</p>

<h2>11. Data Retention</h2>
<p>We retain your personal information only as long as necessary to:</p>
<ul>
<li>Provide our services to you</li>
<li>Comply with legal obligations</li>
<li>Resolve disputes and enforce agreements</li>
<li>Maintain security and prevent fraud</li>
</ul>

<h2>12. Children''s Privacy</h2>
<p>ALIVE NG is committed to protecting the privacy of children who use our services. Our platform includes content designed for children ages 3 and above to support their moral and spiritual growth.</p>

<h3>12.1 Parental Responsibility and Consent</h3>
<p>Parents or legal guardians are responsible for creating and managing accounts that may be shared with children. We require parental consent before collecting any personal information from children under 13 years of age.</p>

<h3>12.2 Account Creation for Minors</h3>   
<p>Guidelines:</p>
<ul>
<li>Parents must create accounts on behalf of children under 13</li>
<li>Children aged 13-17 may create accounts with parental supervision and consent</li>
<li>All accounts for minors require ongoing parental oversight</li>
<li>Parents can review, modify, or delete their child''s information at any time</li>
</ul>

<h3>12.3 Information Collection from Children</h3>
<p>We only collect information from children that is necessary to provide our educational and spiritual content services. This may include:</p>
<ul>
<li>Basic account information (managed by parents)</li>
<li>Progress tracking for educational content</li>
<li>Preferences for age-appropriate content delivery</li>
</ul>

<h3>12.4 Parental Rights</h3>
<p>Parents have the right to:</p>
<ul>
<li>Review their child''s personal information</li>
<li>Request deletion of their child''s information</li>
<li>Refuse further collection of their child''s information</li>
<li>Control their child''s access to community features</li>
</ul>

<p>If you are a parent and believe your child has provided personal information without your consent, please contact us immediately at alivenigeria2011@gmail.com.</p>

<h2>13. Changes to This Policy</h2>
<p>We may update this Privacy Policy periodically to reflect changes in our practices or legal requirements. We will notify you of significant changes through the app, email, or by posting a notice on our website. Your continued use of our services after such changes constitutes acceptance of the updated policy.</p>

<h2>14. Contact Us</h2>
<p>For questions about this Privacy Policy or to exercise your privacy rights, contact us at:</p>
<ul>
<li>Email: alivenigeria2011@gmail.com</li>
<li>Phone: +2347068548865</li>
<li>Organization: ALIVE Nigeria</li>
</ul>

<p><em>Your privacy is important to us. We are committed to protecting your personal information and being transparent about our data practices. Please review this Privacy Policy regularly to stay informed about how we protect your information.</em></p>', 
true, NOW()),

('terms-conditions', 'Terms & Conditions', 
'<h1>ALIVE NG Terms & Conditions</h1>
<p>Last updated: September 2025</p>

<h3>1. Acceptance of Terms</h3>
<p>By downloading, installing, or using the ALIVE Nigeria mobile application, you agree to be bound by these Terms and Conditions.</p>

<h3>2. Description of Service</h3>
<p>ALIVE NG is a Christian mobile application that provides:</p>
<ul>
<li>Daily devotionals and Bible verses</li>
<li>Prayer resources and categories</li>
<li>Christian educational content</li>
<li>Community features for believers</li>
<li>Tract downloads and sharing</li>
</ul>

<h3>3. User Accounts</h3>
<p>To access certain features, you may need to create an account. You are responsible for:</p>
<ul>
<li>Maintaining the confidentiality of your account information</li>
<li>All activities that occur under your account</li>
<li>Notifying us immediately of any unauthorized use</li>
</ul>

<h3>4. Acceptable Use</h3>
<p>You agree not to:</p>
<ul>
<li>Use the app for any unlawful purpose</li>
<li>Violate any applicable laws or regulations</li>
<li>Infringe on the rights of others</li>
<li>Upload or share inappropriate content</li>
<li>Attempt to gain unauthorized access to our systems</li>
</ul>

<h3>5. Content and Intellectual Property</h3>
<p>All content provided through the app, including but not limited to text, graphics, logos, and software, is the property of ALIVE Nigeria or its licensors and is protected by copyright and other intellectual property laws.</p>

<h3>6. Donations and Payments</h3>
<p>When making donations through our app:</p>
<ul>
<li>All donations are processed through secure third-party payment processors</li>
<li>Donations are voluntary and non-refundable unless required by law</li>
<li>You are responsible for any applicable taxes on your donations</li>
<li>Donation receipts will be provided for tax purposes where applicable</li>
</ul>

<h3>7. Privacy</h3>
<p>Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.</p>

<h3>8. Disclaimers</h3>
<p>The app is provided "as is" without warranties of any kind. We do not guarantee that the app will be error-free or uninterrupted.</p>

<h3>9. Limitation of Liability</h3>
<p>To the fullest extent permitted by law, ALIVE Nigeria shall not be liable for any indirect, incidental, special, or consequential damages.</p>

<h3>10. Termination</h3>
<p>We may terminate or suspend your access to the app at any time, with or without cause, with or without notice.</p>

<h3>11. Changes to Terms</h3>
<p>We reserve the right to modify these terms at any time. Changes will be effective immediately upon posting in the app.</p>

<h3>12. Contact Information</h3>
<p>If you have any questions about these Terms and Conditions, please contact us:</p>
<ul>
<li><strong>Email:</strong> alivenigeria2011@gmail.com</li>
<li><strong>Phone:</strong> +2347068548865</li>
<li><strong>Organization:</strong> ALIVE Nigeria</li>
</ul>

<p><em>By using ALIVE NG, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.</em></p>', 
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
('NKJV', 'New King James Version', 'English', 'Traditional English translation', true, NOW()),
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