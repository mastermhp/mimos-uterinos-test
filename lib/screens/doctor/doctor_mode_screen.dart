import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/models/user_data.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/providers/theme_provider.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/services/ai_service.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:menstrual_health_ai/widgets/animated_gradient_button.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class DoctorModeScreen extends StatefulWidget {
  const DoctorModeScreen({super.key});

  @override
  State<DoctorModeScreen> createState() => _DoctorModeScreenState();
}

class _DoctorModeScreenState extends State<DoctorModeScreen>
    with SingleTickerProviderStateMixin {
  final AIService _aiService = AIService();
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic> _report = {};
  List<Map<String, dynamic>> _consultations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData =
          Provider.of<UserDataProvider>(context, listen: false).userData;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (userData != null && currentUser != null) {
        // Load AI report and consultations in parallel
        await Future.wait([
          _loadAIReport(userData),
          _loadConsultations(currentUser.id),
        ]);
      }
    } catch (e) {
      print('❌ Error loading doctor data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAIReport(UserData userData) async {
    try {
      final report = await _aiService.generateDoctorReport(userData);
      setState(() {
        _report = report;
      });
      print('✅ AI report loaded successfully');
    } catch (e) {
      print('❌ Error loading AI report: $e');
    }
  }

  Future<void> _loadConsultations(String userId) async {
    try {
      print('🔄 Loading consultations for user: $userId');

      final response = await ApiService.getDoctorConsultations(
        userId: userId,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>;

        setState(() {
          _consultations = data.cast<Map<String, dynamic>>();
        });

        print('✅ CONSULTATIONS LOADED SUCCESSFULLY!');
        _displayConsultationsResponse(response);
      } else {
        print('❌ Failed to load consultations or no consultations exist');
        setState(() {
          _consultations = [];
        });
      }
    } catch (e) {
      print('❌ Error loading consultations: $e');
      setState(() {
        _consultations = [];
      });
    }
  }

  void _displayConsultationsResponse(Map<String, dynamic> response) {
    print('📋 Consultations Success Response:');
    print('{');
    print('  "success": ${response['success']},');
    print('  "data": [');

    final data = response['data'] as List<dynamic>;
    for (int i = 0; i < data.length; i++) {
      final consultation = data[i];
      print('    {');
      print('      "id": "${consultation['id']}",');
      print('      "userId": "${consultation['userId']}",');
      print('      "doctorName": "${consultation['doctorName']}",');
      print('      "type": "${consultation['type']}",');
      print('      "scheduledDate": "${consultation['scheduledDate']}",');
      print('      "duration": ${consultation['duration']},');
      print('      "reason": "${consultation['reason']}",');
      print('      "notes": "${consultation['notes']}",');
      print('      "status": "${consultation['status']}",');
      print('      "createdAt": "${consultation['createdAt']}",');
      print('      "updatedAt": "${consultation['updatedAt']}"');
      print('    }${i < data.length - 1 ? ',' : ''}');
    }
    print('  ]');
    print('}');
  }

  Future<void> _showAddConsultationDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    final TextEditingController doctorController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedType = 'general';
    int duration = 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule Consultation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: doctorController,
                  decoration: const InputDecoration(
                    labelText: 'Doctor Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Consultation Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(
                        value: 'specialist', child: Text('Specialist')),
                    DropdownMenuItem(
                        value: 'followup', child: Text('Follow-up')),
                    DropdownMenuItem(
                        value: 'emergency', child: Text('Emergency')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(
                            'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('Time: ${selectedTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setState(() {
                              selectedTime = time;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: duration,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 minutes')),
                    DropdownMenuItem(value: 30, child: Text('30 minutes')),
                    DropdownMenuItem(value: 45, child: Text('45 minutes')),
                    DropdownMenuItem(value: 60, child: Text('60 minutes')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      duration = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for consultation',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (doctorController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter doctor name')),
                  );
                  return;
                }

                try {
                  final scheduledDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  final response = await ApiService.createDoctorConsultation(
                    userId: currentUser.id,
                    doctorName: doctorController.text.trim(),
                    scheduledDate: scheduledDateTime.toIso8601String(),
                    type: selectedType,
                    duration: duration,
                    reason: reasonController.text.trim(),
                    notes: notesController.text.trim(),
                  );

                  if (response != null && response['success'] == true) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Consultation scheduled successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadConsultations(currentUser.id);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to schedule consultation: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final userData = Provider.of<UserDataProvider>(context).userData;

    return Theme(
      data: themeProvider.getTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Doctor Mode"),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'AI Report', icon: Icon(Icons.psychology)),
              Tab(text: 'Consultations', icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : userData == null
                ? const Center(
                    child: Text("No user data available"),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAIReportTab(userData, isDarkMode),
                      _buildConsultationsTab(),
                    ],
                  ),
        floatingActionButton: _tabController.index == 1
            ? FloatingActionButton(
                onPressed: _showAddConsultationDialog,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildAIReportTab(UserData userData, bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(userData),
          const SizedBox(height: 24),
          _buildSummaryCard(),
          const SizedBox(height: 24),
          _buildMedicationsCard(),
          const SizedBox(height: 24),
          _buildRecommendationsCard(),
          const SizedBox(height: 32),
          AnimatedGradientButton(
            text: "Generate PDF Report",
            onPressed: _generateAndSharePDF,
            icon: Icons.picture_as_pdf,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "This report is generated by AI and should be reviewed by a healthcare professional. It is not a substitute for professional medical advice.",
                    style: TextStyles.caption.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildConsultationsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          await _loadConsultations(currentUser.id);
        }
      },
      child: _consultations.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No consultations scheduled',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to schedule your first consultation',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _consultations.length,
              itemBuilder: (context, index) {
                final consultation = _consultations[index];
                return _buildConsultationCard(consultation);
              },
            ),
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> consultation) {
    final scheduledDate = DateTime.parse(consultation['scheduledDate']);
    final isUpcoming = scheduledDate.isAfter(DateTime.now());
    final status = consultation['status'] ?? 'scheduled';

    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'scheduled':
      default:
        statusColor = isUpcoming ? AppColors.primary : Colors.orange;
        statusIcon = isUpcoming ? Icons.schedule : Icons.warning;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        consultation['doctorName'] ?? 'Unknown Doctor',
                        style: TextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (consultation['type'] ?? 'General')
                            .toLowerCase()
                            .split(' ')
                            .map((word) => word.isEmpty
                                ? word
                                : word[0].toUpperCase() + word.substring(1))
                            .join(' '),
                        style: TextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM dd, yyyy').format(scheduledDate),
                        style: TextStyles.body2,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('hh:mm a').format(scheduledDate),
                        style: TextStyles.body2,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.timer,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${consultation['duration'] ?? 30} min',
                      style: TextStyles.body2,
                    ),
                  ],
                ),
              ],
            ),
            if (consultation['reason'] != null &&
                consultation['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Reason:',
                style: TextStyles.body2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                consultation['reason'],
                style: TextStyles.body2,
              ),
            ],
            if (consultation['notes'] != null &&
                consultation['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes:',
                style: TextStyles.body2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                consultation['notes'],
                style: TextStyles.body2.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status.toLowerCase() == 'scheduled') ...[
                  TextButton.icon(
                    onPressed: () => _updateConsultationStatus(
                      consultation['id'],
                      'completed',
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark Complete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _updateConsultationStatus(
                      consultation['id'],
                      'cancelled',
                    ),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 20, end: 0);
  }

  Future<void> _updateConsultationStatus(
      String consultationId, String status) async {
    try {
      final response = await ApiService.updateDoctorConsultation(
        consultationId: consultationId,
        status: status,
      );

      if (response != null && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Consultation $status successfully!'),
            backgroundColor:
                status == 'completed' ? Colors.green : Colors.orange,
          ),
        );

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          await _loadConsultations(currentUser.id);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update consultation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateAndSharePDF() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData =
          Provider.of<UserDataProvider>(context, listen: false).userData;
      if (userData == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Show a message that PDF generation is not available in this version
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'PDF generation is not available in this version. Please install the pdf and share_plus packages.'),
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating PDF: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate PDF. Please try again.'),
        ),
      );
    }
  }

  // ... existing methods like _buildHeader, _buildSummaryCard, etc. remain the same ...

  Widget _buildHeader(UserData userData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFE899B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_information_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Medical Report",
                      style: TextStyles.heading3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "For Dr. Review",
                      style: TextStyles.body2.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(
            color: Colors.white24,
            height: 1,
          ),
          const SizedBox(height: 20),
          _buildPatientInfoRow("Name", userData.name),
          const SizedBox(height: 8),
          _buildPatientInfoRow("Age", "${userData.age} years"),
          const SizedBox(height: 8),
          _buildPatientInfoRow("Height", "${userData.height} cm"),
          const SizedBox(height: 8),
          _buildPatientInfoRow("Weight", "${userData.weight} kg"),
          const SizedBox(height: 8),
          _buildPatientInfoRow("Cycle Length", "${userData.cycleLength} days"),
          const SizedBox(height: 8),
          _buildPatientInfoRow(
              "Period Length", "${userData.periodLength} days"),
          const SizedBox(height: 8),
          _buildPatientInfoRow(
            "Last Period",
            userData.lastPeriodDate.toString().split(' ')[0],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 20, end: 0);
  }

  Widget _buildPatientInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: TextStyles.body2.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        Text(
          value,
          style: TextStyles.body2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.summarize_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Summary",
                style: TextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _report['summary'] ?? 'No summary available.',
            style: TextStyles.body2,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
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
                        "Next Period Expected",
                        style: TextStyles.body2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _report['nextPeriodStart'] != null
                            ? DateTime.parse(_report['nextPeriodStart'])
                                .toString()
                                .split(' ')[0]
                            : 'Not available',
                        style: TextStyles.body2.copyWith(
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
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms)
        .slideY(delay: 200.ms, begin: 20, end: 0);
  }

  Widget _buildMedicationsCard() {
    final medications = _report['medications'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Medications",
                style: TextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (medications.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: medications.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final medication = medications[index];
                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_liquid_outlined,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication['name'] ?? '',
                            style: TextStyles.body1.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${medication['dosage'] ?? ''} - ${medication['days'] ?? ''} days",
                            style: TextStyles.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Text(
              "No medications recommended.",
              style: TextStyles.body2,
            ),
          const SizedBox(height: 16),
          Text(
            _report['medicationNotes'] ?? '',
            style: TextStyles.body2.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 600.ms)
        .slideY(delay: 400.ms, begin: 20, end: 0);
  }

  Widget _buildRecommendationsCard() {
    final recommendations = _report['recommendations'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.recommend_outlined,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Recommendations",
                style: TextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recommendations.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recommendations.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final recommendation = recommendations[index];
                final IconData icon = _getRecommendationIcon(
                    recommendation['type'] as String? ?? 'general');
                final Color color = _getRecommendationColor(
                    recommendation['type'] as String? ?? 'general');

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recommendation['title'] ?? '',
                            style: TextStyles.body1.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recommendation['description'] ?? '',
                            style: TextStyles.body2,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Text(
              "No recommendations available.",
              style: TextStyles.body2,
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 600.ms, duration: 600.ms)
        .slideY(delay: 600.ms, begin: 20, end: 0);
  }

  IconData _getRecommendationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'hydration':
        return Icons.water_drop_outlined;
      case 'nutrition':
        return Icons.restaurant_outlined;
      case 'exercise':
        return Icons.fitness_center_outlined;
      case 'sleep':
        return Icons.bedtime_outlined;
      case 'medication':
        return Icons.medication_outlined;
      case 'stress':
        return Icons.spa_outlined;
      default:
        return Icons.recommend_outlined;
    }
  }

  Color _getRecommendationColor(String type) {
    switch (type.toLowerCase()) {
      case 'hydration':
        return Colors.blue;
      case 'nutrition':
        return Colors.green;
      case 'exercise':
        return Colors.orange;
      case 'sleep':
        return Colors.indigo;
      case 'medication':
        return Colors.purple;
      case 'stress':
        return Colors.teal;
      default:
        return AppColors.accent;
    }
  }
}
