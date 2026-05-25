export const appwriteProject = {
  endpoint:
    process.env.APPWRITE_ENDPOINT ||
    'http://appwrite-he4p5j9b9dj42v5nzeklu2u3.84.8.219.248.sslip.io/v1',
  projectId: process.env.APPWRITE_PROJECT_ID || '6a088e5f0003764bde50',
  databaseId: process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32',
};

const appwrite17MaxFileSize = 30000000;

export const buckets = [
  {
    id: '6a08f51f002d2baf5e78',
    name: 'Chat Files',
    maximumFileSize: 25 * 1024 * 1024,
    allowedFileExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'mp3', 'mp4'],
  },
  {
    id: 'profile_files',
    name: 'Profile Files',
    maximumFileSize: 10 * 1024 * 1024,
    allowedFileExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
  },
  {
    id: 'board_documents',
    name: 'Board Documents',
    maximumFileSize: appwrite17MaxFileSize,
    allowedFileExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
  },
  {
    id: 'tract_files',
    name: 'Tracts and Books',
    maximumFileSize: appwrite17MaxFileSize,
    allowedFileExtensions: ['pdf', 'epub', 'jpg', 'jpeg', 'png', 'webp'],
  },
  {
    id: 'podcast_media',
    name: 'Podcasts and Audio',
    maximumFileSize: appwrite17MaxFileSize,
    allowedFileExtensions: ['mp3', 'm4a', 'wav', 'aac', 'jpg', 'jpeg', 'png', 'webp'],
  },
  {
    id: 'content_media',
    name: 'Content Media',
    maximumFileSize: appwrite17MaxFileSize,
    allowedFileExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'mp3', 'mp4'],
  },
  {
    id: 'meeting_files',
    name: 'Meeting Files',
    maximumFileSize: appwrite17MaxFileSize,
    allowedFileExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png'],
  },
  {
    id: 'system_exports',
    name: 'System Exports and Backups',
    maximumFileSize: appwrite17MaxFileSize,
    allowedFileExtensions: ['json', 'csv', 'zip', 'txt'],
  },
];

export const teams = [
  { id: '6a098ba2001455c27fdb', name: 'Administrators' },
  { id: 'bod', name: 'Board of Directors' },
  { id: 'trustees', name: 'Trustees' },
  { id: 'directors', name: 'Directors' },
  { id: 'chapter_leaders', name: 'Chapter Leaders' },
  { id: 'content_editors', name: 'Content Editors' },
  { id: 'moderators', name: 'Moderators' },
];

export const topics = [
  { id: 'all_users', name: 'All Users' },
  { id: 'admins', name: 'Admins' },
  { id: 'bod', name: 'Board of Directors' },
  { id: 'directors', name: 'Directors' },
  { id: 'chapter_leaders', name: 'Chapter Leaders' },
  { id: 'approvals', name: 'Approvals' },
  { id: 'prayer', name: 'Prayer' },
  { id: 'chat', name: 'Chat' },
  { id: 'donations', name: 'Donations' },
  { id: 'events', name: 'Events' },
  { id: 'study', name: 'Study Guides' },
  { id: 'kids', name: 'Kids Ministry' },
  { id: 'health', name: 'Health' },
  { id: 'content', name: 'Content Updates' },
];

const s = (key, size = 255, required = false, array = false) => ({ type: 'varchar', key, size, required, array });
const text = (key, required = false) => ({ type: 'text', key, required });
const mediumtext = (key, required = false) => ({ type: 'mediumtext', key, required });
const i = (key, required = false) => ({ type: 'integer', key, required });
const f = (key, required = false) => ({ type: 'float', key, required });
const b = (key, required = false, defaultValue = undefined) => ({ type: 'boolean', key, required, default: defaultValue });
const dt = (key, required = false) => ({ type: 'datetime', key, required });

export const tables = [
  {
    id: '6a08943100226f5b4963',
    name: 'Users',
    columns: [
      s('email', 320, true), s('fullName'), s('full_name'), s('avatar_url', 1024), s('photo_url', 1024), b('is_email_verified'), b('is_anonymous'),
      s('provider', 64), dt('date_of_birth'), s('phone_number', 64), text('address'), text('bio'), s('chapter_id', 128), s('role', 64, true),
      b('is_archived', false, false), b('is_new_convert', false, false), dt('convert_date'), b('is_approved', false, false), s('approved_by', 128),
      dt('approved_at'), s('approval_status', 64), text('rejection_reason'), s('location'), s('local_church'), s('occupation'), text('skills'),
      s('work_contact'), s('home_contact'), text('general_info'), s('local_chapter'), s('conference'), b('is_chapter_verified', false, false),
      b('is_church_verified', false, false), b('is_conference_verified', false, false), s('commitment_type', 64), f('financial_commitment'),
      text('availability_commitment'), mediumtext('commitment_details'), i('total_reading_time'), i('chapters_read'), i('verses_read'),
      i('prayers_offered'), i('study_sessions_completed'), i('session_count'), i('total_study_time'), i('total_app_time'),
      s('last_chapter_read'), s('last_verse_read'), s('last_prayer_type'), s('last_study_session_type'), dt('last_reading_date'),
      dt('last_prayer_date'), dt('last_study_date'), dt('last_session_start'), dt('last_activity'), dt('stats_start_date'),
      b('is_online'), dt('last_seen'), dt('created_at'), dt('updated_at'),
    ],
    indexes: [{ key: 'users_email_idx', type: 'key', columns: ['email'] }, { key: 'users_role_idx', type: 'key', columns: ['role'] }, { key: 'users_approval_idx', type: 'key', columns: ['approval_status'] }],
  },
  {
    id: '6a08f1c70032affbc00d',
    name: 'Chat Channels',
    columns: [s('name', 255, true), text('description'), s('type', 64, true), s('created_by', 128), dt('created_at'), dt('updated_at'), b('is_archived', false, false), s('members', 128, false, true), s('admins', 128, false, true), text('last_message'), dt('last_message_at'), s('last_message_sender_id', 128), mediumtext('settings')],
    indexes: [{ key: 'chat_channels_type_idx', type: 'key', columns: ['type'] }, { key: 'chat_channels_last_message_idx', type: 'key', columns: ['last_message_at'], orders: ['DESC'] }],
  },
  {
    id: '6a08e25e0034f79fcd2f',
    name: 'Chat Messages',
    columns: [s('channel_id', 128, true), s('roomId', 128), s('sender_id', 128, true), s('senderId', 128), s('sender_name'), s('sender_avatar', 1024), mediumtext('content', true), mediumtext('messageText'), i('timestamp', true), s('type', 64, true), s('tagged_users', 128, false, true), s('tagged_groups', 128, false, true), s('reply_to_id', 128), s('attachments', 2048, false, true), b('is_edited', false, false), dt('edited_at')],
    indexes: [{ key: 'chat_messages_channel_time_idx', type: 'key', columns: ['channel_id', 'timestamp'] }, { key: 'chat_messages_sender_idx', type: 'key', columns: ['sender_id'] }],
  },
  {
    id: '6a08f391001a5c02aaa9',
    name: 'Message Tags',
    columns: [s('message_id', 128, true), s('type', 64, true), s('value', 255, true), s('display_name'), s('user_id', 128), s('role_id', 128), dt('created_at')],
    indexes: [{ key: 'message_tags_message_idx', type: 'key', columns: ['message_id'] }, { key: 'message_tags_value_idx', type: 'key', columns: ['value'] }],
  },
  {
    id: 'approval_tokens',
    name: 'Approval Tokens',
    columns: [s('token', 128, true), s('userId', 128, true), s('user_id', 128), s('email', 320), dt('expiresAt'), dt('expires_at'), b('used', false, false), dt('usedAt'), dt('createdAt'), dt('created_at')],
    indexes: [{ key: 'approval_tokens_user_idx', type: 'key', columns: ['userId'] }, { key: 'approval_tokens_expiry_idx', type: 'key', columns: ['expiresAt'] }],
  },
  {
    id: 'donation_records',
    name: 'Donation Records',
    columns: [
      s('user_id', 128), s('userId', 128), s('user_name'), s('user_email', 320), s('email', 320), s('full_name'),
      s('type', 64), i('amount_kobo', true), f('amount'), s('currency', 16), s('reference', 128, true),
      s('payment_method', 64), s('payment_intent_id', 255), s('transaction_id', 128), s('status', 64, true),
      s('processor', 64), s('material_id', 128), s('material_title'), text('notes'), mediumtext('metadata'),
      dt('created_at'), dt('updated_at'), dt('completed_at'),
    ],
    indexes: [{ key: 'donations_reference_idx', type: 'unique', columns: ['reference'] }, { key: 'donations_status_idx', type: 'key', columns: ['status'] }],
  },
  {
    id: 'projects',
    name: 'Donation Projects',
    columns: [
      s('title', 255, true), s('summary', 512), mediumtext('description'), s('category', 128), s('type', 128),
      s('status', 64), f('goal'), f('target_amount'), f('raised'), f('amount_raised'), s('currency', 16),
      s('image_url', 1024), s('cta_label', 128), i('priority'), b('is_active', false, true), dt('created_at'), dt('updated_at'),
    ],
    indexes: [{ key: 'projects_priority_idx', type: 'key', columns: ['priority'] }],
  },
  {
    id: 'downloadable_materials',
    name: 'Downloadable Materials',
    columns: [
      s('title', 255, true), mediumtext('description'), s('category', 128), s('file_url', 2048, true),
      s('thumbnail_url', 2048), i('file_size_bytes'), s('file_type', 64), f('minimum_donation'),
      b('requires_donation', false, true), b('is_active', false, true), i('download_count'),
      mediumtext('metadata'), dt('created_at'), dt('updated_at'), s('created_by', 128),
    ],
    indexes: [{ key: 'materials_active_idx', type: 'key', columns: ['is_active'] }],
  },
  {
    id: 'material_downloads',
    name: 'Material Downloads',
    columns: [
      s('user_id', 128, true), s('material_id', 128, true), s('material_title'), s('donation_id', 128),
      f('donation_amount'), dt('downloaded_at'), s('download_url', 2048), dt('url_expires_at'),
    ],
    indexes: [{ key: 'material_downloads_user_idx', type: 'key', columns: ['user_id'] }],
  },
  {
    id: 'payment_logs',
    name: 'Payment Logs',
    columns: [
      s('provider', 64, true), s('reference', 128), s('event', 128), s('status', 64),
      s('donation_id', 128), mediumtext('payload'), dt('created_at'),
    ],
    indexes: [{ key: 'payment_logs_reference_idx', type: 'key', columns: ['reference'] }],
  },
  {
    id: 'gift_submissions',
    name: 'Gift Submissions',
    columns: [
      s('gift_type', 128, true), s('user_id', 128), s('full_name'), s('email', 320, true), s('phone', 64, true),
      s('item_type', 128), s('quantity', 128), s('estimated_value', 128), s('delivery_preference', 128),
      s('location'), s('skills_or_service'), s('availability'), mediumtext('description'),
      s('status', 64), dt('created_at'), dt('updated_at'),
    ],
    indexes: [{ key: 'gift_submissions_status_idx', type: 'key', columns: ['status'] }],
  },
  {
    id: 'prayer_requests',
    name: 'Prayer Requests',
    columns: [s('user_id', 128), s('userId', 128), s('requested_by'), s('requestedById', 128), s('title', 255, true), mediumtext('description', true), s('category', 128), s('status', 64), b('is_anonymous', false, false), b('is_answered', false, false), i('prayer_count'), text('answer'), dt('answered_at'), dt('created_at'), dt('updated_at')],
    indexes: [{ key: 'prayer_status_idx', type: 'key', columns: ['status'] }, { key: 'prayer_user_idx', type: 'key', columns: ['user_id'] }],
  },
  { id: 'prayer_interactions', name: 'Prayer Interactions', columns: [s('request_id', 128, true), s('user_id', 128, true), s('type', 64, true), dt('created_at')], indexes: [{ key: 'prayer_interactions_request_idx', type: 'key', columns: ['request_id'] }, { key: 'prayer_interactions_user_idx', type: 'key', columns: ['user_id'] }] },
  { id: 'prayer_strengthening_feed', name: 'Prayer Strengthening Feed', columns: [s('source_id', 128), s('testimony_id', 128), s('user_id', 128), s('title'), s('author_name'), mediumtext('content'), s('source', 64), b('is_anonymous', false, false), b('is_approved'), b('is_visible', false, false), dt('created_at'), dt('updated_at')] },
  { id: 'testimonies', name: 'Testimonies', columns: [s('user_id', 128), s('userId', 128), s('user_name'), s('user_avatar_url', 1024), mediumtext('content', true), b('is_anonymous', false, false), b('is_approved', false, false), b('is_shared_publicly', false, true), i('likes_count'), dt('created_at'), dt('updated_at')], indexes: [{ key: 'testimonies_approved_idx', type: 'key', columns: ['is_approved'] }] },
  { id: 'chapters', name: 'Chapters', columns: [s('name', 255, true), s('location'), s('location_city'), mediumtext('description'), s('type', 64), s('coordinator_id', 128), s('director_id', 128), s('member_ids', 128, false, true), mediumtext('settings'), b('is_active', false, true), dt('created_at'), dt('updated_at')], indexes: [{ key: 'chapters_name_idx', type: 'key', columns: ['name'] }, { key: 'chapters_type_idx', type: 'key', columns: ['type'] }, { key: 'chapters_active_idx', type: 'key', columns: ['is_active'] }] },
  { id: 'chapter_members', name: 'Chapter Members', columns: [s('user_id', 128, true), s('chapter_id', 128, true), s('role', 64), dt('joined_at'), dt('left_at'), b('is_active', false, true), mediumtext('permissions'), mediumtext('metadata'), dt('updated_at')], indexes: [{ key: 'chapter_members_user_idx', type: 'key', columns: ['user_id'] }, { key: 'chapter_members_chapter_idx', type: 'key', columns: ['chapter_id'] }, { key: 'chapter_members_active_idx', type: 'key', columns: ['is_active'] }, { key: 'chapter_members_joined_idx', type: 'key', columns: ['joined_at'], orders: ['DESC'] }] },
  {
    id: 'chapter_activities',
    name: 'Chapter Activities',
    columns: [
      s('chapter_id', 128, true), s('title', 255, true), mediumtext('description'), s('type', 64), s('status', 64),
      dt('scheduled_at'), dt('started_at'), dt('completed_at'), s('location', 512), s('assigned_member_ids', 128, false, true),
      mediumtext('resources'), mediumtext('results'), s('created_by', 128), dt('created_at'), dt('updated_at'),
    ],
    indexes: [
      { key: 'chapter_activities_chapter_idx', type: 'key', columns: ['chapter_id'] },
      { key: 'chapter_activities_status_idx', type: 'key', columns: ['status'] },
      { key: 'chapter_activities_type_idx', type: 'key', columns: ['type'] },
      { key: 'chapter_activities_scheduled_idx', type: 'key', columns: ['scheduled_at'], orders: ['DESC'] },
    ],
  },
  {
    id: 'chapter_tasks',
    name: 'Chapter Tasks',
    columns: [
      s('chapter_id', 128, true), s('title', 255, true), mediumtext('description'), s('assigned_to', 128), s('assigned_by', 128),
      dt('due_date'), s('status', 64), i('priority'), s('tags', 128, false, true), mediumtext('metadata'), dt('completed_at'),
      dt('created_at'), dt('updated_at'),
    ],
    indexes: [
      { key: 'chapter_tasks_chapter_idx', type: 'key', columns: ['chapter_id'] },
      { key: 'chapter_tasks_assigned_idx', type: 'key', columns: ['assigned_to'] },
      { key: 'chapter_tasks_status_idx', type: 'key', columns: ['status'] },
      { key: 'chapter_tasks_due_idx', type: 'key', columns: ['due_date'] },
    ],
  },
  {
    id: 'chapter_reports',
    name: 'Chapter Reports',
    columns: [
      s('chapter_id', 128, true), s('title', 255, true), mediumtext('content'), s('status', 64), dt('report_period_start'),
      dt('report_period_end'), s('activity_ids', 128, false, true), mediumtext('statistics'), mediumtext('attachments'),
      s('submitted_by', 128), dt('submitted_at'), s('reviewed_by', 128), dt('reviewed_at'), text('review_comments'),
      dt('created_at'), dt('updated_at'),
    ],
    indexes: [
      { key: 'chapter_reports_chapter_idx', type: 'key', columns: ['chapter_id'] },
      { key: 'chapter_reports_status_idx', type: 'key', columns: ['status'] },
      { key: 'chapter_reports_created_idx', type: 'key', columns: ['created_at'], orders: ['DESC'] },
    ],
  },
  { id: 'events', name: 'Events', columns: [s('title', 255, true), mediumtext('description'), dt('scheduled_time'), i('event_timestamp'), s('location'), s('chapter_id', 128), s('status', 64), s('image_url', 1024), dt('created_at'), dt('updated_at')] },
  { id: 'user_events', name: 'User Events', columns: [s('user_id', 128, true), s('event_id', 128, true), s('status', 64), dt('created_at'), dt('updated_at')] },
  { id: 'announcements', name: 'Announcements', columns: [s('title', 255, true), mediumtext('content', true), s('author_id', 128), s('audience', 128), s('target_audience', 128), s('priority', 64), b('is_active', false, true), s('media_urls', 2048, false, true), i('created_timestamp'), dt('published_at'), dt('created_at'), dt('updated_at')], indexes: [{ key: 'announcements_created_idx', type: 'key', columns: ['created_at'], orders: ['DESC'] }] },
  { id: 'content_pages', name: 'Content Pages', columns: [s('slug', 255, true), s('title', 255, true), mediumtext('content'), s('category', 128), s('language', 32), s('language_code', 32), b('is_published', false, false), mediumtext('metadata'), dt('publish_date'), dt('created_at'), dt('updated_at')], indexes: [{ key: 'content_pages_slug_idx', type: 'unique', columns: ['slug'] }] },
  { id: 'dynamic_content', name: 'Dynamic Content', columns: [s('key', 255, true), s('category', 128), mediumtext('value'), mediumtext('metadata'), dt('created_at'), dt('updated_at')] },
  { id: 'featured_content', name: 'Featured Content', columns: [s('title', 255), text('description'), s('content_id', 128), s('content_type', 128), i('priority'), b('is_active', false, true), dt('created_at'), dt('updated_at')] },
  { id: 'app_settings', name: 'App Settings', columns: [s('key', 255, true), s('setting_key', 255), s('display_name', 255), mediumtext('value'), mediumtext('setting_value'), s('type', 64), s('data_type', 64), s('category', 128), text('description'), b('is_public', false, false), b('is_active', false, true), s('updated_by', 128), dt('created_at'), dt('updated_at')], indexes: [{ key: 'app_settings_key_idx', type: 'unique', columns: ['key'] }] },
  { id: 'board_reports', name: 'Board Reports', columns: [s('title', 255, true), mediumtext('content'), s('type', 128), s('author_id', 128), s('chapter_id', 128), s('team_id', 128), s('status', 64), s('attachments', 2048, false, true), dt('created_at'), dt('updated_at'), dt('submitted_at'), dt('reviewed_at')] },
  { id: 'board_documents', name: 'Board Documents', columns: [s('title', 255, true), mediumtext('description'), s('file_url', 2048), s('file_path', 1024), s('uploaded_by', 128), s('category', 128), s('visibility', 128), dt('created_at'), dt('updated_at')] },
  { id: 'board_decisions', name: 'Board Decisions', columns: [s('title', 255, true), mediumtext('description'), s('status', 64), s('created_by', 128), s('approved_by', 128, false, true), s('attachments', 2048, false, true), dt('created_at'), dt('updated_at')] },
  {
    id: 'discipleship_contacts',
    name: 'Discipleship Contacts',
    columns: [
      s('disciple_maker_id', 128, true), s('first_name', 128, true), s('last_name', 128, true), s('email', 320),
      s('phone', 64), text('address'), dt('date_of_birth'), s('occupation', 255), text('interests'),
      s('current_level', 64, true), dt('first_contact', true), dt('last_contact'), dt('baptism_date'),
      text('notes'), b('is_active', false, true), s('tags', 128, false, true), mediumtext('custom_fields'),
      dt('created_at', true), dt('updated_at', true),
    ],
    indexes: [
      { key: 'discipleship_contacts_maker_idx', type: 'key', columns: ['disciple_maker_id'] },
      { key: 'discipleship_contacts_level_idx', type: 'key', columns: ['current_level'] },
      { key: 'discipleship_contacts_active_idx', type: 'key', columns: ['is_active'] },
      { key: 'discipleship_contacts_updated_idx', type: 'key', columns: ['updated_at'], orders: ['DESC'] },
    ],
  },
  {
    id: 'contact_interactions',
    name: 'Contact Interactions',
    columns: [
      s('contact_id', 128, true), s('disciple_maker_id', 128, true), s('method', 64, true), s('title', 255, true),
      mediumtext('description'), dt('date', true), i('duration_minutes'), text('outcome'), text('next_steps'),
      s('attachments', 2048, false, true), dt('created_at', true),
    ],
    indexes: [
      { key: 'contact_interactions_contact_idx', type: 'key', columns: ['contact_id'] },
      { key: 'contact_interactions_maker_idx', type: 'key', columns: ['disciple_maker_id'] },
      { key: 'contact_interactions_date_idx', type: 'key', columns: ['date'], orders: ['DESC'] },
    ],
  },
  {
    id: 'discipleship_study_sessions',
    name: 'Discipleship Study Sessions',
    columns: [
      s('contact_id', 128, true), s('disciple_maker_id', 128, true), s('type', 64, true), s('title', 255, true),
      s('topic', 255), text('bible_texts'), dt('date', true), i('duration_minutes'), text('notes'), text('homework'),
      i('rating'), b('completed', false, false), dt('created_at', true),
    ],
    indexes: [
      { key: 'discipleship_study_contact_idx', type: 'key', columns: ['contact_id'] },
      { key: 'discipleship_study_maker_idx', type: 'key', columns: ['disciple_maker_id'] },
      { key: 'discipleship_study_type_idx', type: 'key', columns: ['type'] },
      { key: 'discipleship_study_date_idx', type: 'key', columns: ['date'], orders: ['DESC'] },
    ],
  },
  {
    id: 'discipleship_prayer_requests',
    name: 'Discipleship Prayer Requests',
    columns: [
      s('contact_id', 128, true), s('disciple_maker_id', 128, true), mediumtext('request', true), s('category', 128),
      s('status', 64, true), dt('date_requested', true), dt('date_answered'), mediumtext('answer'), text('notes'),
      dt('created_at', true), dt('updated_at', true),
    ],
    indexes: [
      { key: 'discipleship_prayer_contact_idx', type: 'key', columns: ['contact_id'] },
      { key: 'discipleship_prayer_maker_idx', type: 'key', columns: ['disciple_maker_id'] },
      { key: 'discipleship_prayer_status_idx', type: 'key', columns: ['status'] },
      { key: 'discipleship_prayer_date_idx', type: 'key', columns: ['date_requested'], orders: ['DESC'] },
    ],
  },
  {
    id: 'progress_milestones',
    name: 'Discipleship Progress Milestones',
    columns: [s('contact_id', 128, true), s('from_level', 64, true), s('to_level', 64, true), dt('date', true), text('notes'), text('celebration_plan'), dt('created_at', true)],
    indexes: [{ key: 'progress_milestones_contact_idx', type: 'key', columns: ['contact_id'] }, { key: 'progress_milestones_date_idx', type: 'key', columns: ['date'], orders: ['DESC'] }],
  },
  {
    id: 'discipleship_reports',
    name: 'Discipleship Reports',
    columns: [
      s('disciple_maker_id', 128, true), s('supervisor_id', 128), dt('report_period_start', true), dt('report_period_end', true),
      i('total_contacts', true), i('active_contacts', true), i('new_contacts', true), i('baptisms', true),
      i('study_sessions', true), i('interactions', true), text('highlights'), text('challenges'), text('prayer_requests'),
      text('goals'), s('frequency', 64, true), dt('created_at', true), dt('submitted_at'),
    ],
    indexes: [
      { key: 'discipleship_reports_maker_idx', type: 'key', columns: ['disciple_maker_id'] },
      { key: 'discipleship_reports_supervisor_idx', type: 'key', columns: ['supervisor_id'] },
      { key: 'discipleship_reports_created_idx', type: 'key', columns: ['created_at'], orders: ['DESC'] },
    ],
  },
  {
    id: 'leadership_records',
    name: 'Leadership Records',
    columns: [
      s('user_id', 128, true), s('user_name', 255, true), s('user_email', 320, true), s('user_phone', 64),
      s('position', 128, true), s('position_title', 255, true), s('chapter_id', 128), dt('start_date', true),
      dt('end_date'), i('years_of_service', true), s('status', 64, true), text('notes'), mediumtext('achievements'),
      mediumtext('contact_info'), s('created_by', 128), s('updated_by', 128), s('approved_by', 128), dt('approved_at'),
      text('approval_notes'), s('rejected_by', 128), dt('rejected_at'), text('rejection_reason'), dt('completed_at'),
      text('completion_notes'), dt('created_at', true), dt('updated_at', true),
    ],
    indexes: [
      { key: 'leadership_records_user_idx', type: 'key', columns: ['user_id'] },
      { key: 'leadership_records_status_idx', type: 'key', columns: ['status'] },
      { key: 'leadership_records_position_idx', type: 'key', columns: ['position'] },
      { key: 'leadership_records_chapter_idx', type: 'key', columns: ['chapter_id'] },
    ],
  },
  {
    id: 'leadership_transitions',
    name: 'Leadership Transitions',
    columns: [
      s('user_id', 128, true), s('from_position', 128), s('to_position', 128, true), s('from_position_title', 255),
      s('to_position_title', 255, true), dt('transition_date', true), text('reason'), text('notes'), s('approved_by', 128),
      dt('created_at', true),
    ],
    indexes: [
      { key: 'leadership_transitions_user_idx', type: 'key', columns: ['user_id'] },
      { key: 'leadership_transitions_date_idx', type: 'key', columns: ['transition_date'], orders: ['DESC'] },
    ],
  },
  { id: 'leadership_history', name: 'Leadership History', columns: [s('user_id', 128, true), s('role', 128, true), dt('start_date'), dt('end_date'), s('chapter_id', 128), text('notes')] },
  { id: 'teams', name: 'Teams', columns: [s('name', 255, true), s('type', 128), mediumtext('description'), s('coordinator_id', 128), s('member_ids', 128, false, true), s('chapter_id', 128), b('is_active', false, true), dt('created_at'), dt('updated_at')] },
  { id: 'task_assignments', name: 'Task Assignments', columns: [s('title', 255, true), mediumtext('description'), s('assigned_by_id', 128), s('assigned_to_id', 128), s('team_id', 128), s('chapter_id', 128), s('priority', 64), s('status', 64), dt('due_date'), dt('created_at'), dt('updated_at'), dt('completed_at')] },
  { id: 'tracts', name: 'Tracts', columns: [s('title', 255, true), mediumtext('description'), s('category', 128), s('pdf_url', 2048), s('image_url', 2048), s('cover_image', 2048), s('cover_images', 2048, false, true), s('author'), i('pages'), i('order'), s('language', 32), b('featured', false, false), s('tags', 128, false, true), dt('created_at'), dt('updated_at')] },
  { id: 'tract_contents', name: 'Tract Contents', columns: [s('tract_id', 128, true), mediumtext('content'), mediumtext('questions'), mediumtext('metadata'), dt('created_at'), dt('updated_at')], indexes: [{ key: 'tract_contents_tract_idx', type: 'key', columns: ['tract_id'] }] },
  { id: 'tract_categories', name: 'Tract Categories', columns: [s('name', 255, true), text('description'), s('image_url', 2048), i('order'), b('is_active', false, true)] },
  { id: 'tract_progress', name: 'Tract Progress', columns: [s('user_id', 128, true), s('tract_id', 128, true), i('current_page'), b('is_completed', false, false), dt('last_updated')] },
  { id: 'user_tract_answers', name: 'User Tract Answers', columns: [s('user_id', 128, true), s('tract_id', 128, true), mediumtext('answers'), b('is_completed'), i('score'), dt('completed_at')] },
  { id: 'podcasts', name: 'Podcasts', columns: [s('title', 255, true), mediumtext('description'), s('category', 128), s('host'), i('episodes'), f('rating'), b('is_subscribed'), s('tags', 128, false, true), s('cover_image', 2048), s('audio_url', 2048), dt('created_at'), dt('updated_at')] },
  { id: 'podcast_episodes', name: 'Podcast Episodes', columns: [s('title', 255, true), s('podcast_id', 128, true), s('podcast_title'), mediumtext('description'), s('duration', 64), s('audio_url', 2048), dt('publish_date'), b('is_downloaded'), s('local_path', 1024)] },
  { id: 'podcast_categories', name: 'Podcast Categories', columns: [s('name', 255, true), text('description'), i('order'), b('is_active', false, true)] },
  { id: 'study_guides', name: 'Study Guides', columns: [s('title', 255, true), mediumtext('description'), s('type', 128), s('difficulty', 64), s('cover_image_url', 2048), i('lesson_count'), b('is_featured'), b('is_published'), dt('created_at'), dt('updated_at')] },
  { id: 'study_lessons', name: 'Study Lessons', columns: [s('study_guide_id', 128, true), i('lesson_number'), s('title', 255, true), mediumtext('content'), mediumtext('resources'), dt('created_at'), dt('updated_at')] },
  { id: 'study_questions', name: 'Study Questions', columns: [s('lesson_id', 128, true), mediumtext('question'), s('type', 64), mediumtext('options'), mediumtext('correct_answer'), i('order')] },
  { id: 'study_progress', name: 'Study Progress', columns: [s('user_id', 128, true), s('program_id', 128), s('study_guide_id', 128), s('lesson_id', 128), b('completed'), i('score'), i('current_lesson'), i('completed_lessons'), f('progress_percentage'), dt('completed_at'), dt('last_accessed_at'), dt('created_at'), dt('updated_at')] },
  { id: 'study_sessions', name: 'Study Sessions', columns: [s('study_guide_id', 128), s('lesson_id', 128), s('facilitator_id', 128), s('participant_ids', 128, false, true), s('title', 255), mediumtext('description'), dt('scheduled_at'), i('duration_minutes'), s('status', 64), s('meeting_link', 2048), s('location'), mediumtext('resources'), text('notes'), dt('created_at'), dt('updated_at')] },
  { id: 'daily_verses', name: 'Daily Verses', columns: [mediumtext('verse', true), s('reference', 255, true), s('translation', 64), dt('date'), mediumtext('reflection'), s('book', 128), i('chapter'), i('verse_number'), b('is_generated'), dt('created_at')], indexes: [{ key: 'daily_verses_date_idx', type: 'key', columns: ['date'], orders: ['DESC'] }] },
  { id: 'bible_books', name: 'Bible Books', columns: [s('name', 255, true), s('abbreviation', 32), i('chapters'), s('testament', 64), mediumtext('translations'), s('language', 32), s('version', 64), i('order')] },
  { id: 'bible_chapters', name: 'Bible Chapters', columns: [s('book_id', 128), s('book', 255), i('chapter'), s('language', 32), s('version', 64), mediumtext('content')] },
  { id: 'bible_verses', name: 'Bible Verses', columns: [s('book', 255), i('chapter'), i('verse'), mediumtext('text'), s('language', 32), s('version', 64), s('reference', 255)] },
  { id: 'memory_verses', name: 'Kids Memory Verses', columns: [mediumtext('verse', true), s('reference', 255, true), s('category', 128), s('age_group', 64), s('difficulty', 64), s('theme', 128), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'prayer_activities', name: 'Kids Prayer Activities', columns: [s('title', 255, true), mediumtext('content'), s('type', 128), s('category', 128), s('age_group', 64), s('duration', 64), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'service_projects', name: 'Kids Service Projects', columns: [s('title', 255, true), mediumtext('description'), s('category', 128), s('age_group', 64), s('duration', 64), s('difficulty', 64), mediumtext('impact'), s('materials', 255, false, true), s('sda_values', 128, false, true), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'kids_stories', name: 'Kids Stories', columns: [s('title', 255, true), s('subtitle'), s('age_group', 64), i('duration'), mediumtext('description'), mediumtext('content'), mediumtext('moral_lesson'), s('bible_reference'), s('sda_doctrine', 128), s('category', 128), s('categories', 128, false, true), s('tags', 128, false, true), s('image_url', 2048), s('audio_url', 2048), s('illustration_url', 2048), s('media_url', 2048), b('completed'), b('favorite'), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'kids_missions', name: 'Kids Missions', columns: [s('title', 255, true), mediumtext('description'), s('location'), s('category', 128), s('difficulty', 64), s('duration', 64), i('points'), b('completed'), mediumtext('instructions'), s('verification_method', 128), s('prerequisite_mission_ids', 128, false, true), b('is_locked'), s('unlocked_by', 128), s('media_url', 2048), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'learning_resources', name: 'Kids Learning Resources', columns: [s('title', 255, true), mediumtext('description'), s('subject', 128), s('category', 128), s('age_group', 64), s('resource_type', 128), b('downloadable'), s('file_url', 2048), s('image_url', 2048), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'health_tracking', name: 'Health Tracking', columns: [
    s('user_id', 128, true), s('category', 128), f('value'), s('unit', 64), text('notes'), dt('tracked_at'),
    s('date', 32), i('water_intake'), i('exercise_minutes'), i('sunlight_minutes'), f('sleep_hours'),
    i('nutrition_score'), i('temperance_score'), i('fresh_air_score'), i('air_quality_score'), i('rest_score'),
    i('trust_score'), i('trust_in_god_score'), dt('created_at'), dt('updated_at'),
  ], indexes: [{ key: 'health_tracking_user_idx', type: 'key', columns: ['user_id'] }, { key: 'health_tracking_date_idx', type: 'key', columns: ['date'] }] },
  { id: 'nigerian_meal_plans', name: 'Nigerian Meal Plans', columns: [s('title', 255, true), mediumtext('description'), s('region', 128), s('available_ingredients', 255, false, true), mediumtext('days'), s('health_principles', 255, false, true), s('bible_verses', 255, false, true), text('nutritionist_notes'), s('difficulty_level', 64), i('duration_days'), b('is_featured'), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'wholesome_living_tips', name: 'Wholesome Living Tips', columns: [s('title', 255, true), mediumtext('content'), s('category', 128), s('tags', 128, false, true), s('bible_verse', 512), s('bible_reference'), s('difficulty', 64), i('estimated_time_minutes'), s('benefits', 255, false, true), s('image_url', 2048), i('likes'), i('shares'), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'user_submitted_recipes', name: 'User Submitted Recipes', columns: [s('name', 255, true), s('type', 64), s('category', 128), s('difficulty', 64), s('prep_time', 64), i('servings'), mediumtext('ingredients'), mediumtext('instructions'), mediumtext('nutritional_benefits'), mediumtext('cultural_significance'), s('submitted_by', 128), s('submitted_by_email', 255), s('status', 64), dt('created_at'), dt('updated_at')], indexes: [{ key: 'user_recipes_status_idx', type: 'key', columns: ['status'] }] },
  { id: 'user_submitted_health_tips', name: 'User Submitted Health Tips', columns: [s('name', 255, true), s('type', 64), s('category', 128), s('difficulty', 64), s('prep_time', 64), mediumtext('ingredients'), mediumtext('instructions'), mediumtext('usage_instructions'), mediumtext('health_benefits'), mediumtext('precautions'), mediumtext('traditional_source'), s('submitted_by', 128), s('submitted_by_email', 255), s('status', 64), dt('created_at'), dt('updated_at')], indexes: [{ key: 'user_health_tips_status_idx', type: 'key', columns: ['status'] }] },
  { id: 'lifestyle_trackers', name: 'Lifestyle Trackers', columns: [s('user_id', 128, true), dt('date'), mediumtext('natural_remedies'), mediumtext('metrics'), s('meals', 255, false, true), text('notes'), s('mood', 64), i('energy_level'), s('achievements', 255, false, true), dt('created_at'), dt('updated_at')] },
  { id: 'lifestyle_goals', name: 'Lifestyle Goals', columns: [s('user_id', 128, true), s('goal', 128), s('title', 255), mediumtext('description'), dt('start_date'), dt('target_date'), mediumtext('target_metrics'), s('milestones', 255, false, true), s('completed_milestones', 255, false, true), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'user_health_profiles', name: 'User Health Profiles', columns: [s('user_id', 128, true), s('preferred_region', 128), s('dietary_restrictions', 128, false, true), s('allergies', 128, false, true), s('current_goals', 128, false, true), mediumtext('health_conditions'), f('height'), f('weight'), i('age'), s('activity_level', 64), dt('created_at'), dt('updated_at')] },
  { id: 'missions', name: 'Missions', columns: [s('title', 255, true), mediumtext('description'), s('location'), s('category', 128), s('difficulty', 64), i('duration'), i('points'), s('status', 64), s('instructions', 512, false, true), s('verification_method', 128), dt('start_date'), dt('end_date'), i('participants_count'), i('max_participants'), s('current_participants', 128, false, true), s('image_url', 2048), s('requirements', 255, false, true), s('contact_info'), b('is_active'), dt('created_at'), dt('updated_at')] },
  { id: 'user_missions', name: 'User Missions', columns: [s('user_id', 128, true), s('mission_id', 128, true), s('status', 64), s('proof_url', 2048), dt('created_at'), dt('updated_at')] },
  { id: 'conference_meetings', name: 'Conference Meetings', columns: [s('title', 255, true), mediumtext('description'), dt('scheduled_time'), i('duration'), s('host_id', 128), s('host_name'), s('meeting_type', 128), s('participants', 128, false, true), i('max_participants'), b('is_recurring'), s('meeting_link', 2048), s('status', 64), s('room_name'), s('recording_link', 2048), dt('created_at'), dt('updated_at')] },
  { id: 'meeting_files', name: 'Meeting Files', columns: [s('meeting_id', 128), s('name', 255), s('file_url', 2048), s('file_path', 1024), s('file_name', 255), s('file_type', 64), i('file_size'), text('description'), s('uploaded_by', 128), s('uploader_id', 128), s('visibility', 128), dt('uploaded_at'), dt('created_at'), dt('updated_at')] },
  { id: 'push_tokens', name: 'Push Tokens', columns: [s('user_id', 128, true), s('token', 512, true), s('provider', 64), s('platform', 64), dt('created_at'), dt('updated_at')], indexes: [{ key: 'push_tokens_user_idx', type: 'key', columns: ['user_id'] }] },
  {
    id: 'notification_settings',
    name: 'Notification Settings',
    columns: [
      s('user_id', 128, true), b('daily_verse_reminder', false, true), b('prayer_reminder', false, true),
      b('health_tracking_reminder', false, true), b('study_reminder', false, true), b('mission_reminder', false, true),
      s('reminder_time', 16), b('push_notifications_enabled', false, false), b('sound_enabled', false, true),
      b('prayer'), b('chat'), b('events'), b('donations'), b('study'), b('kids'), b('health'),
      b('prayer_requests'), b('missions'), b('daily_verse'), b('health_reminders'), b('study_reminders'),
      b('bible_memorization_reminder'), dt('daily_verse_time'), mediumtext('health_reminder_settings'),
      mediumtext('study_reminder_settings'), dt('created_at'), dt('updated_at'),
    ],
  },
  {
    id: 'admin_notifications',
    name: 'Admin Notifications',
    columns: [
      s('type', 128, true), s('title', 255), mediumtext('message'), s('user_id', 128),
      mediumtext('details'), mediumtext('metadata'), b('is_read', false, false),
      s('priority', 64), dt('created_at'),
    ],
    indexes: [
      { key: 'admin_notifications_user_idx', type: 'key', columns: ['user_id'] },
      { key: 'admin_notifications_created_idx', type: 'key', columns: ['created_at'], orders: ['DESC'] },
    ],
  },
  {
    id: 'analytics_events',
    name: 'Analytics Events',
    columns: [
      s('user_id', 128), s('event_name', 128, true), mediumtext('parameters'),
      s('session_id', 128), dt('created_at'),
    ],
    indexes: [
      { key: 'analytics_events_user_idx', type: 'key', columns: ['user_id'] },
      { key: 'analytics_events_name_idx', type: 'key', columns: ['event_name'] },
      { key: 'analytics_events_created_idx', type: 'key', columns: ['created_at'], orders: ['DESC'] },
    ],
  },
  {
    id: 'user_activities',
    name: 'User Activities',
    columns: [
      s('user_id', 128, true), s('activity_type', 128, true), dt('activity_date'), dt('created_at'),
    ],
    indexes: [
      { key: 'user_activities_user_idx', type: 'key', columns: ['user_id'] },
      { key: 'user_activities_type_idx', type: 'key', columns: ['activity_type'] },
      { key: 'user_activities_date_idx', type: 'key', columns: ['activity_date'], orders: ['DESC'] },
    ],
  },
  {
    id: 'reading_sessions',
    name: 'Reading Sessions',
    columns: [
      s('user_id', 128, true), i('duration_minutes'), dt('session_date'), dt('created_at'),
    ],
    indexes: [
      { key: 'reading_sessions_user_idx', type: 'key', columns: ['user_id'] },
      { key: 'reading_sessions_date_idx', type: 'key', columns: ['session_date'], orders: ['DESC'] },
    ],
  },
  {
    id: 'chapter_readings',
    name: 'Chapter Readings',
    columns: [
      s('user_id', 128, true), s('book', 128, true), i('chapter', true), dt('read_date'), dt('created_at'),
    ],
    indexes: [
      { key: 'chapter_readings_user_idx', type: 'key', columns: ['user_id'] },
      { key: 'chapter_readings_date_idx', type: 'key', columns: ['read_date'], orders: ['DESC'] },
    ],
  },
  { id: 'admin_audit_logs', name: 'Admin Audit Logs', columns: [s('admin_id', 128), s('action', 255), s('resource', 128), s('resource_id', 128), mediumtext('old_values'), mediumtext('new_values'), s('ip_address', 128), s('user_agent', 512), dt('timestamp')], indexes: [{ key: 'audit_resource_idx', type: 'key', columns: ['resource'] }] },
];

export const webhooks = [
  {
    id: 'profile_approval_events',
    name: 'Profile Approval Events',
    urlEnv: 'APPWRITE_PROFILE_APPROVAL_WEBHOOK_URL',
    events: ['databases.*.collections.6a08943100226f5b4963.documents.*.update'],
  },
  {
    id: 'chat_file_events',
    name: 'Chat File Upload Events',
    urlEnv: 'APPWRITE_CHAT_FILE_WEBHOOK_URL',
    events: ['buckets.6a08f51f002d2baf5e78.files.*.create'],
  },
  {
    id: 'donation_record_events',
    name: 'Donation Record Events',
    urlEnv: 'APPWRITE_DONATION_WEBHOOK_URL',
    events: ['databases.*.collections.donation_records.documents.*.create', 'databases.*.collections.donation_records.documents.*.update'],
  },
];
