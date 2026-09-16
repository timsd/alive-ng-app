import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_ig.dart';
import 'app_localizations_yo.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ha'),
    Locale('ig'),
    Locale('yo')
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @study.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get study;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @prayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get prayer;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @prayerWall.
  ///
  /// In en, this message translates to:
  /// **'Prayer Wall'**
  String get prayerWall;

  /// No description provided for @sharePrayerRequest.
  ///
  /// In en, this message translates to:
  /// **'Share a Prayer Request'**
  String get sharePrayerRequest;

  /// No description provided for @prayFor.
  ///
  /// In en, this message translates to:
  /// **'Pray For'**
  String get prayFor;

  /// No description provided for @prayerRequests.
  ///
  /// In en, this message translates to:
  /// **'Prayer Requests'**
  String get prayerRequests;

  /// No description provided for @myPrayers.
  ///
  /// In en, this message translates to:
  /// **'My Prayers'**
  String get myPrayers;

  /// No description provided for @addPrayer.
  ///
  /// In en, this message translates to:
  /// **'Add Prayer'**
  String get addPrayer;

  /// No description provided for @bibleStudy.
  ///
  /// In en, this message translates to:
  /// **'Bible Study'**
  String get bibleStudy;

  /// No description provided for @continueLesson.
  ///
  /// In en, this message translates to:
  /// **'Continue Lesson'**
  String get continueLesson;

  /// No description provided for @startProgram.
  ///
  /// In en, this message translates to:
  /// **'Start Program'**
  String get startProgram;

  /// No description provided for @studyProgress.
  ///
  /// In en, this message translates to:
  /// **'Study Progress'**
  String get studyProgress;

  /// No description provided for @completedLessons.
  ///
  /// In en, this message translates to:
  /// **'Completed Lessons'**
  String get completedLessons;

  /// No description provided for @healthyLiving.
  ///
  /// In en, this message translates to:
  /// **'Healthy Living'**
  String get healthyLiving;

  /// No description provided for @todaysScore.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Wellness Score'**
  String get todaysScore;

  /// No description provided for @logWater.
  ///
  /// In en, this message translates to:
  /// **'Log Water Intake'**
  String get logWater;

  /// No description provided for @waterIntake.
  ///
  /// In en, this message translates to:
  /// **'Water Intake'**
  String get waterIntake;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @nutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get nutrition;

  /// No description provided for @missionStories.
  ///
  /// In en, this message translates to:
  /// **'Mission Stories'**
  String get missionStories;

  /// No description provided for @supportMission.
  ///
  /// In en, this message translates to:
  /// **'Support This Mission'**
  String get supportMission;

  /// No description provided for @missions.
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get missions;

  /// No description provided for @donate.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donate;

  /// No description provided for @volunteer.
  ///
  /// In en, this message translates to:
  /// **'Volunteer'**
  String get volunteer;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @archived_users.
  ///
  /// In en, this message translates to:
  /// **'Archived Users'**
  String get archived_users;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @welcome_message.
  ///
  /// In en, this message translates to:
  /// **'Welcome Message'**
  String get welcome_message;

  /// No description provided for @good_morning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get good_morning;

  /// No description provided for @good_afternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get good_afternoon;

  /// No description provided for @good_evening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get good_evening;

  /// No description provided for @daily_verse.
  ///
  /// In en, this message translates to:
  /// **'Daily Verse'**
  String get daily_verse;

  /// No description provided for @quick_actions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quick_actions;

  /// No description provided for @study_programs.
  ///
  /// In en, this message translates to:
  /// **'Study Programs'**
  String get study_programs;

  /// No description provided for @prayer_requests.
  ///
  /// In en, this message translates to:
  /// **'Prayer Requests'**
  String get prayer_requests;

  /// No description provided for @health_tracking.
  ///
  /// In en, this message translates to:
  /// **'Health Tracking'**
  String get health_tracking;

  /// No description provided for @mission_updates.
  ///
  /// In en, this message translates to:
  /// **'Mission Updates'**
  String get mission_updates;

  /// No description provided for @bible.
  ///
  /// In en, this message translates to:
  /// **'Bible'**
  String get bible;

  /// No description provided for @read_bible.
  ///
  /// In en, this message translates to:
  /// **'Read Bible'**
  String get read_bible;

  /// No description provided for @bible_study.
  ///
  /// In en, this message translates to:
  /// **'Bible Study'**
  String get bible_study;

  /// No description provided for @daily_devotion.
  ///
  /// In en, this message translates to:
  /// **'Daily Devotion'**
  String get daily_devotion;

  /// No description provided for @interactive_lessons.
  ///
  /// In en, this message translates to:
  /// **'Interactive Lessons'**
  String get interactive_lessons;

  /// No description provided for @search_lessons.
  ///
  /// In en, this message translates to:
  /// **'Search Lessons'**
  String get search_lessons;

  /// No description provided for @all_lessons.
  ///
  /// In en, this message translates to:
  /// **'All Lessons'**
  String get all_lessons;

  /// No description provided for @in_progress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get in_progress;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @no_lessons_found.
  ///
  /// In en, this message translates to:
  /// **'No lessons found'**
  String get no_lessons_found;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get sign_in;

  /// No description provided for @sign_up.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get sign_up;

  /// No description provided for @sign_in_to_continue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your spiritual growth'**
  String get sign_in_to_continue;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sign_out;

  /// No description provided for @full_name.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get full_name;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirm_password;

  /// No description provided for @create_account_message.
  ///
  /// In en, this message translates to:
  /// **'Create your account to start your spiritual journey'**
  String get create_account_message;

  /// No description provided for @welcome_back_message.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Sign in to continue your spiritual growth'**
  String get welcome_back_message;

  /// No description provided for @please_enter_full_name.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get please_enter_full_name;

  /// No description provided for @please_enter_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get please_enter_email;

  /// No description provided for @please_enter_valid_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get please_enter_valid_email;

  /// No description provided for @please_enter_password.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get please_enter_password;

  /// No description provided for @password_min_length.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get password_min_length;

  /// No description provided for @passwords_do_not_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwords_do_not_match;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @try_again.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get try_again;

  /// No description provided for @no_data.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get no_data;

  /// No description provided for @selection.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get selection;

  /// No description provided for @coming_soon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get coming_soon;

  /// No description provided for @continue_spiritual_journey.
  ///
  /// In en, this message translates to:
  /// **'Continue your spiritual journey today'**
  String get continue_spiritual_journey;

  /// No description provided for @recent_activity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recent_activity;

  /// No description provided for @your_progress.
  ///
  /// In en, this message translates to:
  /// **'Your Progress'**
  String get your_progress;

  /// No description provided for @bible_study_completed.
  ///
  /// In en, this message translates to:
  /// **'Bible Study Completed'**
  String get bible_study_completed;

  /// No description provided for @prayer_request_submitted.
  ///
  /// In en, this message translates to:
  /// **'Prayer Request Submitted'**
  String get prayer_request_submitted;

  /// No description provided for @joined_small_group.
  ///
  /// In en, this message translates to:
  /// **'Joined Small Group'**
  String get joined_small_group;

  /// No description provided for @hours_ago.
  ///
  /// In en, this message translates to:
  /// **'hours ago'**
  String get hours_ago;

  /// No description provided for @day_ago.
  ///
  /// In en, this message translates to:
  /// **'day ago'**
  String get day_ago;

  /// No description provided for @studies.
  ///
  /// In en, this message translates to:
  /// **'Studies'**
  String get studies;

  /// No description provided for @prayers.
  ///
  /// In en, this message translates to:
  /// **'Prayers'**
  String get prayers;

  /// No description provided for @this_month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get this_month;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @failed_to_load_verse.
  ///
  /// In en, this message translates to:
  /// **'Failed to load verse'**
  String get failed_to_load_verse;

  /// No description provided for @featured_today.
  ///
  /// In en, this message translates to:
  /// **'Featured Today'**
  String get featured_today;

  /// No description provided for @health_message.
  ///
  /// In en, this message translates to:
  /// **'Health Message: Natural Remedies'**
  String get health_message;

  /// No description provided for @health_message_desc.
  ///
  /// In en, this message translates to:
  /// **'Discover God\'s design for healthy living through the 8 natural doctors'**
  String get health_message_desc;

  /// No description provided for @mission_spotlight.
  ///
  /// In en, this message translates to:
  /// **'Mission Spotlight: Northern Nigeria'**
  String get mission_spotlight;

  /// No description provided for @mission_spotlight_desc.
  ///
  /// In en, this message translates to:
  /// **'Read inspiring stories from our mission work across Nigeria'**
  String get mission_spotlight_desc;

  /// No description provided for @join_us_spiritual_growth.
  ///
  /// In en, this message translates to:
  /// **'Join us in spiritual growth'**
  String get join_us_spiritual_growth;

  /// No description provided for @about_app.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get about_app;

  /// No description provided for @about_alive.
  ///
  /// In en, this message translates to:
  /// **'About ALIVE'**
  String get about_alive;

  /// No description provided for @app_tagline.
  ///
  /// In en, this message translates to:
  /// **'Bible study, prayer, and service in one community'**
  String get app_tagline;

  /// No description provided for @resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided for @resources_title.
  ///
  /// In en, this message translates to:
  /// **'Ministry Resources'**
  String get resources_title;

  /// No description provided for @resources_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Study, prayer, health, music, and outreach materials'**
  String get resources_subtitle;

  /// No description provided for @error_loading_reports.
  ///
  /// In en, this message translates to:
  /// **'Error loading reports'**
  String get error_loading_reports;

  /// No description provided for @board_reports.
  ///
  /// In en, this message translates to:
  /// **'Board Reports'**
  String get board_reports;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @create_new_report.
  ///
  /// In en, this message translates to:
  /// **'Create New Report'**
  String get create_new_report;

  /// No description provided for @report_title.
  ///
  /// In en, this message translates to:
  /// **'Report Title'**
  String get report_title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @report_content.
  ///
  /// In en, this message translates to:
  /// **'Report Content'**
  String get report_content;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @report_created_successfully.
  ///
  /// In en, this message translates to:
  /// **'Report created successfully'**
  String get report_created_successfully;

  /// No description provided for @report_submitted_for_review.
  ///
  /// In en, this message translates to:
  /// **'Report submitted for review'**
  String get report_submitted_for_review;

  /// No description provided for @error_loading_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Error loading dashboard'**
  String get error_loading_dashboard;

  /// No description provided for @access_denied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get access_denied;

  /// No description provided for @admin_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get admin_dashboard;

  /// No description provided for @user_approval.
  ///
  /// In en, this message translates to:
  /// **'User Approval'**
  String get user_approval;

  /// No description provided for @pending_users.
  ///
  /// In en, this message translates to:
  /// **'Pending Users'**
  String get pending_users;

  /// No description provided for @approved_users.
  ///
  /// In en, this message translates to:
  /// **'Approved Users'**
  String get approved_users;

  /// No description provided for @rejected_users.
  ///
  /// In en, this message translates to:
  /// **'Rejected Users'**
  String get rejected_users;

  /// No description provided for @approve_user.
  ///
  /// In en, this message translates to:
  /// **'Approve User'**
  String get approve_user;

  /// No description provided for @reject_user.
  ///
  /// In en, this message translates to:
  /// **'Reject User'**
  String get reject_user;

  /// No description provided for @approval_reason.
  ///
  /// In en, this message translates to:
  /// **'Approval Reason'**
  String get approval_reason;

  /// No description provided for @rejection_reason.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get rejection_reason;

  /// No description provided for @user_approved_successfully.
  ///
  /// In en, this message translates to:
  /// **'User approved successfully'**
  String get user_approved_successfully;

  /// No description provided for @user_rejected_successfully.
  ///
  /// In en, this message translates to:
  /// **'User rejected successfully'**
  String get user_rejected_successfully;

  /// No description provided for @account_pending_approval.
  ///
  /// In en, this message translates to:
  /// **'Account Pending Approval'**
  String get account_pending_approval;

  /// No description provided for @account_under_review.
  ///
  /// In en, this message translates to:
  /// **'Your account is currently under review. You\'ll have full access once approved.'**
  String get account_under_review;

  /// No description provided for @pending_admin_approval.
  ///
  /// In en, this message translates to:
  /// **'Pending admin approval'**
  String get pending_admin_approval;

  /// No description provided for @no_pending_users.
  ///
  /// In en, this message translates to:
  /// **'No pending users found'**
  String get no_pending_users;

  /// No description provided for @local_chapter.
  ///
  /// In en, this message translates to:
  /// **'Local Chapter'**
  String get local_chapter;

  /// No description provided for @local_church.
  ///
  /// In en, this message translates to:
  /// **'Local Church'**
  String get local_church;

  /// No description provided for @conference.
  ///
  /// In en, this message translates to:
  /// **'Conference'**
  String get conference;

  /// No description provided for @commitment_type.
  ///
  /// In en, this message translates to:
  /// **'Commitment Type'**
  String get commitment_type;

  /// No description provided for @financial_commitment.
  ///
  /// In en, this message translates to:
  /// **'Financial Commitment'**
  String get financial_commitment;

  /// No description provided for @verification_details.
  ///
  /// In en, this message translates to:
  /// **'Verification Details'**
  String get verification_details;

  /// No description provided for @commitment_details.
  ///
  /// In en, this message translates to:
  /// **'Commitment Details'**
  String get commitment_details;

  /// No description provided for @bible_reader.
  ///
  /// In en, this message translates to:
  /// **'Bible Reader'**
  String get bible_reader;

  /// No description provided for @enter_bible_reference.
  ///
  /// In en, this message translates to:
  /// **'Enter Bible Reference (e.g., John 3:16)'**
  String get enter_bible_reference;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @verse_copied_to_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Verse copied to clipboard'**
  String get verse_copied_to_clipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @search_verses.
  ///
  /// In en, this message translates to:
  /// **'Search verses...'**
  String get search_verses;

  /// No description provided for @opening_book.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get opening_book;

  /// No description provided for @search_topic_or_reference.
  ///
  /// In en, this message translates to:
  /// **'Search topic or Bible reference...'**
  String get search_topic_or_reference;

  /// No description provided for @searching_for.
  ///
  /// In en, this message translates to:
  /// **'Searching for'**
  String get searching_for;

  /// No description provided for @authentication_required.
  ///
  /// In en, this message translates to:
  /// **'Authentication Required'**
  String get authentication_required;

  /// No description provided for @prayer_auth_message.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to access prayer requests and share your prayer needs.'**
  String get prayer_auth_message;

  /// No description provided for @add_prayer_request.
  ///
  /// In en, this message translates to:
  /// **'Add Prayer Request'**
  String get add_prayer_request;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @message_copied_to_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Message copied to clipboard'**
  String get message_copied_to_clipboard;

  /// No description provided for @create_channel.
  ///
  /// In en, this message translates to:
  /// **'Create Channel'**
  String get create_channel;

  /// No description provided for @channel_info.
  ///
  /// In en, this message translates to:
  /// **'Channel Info'**
  String get channel_info;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @failed_to_create_channel.
  ///
  /// In en, this message translates to:
  /// **'Failed to create channel'**
  String get failed_to_create_channel;

  /// No description provided for @create_channel_title.
  ///
  /// In en, this message translates to:
  /// **'Create Channel'**
  String get create_channel_title;

  /// No description provided for @channel_name.
  ///
  /// In en, this message translates to:
  /// **'Channel Name'**
  String get channel_name;

  /// No description provided for @channel_type.
  ///
  /// In en, this message translates to:
  /// **'Channel Type'**
  String get channel_type;

  /// No description provided for @attach_file.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attach_file;

  /// No description provided for @send_message.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get send_message;

  /// No description provided for @refresh_channels.
  ///
  /// In en, this message translates to:
  /// **'Refresh channels'**
  String get refresh_channels;

  /// No description provided for @search_channels.
  ///
  /// In en, this message translates to:
  /// **'Search channels...'**
  String get search_channels;

  /// No description provided for @go_home.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get go_home;

  /// No description provided for @go_back.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get go_back;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @gift_in_kind.
  ///
  /// In en, this message translates to:
  /// **'Gift in Kind'**
  String get gift_in_kind;

  /// No description provided for @donate_specific_items.
  ///
  /// In en, this message translates to:
  /// **'Donate Specific Items'**
  String get donate_specific_items;

  /// No description provided for @gik_intro.
  ///
  /// In en, this message translates to:
  /// **'Fill this form to donate specific items like ministry bus, land, etc.'**
  String get gik_intro;

  /// No description provided for @item_type.
  ///
  /// In en, this message translates to:
  /// **'Item Type'**
  String get item_type;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @estimated_value_optional.
  ///
  /// In en, this message translates to:
  /// **'Estimated Value (Optional)'**
  String get estimated_value_optional;

  /// No description provided for @delivery_preference.
  ///
  /// In en, this message translates to:
  /// **'Delivery Preference'**
  String get delivery_preference;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @description_optional.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get description_optional;

  /// No description provided for @helper_additional_details.
  ///
  /// In en, this message translates to:
  /// **'Provide any additional details'**
  String get helper_additional_details;

  /// No description provided for @submit_and_email.
  ///
  /// In en, this message translates to:
  /// **'Submit and Email'**
  String get submit_and_email;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @drop_off.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get drop_off;

  /// No description provided for @guest_user.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guest_user;

  /// No description provided for @no_email.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get no_email;

  /// No description provided for @edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get edit_profile;

  /// No description provided for @help_support.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get help_support;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @guides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get guides;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @sunday_thursday.
  ///
  /// In en, this message translates to:
  /// **'Sunday - Thursday'**
  String get sunday_thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© 2025 ALIVE Nigeria'**
  String get copyright;

  /// No description provided for @books_and_tracts.
  ///
  /// In en, this message translates to:
  /// **'Books & Tracts'**
  String get books_and_tracts;

  /// No description provided for @books.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get books;

  /// No description provided for @tracts.
  ///
  /// In en, this message translates to:
  /// **'Tracts'**
  String get tracts;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @search_books_tracts.
  ///
  /// In en, this message translates to:
  /// **'Search books and tracts...'**
  String get search_books_tracts;

  /// No description provided for @all_categories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get all_categories;

  /// No description provided for @category_doctrine.
  ///
  /// In en, this message translates to:
  /// **'Doctrine'**
  String get category_doctrine;

  /// No description provided for @category_prophecy.
  ///
  /// In en, this message translates to:
  /// **'Prophecy'**
  String get category_prophecy;

  /// No description provided for @category_health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get category_health;

  /// No description provided for @category_youth.
  ///
  /// In en, this message translates to:
  /// **'Youth'**
  String get category_youth;

  /// No description provided for @category_family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get category_family;

  /// No description provided for @category_evangelism.
  ///
  /// In en, this message translates to:
  /// **'Evangelism'**
  String get category_evangelism;

  /// No description provided for @category_sabbath.
  ///
  /// In en, this message translates to:
  /// **'Sabbath'**
  String get category_sabbath;

  /// No description provided for @no_tracts_found.
  ///
  /// In en, this message translates to:
  /// **'No tracts found'**
  String get no_tracts_found;

  /// No description provided for @no_downloads_yet.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get no_downloads_yet;

  /// No description provided for @materials_download_message.
  ///
  /// In en, this message translates to:
  /// **'Materials you download will appear here'**
  String get materials_download_message;

  /// No description provided for @view_pdf.
  ///
  /// In en, this message translates to:
  /// **'View PDF'**
  String get view_pdf;

  /// No description provided for @administrative.
  ///
  /// In en, this message translates to:
  /// **'Administrative'**
  String get administrative;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// No description provided for @claim_admin_role.
  ///
  /// In en, this message translates to:
  /// **'Claim Admin Role'**
  String get claim_admin_role;

  /// No description provided for @admin_claims_preview.
  ///
  /// In en, this message translates to:
  /// **'Admin Claims Preview'**
  String get admin_claims_preview;

  /// No description provided for @more_features.
  ///
  /// In en, this message translates to:
  /// **'More Features'**
  String get more_features;

  /// No description provided for @christian_community.
  ///
  /// In en, this message translates to:
  /// **'Christian Community'**
  String get christian_community;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @main_features.
  ///
  /// In en, this message translates to:
  /// **'Main Features'**
  String get main_features;

  /// No description provided for @page_not_found.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get page_not_found;

  /// No description provided for @admin_role_claimed.
  ///
  /// In en, this message translates to:
  /// **'Admin role claimed. Sign out and sign in again.'**
  String get admin_role_claimed;

  /// No description provided for @claim_failed.
  ///
  /// In en, this message translates to:
  /// **'Claim failed. Confirm Cloud Function is deployed.'**
  String get claim_failed;

  /// No description provided for @could_not_claim_admin.
  ///
  /// In en, this message translates to:
  /// **'Could not claim admin role right now.'**
  String get could_not_claim_admin;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @board_meeting_available.
  ///
  /// In en, this message translates to:
  /// **'Board of Directors Meeting is available'**
  String get board_meeting_available;

  /// No description provided for @how_to_join_chapter.
  ///
  /// In en, this message translates to:
  /// **'How do I join a local chapter?'**
  String get how_to_join_chapter;

  /// No description provided for @join_chapter_answer.
  ///
  /// In en, this message translates to:
  /// **'You can join a local chapter by navigating to the \"Chapters\" section on the Home screen, selecting a chapter near you, and clicking the \"Join\" button.'**
  String get join_chapter_answer;

  /// No description provided for @how_to_submit_prayer_request.
  ///
  /// In en, this message translates to:
  /// **'How can I submit a prayer request?'**
  String get how_to_submit_prayer_request;

  /// No description provided for @prayer_request_answer.
  ///
  /// In en, this message translates to:
  /// **'Go to the \"Prayer\" tab, click the \"Add Request\" button, fill in your details, and select \"Public\" or \"Private\".'**
  String get prayer_request_answer;

  /// No description provided for @how_to_access_study_materials.
  ///
  /// In en, this message translates to:
  /// **'How do I access study materials?'**
  String get how_to_access_study_materials;

  /// No description provided for @study_materials_answer.
  ///
  /// In en, this message translates to:
  /// **'Navigate to the \"Study\" tab to see all available Bible study programs and lessons.'**
  String get study_materials_answer;

  /// No description provided for @how_to_track_health.
  ///
  /// In en, this message translates to:
  /// **'How do I track my health activities?'**
  String get how_to_track_health;

  /// No description provided for @health_tracking_answer.
  ///
  /// In en, this message translates to:
  /// **'Use the \"Health Tracking\" quick action on the Home screen or navigate to the Health tab to log your activities.'**
  String get health_tracking_answer;

  /// No description provided for @how_to_reset_password.
  ///
  /// In en, this message translates to:
  /// **'How do I reset my password?'**
  String get how_to_reset_password;

  /// No description provided for @reset_password_answer.
  ///
  /// In en, this message translates to:
  /// **'On the Sign In screen, click \"Forgot Password\". We will send you a link to reset your password via email.'**
  String get reset_password_answer;

  /// No description provided for @how_to_change_language.
  ///
  /// In en, this message translates to:
  /// **'How can I change the app language?'**
  String get how_to_change_language;

  /// No description provided for @change_language_answer.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile > Settings > Language and select your preferred language or use the language icon on the AppBar for Quick Access.'**
  String get change_language_answer;

  /// No description provided for @search_faq.
  ///
  /// In en, this message translates to:
  /// **'Search FAQ...'**
  String get search_faq;

  /// No description provided for @getting_started.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get getting_started;

  /// No description provided for @getting_started_desc.
  ///
  /// In en, this message translates to:
  /// **'Learn the basics of using the ALIVE Nigeria app.'**
  String get getting_started_desc;

  /// No description provided for @using_prayer_wall.
  ///
  /// In en, this message translates to:
  /// **'Using the Prayer Wall'**
  String get using_prayer_wall;

  /// No description provided for @prayer_wall_guide_desc.
  ///
  /// In en, this message translates to:
  /// **'Discover how to share requests and pray for others.'**
  String get prayer_wall_guide_desc;

  /// No description provided for @study_guides_tutorial.
  ///
  /// In en, this message translates to:
  /// **'Study Guides Tutorial'**
  String get study_guides_tutorial;

  /// No description provided for @study_guides_desc.
  ///
  /// In en, this message translates to:
  /// **'A step-by-step guide to completing study lessons.'**
  String get study_guides_desc;

  /// No description provided for @health_tracking_guide.
  ///
  /// In en, this message translates to:
  /// **'Health Tracking Guide'**
  String get health_tracking_guide;

  /// No description provided for @health_tracking_desc.
  ///
  /// In en, this message translates to:
  /// **'How to use the health tracker for better living.'**
  String get health_tracking_desc;

  /// No description provided for @chapter_management.
  ///
  /// In en, this message translates to:
  /// **'Chapter Management'**
  String get chapter_management;

  /// No description provided for @chapter_management_desc.
  ///
  /// In en, this message translates to:
  /// **'For chapter leaders on how to manage members.'**
  String get chapter_management_desc;

  /// No description provided for @notification_settings_guide.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notification_settings_guide;

  /// No description provided for @notification_settings_desc.
  ///
  /// In en, this message translates to:
  /// **'Configure alerts for missions and prayers.'**
  String get notification_settings_desc;

  /// No description provided for @user_guides.
  ///
  /// In en, this message translates to:
  /// **'User Guides'**
  String get user_guides;

  /// No description provided for @need_help.
  ///
  /// In en, this message translates to:
  /// **'Need Help?'**
  String get need_help;

  /// No description provided for @contact_us_message.
  ///
  /// In en, this message translates to:
  /// **'Our support team is available to assist you with any questions or issues.'**
  String get contact_us_message;

  /// No description provided for @office_hours.
  ///
  /// In en, this message translates to:
  /// **'Office Hours'**
  String get office_hours;

  /// No description provided for @send_feedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get send_feedback;

  /// No description provided for @feedback_type.
  ///
  /// In en, this message translates to:
  /// **'Feedback Type'**
  String get feedback_type;

  /// No description provided for @email_optional.
  ///
  /// In en, this message translates to:
  /// **'Email (Optional)'**
  String get email_optional;

  /// No description provided for @enter_email.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enter_email;

  /// No description provided for @feedback_message.
  ///
  /// In en, this message translates to:
  /// **'Feedback Message'**
  String get feedback_message;

  /// No description provided for @describe_feedback.
  ///
  /// In en, this message translates to:
  /// **'Describe your feedback or report an issue...'**
  String get describe_feedback;

  /// No description provided for @submit_feedback.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get submit_feedback;

  /// No description provided for @enable_biometric_auth.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Sign-In'**
  String get enable_biometric_auth;

  /// No description provided for @biometric_setup_message.
  ///
  /// In en, this message translates to:
  /// **'Would you like to enable fingerprint or face recognition for faster and more secure access to your account next time?'**
  String get biometric_setup_message;

  /// No description provided for @dont_ask_again.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get dont_ask_again;

  /// No description provided for @biometric_enabled_success.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication enabled successfully'**
  String get biometric_enabled_success;

  /// No description provided for @biometric_setup_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable biometric authentication'**
  String get biometric_setup_failed;

  /// No description provided for @use_biometric_auth.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Biometrics'**
  String get use_biometric_auth;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @alive_meet.
  ///
  /// In en, this message translates to:
  /// **'ALIVE Meet'**
  String get alive_meet;

  /// No description provided for @recipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipes;

  /// No description provided for @bod_trustees.
  ///
  /// In en, this message translates to:
  /// **'BOD Trustees'**
  String get bod_trustees;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @bible_game.
  ///
  /// In en, this message translates to:
  /// **'Bible Game'**
  String get bible_game;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @podcasts.
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get podcasts;

  /// No description provided for @lessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessons;

  /// No description provided for @testimonies.
  ///
  /// In en, this message translates to:
  /// **'Testimonies'**
  String get testimonies;

  /// No description provided for @kids_stories.
  ///
  /// In en, this message translates to:
  /// **'Kids Stories'**
  String get kids_stories;

  /// No description provided for @kids_mission.
  ///
  /// In en, this message translates to:
  /// **'Kids Mission'**
  String get kids_mission;

  /// No description provided for @submit_recipe.
  ///
  /// In en, this message translates to:
  /// **'Submit Recipe'**
  String get submit_recipe;

  /// No description provided for @tools_games.
  ///
  /// In en, this message translates to:
  /// **'Tools & Games'**
  String get tools_games;

  /// No description provided for @content_tools.
  ///
  /// In en, this message translates to:
  /// **'Content Tools'**
  String get content_tools;

  /// No description provided for @content_management.
  ///
  /// In en, this message translates to:
  /// **'Content Management'**
  String get content_management;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @user_archive.
  ///
  /// In en, this message translates to:
  /// **'User Archive'**
  String get user_archive;

  /// No description provided for @role_management.
  ///
  /// In en, this message translates to:
  /// **'Role Management'**
  String get role_management;

  /// No description provided for @auto_theme.
  ///
  /// In en, this message translates to:
  /// **'Auto Theme'**
  String get auto_theme;

  /// No description provided for @light_mode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get light_mode;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @one_time.
  ///
  /// In en, this message translates to:
  /// **'One-Time'**
  String get one_time;

  /// No description provided for @giving_method.
  ///
  /// In en, this message translates to:
  /// **'Giving Method'**
  String get giving_method;

  /// No description provided for @enter_amount_monthly.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount to give monthly'**
  String get enter_amount_monthly;

  /// No description provided for @enter_amount_one_time.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount to give one time'**
  String get enter_amount_one_time;

  /// No description provided for @enter_amount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get enter_amount;

  /// No description provided for @cover_processing_fees.
  ///
  /// In en, this message translates to:
  /// **'Cover processing fees'**
  String get cover_processing_fees;

  /// No description provided for @custom_amount.
  ///
  /// In en, this message translates to:
  /// **'Custom Amount'**
  String get custom_amount;

  /// No description provided for @selected_fund_designations.
  ///
  /// In en, this message translates to:
  /// **'Selected Fund Designations'**
  String get selected_fund_designations;

  /// No description provided for @designated.
  ///
  /// In en, this message translates to:
  /// **'Designated'**
  String get designated;

  /// No description provided for @split_donation.
  ///
  /// In en, this message translates to:
  /// **'Split Donation'**
  String get split_donation;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @total_amount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get total_amount;

  /// No description provided for @start_monthly_giving.
  ///
  /// In en, this message translates to:
  /// **'Start Monthly Giving'**
  String get start_monthly_giving;

  /// No description provided for @donate_one_time.
  ///
  /// In en, this message translates to:
  /// **'Donate One-Time'**
  String get donate_one_time;

  /// No description provided for @donation_help_text.
  ///
  /// In en, this message translates to:
  /// **'Your donation helps make the life-changing wisdom of the Bible accessible to all.'**
  String get donation_help_text;

  /// No description provided for @your_details.
  ///
  /// In en, this message translates to:
  /// **'Your Details'**
  String get your_details;

  /// No description provided for @email_address.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get email_address;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @non_monetary.
  ///
  /// In en, this message translates to:
  /// **'Non-Monetary'**
  String get non_monetary;

  /// No description provided for @active_projects.
  ///
  /// In en, this message translates to:
  /// **'Active Projects'**
  String get active_projects;

  /// No description provided for @something_bigger.
  ///
  /// In en, this message translates to:
  /// **'You Can Be a Part of Something Bigger.'**
  String get something_bigger;

  /// No description provided for @ministry_years_intro.
  ///
  /// In en, this message translates to:
  /// **'For more than {years} years, ALIVE Nigeria Ministries has helped connect thousands of people with God\'s word and established churches around Nigeria.'**
  String ministry_years_intro(Object years);

  /// No description provided for @ministry_years_outro.
  ///
  /// In en, this message translates to:
  /// **'We can help connect new generations to the life-changing wisdom of the Bible.'**
  String get ministry_years_outro;

  /// No description provided for @impact_rural_missions.
  ///
  /// In en, this message translates to:
  /// **'Rural Missions'**
  String get impact_rural_missions;

  /// No description provided for @impact_rural_missions_desc.
  ///
  /// In en, this message translates to:
  /// **'Send teams to remote communities with the Gospel and compassionate care.'**
  String get impact_rural_missions_desc;

  /// No description provided for @impact_campus_missions.
  ///
  /// In en, this message translates to:
  /// **'Campus/City Missions'**
  String get impact_campus_missions;

  /// No description provided for @impact_campus_missions_desc.
  ///
  /// In en, this message translates to:
  /// **'Send teams to Campus/City communities with the Gospel and compassionate care.'**
  String get impact_campus_missions_desc;

  /// No description provided for @impact_missionary_training.
  ///
  /// In en, this message translates to:
  /// **'Missionary Training'**
  String get impact_missionary_training;

  /// No description provided for @impact_missionary_training_desc.
  ///
  /// In en, this message translates to:
  /// **'Equip and train the next generation of Groundbreakers and Missionaries for effective witness.'**
  String get impact_missionary_training_desc;

  /// No description provided for @impact_health_evangelism.
  ///
  /// In en, this message translates to:
  /// **'Health Evangelism'**
  String get impact_health_evangelism;

  /// No description provided for @impact_health_evangelism_desc.
  ///
  /// In en, this message translates to:
  /// **'Provide medical care that opens hearts to the transforming power of the Gospel.'**
  String get impact_health_evangelism_desc;

  /// No description provided for @impact_education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get impact_education;

  /// No description provided for @impact_education_desc.
  ///
  /// In en, this message translates to:
  /// **'Support schools and educational programs that empower communities.'**
  String get impact_education_desc;

  /// No description provided for @selected_for_gift.
  ///
  /// In en, this message translates to:
  /// **'Selected for this Gift'**
  String get selected_for_gift;

  /// No description provided for @tap_to_add_to_gift.
  ///
  /// In en, this message translates to:
  /// **'Tap to add to gift allocation'**
  String get tap_to_add_to_gift;

  /// No description provided for @split_donation_multiple.
  ///
  /// In en, this message translates to:
  /// **'Split donation between multiple ministries'**
  String get split_donation_multiple;

  /// No description provided for @choose_funds.
  ///
  /// In en, this message translates to:
  /// **'Choose Funds'**
  String get choose_funds;

  /// No description provided for @project_goal.
  ///
  /// In en, this message translates to:
  /// **'Project Goal'**
  String get project_goal;

  /// No description provided for @progress_made.
  ///
  /// In en, this message translates to:
  /// **'Progress Made'**
  String get progress_made;

  /// No description provided for @raised_of.
  ///
  /// In en, this message translates to:
  /// **'raised of'**
  String get raised_of;

  /// No description provided for @explore_project_3d.
  ///
  /// In en, this message translates to:
  /// **'Explore the project in 3D'**
  String get explore_project_3d;

  /// No description provided for @what_your_giving_has_done.
  ///
  /// In en, this message translates to:
  /// **'What your giving has done'**
  String get what_your_giving_has_done;

  /// No description provided for @no_designation.
  ///
  /// In en, this message translates to:
  /// **'No specific designation'**
  String get no_designation;

  /// No description provided for @added_to_gift.
  ///
  /// In en, this message translates to:
  /// **'Added to gift allocation'**
  String get added_to_gift;

  /// No description provided for @could_not_add_designation.
  ///
  /// In en, this message translates to:
  /// **'Could not add designation'**
  String get could_not_add_designation;

  /// No description provided for @custom_designation_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ondo Medical Outreach, Tract printing'**
  String get custom_designation_hint;

  /// No description provided for @add_fund.
  ///
  /// In en, this message translates to:
  /// **'Add Fund'**
  String get add_fund;

  /// No description provided for @please_enter_amount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get please_enter_amount;

  /// No description provided for @invalid_amount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get invalid_amount;

  /// No description provided for @donation_processing.
  ///
  /// In en, this message translates to:
  /// **'Processing your donation...'**
  String get donation_processing;

  /// No description provided for @donation_success_title.
  ///
  /// In en, this message translates to:
  /// **'Thank You!'**
  String get donation_success_title;

  /// No description provided for @donation_success_message.
  ///
  /// In en, this message translates to:
  /// **'Your donation has been processed successfully.'**
  String get donation_success_message;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ha', 'ig', 'yo'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ha':
      return AppLocalizationsHa();
    case 'ig':
      return AppLocalizationsIg();
    case 'yo':
      return AppLocalizationsYo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
