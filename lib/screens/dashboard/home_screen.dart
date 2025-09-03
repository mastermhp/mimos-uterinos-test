import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/models/user_data.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/screens/ai_features/ai_coach_screen.dart';
import 'package:menstrual_health_ai/screens/auth/login_screen.dart';
import 'package:menstrual_health_ai/screens/cycle/cycle_calendar_screen.dart';
import 'package:menstrual_health_ai/screens/cycle/log_symptoms_screen.dart';
import 'package:menstrual_health_ai/screens/doctor/doctor_mode_screen.dart';
import 'package:menstrual_health_ai/screens/premium/premium_screen.dart';
import 'package:menstrual_health_ai/screens/reminders/reminders_screen.dart';
import 'package:menstrual_health_ai/services/ai_service.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/screens/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AIService _aiService = AIService();
  List<String> _aiInsights = [];
  bool _isLoadingInsights = true;
  bool _showReminders = false;
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoadingReminders = true;
  Map<String, dynamic> _predictions = {};
  bool _isLoadingPredictions = true;
  Map<String, dynamic> _recommendations = {};
  bool _isLoadingRecommendations = true;
  DateTime _selectedDate = DateTime.now();

  // Added new state variables for API data
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;
  List<dynamic> _recentCycles = [];
  List<dynamic> _recentSymptoms = [];
  List<dynamic> _doctorConsultations = [];
  Map<String, dynamic>? _aiDashboardInsights;

  // Add cycle prediction variables (same as cycle calendar)
  List<DateTime> _periodDays = [];
  List<DateTime> _fertileDays = [];
  DateTime? _ovulationDay;
  DateTime? _nextPeriodDate;
  DateTime? _nextOvulationDate;
  int _currentCycleLength = 28;
  int _currentPeriodLength = 5;

  bool _isLoadingProfile = true;
  bool _isLoadingStats = true;
  bool _isLoadingCycles = true;
  bool _isLoadingSymptoms = true;
  bool _isLoadingConsultations = true;
  bool _isLoadingAIDashboardInsights = true;

  // Add these new state variables for journal recommendations
  List<Map<String, dynamic>> _journalRecommendations = [];
  bool _isLoadingJournalRecommendations = true;
  String _currentCyclePhase = "unknown";

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      print('🔄 Starting to load dashboard data...');

      // Load critical data first
      await Future.wait([
        _loadUserProfile(),
        _loadCycles(), // This calculates predictions
      ]);

      // Load remaining data in parallel
      await Future.wait([
        _loadUserStats(),
        _loadSymptoms(),
        _loadDoctorConsultations(),
        _loadJournalRecommendations(), // Add this new method
        _loadAIData(), // Local AI processing
      ]);

      // Load AI insights last (non-critical)
      await _loadAIDashboardInsights();

      print('✅ Dashboard data loading completed');
    } catch (e) {
      print('❌ Error in main data loading: $e');
      // Continue with available data
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoadingProfile = true;
      });

      print('🔄 Loading user profile...');
      final response = await ApiService.getUserProfile();

      if (response != null && response['success'] == true) {
        setState(() {
          _userProfile = response['data'];
          _isLoadingProfile = false;
        });

        print('✅ User profile loaded:');
        print('👤 Name: ${_userProfile?['name']}');
        print('📧 Email: ${_userProfile?['email']}');
        print('🩸 Cycle Length: ${_userProfile?['cycleLength']} days');
        print('🩸 Period Length: ${_userProfile?['periodLength']} days');
        print('📆 Last Period: ${_userProfile?['lastPeriodDate']}');
      } else {
        print('❌ Failed to load user profile');
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadUserStats() async {
    try {
      setState(() {
        _isLoadingStats = true;
      });

      print('🔄 Loading user statistics...');
      final response = await ApiService.getUserStats();

      if (response != null && response['success'] == true) {
        setState(() {
          _userStats = response['stats'];
          _isLoadingStats = false;
        });

        print('✅ User stats loaded:');
        print('📊 Cycles tracked: ${_userStats?['cyclesTracked']}');
        print('📏 Avg cycle length: ${_userStats?['avgCycleLength']} days');
        print('📏 Avg period length: ${_userStats?['avgPeriodLength']} days');
      } else {
        print('❌ Failed to load user statistics');
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user statistics: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadCycles() async {
    try {
      setState(() {
        _isLoadingCycles = true;
        _isLoadingPredictions = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        print('❌ Cannot load cycles: User ID is null');
        setState(() {
          _isLoadingCycles = false;
          _isLoadingPredictions = false;
        });
        return;
      }

      print('🔄 Loading cycles for user: $userId');
      final response = await ApiService.getCycles(userId: userId);

      if (response != null && response['success'] == true) {
        setState(() {
          _recentCycles = response['data'] ?? [];
          _isLoadingCycles = false;
        });

        print('✅ Cycles loaded: ${_recentCycles.length} cycles');

        // Calculate cycle predictions (same logic as cycle calendar)
        _calculateCycleDates();

        if (_recentCycles.isNotEmpty) {
          print('📅 Most recent cycle:');
          print('   Start date: ${_recentCycles[0]['startDate']}');
          print('   End date: ${_recentCycles[0]['endDate']}');
          print('   Length: ${_recentCycles[0]['cycleLength']} days');
        }
      } else {
        print('❌ Failed to load cycles');
        _loadDefaultCycleData();
      }
    } catch (e) {
      print('❌ Error loading cycles: $e');
      _loadDefaultCycleData();
    } finally {
      setState(() {
        _isLoadingCycles = false;
        _isLoadingPredictions = false;
      });
    }
  }

  void _calculateCycleDates() {
    if (_recentCycles.isEmpty) {
      _loadDefaultCycleData();
      return;
    }

    // Get the most recent cycle
    final lastCycle = _recentCycles.first;
    final startDate = DateTime.parse(lastCycle['startDate']);
    _currentCycleLength = lastCycle['cycleLength'] ?? 28;
    _currentPeriodLength = lastCycle['periodLength'] ?? 5;

    // Calculate period days from all cycles
    _periodDays.clear();
    for (final cycle in _recentCycles) {
      final start = DateTime.parse(cycle['startDate']);
      final periodLength = cycle['periodLength'] ?? 5;

      for (int i = 0; i < periodLength; i++) {
        _periodDays.add(start.add(Duration(days: i)));
      }
    }

    // Calculate next period and ovulation dates
    _nextPeriodDate = startDate.add(Duration(days: _currentCycleLength));
    _nextOvulationDate =
        startDate.add(Duration(days: (_currentCycleLength / 2).round()));

    // Calculate fertile window (5 days before ovulation + ovulation day)
    _fertileDays.clear();
    if (_nextOvulationDate != null) {
      for (int i = 5; i >= 0; i--) {
        _fertileDays.add(_nextOvulationDate!.subtract(Duration(days: i)));
      }
      _ovulationDay = _nextOvulationDate;
    }

    // Update predictions with calculated data
    final nextPeriodText = _nextPeriodDate != null
        ? "Likely to start around ${DateFormat('MMM dd').format(_nextPeriodDate!)}"
        : "Loading prediction...";

    final ovulationText = _nextOvulationDate != null
        ? "Expected around ${DateFormat('MMM dd').format(_nextOvulationDate!)}"
        : "Calculating...";

    final fertileText = _fertileDays.isNotEmpty
        ? "${DateFormat('MMM dd').format(_fertileDays.first)}-${DateFormat('dd').format(_fertileDays.last)} (${_fertileDays.length} days)"
        : "Calculating...";

    setState(() {
      _predictions = {
        'nextPeriod': nextPeriodText,
        'ovulation': ovulationText,
        'fertileWindow': fertileText,
      };
    });

    print('📊 Calculated cycle predictions for home page:');
    print('  Next period: $nextPeriodText');
    print('  Next ovulation: $ovulationText');
    print('  Fertile window: $fertileText');
  }

  void _loadDefaultCycleData() {
    // Fallback to default data if no cycles available
    final today = DateTime.now();
    _nextPeriodDate = today.add(const Duration(days: 28));
    _nextOvulationDate = today.add(const Duration(days: 14));

    // Set default predictions
    setState(() {
      _predictions = {
        'nextPeriod': 'Track your cycle for predictions',
        'ovulation': 'Complete your profile first',
        'fertileWindow': 'Data needed for accurate prediction',
      };
    });
  }

  Future<void> _loadSymptoms() async {
    try {
      setState(() {
        _isLoadingSymptoms = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        print('❌ Cannot load symptoms: User ID is null');
        setState(() {
          _isLoadingSymptoms = false;
        });
        return;
      }

      print('🔄 Loading symptoms for user: $userId');
      final response = await ApiService.getSymptomLogs(userId: userId);

      if (response != null && response['success'] == true) {
        setState(() {
          _recentSymptoms = response['data'] ?? [];
          _isLoadingSymptoms = false;
        });

        print('✅ Symptoms loaded: ${_recentSymptoms.length} symptom logs');
        if (_recentSymptoms.isNotEmpty) {
          print('🤒 Most recent symptoms:');
          print('   Date: ${_recentSymptoms[0]['date']}');
          print('   Symptoms: ${_recentSymptoms[0]['symptoms']}');
        }
      } else {
        print('❌ Failed to load symptoms');
        setState(() {
          _isLoadingSymptoms = false;
        });
      }
    } catch (e) {
      print('❌ Error loading symptoms: $e');
      setState(() {
        _isLoadingSymptoms = false;
      });
    }
  }

  Future<void> _loadDoctorConsultations() async {
    try {
      setState(() {
        _isLoadingConsultations = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        print('❌ Cannot load consultations: User ID is null');
        setState(() {
          _isLoadingConsultations = false;
        });
        return;
      }

      print('🔄 Loading doctor consultations for user: $userId');
      final response = await ApiService.getDoctorConsultations(userId: userId);

      if (response != null && response['success'] == true) {
        setState(() {
          _doctorConsultations = response['data'] ?? [];
          _isLoadingConsultations = false;
        });

        print(
            '✅ Doctor consultations loaded: ${_doctorConsultations.length} consultations');
        if (_doctorConsultations.isNotEmpty) {
          print('👩‍⚕️ Upcoming consultation:');
          print('   Date: ${_doctorConsultations[0]['scheduledDate']}');
          print('   Status: ${_doctorConsultations[0]['status']}');
        }
      } else {
        print('❌ Failed to load doctor consultations');
        setState(() {
          _isLoadingConsultations = false;
        });
      }
    } catch (e) {
      print('❌ Error loading doctor consultations: $e');
      setState(() {
        _isLoadingConsultations = false;
      });
    }
  }

  Future<void> _loadAIDashboardInsights() async {
    try {
      setState(() {
        _isLoadingAIDashboardInsights = true;
      });

      print('🔄 Loading AI dashboard insights...');

      // Get the actual user ID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? '';

      // Direct API call without retry mechanism that's causing issues
      final response = await ApiService.getAIDashboardInsights(userId: userId);

      if (response != null && response['success'] == true) {
        setState(() {
          _aiDashboardInsights = response;
          _isLoadingAIDashboardInsights = false;
        });

        print('✅ AI insights loaded successfully');
        _processAIDashboardData(response);
      } else {
        print('❌ Failed to load AI dashboard insights - API response error');
        _handleAIInsightsError();
      }
    } catch (e) {
      print('❌ Error loading AI dashboard insights: $e');
      _handleAIInsightsError();
    }
  }

  Future<void> _loadJournalRecommendations() async {
    try {
      setState(() {
        _isLoadingJournalRecommendations = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        print('❌ Cannot load journal recommendations: User ID is null');
        _setFallbackJournalRecommendations();
        return;
      }

      print('🔄 Loading journal recommendations for user: $userId');
      final response =
          await ApiService.getJournalRecommendations(userId: userId);

      if (response != null && response['success'] == true) {
        setState(() {
          _journalRecommendations = List<Map<String, dynamic>>.from(
              response['data']['recommendations'] ?? []);
          _currentCyclePhase = response['data']['cyclePhase'] ?? 'unknown';
          _isLoadingJournalRecommendations = false;
        });

        print(
            '✅ Journal recommendations loaded: ${_journalRecommendations.length} items');
        print('🔄 Current cycle phase: $_currentCyclePhase');
      } else {
        print('❌ Failed to load journal recommendations');
        _setFallbackJournalRecommendations();
      }
    } catch (e) {
      print('❌ Error loading journal recommendations: $e');
      _setFallbackJournalRecommendations();
    }
  }

  void _setFallbackJournalRecommendations() {
    setState(() {
      _journalRecommendations = [
        {
          'id': 'cramp-relief',
          'title': 'Coping with cramps',
          'subtitle': 'Quick pain relief tips',
          'content':
              'Heat therapy, gentle movement, and anti-inflammatory foods can provide natural cramp relief during your menstrual cycle.',
          'category': 'pain-relief',
          'thumbnail': '🔥',
          'image': 'assets/images/jornal1.png',
          'readTime': '4 min read',
          'tips': [
            'Quick pain relief tips',
            'What\'s causing your cramps',
            'Natural remedies that work',
          ],
          'publishedDate': '2 days ago',
          'isFeatured': true,
        },
        {
          'id': 'cycle-tracking',
          'title': 'Managing Multiple Symptoms: Breast...',
          'subtitle': 'Understanding your unique patterns',
          'content':
              'Regular cycle tracking helps you understand your body\'s patterns and predict how you might feel throughout your cycle.',
          'category': 'education',
          'thumbnail': '📊',
          'image': 'assets/images/jornal2.png',
          'readTime': '10 min read',
          'publishedDate': '1 week ago',
        },
        {
          'id': 'mood-management',
          'title': 'Managing Multiple Symptoms:...',
          'subtitle': 'Emotional wellness during your cycle',
          'content':
              'Understanding and managing emotional changes throughout your menstrual cycle with practical strategies.',
          'category': 'mood',
          'thumbnail': '💭',
          'image': 'assets/images/jornal3.png',
          'readTime': '9 min read',
          'publishedDate': '3 days ago',
        },
      ];
      _currentCyclePhase = 'menstrual';
      _isLoadingJournalRecommendations = false;
    });
  }

  String _getPhaseMessage() {
    switch (_currentCyclePhase) {
      case 'menstrual':
        return 'During period';
      case 'follicular':
        return 'Follicular phase';
      case 'ovulation':
        return 'Ovulation phase';
      case 'luteal':
        return 'Luteal phase';
      default:
        return 'During period';
    }
  }

  // ADD THIS MISSING METHOD
  String _getCycleStatusText() {
    if (_nextPeriodDate != null) {
      final today = DateTime.now();
      final daysUntilPeriod = _nextPeriodDate!.difference(today).inDays;
      
      if (daysUntilPeriod > 0) {
        return 'Day ${_getCurrentCycleDay()} • $daysUntilPeriod days until next period';
      } else if (daysUntilPeriod == 0) {
        return 'Period expected today';
      } else {
        // Period might be late
        final lateDays = -daysUntilPeriod;
        return 'Period is $lateDays days late';
      }
    } else {
      return 'Track your cycle for insights';
    }
  }

  // ADD THIS HELPER METHOD TOO
  int _getCurrentCycleDay() {
    if (_userProfile == null) return 17; // Default day from your image

    final lastPeriodDateString = _userProfile?['lastPeriodDate'];
    if (lastPeriodDateString == null) return 17;

    final lastPeriodDate = DateTime.tryParse(lastPeriodDateString);
    if (lastPeriodDate == null) return 17;

    final today = DateTime.now();
    final daysSinceLastPeriod = today.difference(lastPeriodDate).inDays + 1;
    
    // Make sure we return a positive day number
    return daysSinceLastPeriod > 0 ? daysSinceLastPeriod : 17;
  }

  int _getCurrentCycleDayForPhase() {
    if (_userProfile == null) return 1;

    final lastPeriodDateString = _userProfile?['lastPeriodDate'];
    final cycleLength = _userProfile?['cycleLength'] ?? 28;

    if (lastPeriodDateString == null) return 1;

    final lastPeriodDate = DateTime.tryParse(lastPeriodDateString);
    if (lastPeriodDate == null) return 1;

    final today = DateTime.now();
    final daysSinceLastPeriod = today.difference(lastPeriodDate).inDays;
    return ((daysSinceLastPeriod % cycleLength) + 1).toInt();
  }

  void _processAIDashboardData(Map<String, dynamic> response) {
    try {
      // Update the AI insights from backend - use the actual insights field
      if (response['insights'] != null) {
        _aiInsights = [response['insights'].toString()];
        print('✅ Processed insights: ${response['insights']}');
      }

      // Update predictions only if cycle data is not available
      if (response['cyclePredictions'] != null && _recentCycles.isEmpty) {
        _predictions = {
          'nextPeriod': response['cyclePredictions'].toString(),
          'ovulation': 'Coming soon',
          'fertileWindow': 'Coming soon',
        };
        print('✅ Updated predictions from AI');
      }

      // Parse and update recommendations if available
      if (response['recommendations'] != null) {
        _processRecommendations(response['recommendations']);
      } else {
        print('⚠️ No recommendations in response, using fallback');
        _setFallbackRecommendations();
      }
    } catch (e) {
      print('❌ Error processing AI dashboard data: $e');
      _setFallbackRecommendations();
    }
  }

  void _processRecommendations(dynamic recommendationsData) {
    try {
      final recommendationsList = recommendationsData as List;
      if (recommendationsList.isNotEmpty) {
        // Create separate categories for recommendations
        final nutritionRecs = recommendationsList
            .where((item) => item['category'] == 'Nutrition')
            .map((item) => item['text'].toString())
            .toList();

        final exerciseRecs = recommendationsList
            .where((item) => item['category'] == 'Exercise')
            .map((item) => item['text'].toString())
            .toList();

        final sleepRecs = recommendationsList
            .where((item) => item['category'] == 'Sleep')
            .map((item) => item['text'].toString())
            .toList();

        final selfCareRecs = recommendationsList
            .where((item) => item['category'] == 'Self-Care')
            .map((item) => item['text'].toString())
            .toList();

        // Update the recommendations map
        _recommendations = {
          'nutrition': nutritionRecs.isNotEmpty
              ? nutritionRecs
              : ['Focus on iron-rich foods during menstruation'],
          'exercise': exerciseRecs.isNotEmpty
              ? exerciseRecs
              : ['Light yoga or walking can help with cramps'],
          'sleep': sleepRecs.isNotEmpty
              ? sleepRecs
              : ['Aim for 7-8 hours of quality sleep'],
          'selfCare': selfCareRecs.isNotEmpty
              ? selfCareRecs
              : ['Practice relaxation techniques'],
        };

        print('✅ Successfully processed recommendations by category');
      } else {
        print('⚠️ Empty recommendations list, using fallback');
        _setFallbackRecommendations();
      }
    } catch (e) {
      print('❌ Error parsing recommendations: $e');
      _setFallbackRecommendations();
    }
  }

  void _handleAIInsightsError() {
    setState(() {
      _isLoadingAIDashboardInsights = false;

      // Set fallback data when API fails
      if (_aiInsights.isEmpty) {
        _aiInsights = [
          "Welcome to Mimos Uterinos! Track your cycle to get personalized insights.",
          "Regular tracking helps us provide better recommendations for your health.",
          "AI insights are temporarily unavailable, but you can still track your cycle."
        ];
      }

      // Only set fallback predictions if no cycle data is available
      if (_predictions.isEmpty && _recentCycles.isEmpty) {
        _predictions = {
          'nextPeriod': 'Track your cycle for predictions',
          'ovulation': 'Data needed for prediction',
          'fertileWindow': 'Complete your profile first',
        };
      }

      _setFallbackRecommendations();
    });
  }

  void _setFallbackRecommendations() {
    _recommendations = {
      'nutrition': [
        'Eat iron-rich foods like spinach and lean meats',
        'Stay hydrated with plenty of water',
        'Include calcium-rich foods in your diet',
      ],
      'exercise': [
        'Try gentle yoga or stretching',
        'Take a 10-15 minute walk daily',
        'Avoid intense workouts during heavy flow days',
      ],
      'sleep': [
        'Maintain a regular sleep schedule',
        'Aim for 7-8 hours of sleep nightly',
        'Create a calming bedtime routine',
      ],
      'selfCare': [
        'Use a heating pad for cramps',
        'Practice deep breathing exercises',
        'Take warm baths to relax muscles',
      ],
    };
  }

  Future<void> _loadAIData() async {
    setState(() {
      _isLoadingInsights = true;
      _isLoadingReminders = true;
      _isLoadingRecommendations = true;
    });

    final userData =
        Provider.of<UserDataProvider>(context, listen: false).userData;

    if (userData != null) {
      // Load insights
      final insights = await _aiService.generateDailyInsights(userData);

      // Load reminders
      final reminders = await _aiService.generateSmartReminders(userData);

      // Load recommendations
      final recommendations =
          await _aiService.generatePersonalizedRecommendations(userData);

      print('✅ Loaded recommendations:');
      print(recommendations);

      setState(() {
        _aiInsights = insights;
        _reminders = reminders;
        _recommendations = recommendations;
        _isLoadingInsights = false;
        _isLoadingReminders = false;
        _isLoadingRecommendations = false;
      });
    } else {
      setState(() {
        _aiInsights = [
          "Complete your profile to get personalized insights.",
          "Track your cycle to receive tailored recommendations.",
          "Your data helps us provide better guidance for your health."
        ];
        _reminders = [
          {
            'title': 'Complete Profile',
            'description': 'Set up your profile to get personalized reminders',
            'timing': 'Now',
            'icon': 'person'
          }
        ];
        // Don't override _predictions here - let cycle data handle it

        // Initialize with default recommendations
        _recommendations = {
          'nutrition': [
            'Complete your profile to get personalized nutrition recommendations'
          ],
          'exercise': [
            'Complete your profile to get personalized exercise recommendations'
          ],
          'sleep': [
            'Complete your profile to get personalized sleep recommendations'
          ],
          'selfCare': [
            'Complete your profile to get personalized self-care recommendations'
          ]
        };
        _isLoadingInsights = false;
        _isLoadingReminders = false;
        _isLoadingRecommendations = false;
      });
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    // You can add additional logic here to update other parts of the UI based on the selected date
    // For example, load symptoms or data specific to the selected date
  }

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context).userData;
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    // Use authenticated user data if available - REMOVE EXCLAMATION MARK
    final displayName = _userProfile?['name'] ??
        authProvider.currentUser?.name ??
        userData?.name ??
        'there';
    final userEmail = _userProfile?['email'] ??
        authProvider.currentUser?.email ??
        userData?.email ??
        '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // App Bar (updated with new design)
            SliverAppBar(
              expandedHeight: 500, // Keep the same height
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                title: null,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image with overlay
                    Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/hero.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // Optional gradient overlay to ensure text readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.3),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),

                    // Top section with profile, greeting, and notification
                    Positioned(
                      top: 60,
                      left: 20,
                      right: 20,
                      child: Column(
                        children: [
                          // Profile, Date, and Calendar row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Profile icon - now clickable
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),

                              // Date display
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  DateFormat('dd MMMM')
                                      .format(DateTime.now()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              // Calendar icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_today_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Greeting and notification row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Greeting text - FIXED: Remove exclamation mark
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, ${displayName.split(' ').first}', // REMOVED EXCLAMATION MARK
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getCycleStatusText()
                                            .contains('days until')
                                        ? _getCycleStatusText()
                                            .split('•')
                                            .last
                                            .trim()
                                        : 'Track your cycle for insights',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),

                              // Notification icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Calendar strip (horizontal date selector) - FIXED POSITION
                    Positioned(
                      top: 170, // Reduced from 200 to bring it closer to greeting
                      left: 0,
                      right: 0,
                      child: _buildEnhancedCalendarStrip(),
                    ),

                    // Period information section - FIXED POSITION AND SPACING
                    Positioned(
                      bottom: 20, // Reduced from 60 to bring it closer to calendar
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          const Text(
                            "Period",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 8), // Reduced spacing
                          Text(
                            _getCurrentCycleDay().toString(), // Show the actual day number
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12), // Reduced spacing
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CycleCalendarScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFC75385),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text(
                                "Edit period",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ...rest of your existing code...