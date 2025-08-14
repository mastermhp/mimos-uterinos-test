import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:menstrual_health_ai/screens/cycle/log_symptoms_screen.dart';
import 'package:menstrual_health_ai/screens/date/new_date_screen.dart';
import 'package:menstrual_health_ai/screens/doctor/doctor_mode_screen.dart';
import 'package:menstrual_health_ai/screens/reports/reports_screen.dart';
import 'package:menstrual_health_ai/widgets/animated_gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class CycleCalendarScreen extends StatefulWidget {
  const CycleCalendarScreen({super.key});

  @override
  State<CycleCalendarScreen> createState() => _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends State<CycleCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  // Cycle data from API
  List<Map<String, dynamic>> _cycles = [];
  List<DateTime> _periodDays = [];
  List<DateTime> _fertileDays = [];
  DateTime? _ovulationDay;

  // Current cycle info
  int _currentCycleLength = 28;
  int _currentPeriodLength = 5;
  DateTime? _nextPeriodDate;
  DateTime? _nextOvulationDate;

  @override
  void initState() {
    super.initState();
    _loadCycleData();
  }

  Future<void> _loadCycleData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        print('❌ No current user found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('🔄 Loading cycle data for user: ${currentUser.id}');

      final response = await ApiService.getCycles(
        userId: currentUser.id,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>;

        setState(() {
          _cycles = data.cast<Map<String, dynamic>>();
        });

        print('✅ Loaded ${_cycles.length} cycles from backend');
        _calculateCycleDates();
        _displaySuccessResponse(response);
      } else {
        print('❌ Failed to load cycle data or no cycles exist');
        _loadDefaultData();
      }
    } catch (e) {
      print('❌ Error loading cycle data: $e');
      _loadDefaultData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _displaySuccessResponse(Map<String, dynamic> response) {
    print('✅ CYCLES LOADED SUCCESSFULLY!');
    print('📋 Success Response:');
    print('{');
    print('  "success": ${response['success']},');
    print('  "data": [');
    final data = response['data'] as List<dynamic>;
    for (int i = 0; i < data.length; i++) {
      final cycle = data[i];
      print('    {');
      print('      "id": "${cycle['id']}",');
      print('      "userId": "${cycle['userId']}",');
      print('      "startDate": "${cycle['startDate']}",');
      print('      "endDate": "${cycle['endDate'] ?? 'null'}",');
      print('      "cycleLength": ${cycle['cycleLength']},');
      print('      "periodLength": ${cycle['periodLength']},');
      print('      "flow": "${cycle['flow']}",');
      print('      "mood": "${cycle['mood']}",');
      print('      "symptoms": ${cycle['symptoms']},');
      print('      "temperature": ${cycle['temperature'] ?? 'null'},');
      print('      "notes": "${cycle['notes']}",');
      print('      "createdAt": "${cycle['createdAt']}",');
      print('      "updatedAt": "${cycle['updatedAt']}"');
      print('    }${i < data.length - 1 ? ',' : ''}');
    }
    print('  ]');
    print('}');
  }

  void _calculateCycleDates() {
    if (_cycles.isEmpty) {
      _loadDefaultData();
      return;
    }

    // Get the most recent cycle
    final lastCycle = _cycles.first;
    final startDate = DateTime.parse(lastCycle['startDate']);
    _currentCycleLength = lastCycle['cycleLength'] ?? 28;
    _currentPeriodLength = lastCycle['periodLength'] ?? 5;

    // Calculate period days from all cycles
    _periodDays.clear();
    for (final cycle in _cycles) {
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

    print('📊 Calculated cycle dates:');
    print('  Next period: $_nextPeriodDate');
    print('  Next ovulation: $_nextOvulationDate');
    print('  Fertile days: ${_fertileDays.length}');
    print('  Period days: ${_periodDays.length}');
  }

  void _loadDefaultData() {
    // Fallback to default data if no cycles available
    final today = DateTime.now();
    _periodDays = [
      today.subtract(const Duration(days: 2)),
      today.subtract(const Duration(days: 1)),
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
    ];

    _fertileDays = [
      today.add(const Duration(days: 12)),
      today.add(const Duration(days: 13)),
      today.add(const Duration(days: 14)),
      today.add(const Duration(days: 15)),
      today.add(const Duration(days: 16)),
    ];

    _ovulationDay = today.add(const Duration(days: 14));
    _nextPeriodDate = today.add(const Duration(days: 28));
    _nextOvulationDate = today.add(const Duration(days: 14));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCycleData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header - SIMPLIFIED (removed reload button)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Left side - Title section (flexible)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "My Cycle",
                                    style: TextStyles.heading2,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Track your period and symptoms",
                                    style: TextStyles.subtitle2,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Right side - Action buttons (only 2 buttons now)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NewDateScreen(),
                                      ),
                                    ).then((_) => _loadCycleData());
                                  },
                                  icon: const Icon(Icons.calendar_month),
                                  color: AppColors.primary,
                                  iconSize: 24,
                                  tooltip: 'Set Period Date',
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DoctorModeScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                      Icons.medical_services_outlined),
                                  color: AppColors.primary,
                                  iconSize: 24,
                                  tooltip: 'Doctor Mode',
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: -10, end: 0),

                      // Calendar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2023, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            weekendTextStyle:
                                const TextStyle(color: Colors.red),
                            holidayTextStyle:
                                const TextStyle(color: Colors.red),
                            todayDecoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: true,
                            titleCentered: true,
                            formatButtonDecoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            formatButtonTextStyle: TextStyle(
                              color: AppColors.primary,
                            ),
                            titleTextStyle: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              final isPeriodDay =
                                  _periodDays.any((d) => isSameDay(d, date));
                              final isFertileDay =
                                  _fertileDays.any((d) => isSameDay(d, date));
                              final isOvulationDay = _ovulationDay != null &&
                                  isSameDay(_ovulationDay!, date);

                              if (isPeriodDay) {
                                return Positioned(
                                  bottom: 8,
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }

                              if (isOvulationDay) {
                                return Positioned(
                                  bottom: 8,
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }

                              if (isFertileDay) {
                                return Positioned(
                                  bottom: 8,
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }

                              return null;
                            },
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 200.ms),

                      // Legend
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegendItem(
                                "Period", AppColors.primary.withOpacity(0.3)),
                            _buildLegendItem("Fertile Window",
                                Colors.green.withOpacity(0.2)),
                            _buildLegendItem(
                                "Ovulation", Colors.purple.withOpacity(0.3)),
                          ],
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 400.ms),

                      // AI Prediction Card
                      _buildAIPredictionCard(),

                      // Cycle Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Cycle Information",
                                style: TextStyles.heading3,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildCycleInfoItem(
                                    "Cycle Length",
                                    "$_currentCycleLength days",
                                    Icons.loop_rounded,
                                    AppColors.primary,
                                  ),
                                  _buildCycleInfoItem(
                                    "Period Length",
                                    "$_currentPeriodLength days",
                                    Icons.calendar_today_rounded,
                                    Colors.red,
                                  ),
                                  _buildCycleInfoItem(
                                    "Ovulation",
                                    "Day ${(_currentCycleLength / 2).round()}",
                                    Icons.egg_alt_rounded,
                                    Colors.purple,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 600.ms),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AnimatedGradientButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LogSymptomsScreen(),
                                        ),
                                      ).then((_) => _loadCycleData());
                                    },
                                    text: "Log Symptoms",
                                    icon: Icons.add_circle_outline_rounded,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AnimatedGradientButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const NewDateScreen(),
                                        ),
                                      ).then((_) => _loadCycleData());
                                    },
                                    text: "Set Period Date",
                                    icon: Icons.calendar_today_rounded,
                                    gradientColors: [
                                      Colors.purple,
                                      Colors.purpleAccent,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AnimatedGradientButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const DoctorModeScreen(),
                                        ),
                                      );
                                    },
                                    text: "Doctor Mode",
                                    icon: Icons.medical_services_rounded,
                                    gradientColors: [
                                      Colors.blue,
                                      Colors.lightBlueAccent,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AnimatedGradientButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ReportsScreen(),
                                        ),
                                      );
                                    },
                                    text: "View Reports",
                                    icon: Icons.bar_chart_rounded,
                                    gradientColors: [
                                      Colors.orange,
                                      Colors.amber,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 800.ms),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCycleInfoItem(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
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
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAIPredictionCard() {
    final nextPeriodText = _nextPeriodDate != null
        ? "Likely to start around ${DateFormat('MMM dd').format(_nextPeriodDate!)}"
        : "Loading prediction...";

    final ovulationText = _nextOvulationDate != null
        ? "Expected around ${DateFormat('MMM dd').format(_nextOvulationDate!)}"
        : "Calculating...";

    final fertileText = _fertileDays.isNotEmpty
        ? "${DateFormat('MMM dd').format(_fertileDays.first)}-${DateFormat('dd').format(_fertileDays.last)} (${_fertileDays.length} days)"
        : "Calculating...";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6A11CB),
            Color(0xFF2575FC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "AI Prediction",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPredictionItem(
            icon: Icons.calendar_today,
            title: "Next Period",
            prediction: nextPeriodText,
          ),
          const SizedBox(height: 12),
          _buildPredictionItem(
            icon: Icons.egg_alt,
            title: "Ovulation Window",
            prediction: ovulationText,
          ),
          const SizedBox(height: 12),
          _buildPredictionItem(
            icon: Icons.water_drop,
            title: "Fertile Days",
            prediction: fertileText,
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
                    _cycles.isNotEmpty
                        ? "Predictions based on your ${_cycles.length} recorded cycle${_cycles.length > 1 ? 's' : ''}. Keep logging for better accuracy."
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
    ).animate().fadeIn(duration: 800.ms, delay: 1000.ms);
  }

  Widget _buildPredictionItem({
    required IconData icon,
    required String title,
    required String prediction,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              prediction,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
