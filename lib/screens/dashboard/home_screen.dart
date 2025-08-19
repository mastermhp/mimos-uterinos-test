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

  bool _isLoadingProfile = true;
  bool _isLoadingStats = true;
  bool _isLoadingCycles = true;
  bool _isLoadingSymptoms = true;
  bool _isLoadingConsultations = true;
  bool _isLoadingAIDashboardInsights = true;

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
    // Load all data at once
    await Future.wait([
      _loadUserProfile(),
      _loadUserStats(),
      _loadAIData(),
      _loadCycles(),
      _loadSymptoms(),
      _loadDoctorConsultations(),
      _loadAIDashboardInsights(),
    ]);
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

  Future<void> _loadAIData() async {
    setState(() {
      _isLoadingInsights = true;
      _isLoadingReminders = true;
      _isLoadingPredictions = true;
      _isLoadingRecommendations = true;
    });

    final userData =
        Provider.of<UserDataProvider>(context, listen: false).userData;

    if (userData != null) {
      // Load insights
      final insights = await _aiService.generateDailyInsights(userData);

      // Load reminders
      final reminders = await _aiService.generateSmartReminders(userData);

      // Load predictions
      final predictions = await _aiService.getCalendarPredictions(userData);

      // Load recommendations
      final recommendations =
          await _aiService.generatePersonalizedRecommendations(userData);

      print('✅ Loaded recommendations:');
      print(recommendations);

      setState(() {
        _aiInsights = insights;
        _reminders = reminders;
        _predictions = predictions;
        _recommendations = recommendations;
        _isLoadingInsights = false;
        _isLoadingReminders = false;
        _isLoadingPredictions = false;
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
        _predictions = {
          'nextPeriod': 'Complete your profile',
          'ovulation': 'Complete your profile',
          'fertileWindow': 'Complete your profile',
        };
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
        _isLoadingPredictions = false;
        _isLoadingRecommendations = false;
      });
    }
  }

  Future<void> _loadCycles() async {
    try {
      setState(() {
        _isLoadingCycles = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        print('❌ Cannot load cycles: User ID is null');
        setState(() {
          _isLoadingCycles = false;
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
        if (_recentCycles.isNotEmpty) {
          print('📅 Most recent cycle:');
          print('   Start date: ${_recentCycles[0]['startDate']}');
          print('   End date: ${_recentCycles[0]['endDate']}');
          print('   Length: ${_recentCycles[0]['cycleLength']} days');
        }
      } else {
        print('❌ Failed to load cycles');
        setState(() {
          _isLoadingCycles = false;
        });
      }
    } catch (e) {
      print('❌ Error loading cycles: $e');
      setState(() {
        _isLoadingCycles = false;
      });
    }
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
      final response = await ApiService.getAIDashboardInsights();

      if (response != null && response['success'] == true) {
        setState(() {
          _aiDashboardInsights = response;
          _isLoadingAIDashboardInsights = false;
        });

        print('✅ AI insights loaded:');
        print('💡 Insights: ${_aiDashboardInsights?['insights']}');
        print('📅 Cycle predictions: ${_aiDashboardInsights?['cyclePredictions']}');
        print('📝 Recommendations: ${_aiDashboardInsights?['recommendations']}');

        // Update the AI insights from backend - use the actual insights field
        if (_aiDashboardInsights?['insights'] != null) {
          _aiInsights = [_aiDashboardInsights!['insights'].toString()];
        }

        // Update predictions
        if (_aiDashboardInsights?['cyclePredictions'] != null) {
          _predictions = {
            'nextPeriod': _aiDashboardInsights?['cyclePredictions'] ?? 'Not available',
            'ovulation': 'Coming soon',
            'fertileWindow': 'Coming soon',
          };
        }
        
        // Parse and update recommendations if available
        if (_aiDashboardInsights?['recommendations'] != null) {
          try {
            final recommendationsList = _aiDashboardInsights!['recommendations'] as List;
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
                'nutrition': nutritionRecs,
                'exercise': exerciseRecs,
                'sleep': sleepRecs,
                'selfCare': selfCareRecs,
              };
              
              print('✅ Processed recommendations by category:');
              print('🍎 Nutrition: $nutritionRecs');
              print('💪 Exercise: $exerciseRecs');
              print('😴 Sleep: $sleepRecs');
              print('🧘‍♀️ Self-Care: $selfCareRecs');
            }
          } catch (e) {
            print('❌ Error parsing recommendations: $e');
          }
        }
      } else {
        print('❌ Failed to load AI dashboard insights');
        setState(() {
          _isLoadingAIDashboardInsights = false;
        });
      }
    } catch (e) {
      print('❌ Error loading AI dashboard insights: $e');
      setState(() {
        _isLoadingAIDashboardInsights = false;
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
            // App Bar
            SliverAppBar(
              expandedHeight: 400, // Increased to accommodate calendar strip
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  "Mimos Uterinos",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                        ),
                      ),
                    ),
                    // Decorative circles
                    Positioned(
                      top: -50,
                      right: -80,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -90,
                      left: -90,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // User greeting and cycle info
                    Positioned(
                      top: 120,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, $displayName!",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCycleStatusText(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          if (userEmail.isNotEmpty)
                            Text(
                              userEmail,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Calendar strip
                    Positioned(
                      top: 240,
                      left: 0,
                      right: 0,
                      child: _buildCalendarStrip(),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showReminders = !_showReminders;
                    });
                  },
                ),
                IconButton(
                  icon:
                      const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                // Add logout button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.account_circle, color: Colors.white),
                  onSelected: (value) async {
                    if (value == 'logout') {
                      await authProvider.logout();
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _buildCalendarStrip() {
    // Get today's date
    final today = DateTime.now();

    // Generate dates for the strip (2 days before today, today, and 3 days after)
    final dates = List.generate(
      6,
      (index) => today.subtract(Duration(days: 2 - index)),
    );

    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.primary,
          ],
        ),
      ),
      child: Column(
        children: [
          // Day of week labels
          Padding(
            padding: const EdgeInsets.only(
                top: 16.0, left: 20.0, right: 20.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: dates.map((date) {
                final dayLetter = DateFormat('E').format(date)[0];
                return Expanded(
                  child: Text(
                    dayLetter,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Date numbers
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: dates.map((date) {
                  final isToday = _isSameDay(date, today);
                  final isSelected = _isSameDay(date, _selectedDate);

                  // Check if this date is in period (for highlighting)
                  bool isInPeriod = false;
                  if (_userProfile != null) {
                    final lastPeriodDate = DateTime.tryParse(
                        _userProfile?['lastPeriodDate'] ?? '');
                    final periodLength = _userProfile?['periodLength'] ?? 5;
                    final cycleLength = _userProfile?['cycleLength'] ?? 28;

                    if (lastPeriodDate != null) {
                      final daysSinceLastPeriod =
                          date.difference(lastPeriodDate).inDays;
                      final cycleDay = (daysSinceLastPeriod % cycleLength) + 1;
                      isInPeriod = cycleDay > 0 && cycleDay <= periodLength;
                    }
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onDateSelected(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Today label
                          SizedBox(
                            height: 16,
                            child: isToday
                                ? const Text(
                                    "TODAY",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const SizedBox(),
                          ),

                          const SizedBox(height: 4),

                          // Date container
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday
                                  ? Colors.white
                                  : isSelected
                                      ? Colors.white.withOpacity(0.3)
                                      : isInPeriod
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.transparent,
                              border: isInPeriod && !isToday
                                  ? Border.all(
                                      color: Colors.white.withOpacity(0.6),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                date.day.toString(),
                                style: TextStyle(
                                  color: isToday
                                      ? AppColors.primary
                                      : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Period indicator dot
                          SizedBox(
                            height: 8,
                            child: isInPeriod && !isToday
                                ? Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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
    String nextPeriodText = _predictions['nextPeriod'] ?? 'Unable to predict';
    String ovulationText = _predictions['ovulation'] ?? 'Unable to predict';
    String fertileWindowText =
        _predictions['fertileWindow'] ?? 'Unable to predict';

    // Use AI dashboard insights if available
    if (_aiDashboardInsights != null &&
        _aiDashboardInsights!['cyclePredictions'] != null) {
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
          if (_isLoadingPredictions || _isLoadingAIDashboardInsights)
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
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Predictions improve with more cycle data. Log your periods regularly for better accuracy.",
                    style: TextStyle(
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
    // Use insights from API if available - specifically the 'insights' field
    String insightText = "Complete your profile to get personalized insights.";
    
    if (_aiDashboardInsights != null && _aiDashboardInsights!['insights'] != null) {
      insightText = _aiDashboardInsights!['insights'].toString();
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "AI Insights",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingInsights || _isLoadingAIDashboardInsights)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                insightText,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
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
}
