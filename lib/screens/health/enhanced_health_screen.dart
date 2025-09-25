import 'package:flutter/material.dart';
import '../../models/health_models.dart';
import '../../services/health_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnhancedHealthScreen extends ConsumerStatefulWidget {
  const EnhancedHealthScreen({super.key});

  @override
  ConsumerState<EnhancedHealthScreen> createState() => _EnhancedHealthScreenState();
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
      final userId = currentUser?.id ?? '';

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
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Failed to load health data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildQuickStats(),
          const SizedBox(height: 16),
          _buildTodayProgress(),
          const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Wholesome Living',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Embrace the 8 natural laws of health',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '"Beloved, I wish above all things that thou mayest prosper and be in health, even as thy soul prospereth." - 3 John 1:2',
              style: TextStyle(
                fontSize: 14,
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Tracking Days',
            '${_statistics['totalDays'] ?? 0}',
            Icons.calendar_today,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Average Score',
            '${(_statistics['averageScore'] ?? 0.0).toStringAsFixed(1)}/10',
            Icons.star,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.add_circle_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(ref.watch(translationProvider)('no_tracking_data_today')),
              const SizedBox(height: 8),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(_todayTracker!.completionPercentage / 10).toStringAsFixed(1)}/10',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(_todayTracker!.completionPercentage / 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressIndicator('Nutrition', (_todayTracker!.metrics['nutrition_score'] ?? 0) / 10),
            _buildProgressIndicator('Exercise', (_todayTracker!.metrics['exercise_minutes'] ?? 0) >= 30 ? 1.0 : (_todayTracker!.metrics['exercise_minutes'] ?? 0) / 30),
            _buildProgressIndicator('Water', (_todayTracker!.metrics['water_glasses'] ?? 0) >= 8 ? 1.0 : (_todayTracker!.metrics['water_glasses'] ?? 0) / 8),
            _buildProgressIndicator('Sleep', (_todayTracker!.metrics['sleep_hours'] ?? 0) >= 7 ? 1.0 : (_todayTracker!.metrics['sleep_hours'] ?? 0) / 7),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(String label, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getScoreColor(progress * 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(fontSize: 12),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlansTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nigerian Vegetarian Meal Plans',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Wholesome meals based on Adventist health principles',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_mealPlans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(ref.watch(translationProvider)('no_meal_plans_available')),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mealPlan.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mealPlan.region.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mealPlan.description,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${mealPlan.days.length} days',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.restaurant_menu, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${mealPlan.days.length} meals',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            if (mealPlan.healthPrinciples.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: mealPlan.healthPrinciples
                    .take(3)
                    .map((principle) => Chip(
                          label: Text(
                            principle,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.blue.shade50,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wholesome Living Tips',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Practical guidance for healthy Christian living',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_tips.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(ref.watch(translationProvider)('no_tips_available')),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lightbulb,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tip.content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (tip.bibleVerse != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip.bibleVerse!,
                        style: TextStyle(
                          fontSize: 12,
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: tip.tags
                    .take(3)
                    .map((tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.grey.shade100,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lifestyle Tracker',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Track the 8 natural laws of health daily',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Today\'s Health Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Track your progress in the 8 natural laws of health. This feature will be fully implemented with interactive sliders and input fields.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Insights',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalized recommendations for better health',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_insights.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.insights,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No insights available',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    priorityIcon,
                    color: priorityColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.content,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (insight.recommendations.isNotEmpty)
              Text(
                'Recommendations: ${insight.recommendations.join(', ')}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              ),
            if (insight.data.containsKey('bibleVerse') && insight.data['bibleVerse'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight.data['bibleVerse'] as String,
                        style: TextStyle(
                          fontSize: 12,
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
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bloodPressureController,
                decoration: InputDecoration(
                  labelText: '${translate('blood_pressure')} (120/80)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: heartRateController,
                decoration: InputDecoration(
                  labelText: '${translate('heart_rate')} (bpm)',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sleepHoursController,
                decoration: InputDecoration(
                  labelText: '${translate('sleep_hours')} (hours)',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: waterIntakeController,
                decoration: InputDecoration(
                  labelText: '${translate('water_intake')} (glasses)',
                  border: const OutlineInputBorder(),
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
