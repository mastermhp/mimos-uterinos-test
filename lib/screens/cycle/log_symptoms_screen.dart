import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/models/user_data.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/services/ai_service.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:menstrual_health_ai/widgets/animated_gradient_button.dart';
import 'package:menstrual_health_ai/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class LogSymptomsScreen extends StatefulWidget {
  const LogSymptomsScreen({Key? key}) : super(key: key);

  @override
  _LogSymptomsScreenState createState() => _LogSymptomsScreenState();
}

class _LogSymptomsScreenState extends State<LogSymptomsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Create an instance of AIService
  final AIService _aiService = AIService();

  final Map<String, bool> _symptoms = {
    'Cramps': false,
    'Headache': false,
    'Fatigue': false,
    'Bloating': false,
    'Mood Swings': false,
    'Breast Tenderness': false,
    'Acne': false,
    'Backache': false,
    'Nausea': false,
    'Insomnia': false,
    'Food Cravings': false,
    'Dizziness': false,
  };

  final Map<String, String> _symptomIcons = {
    'Cramps': 'assets/images/cramps_icon.png',
    'Headache': 'assets/images/headache_icon.png',
    'Fatigue': 'assets/images/fatigue_icon.png',
    'Bloating': 'assets/images/bloating_icon.png',
    'Mood Swings': 'assets/images/mood_icon.png',
    'Breast Tenderness': 'assets/images/temperature_icon.png',
    'Acne': 'assets/images/cramps_icon.png',
    'Backache': 'assets/images/headache_icon.png',
    'Nausea': 'assets/images/fatigue_icon.png',
    'Insomnia': 'assets/images/bloating_icon.png',
    'Food Cravings': 'assets/images/mood_icon.png',
    'Dizziness': 'assets/images/temperature_icon.png',
  };

  int _painLevel = 0;
  int _moodLevel = 0;
  int _energyLevel = 0;
  DateTime _selectedDate = DateTime.now();
  bool _showAnalysis = false;
  bool _isLoading = false;
  Map<String, dynamic> _aiAnalysisData = {};
  String _aiAnalysis = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _analyzeSymptoms() async {
    if (_symptoms.values.every((selected) => !selected) &&
        _painLevel == 0 &&
        _moodLevel == 0 &&
        _energyLevel == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one symptom or set a level'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get user data from provider
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final userData = userDataProvider.userData;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      print('📊 Checking user data: ${userData != null ? "Available" : "NULL"}');
      print('📊 Checking current user: ${currentUser != null ? "Available" : "NULL"}');
      
      // Create a list of symptoms for analysis
      final List<String> symptomsList = _symptoms.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      if (_painLevel > 0) {
        symptomsList.add("Pain Level: $_painLevel/10");
      }
      if (_moodLevel > 0) {
        symptomsList.add("Mood Level: $_moodLevel/10");
      }
      if (_energyLevel > 0) {
        symptomsList.add("Energy Level: $_energyLevel/10");
      }

      // Try multiple approaches to get user data
      if (userData == null || currentUser == null) {
        print('⚠️ Using fallback approach for analysis with cycle data...');
        
        try {
          // Try to get cycles data for the user
          final cyclesResponse = await ApiService.getCycles(
            userId: currentUser?.id ?? '',
          );
          
          if (cyclesResponse != null && 
              cyclesResponse['success'] == true && 
              cyclesResponse['data'] != null) {
            
            final cyclesData = cyclesResponse['data'] as List<dynamic>;
            print('✅ Successfully fetched ${cyclesData.length} cycles from API');
            
            if (cyclesData.isNotEmpty) {
              // Use the most recent cycle data
              final mostRecentCycle = cyclesData.first;
              
              print('📊 Using cycle data: ${mostRecentCycle['id']}');
              print('📊 Start date: ${mostRecentCycle['startDate']}');
              print('📊 Cycle length: ${mostRecentCycle['cycleLength']}');
              
              // Create a UserData object from cycle data
              final tempUserData = UserData(
                id: mostRecentCycle['userId'] ?? 'default_id',
                name: 'User',
                email: currentUser?.email ?? '',
                age: 30,
                cyclesTracked: cyclesData.length,
                birthDate: DateTime.now().subtract(const Duration(days: 365 * 30)), // Default to 30 years ago
                lastPeriodDate: DateTime.parse(mostRecentCycle['startDate']),
                cycleLength: mostRecentCycle['cycleLength'] ?? 28,
                periodLength: mostRecentCycle['periodLength'] ?? 5,
                height: 165,
                weight: 60,
                healthConditions: [],
                symptoms: [],
                moods: [],
                notes: [],
                isPremium: false,
                profileImageUrl: null,
                periodHistory: [],
                notificationSettings: {},
                language: 'en',
                medications: [],
                exercises: [],
                nutritionLogs: [],
                sleepLogs: [],
                waterIntake: [],
                goals: [],
                preferences: {},
              );
              
              // Calculate current cycle day based on most recent period
              final today = DateTime.now();
              final lastPeriodDate = DateTime.parse(mostRecentCycle['startDate']);
              final daysSinceLastPeriod = today.difference(lastPeriodDate).inDays;
              final cycleDay = ((daysSinceLastPeriod % (mostRecentCycle['cycleLength'] ?? 28)) + 1).toInt();
              
              print('📊 Calculated cycle day: $cycleDay');
              print('🤖 Starting AI analysis with cycle data...');
              
              // Call AI service with the constructed UserData
              final analysisData = await _aiService.analyzeSymptoms(
                symptomsList, 
                cycleDay, 
                tempUserData
              );
              
              setState(() {
                _aiAnalysisData = analysisData;
                _aiAnalysis = analysisData['analysis'] ?? 'Analysis based on your cycle history.';
                _showAnalysis = true;
                _isLoading = false;
              });
              
              print('✅ AI analysis completed successfully with cycle data');
              return;
            }
          } else {
            print('❌ Failed to get cycles or no cycles available');
          }
          
          // If we couldn't get cycle data, continue with basic fallback
          print('⚠️ Using basic fallback approach...');
          
          // Create a minimal UserData object with reasonable defaults
          final fallbackUserData = UserData(
            id: currentUser?.id ?? 'fallback_id',
            name: currentUser?.name ?? 'User',
            email: currentUser?.email ?? '',
            age: 30,
            cyclesTracked: 0,
            birthDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
            lastPeriodDate: DateTime.now().subtract(const Duration(days: 14)),
            cycleLength: 28,
            periodLength: 5,
            height: 165,
            weight: 60,
            healthConditions: [],
            symptoms: [],
            moods: [],
            notes: [],
            isPremium: false,
            profileImageUrl: null,
            periodHistory: [],
            notificationSettings: {},
            language: 'en',
            medications: [],
            exercises: [],
            nutritionLogs: [],
            sleepLogs: [],
            waterIntake: [],
            goals: [],
            preferences: {},
          );
          
          final analysisData = await _aiService.analyzeSymptoms(
            symptomsList, 
            14, // Assume mid-cycle as fallback
            fallbackUserData
          );
          
          setState(() {
            _aiAnalysisData = analysisData;
            _aiAnalysis = analysisData['analysis'] ?? 'Analysis based on limited data. For more accurate results, please update your profile.';
            _showAnalysis = true;
            _isLoading = false;
          });
          
          print('✅ AI analysis completed with fallback data');
        } catch (fallbackError) {
          print('❌ Fallback approach failed: $fallbackError');
          throw Exception("Unable to analyze symptoms. Please ensure your profile is complete.");
        }
      } else {
        // Use actual user data
        final today = DateTime.now();
        final daysSinceLastPeriod = today.difference(userData.lastPeriodDate).inDays;
        final cycleDay = ((daysSinceLastPeriod % userData.cycleLength) + 1).toInt();

        print('📊 User data available: ${userData.name}, age: ${userData.age}');
        print('📊 Last period date: ${userData.lastPeriodDate}');
        print('📊 Cycle length: ${userData.cycleLength}');
        print('📊 Current cycle day: $cycleDay');

        final analysisData = await _aiService.analyzeSymptoms(symptomsList, cycleDay, userData);

        setState(() {
          _aiAnalysisData = analysisData;
          _aiAnalysis = analysisData['analysis'] ?? 'No analysis available';
          _showAnalysis = true;
          _isLoading = false;
        });

        print('✅ AI analysis completed successfully with user data');
      }
    } catch (e) {
      print('❌ Overall analysis failed: $e');
      setState(() {
        _isLoading = false;
        _aiAnalysis = 'We encountered an issue while analyzing your symptoms. Here are some general insights about your symptoms, though they may not be personalized to your cycle.';
        _showAnalysis = true;
      });
      
      // Create some generic analysis as fallback
      _aiAnalysisData = {
        'analysis': 'The symptoms you\'ve logged are common during menstrual cycles. If you experience severe pain, consider consulting a healthcare provider.',
        'recommendations': [
          'Stay hydrated and maintain a balanced diet',
          'Light exercise like walking can help alleviate some symptoms',
          'Consider over-the-counter pain relief if needed',
          'Ensure you\'re getting enough rest'
        ]
      };
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate personalized analysis: ${e.toString()}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _getSeverityFromLevel(int level) {
    if (level <= 3) return 'mild';
    if (level <= 6) return 'moderate';
    return 'severe';
  }

  String _getSeverityFromPainLevel(int painLevel) {
    if (painLevel <= 3) return 'mild';
    if (painLevel <= 6) return 'moderate';
    return 'severe';
  }

  String _getFlowLevel() {
    // You can implement flow detection based on symptoms
    // For now, return default
    if (_symptoms['Cramps'] == true || _painLevel > 5) {
      return 'medium';
    }
    return 'light';
  }

  String _getMoodFromLevel(int moodLevel) {
    if (moodLevel <= 3) return 'sad';
    if (moodLevel <= 6) return 'normal';
    return 'happy';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Log Symptoms',
        showBackButton: true,
      ),
      body: _showAnalysis ? _buildAnalysisScreen() : _buildSymptomForm(),
    );
  }

  Widget _buildSymptomForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateSelector(),
              const SizedBox(height: 24),
              _buildSymptomsGrid(),
              const SizedBox(height: 24),
              _buildSliders(),
              const SizedBox(height: 32),
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : AnimatedGradientButton(
                        text: 'Analyze Symptoms',
                        onPressed: _analyzeSymptoms,
                        width: double.infinity,
                        height: 56,
                        // borderRadius: 28,
                        gradientColors: const [
                          AppColors.primary,
                          AppColors.secondary,
                        ],
                        icon: Icons.analytics,
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  onSurface: AppColors.secondary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: TextStyles.body2.copyWith(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDate),
                      style: TextStyles.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Symptoms',
          style: TextStyles.heading4.copyWith(
            fontSize: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _symptoms.length,
          itemBuilder: (context, index) {
            final symptom = _symptoms.keys.elementAt(index);
            final isSelected = _symptoms[symptom]!;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _symptoms[symptom] = !isSelected;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _symptomIcons.containsKey(symptom)
                        ? Image.asset(
                            _symptomIcons[symptom]!,
                            width: 32,
                            height: 32,
                          )
                        : Icon(
                            Icons.healing,
                            color: isSelected ? AppColors.primary : Colors.grey,
                            size: 32,
                          ),
                    const SizedBox(height: 8),
                    Text(
                      symptom,
                      style: TextStyles.body2.copyWith(
                        color:
                            isSelected ? AppColors.primary : Colors.grey[700],
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSliders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSlider(
          title: 'Pain Level',
          value: _painLevel,
          onChanged: (value) {
            setState(() {
              _painLevel = value.round();
            });
          },
          color: const Color(0xFFF472B6),
          icon: Icons.healing,
        ),
        const SizedBox(height: 16),
        _buildSlider(
          title: 'Mood Level',
          value: _moodLevel,
          onChanged: (value) {
            setState(() {
              _moodLevel = value.round();
            });
          },
          color: const Color(0xFF60A5FA),
          icon: Icons.mood,
        ),
        const SizedBox(height: 16),
        _buildSlider(
          title: 'Energy Level',
          value: _energyLevel,
          onChanged: (value) {
            setState(() {
              _energyLevel = value.round();
            });
          },
          color: const Color(0xFF34D399),
          icon: Icons.battery_charging_full,
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String title,
    required int value,
    required Function(double) onChanged,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyles.body1.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Low', style: TextStyle(color: Colors.grey)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: color.withOpacity(0.2),
                  thumbColor: color,
                  overlayColor: color.withOpacity(0.2),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: onChanged,
                ),
              ),
            ),
            const Text('High', style: TextStyle(color: Colors.grey)),
          ],
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              value == 0 ? 'None' : value.toString(),
              style: TextStyles.body2.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF0F7FF),
                    Color(0xFFF5F3FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
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
                      const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF6366F1),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AI Analysis',
                        style: TextStyles.heading4.copyWith(
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Based on your symptoms on ${DateFormat('MMMM d').format(_selectedDate)}:',
                    style: TextStyles.body1.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSelectedSymptomsList(),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Analysis & Recommendations',
                    style: TextStyles.body1.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAnalysisContent(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedGradientButton(
                text: 'Save to Journal',
                onPressed: () async {
                  try {
                    // Show loading indicator
                    setState(() {
                      _isLoading = true;
                    });
                    
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final currentUser = authProvider.currentUser;
                    
                    if (currentUser == null) {
                      throw Exception("User not logged in");
                    }
                    
                    // Format date as required by API (YYYY-MM-DD)
                    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
                    
                    // Prepare detailed symptoms with severity for API
                    final List<Map<String, dynamic>> apiSymptoms = _symptoms.entries
                        .where((entry) => entry.value)
                        .map((entry) => {
                              'type': entry.key.toLowerCase().replaceAll(' ', '_'),
                              'severity': _getSeverityFromPainLevel(_painLevel),
                              'notes': '',
                            })
                        .toList();
                    
                    // Add level-based symptoms
                    if (_painLevel > 0) {
                      apiSymptoms.add({
                        'type': 'pain',
                        'severity': _getSeverityFromLevel(_painLevel),
                        'notes': 'Pain level: $_painLevel/10',
                      });
                    }

                    if (_energyLevel > 0) {
                      apiSymptoms.add({
                        'type': 'energy',
                        'severity': _getSeverityFromLevel(_energyLevel),
                        'notes': 'Energy level: $_energyLevel/10',
                      });
                    }
                    
                    if (_moodLevel > 0) {
                      apiSymptoms.add({
                        'type': 'mood',
                        'severity': _getSeverityFromLevel(_moodLevel),
                        'notes': 'Mood level: $_moodLevel/10',
                      });
                    }
                    
                    print('🔄 Saving symptoms to journal/backend...');
                    print('📤 User ID: ${currentUser.id}');
                    print('📤 Date: $formattedDate');
                    print('📤 Symptoms: $apiSymptoms');
                    print('📤 Flow: ${_getFlowLevel()}');
                    print('📤 Mood: ${_getMoodFromLevel(_moodLevel)}');
                    
                    // Call the API service to create symptom log
                    final response = await ApiService.createSymptomLog(
                      userId: currentUser.id,
                      date: formattedDate,
                      symptoms: apiSymptoms,
                      flow: _getFlowLevel(),
                      mood: _getMoodFromLevel(_moodLevel),
                      temperature: null,
                      notes: _aiAnalysis.isNotEmpty ? 'Based on AI analysis: $_aiAnalysis' : 'Logged symptoms',
                    );
                    
                    if (response != null && response['success'] == true) {
                      print('✅ SYMPTOM LOG SAVED TO JOURNAL SUCCESSFULLY!');
                      print('📋 Journal Save Confirmation:');
                      print('  "success": true,');
                      print('  "message": "Symptom log saved to journal successfully",');
                      print('  "data": ${response['data']}');
                      print('  "timestamp": "${DateTime.now().toIso8601String()}",');
                      print('  "symptoms_count": ${_symptoms.values.where((v) => v).length},');
                      print('  "pain_level": $_painLevel,');
                      print('  "mood_level": $_moodLevel,');
                      print('  "energy_level": $_energyLevel');

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Symptoms saved to your journal successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );

                      // Navigate back
                      Navigator.pop(context, true);
                    } else {
                      print('❌ Failed to save symptoms to journal: ${response?['message'] ?? 'Unknown error'}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save symptoms: ${response?['message'] ?? 'Unknown error'}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  } catch (e) {
                    print('❌ Exception while saving symptoms: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                width: double.infinity,
                height: 56,
                gradientColors: const [
                  AppColors.primary,
                  AppColors.secondary,
                ],
                isLoading: _isLoading,
                icon: Icons.check,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSymptomsList() {
    final List<String> selectedSymptoms = _symptoms.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...selectedSymptoms.map((symptom) => _buildSymptomChip(symptom)),
        if (_painLevel > 0)
          _buildLevelChip('Pain: $_painLevel/10', const Color(0xFFF472B6)),
        if (_moodLevel > 0)
          _buildLevelChip('Mood: $_moodLevel/10', const Color(0xFF60A5FA)),
        if (_energyLevel > 0)
          _buildLevelChip('Energy: $_energyLevel/10', const Color(0xFF34D399)),
      ],
    );
  }

  Widget _buildSymptomChip(String symptom) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        symptom,
        style: TextStyles.body2.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildLevelChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyles.body2.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildAnalysisContent() {
    // Check if we have recommendations from the AI service
    List<String> recommendations = [];
    if (_aiAnalysisData.containsKey('recommendations') &&
        _aiAnalysisData['recommendations'] is List) {
      recommendations = List<String>.from(_aiAnalysisData['recommendations']);
    }

    if (_aiAnalysis.isEmpty && recommendations.isEmpty) {
      // Fallback content if no AI analysis is available
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisItem(
            'Your symptoms suggest you may be in the luteal phase of your cycle.',
            Icons.info_outline,
          ),
          _buildAnalysisItem(
            'The combination of fatigue and mood swings is common during this phase due to hormonal changes.',
            Icons.psychology,
          ),
          _buildAnalysisItem(
            'Consider increasing your omega-3 intake to help with mood regulation.',
            Icons.restaurant,
          ),
          _buildAnalysisItem(
            'Try gentle yoga or stretching to alleviate cramps and improve energy levels.',
            Icons.fitness_center,
          ),
          _buildAnalysisItem(
            'Ensure you get 7-8 hours of sleep to help manage fatigue.',
            Icons.nightlight,
          ),
        ],
      );
    } else {
      // Display the AI analysis
      List<Widget> analysisWidgets = [];

      // Add the main analysis
      if (_aiAnalysis.isNotEmpty) {
        analysisWidgets.add(
          _buildAnalysisItem(_aiAnalysis, Icons.info_outline),
        );
      }

      // Add recommendations
      if (recommendations.isNotEmpty) {
        for (var recommendation in recommendations) {
          IconData icon = Icons.lightbulb_outline;

          // Assign appropriate icons based on content
          if (recommendation.toLowerCase().contains('food') ||
              recommendation.toLowerCase().contains('diet') ||
              recommendation.toLowerCase().contains('eat')) {
            icon = Icons.restaurant;
          } else if (recommendation.toLowerCase().contains('exercise') ||
              recommendation.toLowerCase().contains('yoga') ||
              recommendation.toLowerCase().contains('activity')) {
            icon = Icons.fitness_center;
          } else if (recommendation.toLowerCase().contains('sleep') ||
              recommendation.toLowerCase().contains('rest')) {
            icon = Icons.nightlight;
          } else if (recommendation.toLowerCase().contains('water') ||
              recommendation.toLowerCase().contains('hydration')) {
            icon = Icons.water_drop;
          }

          analysisWidgets.add(_buildAnalysisItem(recommendation, icon));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: analysisWidgets,
      );
    }
  }

  Widget _buildAnalysisItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyles.body1.copyWith(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
