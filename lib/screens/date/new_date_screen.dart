import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/widgets/animated_gradient_button.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/services/api_service.dart';

class NewDateScreen extends StatefulWidget {
  final int? cycleLength;
  final int? periodLength;
  final DateTime? lastPeriodDate;

  const NewDateScreen(
      {super.key, this.cycleLength, this.periodLength, this.lastPeriodDate});

  @override
  State<NewDateScreen> createState() => _NewDateScreenState();
}

class _NewDateScreenState extends State<NewDateScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _isLoading = false;
  bool _isLoadingLastPeriod = true;
  late int _cycleLength;
  late int _periodLength;

  @override
  void initState() {
    super.initState();
    _cycleLength = widget.cycleLength ?? 28; // Default if not provided
    _periodLength = widget.periodLength ?? 5; // Default if not provided

    // Initialize with passed date or today
    _selectedDay = widget.lastPeriodDate ?? DateTime.now();
    _focusedDay = _selectedDay;

    // If no date was passed, try to fetch the last period date
    if (widget.lastPeriodDate == null) {
      _fetchLastPeriodDate();
    } else {
      _isLoadingLastPeriod = false;
    }
  }

  Future<void> _fetchLastPeriodDate() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        setState(() {
          _isLoadingLastPeriod = false;
        });
        return;
      }

      print('🔄 Fetching last period date for user: ${currentUser.id}');

      final response = await ApiService.getCycles(
        userId: currentUser.id,
      );

      if (response != null &&
          response['success'] == true &&
          response['data'] is List &&
          (response['data'] as List).isNotEmpty) {
        final cycles = response['data'] as List;
        // Get the most recent cycle
        final lastCycle = cycles.first;
        final lastPeriodDate = DateTime.parse(lastCycle['startDate']);

        print('📅 Last period date found: ${lastCycle['startDate']}');

        // Update the selected date to the last period date
        setState(() {
          _selectedDay = lastPeriodDate;
          _focusedDay = lastPeriodDate;

          // Also update cycle length and period length if available
          _cycleLength = lastCycle['cycleLength'] ?? _cycleLength;
          _periodLength = lastCycle['periodLength'] ?? _periodLength;
        });
      } else {
        print('ℹ️ No previous cycles found or error fetching cycles');
      }
    } catch (e) {
      print('❌ Error fetching last period date: $e');
    } finally {
      setState(() {
        _isLoadingLastPeriod = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoadingLastPeriod
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with back button
                      _buildHeader(),

                      // Calendar card
                      _buildCalendarCard(),

                      const SizedBox(height: 16),

                      // Selected date card
                      _buildSelectedDateCard(),

                      const SizedBox(height: 24),

                      // Set button
                      _buildSetButton(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: -10, end: 0, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      width: double.infinity,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Calendar",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "October",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                defaultTextStyle:
                    const TextStyle(fontSize: 14, color: Colors.black87),
                weekendTextStyle:
                    const TextStyle(fontSize: 14, color: Colors.black87),
                holidayTextStyle:
                    const TextStyle(fontSize: 14, color: Colors.black87),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: Colors.black54),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms, delay: 200.ms)
        .slideY(begin: 20, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildSelectedDateCard() {
    return Container(
      width: double.infinity,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Set as New Period Date",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      DateFormat('d MMMM, yyyy').format(_selectedDay),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Cycle: $_cycleLength days | Period: $_periodLength days",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms, delay: 400.ms)
        .slideY(begin: 20, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildSetButton() {
    return AnimatedGradientButton(
      text: _isLoading ? "SETTING..." : "SET PERIOD DATE",
      onPressed: _isLoading
          ? null
          : () {
              print('🖱️ Set button pressed!');
              _setPeriodDate();
            },
    )
        .animate()
        .fadeIn(duration: 800.ms, delay: 800.ms)
        .slideY(begin: 20, end: 0, curve: Curves.easeOutQuad);
  }

  Future<void> _setPeriodDate() async {
    try {
      print('🔄 Starting _setPeriodDate function...');

      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      print('👤 Current user: ${currentUser?.id ?? "null"}');

      if (currentUser == null) {
        print('❌ No current user found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to set a period date'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Format date as YYYY-MM-DD to ensure proper API handling
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDay);

      print('📅 Setting new period date: $formattedDate');
      print(
          '📊 Using cycle length: $_cycleLength, period length: $_periodLength');

      // Create cycle data with the values passed from the previous screen
      final newCycle = {
        "userId": currentUser.id,
        "startDate": formattedDate,
        "cycleLength": _cycleLength,
        "periodLength": _periodLength,
        "flow": "medium",
        "mood": "normal",
        "symptoms": [],
        "notes": "Period date set from calendar"
      };

      print('📤 Sending cycle data to API: $newCycle');

      // Send to API
      final response = await ApiService.addCycle(newCycle);

      print('📥 API response received: $response');

      // Check for success directly from the response
      if (response != null && response['success'] == true) {
        print('✅ Successfully set period date: $formattedDate');
        print('✅ Response data: ${response['data']}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period date set successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return success to previous screen
      } else {
        print('❌ Failed to set period date');
        print('❌ Response details: $response');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to set period date'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error setting period date: $e');
      print('❌ Stack trace: ${StackTrace.current}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('🏁 _setPeriodDate function completed');
    }
  }
}
