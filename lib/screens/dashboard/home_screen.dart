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
      final response = await ApiService.getJournalRecommendations(userId: userId);

      if (response != null && response['success'] == true) {
        setState(() {
          _journalRecommendations = List<Map<String, dynamic>>.from(response['data']['recommendations'] ?? []);
          _currentCyclePhase = response['data']['cyclePhase'] ?? 'unknown';
          _isLoadingJournalRecommendations = false;
        });

        print('✅ Journal recommendations loaded: ${_journalRecommendations.length} items');
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
          'content': 'Heat therapy, gentle movement, and anti-inflammatory foods can provide natural cramp relief during your menstrual cycle.',
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
          'content': 'Regular cycle tracking helps you understand your body\'s patterns and predict how you might feel throughout your cycle.',
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
          'content': 'Understanding and managing emotional changes throughout your menstrual cycle with practical strategies.',
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

    // Use authenticated user data if available
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
              expandedHeight: 500, // Increased height to match design
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              automaticallyImplyLeading: false, // Remove back button
              flexibleSpace: FlexibleSpaceBar(
                title: null, // Remove title to have cleaner look
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

                    // Top section with profile and date
                    Positioned(
                      top: 60,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Profile icon
                          Container(
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

                          // Date display
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              DateFormat('dd MMMM').format(DateTime.now()),
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
                    ),

                    // Calendar strip (horizontal date selector)
                    Positioned(
                      top: 140,
                      left: 0,
                      right: 0,
                      child: _buildEnhancedCalendarStrip(),
                    ),

                    // Period information section
                    Positioned(
                      bottom: 80,
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
                          const SizedBox(height: 8),
                          Text(
                            _getCycleStatusText().contains("Day")
                                ? _getCycleStatusText().split(" ")[1]
                                : "Day 1",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CycleCalendarScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFE91E63),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                "Edit period dates",
                                style: TextStyle(
                                  fontSize: 16,
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
              // Remove actions entirely - no notification or menu icons
            ),

            // Reminders panel (conditionally shown)
            if (_showReminders)
              SliverToBoxAdapter(
                child: _buildRemindersPanel(),
              ),

            // Quick Actions
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildQuickActionCard(
                      icon: Icons.edit_note_rounded,
                      title: "Log Symptoms",
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LogSymptomsScreen()),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.calendar_month_rounded,
                      title: "View Calendar",
                      color: const Color(0xFF6C63FF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const CycleCalendarScreen()),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.auto_awesome,
                      title: "AI Coach",
                      color: const Color(0xFF00D9C6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AiCoachScreen()),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.medical_services_outlined,
                      title: "Doctor Mode",
                      color: const Color(0xFFFF5C8A),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const DoctorModeScreen()),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      icon: Icons.notifications_active_outlined,
                      title: "Reminders",
                      color: const Color(0xFFFFB347),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RemindersScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Journal Recommendations Section
            SliverToBoxAdapter(
              child: _buildJournalRecommendationsSection(),
            ),

            // Cycle Predictions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Cycle Predictions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const CycleCalendarScreen()),
                        );
                      },
                      child: const Text(
                        "View Calendar",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _buildPredictionsCard(),
            ),

            // AI Insights
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Insights",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AiCoachScreen()),
                        );
                      },
                      child: const Text(
                        "Ask AI Coach",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _buildInsightsCard(),
            ),

            // Personalized Recommendations
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Recommendations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PremiumScreen()),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          SizedBox(width: 4),
                          Text(
                            "Premium",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _buildRecommendationsCard(),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedCalendarStrip() {
    final today = DateTime.now();
    final dates =
        List.generate(7, (index) => today.subtract(Duration(days: 3 - index)));

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: dates.map((date) {
          final isToday = _isSameDay(date, today);
          final isSelected = _isSameDay(date, _selectedDate);

          // Determine if this date is a period day
          bool isPeriodDay = false;
          if (_userProfile != null) {
            final lastPeriodDate =
                DateTime.tryParse(_userProfile?['lastPeriodDate'] ?? '');
            final periodLength = _userProfile?['periodLength'] ?? 5;
            final cycleLength = _userProfile?['cycleLength'] ?? 28;

            if (lastPeriodDate != null) {
              final daysSinceLastPeriod =
                  date.difference(lastPeriodDate).inDays;
              final cycleDay = (daysSinceLastPeriod % cycleLength) + 1;
              isPeriodDay = cycleDay > 0 && cycleDay <= periodLength;
            }
          }

          return GestureDetector(
            onTap: () => _onDateSelected(date),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Day letter
                Text(
                  DateFormat('E').format(date)[0],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // Date circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday
                        ? Colors.white
                        : isSelected
                            ? Colors.white.withOpacity(0.3)
                            : Colors.transparent,
                    border: isPeriodDay && !isToday
                        ? Border.all(
                            color: Colors.white,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isToday)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE91E63),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                date.day.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              color: isPeriodDay
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                        // Today label for current date
                        if (isToday)
                          const SizedBox(height: 2)
                        else if (isPeriodDay)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // "TODAY" label
                const SizedBox(height: 4),
                if (isToday)
                  const Text(
                    "TODAY",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getCycleStatusText() {
    if (_userProfile == null) {
      return "Complete your profile to track your cycle";
    }

    // Get cycle information from user profile
    final lastPeriodDateString = _userProfile?['lastPeriodDate'];
    final periodLength = _userProfile?['periodLength'] ?? 5;
    final cycleLength = _userProfile?['cycleLength'] ?? 28;

    if (lastPeriodDateString == null) {
      return "Add your last period date to track your cycle";
    }

    // Parse date
    final lastPeriodDate = DateTime.tryParse(lastPeriodDateString);
    if (lastPeriodDate == null) {
      return "Invalid period date format";
    }

    final today = DateTime.now();
    final daysSinceLastPeriod = today.difference(lastPeriodDate).inDays;
    final currentCycleDay = (daysSinceLastPeriod % cycleLength) + 1;

    if (currentCycleDay <= periodLength) {
      return "Day $currentCycleDay of your period";
    } else {
      final daysUntilNextPeriod = cycleLength - currentCycleDay + 1;
      return "Day $currentCycleDay of your cycle • $daysUntilNextPeriod days until next period";
    }
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Smart Reminders",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _showReminders = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingReminders)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          else
            Column(
              children: _reminders.map((reminder) {
                IconData iconData;
                switch (reminder['icon']) {
                  case 'water_drop':
                    iconData = Icons.water_drop;
                    break;
                  case 'pill':
                    iconData = Icons.medication;
                    break;
                  case 'sleep':
                    iconData = Icons.bedtime;
                    break;
                  case 'exercise':
                    iconData = Icons.fitness_center;
                    break;
                  case 'person':
                    iconData = Icons.person;
                    break;
                  default:
                    iconData = Icons.notifications;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconData,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reminder['description'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reminder['timing'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RemindersScreen()),
                );
              },
              icon: const Icon(Icons.settings, size: 16),
              label: const Text("Manage Reminders"),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard() {
    // Use calculated predictions from cycle data
    String nextPeriodText = _predictions['nextPeriod'] ?? 'Unable to predict';
    String ovulationText = _predictions['ovulation'] ?? 'Unable to predict';
    String fertileWindowText =
        _predictions['fertileWindow'] ?? 'Unable to predict';

    // Override with AI dashboard insights only if cycle data is not available
    if (_aiDashboardInsights != null &&
        _aiDashboardInsights!['cyclePredictions'] != null &&
        _recentCycles.isEmpty) {
      nextPeriodText = _aiDashboardInsights!['cyclePredictions'].toString();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6A11CB),
            Color(0xFF2575FC),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A11CB).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Cycle Predictions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingPredictions)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          else
            Column(
              children: [
                _buildPredictionRow(
                  icon: Icons.calendar_today,
                  title: "Next Period",
                  value: nextPeriodText,
                ),
                const SizedBox(height: 16),
                _buildPredictionRow(
                  icon: Icons.egg_alt,
                  title: "Ovulation",
                  value: ovulationText,
                ),
                const SizedBox(height: 16),
                _buildPredictionRow(
                  icon: Icons.favorite,
                  title: "Fertile Window",
                  value: fertileWindowText,
                ),
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _recentCycles.isNotEmpty
                        ? "Predictions based on your ${_recentCycles.length} recorded cycle${_recentCycles.length > 1 ? 's' : ''}. Keep logging for better accuracy."
                        : "Predictions improve with more cycle data. Log your periods regularly for better accuracy.",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          // Added Expanded widget here to constrain the text
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                // Ensure long text wraps properly
                overflow: TextOverflow.ellipsis,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsCard() {
    String insightText = "Complete your profile to get personalized insights.";
    bool isFromAPI = false;

    if (_aiDashboardInsights != null &&
        _aiDashboardInsights!['insights'] != null) {
      insightText = _aiDashboardInsights!['insights'].toString();
      isFromAPI = true;
    } else if (_aiInsights.isNotEmpty) {
      insightText = _aiInsights.join("\n\n");
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "AI Insights",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormattedInsightText(insightText),
          if (isFromAPI) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "✅ Live AI Analysis",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedInsightText(String text) {
    // Split the text and format it with bold headers
    final parts = text.split('**');
    List<TextSpan> spans = [];
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Regular text
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ));
      } else {
        // Bold text (between **)
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ));
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildRecommendationsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: "Nutrition"),
                Tab(text: "Exercise"),
                Tab(text: "Sleep"),
                Tab(text: "Self-Care"),
              ],
            ),
          ),

          // Tab content
          SizedBox(
            height: 200,
            child: _isLoadingRecommendations || _isLoadingAIDashboardInsights
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecommendationsList(
                          _recommendations['nutrition'] ?? []),
                      _buildRecommendationsList(
                          _recommendations['exercise'] ?? []),
                      _buildRecommendationsList(
                          _recommendations['sleep'] ?? []),
                      _buildRecommendationsList(
                          _recommendations['selfCare'] ?? []),
                    ],
                  ),
          ),

          // Premium button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.star,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Upgrade to Premium for more personalized recommendations",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PremiumScreen()),
                    );
                  },
                  child: const Text(
                    "Upgrade",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsList(List<dynamic> recommendations) {
    // Handle case where recommendations might be null or empty
    if (recommendations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "No recommendations available yet. Complete your profile for personalized suggestions.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.0,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        // Safely convert any recommendation type to string
        String recommendation = recommendations[index].toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recommendation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJournalRecommendationsSection() {
    final featuredRecommendation = _journalRecommendations.isNotEmpty 
        ? _journalRecommendations.firstWhere(
            (rec) => rec['isFeatured'] == true,
            orElse: () => _journalRecommendations.first,
          )
        : null;
    
    final otherRecommendations = _journalRecommendations
        .where((rec) => rec['id'] != featuredRecommendation?['id'])
        .take(2)
        .toList();

    return Column(
      children: [
        // Header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPhaseMessage(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_getCurrentCycleDayForPhase() > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Day ${_getCurrentCycleDayForPhase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              TextButton(
                onPressed: () {
                  _navigateToJournalScreen();
                },
                child: const Text(
                  "View All",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),

        // Search Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search articles, etc",
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onTap: () {
                    _navigateToJournalSearch();
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Featured Article
        if (_isLoadingJournalRecommendations)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 280,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (featuredRecommendation != null)
          _buildFeaturedArticleCard(featuredRecommendation),

        const SizedBox(height: 24),

        // "Based on your current cycle" section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Based on your current cycle",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              if (_isLoadingJournalRecommendations)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                )
              else if (otherRecommendations.isNotEmpty)
                Row(
                  children: otherRecommendations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final rec = entry.value;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(left: index > 0 ? 12 : 0),
                        child: _buildSmallArticleCard(rec),
                      ),
                    );
                  }).toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No recommendations available",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Log some symptoms to get personalized insights!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedArticleCard(Map<String, dynamic> article) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            Image.asset(
              'assets/images/article.png', // Use a default article background
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE91E63),
                        Color(0xFFEC407A),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE91E63).withOpacity(0.7),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),

            // Content
            Positioned(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  Row(
                    children: [
                      if (article['isCommunityGenerated'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Your Insight',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (article['publishedDate'] != null)
                        Text(
                          article['publishedDate'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Title
                  Text(
                    '${article['title']} ?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tips
                  if (article['tips'] != null)
                    ...List.generate(
                      (article['tips'] as List).take(3).length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                article['tips'][index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Action Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        _showArticleDialog(article);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B1538),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Full Article',
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
    );
  }

  Widget _buildSmallArticleCard(Map<String, dynamic> article) {
    return GestureDetector(
      onTap: () => _showArticleDialog(article),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.pink.withOpacity(0.2),
                    Colors.purple.withOpacity(0.2),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  if (article['image'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.asset(
                        article['image'],
                        width: double.infinity,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.pink.withOpacity(0.3),
                                  Colors.purple.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                article['thumbnail'] ?? '📄',
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        article['thumbnail'] ?? '📄',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  
                  if (article['isCommunityGenerated'] == true)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Your Insight',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article['readTime'] ?? '5 min read',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArticleDialog(Map<String, dynamic> article) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          article['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (article['subtitle'] != null) ...[
                          Text(
                            article['subtitle'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        Text(
                          article['content'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        
                        if (article['tips'] != null) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Key Tips:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(
                            (article['tips'] as List).length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      article['tips'][index],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Action buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _navigateToJournalScreen(); // Navigate to full journal
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Read More'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToJournalScreen() {
    // TODO: Replace with actual journal screen when created
    // For now, navigate to a placeholder or existing screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AiCoachScreen(), // Temporary - replace with JournalScreen
      ),
    );
  }

  void _navigateToJournalSearch() {
    // TODO: Replace with actual journal search screen when created
    // For now, navigate to a placeholder or show search functionality
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AiCoachScreen(), // Temporary - replace with JournalSearchScreen
      ),
    );
  }
}
