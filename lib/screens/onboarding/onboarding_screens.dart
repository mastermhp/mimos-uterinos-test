import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/screens/dashboard/bottom_nav.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:menstrual_health_ai/services/auth_service.dart';

class OnboardingScreens extends StatefulWidget {
  final String? userName;

  const OnboardingScreens({
    super.key,
    this.userName,
  });

  @override
  State<OnboardingScreens> createState() => _OnboardingScreensState();
}

class _OnboardingScreensState extends State<OnboardingScreens> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 11; // Updated total pages to include all screens

  // User data
  String _name = "";
  int _age = 25; // Default age
  DateTime _birthdate = DateTime(1995, 12, 25);
  double _weight = 60.0;
  double _height = 165.0;
  int _periodLength = 4;
  bool _isRegularCycle = true;
  int _cycleLength = 28;
  DateTime _lastPeriodDate = DateTime.now().subtract(const Duration(days: 14));
  bool _isLoading = false;
  double _loadingProgress = 0.0;

  // Selected cycle days
  List<int> _selectedCycleDays = [26, 27, 28]; // Default for regular cycle

  // Health data for dynamic screens
  List<String> _selectedSymptoms = [];
  List<String> _selectedMoods = [];
  int _painLevel = 2;
  int _energyLevel = 3;
  int _sleepQuality = 3;

  // Available symptoms and moods
  final List<String> _availableSymptoms = [
    "Cramps",
    "Headache",
    "Bloating",
    "Fatigue",
    "Breast Tenderness",
    "Acne",
    "Backache",
    "Nausea"
  ];

  final List<String> _availableMoods = [
    "Happy",
    "Calm",
    "Irritable",
    "Anxious",
    "Sad",
    "Energetic",
    "Tired",
    "Emotional"
  ];

  @override
  void initState() {
    super.initState();

    // Initialize name from registration if available
    if (widget.userName != null && widget.userName!.isNotEmpty) {
      _name = widget.userName!;
    }

    // Add listener to detect when we reach the loading page
    _pageController.addListener(() {
      if (_pageController.page == 10 && !_isLoading) {
        setState(() {
          _isLoading = true;
        });
        _startLoadingAnimation();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startLoadingAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_loadingProgress < 1.0) {
        setState(() {
          _loadingProgress += 0.02; // Increment by 2% each time
        });
        _startLoadingAnimation();
      } else {
        // Save user data before navigating
        _saveUserData();

        // Navigate to home screen when loading is complete
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const BottomNav()),
          (route) => false,
        );
      }
    });
  }

  void _saveUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Validate required data
      if (_name.isEmpty) {
        throw Exception('Name is required');
      }

      if (_lastPeriodDate == null) {
        throw Exception('Last period date is required');
      }

      // Convert selected symptoms and moods to the required format
      final List<Map<String, dynamic>> symptoms = _selectedSymptoms
          .map((symptom) => {
                'name': symptom.toLowerCase().replaceAll(' ', '_'),
                'intensity': 3, // Default intensity
                'date': DateTime.now().toIso8601String(),
              })
          .toList();

      final List<Map<String, dynamic>> moods = _selectedMoods
          .map((mood) => {
                'name': mood.toLowerCase(),
                'intensity': 3, // Default intensity
                'date': DateTime.now().toIso8601String(),
              })
          .toList();

      // Calculate average cycle length
      int avgCycleLength = 28;
      if (_selectedCycleDays.isNotEmpty) {
        avgCycleLength = _selectedCycleDays.reduce((a, b) => a + b) ~/
            _selectedCycleDays.length;
      } else {
        avgCycleLength = _cycleLength;
      }

      // Print onboarding data to terminal
      print('🔄 Starting onboarding process...');
      print('👤 Name: $_name');
      print('📅 Age: $_age');
      print('⚖️ Weight: ${_weight}kg, Height: ${_height}cm');
      print(
          '🩸 Period Length: $_periodLength days, Cycle Length: $avgCycleLength days');
      print('📊 Regular Cycle: $_isRegularCycle');
      print('📆 Last Period Date: ${_lastPeriodDate.toIso8601String()}');
      print('😊 Selected Moods: $_selectedMoods');
      print('🤕 Selected Symptoms: $_selectedSymptoms');

      // Complete onboarding via API
      final success = await authProvider.completeOnboarding(
        name: _name,
        birthDate: _birthdate,
        age: _age,
        weight: _weight,
        height: _height,
        periodLength: _periodLength,
        isRegularCycle: _isRegularCycle,
        cycleLength: avgCycleLength,
        lastPeriodDate: _lastPeriodDate,
        initialPeriodDate: _lastPeriodDate, // Adding initialPeriodDate field
        goals: ['track_cycle'], // Convert to API format
        email: authProvider.currentUser?.email ?? '',
        healthConditions: [], // Add health conditions if needed
        symptoms: symptoms,
        moods: moods,
        painLevel: _painLevel,
        energyLevel: _energyLevel,
        sleepQuality: _sleepQuality,
        notes: 'Onboarding completed via mobile app',
      );

      if (success) {
        // After successful onboarding, set the period date
        final userId = authProvider.currentUser?.id;
        if (userId != null) {
          print('📅 Setting period date for user: $userId');

          // Create a new cycle with the period information
          await ApiService.createCycle(
            userId: userId,
            startDate: _lastPeriodDate.toIso8601String(),
            periodLength: _periodLength,
            cycleLength: avgCycleLength,
            flow: 'medium', // Default flow
            symptoms: symptoms,
            notes: 'Initial period from onboarding',
          );

          print('✅ Period date set successfully!');
        }

        // Mark onboarding as completed locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasCompletedOnboarding', true);

        print('✅ Onboarding completed successfully!');
        print('🏠 Navigating to dashboard...');

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Welcome! Your profile has been set up successfully! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate to dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BottomNav()),
          );
        }
      } else {
        throw Exception(authProvider.error ?? 'Failed to complete onboarding');
      }
    } catch (e) {
      print('❌ Error completing onboarding: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 24),
                    onPressed: _previousPage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  // Progress indicator
                  Text(
                    "${_currentPage + 1}/$_totalPages",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Container(
              width: double.infinity,
              height: 4,
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width *
                        (_currentPage + 1) /
                        _totalPages,
                    height: 4,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildNamePage(),
                  _buildAgePage(),
                  _buildBirthdayPage(),
                  _buildWeightPage(),
                  _buildHeightPage(),
                  _buildPeriodLengthPage(),
                  _buildCycleLengthPage(),
                  _buildLastPeriodPage(), // Make sure this is included
                  _buildSymptomsAndMoodPage(),
                  _buildHealthMetricsPage(),
                  _buildLoadingPage(),
                ],
              ),
            ),

            // Next button (hide on loading page)
            if (_currentPage < _totalPages - 1)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: _buildNextButton(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "What's your name?",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          Container(
            width: double.infinity,
            child: TextField(
              controller: TextEditingController(text: _name),
              onChanged: (value) {
                setState(() {
                  _name = value;
                });
              },
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: "Isabella",
                hintStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 200,
            height: 2,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildAgePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "How old are you?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),

          // Age display
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrement button
                GestureDetector(
                  onTap: () {
                    if (_age > 12) {
                      setState(() {
                        _age--;
                        _birthdate = DateTime(
                          DateTime.now().year - _age,
                          _birthdate.month,
                          _birthdate.day,
                        );
                      });
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                ),

                // Age value
                Container(
                  width: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    "$_age",
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Increment button
                GestureDetector(
                  onTap: () {
                    if (_age < 70) {
                      setState(() {
                        _age++;
                        _birthdate = DateTime(
                          DateTime.now().year - _age,
                          _birthdate.month,
                          _birthdate.day,
                        );
                      });
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // Age slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 14,
              ),
            ),
            child: Slider(
              value: _age.toDouble(),
              min: 12,
              max: 70,
              divisions: 58,
              onChanged: (value) {
                setState(() {
                  _age = value.round();
                  _birthdate = DateTime(
                    DateTime.now().year - _age,
                    _birthdate.month,
                    _birthdate.day,
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 20),

          // Age range labels
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "12",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  "30",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  "50",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  "70",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "When is your birthday?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),

          // Date picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Month column
              Column(
                children: [
                  const Text(
                    "Month",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDatePickerColumn(
                    items: List.generate(
                        12, (index) => (index + 1).toString().padLeft(2, '0')),
                    selectedIndex: _birthdate.month - 1,
                    onChanged: (value) {
                      setState(() {
                        _birthdate = DateTime(
                          _birthdate.year,
                          int.parse(value),
                          _birthdate.day,
                        );
                        _age = DateTime.now().year - _birthdate.year;
                        if (DateTime.now().month < _birthdate.month ||
                            (DateTime.now().month == _birthdate.month &&
                                DateTime.now().day < _birthdate.day)) {
                          _age--;
                        }
                      });
                    },
                  ),
                ],
              ),

              // Day column
              Column(
                children: [
                  const Text(
                    "Day",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDatePickerColumn(
                    items: List.generate(
                        31, (index) => (index + 1).toString().padLeft(2, '0')),
                    selectedIndex: _birthdate.day - 1,
                    onChanged: (value) {
                      setState(() {
                        _birthdate = DateTime(
                          _birthdate.year,
                          _birthdate.month,
                          int.parse(value),
                        );
                        _age = DateTime.now().year - _birthdate.year;
                        if (DateTime.now().month < _birthdate.month ||
                            (DateTime.now().month == _birthdate.month &&
                                DateTime.now().day < _birthdate.day)) {
                          _age--;
                        }
                      });
                    },
                  ),
                ],
              ),

              // Year column
              Column(
                children: [
                  const Text(
                    "Year",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDatePickerColumn(
                    items: List.generate(
                        50,
                        (index) =>
                            (DateTime.now().year - 50 + index).toString()),
                    selectedIndex: _birthdate.year - (DateTime.now().year - 50),
                    onChanged: (value) {
                      setState(() {
                        _birthdate = DateTime(
                          int.parse(value),
                          _birthdate.month,
                          _birthdate.day,
                        );
                        _age = DateTime.now().year - _birthdate.year;
                        if (DateTime.now().month < _birthdate.month ||
                            (DateTime.now().month == _birthdate.month &&
                                DateTime.now().day < _birthdate.day)) {
                          _age--;
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 60),

          // Display calculated age
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                "You are $_age years old",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "What's your weight?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),

          // Weight display
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _weight.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    "kg",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),

          // Weight slider
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: AppColors.primary,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 14,
                    elevation: 0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 24,
                  ),
                ),
                child: Slider(
                  value: _weight,
                  min: 30,
                  max: 150,
                  onChanged: (value) {
                    setState(() {
                      _weight = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Slider labels
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "30",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "60",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "90",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "120",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "150",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeightPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "How tall are you?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),

          // Height display
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _height.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    "cm",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),

          // Height slider
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: AppColors.primary,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 14,
                    elevation: 0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 24,
                  ),
                ),
                child: Slider(
                  value: _height,
                  min: 120,
                  max: 210,
                  onChanged: (value) {
                    setState(() {
                      _height = double.parse(value.toStringAsFixed(1));
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Slider labels
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "120",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "140",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "160",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "180",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "200",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodLengthPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "How long does your\nperiod usually last?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),

          // Period length display
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$_periodLength",
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    "days",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),

          // Period length options (simplified grid)
          SizedBox(
            height: 200,
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              shrinkWrap: true,
              children: List.generate(6, (index) {
                final days = index + 2; // 2-7 days
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _periodLength = days;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _periodLength == days
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _periodLength == days
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "$days",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _periodLength == days
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleLengthPage() {
    List<int> cycleDays = List.generate(8, (index) => index + 24); // 24-31 days

    if (_isRegularCycle &&
        !_selectedCycleDays.any((day) => day >= 26 && day <= 28)) {
      _selectedCycleDays = [26, 27, 28];
    } else if (!_isRegularCycle &&
        !_selectedCycleDays.any((day) => day >= 28 && day <= 30)) {
      _selectedCycleDays = [28, 29, 30];
    }

    String rangeText = "";
    if (_selectedCycleDays.isNotEmpty) {
      int minDay = _selectedCycleDays.reduce((a, b) => a < b ? a : b);
      int maxDay = _selectedCycleDays.reduce((a, b) => a > b ? a : b);
      rangeText = "$minDay - $maxDay days";
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "How long does your\ncycle usually last?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Regular/Irregular toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToggleButton(
                text: "Regular",
                isSelected: _isRegularCycle,
                onTap: () {
                  setState(() {
                    if (!_isRegularCycle) {
                      _isRegularCycle = true;
                      _selectedCycleDays = [26, 27, 28];
                    }
                  });
                },
              ),
              const SizedBox(width: 16),
              _buildToggleButton(
                text: "Irregular",
                isSelected: !_isRegularCycle,
                onTap: () {
                  setState(() {
                    if (_isRegularCycle) {
                      _isRegularCycle = false;
                      _selectedCycleDays = [28, 29, 30];
                    }
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 60),

          // Display selected range prominently
          Text(
            rangeText,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 60),

          // Cycle length options grid
          SizedBox(
            height: 200,
            child: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 1.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              children: cycleDays.map((day) {
                final isSelected = _selectedCycleDays.contains(day);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        if (_selectedCycleDays.length > 1) {
                          _selectedCycleDays.remove(day);
                        }
                      } else {
                        _selectedCycleDays.add(day);
                      }

                      if (_selectedCycleDays.isNotEmpty) {
                        _cycleLength =
                            _selectedCycleDays.reduce((a, b) => a + b) ~/
                                _selectedCycleDays.length;
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "$day",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? AppColors.primary : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastPeriodPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "When was your\nlast period?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            "This helps us predict your next period\nand fertile window accurately.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Calendar for period selection
          Expanded(
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 90)),
              lastDay: DateTime.now(),
              focusedDay: _lastPeriodDate,
              selectedDayPredicate: (day) {
                return isSameDay(_lastPeriodDate, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _lastPeriodDate = selectedDay;
                });
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: const TextStyle(fontSize: 16),
                weekendTextStyle: const TextStyle(fontSize: 16),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Selected date display
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                "Selected: ${DateFormat('MMM dd, yyyy').format(_lastPeriodDate)}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSymptomsAndMoodPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              "What symptoms do you typically experience?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Symptoms grid
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _availableSymptoms.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedSymptoms.remove(symptom);
                      } else {
                        _selectedSymptoms.add(symptom);
                      }
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      symptom,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            const Text(
              "How would you describe your typical mood?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Moods grid
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _availableMoods.map((mood) {
                final isSelected = _selectedMoods.contains(mood);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMoods.remove(mood);
                      } else {
                        _selectedMoods.add(mood);
                      }
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.secondary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondary
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      mood,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Info text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This information helps us provide more personalized insights about your cycle.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetricsPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              "Your Health Metrics",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Help us understand your typical health patterns",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Pain level
            _buildMetricSlider(
              title: "Pain Level",
              value: _painLevel,
              min: 0,
              max: 5,
              labels: const [
                "None",
                "Mild",
                "Moderate",
                "Strong",
                "Severe",
                "Extreme"
              ],
              onChanged: (value) {
                setState(() {
                  _painLevel = value.round();
                });
              },
            ),

            const SizedBox(height: 24),

            // Energy level
            _buildMetricSlider(
              title: "Energy Level",
              value: _energyLevel,
              min: 0,
              max: 5,
              labels: const [
                "Very Low",
                "Low",
                "Moderate",
                "Good",
                "High",
                "Very High"
              ],
              onChanged: (value) {
                setState(() {
                  _energyLevel = value.round();
                });
              },
            ),

            const SizedBox(height: 24),

            // Sleep quality
            _buildMetricSlider(
              title: "Sleep Quality",
              value: _sleepQuality,
              min: 0,
              max: 5,
              labels: const [
                "Very Poor",
                "Poor",
                "Fair",
                "Good",
                "Very Good",
                "Excellent"
              ],
              onChanged: (value) {
                setState(() {
                  _sleepQuality = value.round();
                });
              },
            ),

            const SizedBox(height: 32),

            // AI personalization note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondary, Color(0xFF9D97FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AI Personalization",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Our AI will analyze your data to provide personalized insights and recommendations.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSlider({
    required String title,
    required int value,
    required int min,
    required int max,
    required List<String> labels,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          labels[value],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
            ),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              labels.first,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              labels.last,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "We're setting up your personalized calendar...",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),

          // Progress indicator
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: _loadingProgress,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                Text(
                  "${(_loadingProgress * 100).toInt()}%",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          const Text(
            "This will only take a moment!",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerColumn({
    required List<String> items,
    required int selectedIndex,
    required Function(String) onChanged,
  }) {
    return Container(
      height: 150,
      width: 80,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () {
              onChanged(items[index]);
            },
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                items[index],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggleButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: _nextPage,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
