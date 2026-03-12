import 'package:flutter/material.dart';
import '../../models/health_models.dart';
import '../../services/health_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnhancedHealthScreen extends ConsumerStatefulWidget {
  const EnhancedHealthScreen({super.key});

  @override
  ConsumerState<EnhancedHealthScreen> createState() =>
      _EnhancedHealthScreenState();
}

class _EnhancedHealthScreenState extends ConsumerState<EnhancedHealthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final HealthService _healthService = HealthService();

  List<NigerianMealPlan> _mealPlans = [];
  List<WholesomeLivingTip> _tips = [];
  LifestyleTracker? _todayTracker;
  List<HealthInsight> _insights = [];
  Map<String, dynamic> _statistics = {};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadHealthData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = ref.read(currentUserProvider);
      final userId = currentUser?.uid ?? '';

      // Load all health data concurrently
      final results = await Future.wait([
        _healthService.getFeaturedMealPlans(),
        _healthService.fetchWholesomeTips(limit: 10),
        _healthService.getTodayLifestyleTracker(userId),
        _healthService.generateHealthInsights(userId),
        _healthService.getHealthStatistics(userId),
      ]);

      setState(() {
        _mealPlans = results[0] as List<NigerianMealPlan>;
        _tips = results[1] as List<WholesomeLivingTip>;
        _todayTracker = results[2] as LifestyleTracker?;
        _insights = results[3] as List<HealthInsight>;
        _statistics = results[4] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('health_wellness')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.restaurant), text: 'Meal Plans'),
            Tab(icon: Icon(Icons.lightbulb), text: 'Tips'),
            Tab(icon: Icon(Icons.track_changes), text: 'Tracker'),
            Tab(icon: Icon(Icons.insights), text: 'Insights'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildMealPlansTab(),
                    _buildTipsTab(),
                    _buildTrackerTab(),
                    _buildInsightsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    final translate = ref.watch(translationProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: context.responsiveIconSize(64), color: Colors.red.shade300),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
          Text(
            'Failed to load health data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
          Text(
            _error ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
          ElevatedButton(
            onPressed: _loadHealthData,
            child: Text(translate('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
          _buildQuickStats(),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
          _buildTodayProgress(),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0)),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0)),
        decoration: BoxDecoration(
          borderRadius: context.responsiveBorderRadius,
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Wholesome Living',
              style: TextStyle(
                fontSize: context.responsiveFontSize(24),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0)),
            Text(
              'Embrace the 8 natural laws of health',
              style: TextStyle(
                fontSize: context.responsiveFontSize(16),
                color: Colors.white70,
              ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0)),
            Text(
              '"Beloved, I wish above all things that thou mayest prosper and be in health, even as thy soul prospereth." - 3 John 1:2',
              style: TextStyle(
                fontSize: context.responsiveFontSize(14),
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return LayoutFixUtils.safeRow(
      children: [
        Expanded(
          child: _buildStatCard(
            'Tracking Days',
            '${_statistics['totalDays'] ?? 0}',
            Icons.calendar_today,
            Colors.blue,
          ),
        ),
        SizedBox(
            width: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        Expanded(
          child: _buildStatCard(
            'Average Score',
            '${(_statistics['averageScore'] ?? 0.0).toStringAsFixed(1)}/10',
            Icons.star,
            Colors.orange,
          ),
        ),
        SizedBox(
            width: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
        Expanded(
          child: _buildStatCard(
            'Current Streak',
            '${_statistics['streakDays'] ?? 0} days',
            Icons.local_fire_department,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          children: [
            Icon(icon, color: color, size: context.responsiveIconSize(32)),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0)),
            Text(
              value,
              style: TextStyle(
                fontSize: context.responsiveFontSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0)),
            Text(
              title,
              style: TextStyle(
                fontSize: context.responsiveFontSize(12),
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayProgress() {
    if (_todayTracker == null) {
      return Card(
        child: Padding(
          padding: context.responsivePadding,
          child: Column(
            children: [
              Icon(Icons.add_circle_outline,
                  size: context.responsiveIconSize(48),
                  color: Colors.grey.shade400),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0)),
              Text(ref.watch(translationProvider)('no_tracking_data_today')),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0)),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(3),
                child: Text(ref.watch(translationProvider)('start_tracking')),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutFixUtils.safeRow(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LayoutFixUtils.safeText(
                  'Today\'s Progress',
                  style: TextStyle(
                      fontSize: context.responsiveFontSize(18),
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(_todayTracker!.completionPercentage / 10).toStringAsFixed(1)}/10',
                  style: TextStyle(
                    fontSize: context.responsiveFontSize(16),
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(
                        _todayTracker!.completionPercentage / 10),
                  ),
                ),
              ],
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            _buildProgressIndicator('Nutrition',
                (_todayTracker!.metrics['nutrition_score'] ?? 0) / 10),
            _buildProgressIndicator(
                'Exercise',
                (_todayTracker!.metrics['exercise_minutes'] ?? 0) >= 30
                    ? 1.0
                    : (_todayTracker!.metrics['exercise_minutes'] ?? 0) / 30),
            _buildProgressIndicator(
                'Water',
                (_todayTracker!.metrics['water_glasses'] ?? 0) >= 8
                    ? 1.0
                    : (_todayTracker!.metrics['water_glasses'] ?? 0) / 8),
            _buildProgressIndicator(
                'Sleep',
                (_todayTracker!.metrics['sleep_hours'] ?? 0) >= 7
                    ? 1.0
                    : (_todayTracker!.metrics['sleep_hours'] ?? 0) / 7),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(String label, double progress) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 4, tablet: 6, desktop: 8)),
      child: LayoutFixUtils.safeRow(
        children: [
          SizedBox(
            width: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 80, tablet: 90, desktop: 100),
            child: LayoutFixUtils.safeText(label,
                style: TextStyle(fontSize: context.responsiveFontSize(12))),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getScoreColor(progress * 10),
              ),
            ),
          ),
          SizedBox(
              width: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(fontSize: context.responsiveFontSize(12)),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return Colors.red;
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                  fontSize: context.responsiveFontSize(18),
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  'Meal Plans',
                  Icons.restaurant_menu,
                  Colors.green,
                  () => _tabController.animateTo(1),
                ),
                _buildActionButton(
                  'Daily Tips',
                  Icons.lightbulb_outline,
                  Colors.blue,
                  () => _tabController.animateTo(2),
                ),
                _buildActionButton(
                  'Track Today',
                  Icons.add_circle,
                  Colors.orange,
                  () => _tabController.animateTo(3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: context.responsivePadding,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: context.responsiveBorderRadius,
            ),
            child:
                Icon(icon, color: color, size: context.responsiveIconSize(32)),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            label,
            style: TextStyle(fontSize: context.responsiveFontSize(12)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlansTab() {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nigerian Vegetarian Meal Plans',
            style: TextStyle(
                fontSize: context.responsiveFontSize(20),
                fontWeight: FontWeight.bold),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            'Wholesome meals based on Adventist health principles',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
          if (_mealPlans.isEmpty)
            Center(
              child: Padding(
                padding: context.responsivePadding,
                child: Text(
                    ref.watch(translationProvider)('no_meal_plans_available')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mealPlans.length,
              itemBuilder: (context, index) {
                final mealPlan = _mealPlans[index];
                return _buildMealPlanCard(mealPlan);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMealPlanCard(NigerianMealPlan mealPlan) {
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 12, tablet: 16, desktop: 20)),
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mealPlan.title,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 8, tablet: 10, desktop: 12),
                      vertical: ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 4, tablet: 6, desktop: 8)),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: context.responsiveBorderRadius,
                  ),
                  child: Text(
                    mealPlan.region.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(10),
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              mealPlan.description,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20)),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: context.responsiveIconSize(16),
                    color: Colors.grey.shade600),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  '${mealPlan.days.length} days',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: context.responsiveFontSize(12)),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 20, desktop: 24)),
                Icon(Icons.restaurant_menu,
                    size: context.responsiveIconSize(16),
                    color: Colors.grey.shade600),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 4, tablet: 6, desktop: 8)),
                Text(
                  '${mealPlan.days.length} meals',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: context.responsiveFontSize(12)),
                ),
              ],
            ),
            if (mealPlan.healthPrinciples.isNotEmpty) ...[
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 8, tablet: 10, desktop: 12)),
              Wrap(
                spacing: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 4, tablet: 6, desktop: 8),
                children: mealPlan.healthPrinciples
                    .take(3)
                    .map((principle) => Chip(
                          label: Text(
                            principle,
                            style: TextStyle(
                                fontSize: context.responsiveFontSize(10)),
                          ),
                          backgroundColor: Colors.blue.shade50,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTipsTab() {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wholesome Living Tips',
            style: TextStyle(
                fontSize: context.responsiveFontSize(20),
                fontWeight: FontWeight.bold),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            'Practical guidance for healthy Christian living',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
          if (_tips.isEmpty)
            Center(
              child: Padding(
                padding: context.responsivePadding,
                child:
                    Text(ref.watch(translationProvider)('no_tips_available')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tips.length,
              itemBuilder: (context, index) {
                final tip = _tips[index];
                return _buildTipCard(tip);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTipCard(WholesomeLivingTip tip) {
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 12, tablet: 16, desktop: 20)),
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: context.responsivePadding,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: context.responsiveBorderRadius,
                  ),
                  child: Icon(
                    Icons.lightbulb,
                    color: Colors.blue.shade700,
                    size: context.responsiveIconSize(20),
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 12, tablet: 16, desktop: 20)),
                Expanded(
                  child: Text(
                    tip.title,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20)),
            Text(
              tip.content,
              style: TextStyle(
                  fontSize: context.responsiveFontSize(14), height: 1.5),
            ),
            if (tip.bibleVerse != null) ...[
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              Container(
                padding: context.responsivePadding,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: context.responsiveBorderRadius,
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: Colors.green.shade700,
                      size: context.responsiveIconSize(16),
                    ),
                    SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12)),
                    Expanded(
                      child: Text(
                        tip.bibleVerse!,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(12),
                          fontStyle: FontStyle.italic,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (tip.tags.isNotEmpty) ...[
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 8, tablet: 10, desktop: 12)),
              Wrap(
                spacing: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 4, tablet: 6, desktop: 8),
                children: tip.tags
                    .take(3)
                    .map((tag) => Chip(
                          label: Text(
                            tag,
                            style: TextStyle(
                                fontSize: context.responsiveFontSize(10)),
                          ),
                          backgroundColor: Colors.grey.shade100,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackerTab() {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lifestyle Tracker',
            style: TextStyle(
                fontSize: context.responsiveFontSize(20),
                fontWeight: FontWeight.bold),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            'Track the 8 natural laws of health daily',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
          _buildTrackerForm(),
        ],
      ),
    );
  }

  Widget _buildTrackerForm() {
    // This would be a comprehensive form for tracking all 8 natural laws
    // For brevity, showing a simplified version
    return Card(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          children: [
            Text(
              'Today\'s Health Tracking',
              style: TextStyle(
                  fontSize: context.responsiveFontSize(18),
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            const Text(
              'Track your progress in the 8 natural laws of health. This feature will be fully implemented with interactive sliders and input fields.',
              textAlign: TextAlign.center,
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
            ElevatedButton(
              onPressed: () {
                _showHealthTrackerForm(context, ref.watch(translationProvider));
              },
              child: Text(ref.watch(translationProvider)('start_tracking')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Insights',
            style: TextStyle(
                fontSize: context.responsiveFontSize(20),
                fontWeight: FontWeight.bold),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            'Personalized recommendations for better health',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
          if (_insights.isEmpty)
            Card(
              child: Padding(
                padding: context.responsivePadding,
                child: Column(
                  children: [
                    Icon(
                      Icons.insights,
                      size: context.responsiveIconSize(48),
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24)),
                    Text(
                      'No insights available',
                      style:
                          TextStyle(fontSize: context.responsiveFontSize(16)),
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12)),
                    const Text(
                      'Start tracking your health to receive personalized insights',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _insights.length,
              itemBuilder: (context, index) {
                final insight = _insights[index];
                return _buildInsightCard(insight);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(HealthInsight insight) {
    Color priorityColor;
    IconData priorityIcon;

    // Use category to determine priority color
    switch (insight.category.toLowerCase()) {
      case 'urgent':
      case 'critical':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'warning':
      case 'moderate':
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      default:
        priorityColor = Colors.blue;
        priorityIcon = Icons.info;
    }

    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 12, tablet: 16, desktop: 20)),
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: context.responsivePadding,
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: context.responsiveBorderRadius,
                  ),
                  child: Icon(
                    priorityIcon,
                    color: priorityColor,
                    size: context.responsiveIconSize(20),
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 12, tablet: 16, desktop: 20)),
                Expanded(
                  child: Text(
                    insight.title,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 12, tablet: 16, desktop: 20)),
            Text(
              insight.content,
              style: TextStyle(fontSize: context.responsiveFontSize(14)),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 8, tablet: 10, desktop: 12)),
            if (insight.recommendations.isNotEmpty)
              Text(
                'Recommendations: ${insight.recommendations.join(', ')}',
                style: TextStyle(
                  fontSize: context.responsiveFontSize(14),
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              ),
            if (insight.data.containsKey('bibleVerse') &&
                insight.data['bibleVerse'] != null) ...[
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              Container(
                padding: context.responsivePadding,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: context.responsiveBorderRadius,
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: Colors.blue.shade700,
                      size: context.responsiveIconSize(16),
                    ),
                    SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 8,
                            tablet: 10,
                            desktop: 12)),
                    Expanded(
                      child: Text(
                        insight.data['bibleVerse'] as String,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(12),
                          fontStyle: FontStyle.italic,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showHealthTrackerForm(BuildContext context, Function translate) {
    final weightController = TextEditingController();
    final bloodPressureController = TextEditingController();
    final heartRateController = TextEditingController();
    final sleepHoursController = TextEditingController();
    final waterIntakeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('health_tracker_form')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                decoration: InputDecoration(
                  labelText: '${translate('weight')} (kg)',
                  border: OutlineInputBorder(
                    borderRadius: context.responsiveBorderRadius,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              TextField(
                controller: bloodPressureController,
                decoration: InputDecoration(
                  labelText: '${translate('blood_pressure')} (120/80)',
                  border: OutlineInputBorder(
                    borderRadius: context.responsiveBorderRadius,
                  ),
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              TextField(
                controller: heartRateController,
                decoration: InputDecoration(
                  labelText: '${translate('heart_rate')} (bpm)',
                  border: OutlineInputBorder(
                    borderRadius: context.responsiveBorderRadius,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              TextField(
                controller: sleepHoursController,
                decoration: InputDecoration(
                  labelText: '${translate('sleep_hours')} (hours)',
                  border: OutlineInputBorder(
                    borderRadius: context.responsiveBorderRadius,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              TextField(
                controller: waterIntakeController,
                decoration: InputDecoration(
                  labelText: '${translate('water_intake')} (glasses)',
                  border: OutlineInputBorder(
                    borderRadius: context.responsiveBorderRadius,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(translate('health_data_saved')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(translate('save')),
          ),
        ],
      ),
    );
  }
}
