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

  bool _isLoading = false;
  Map<String, dynamic> _report = {};
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _aiConsultations = [];

  // Variables for AI consultation form
  final _symptomsController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();
  double _severity = 5.0;

  // Flag to show which view is active (AI or real doctor)
  bool _showAiDoctorView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _symptomsController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final userData = userDataProvider.userData;
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    // Debug prints to help identify the issue
    print('🔍 DoctorModeScreen Build Debug:');
    print('- User Data: ${userData != null ? "Available" : "Null"}');
    print(
        '- Current User: ${currentUser != null ? "Available (${currentUser.id})" : "Null"}');
    print('- Is Loading: $_isLoading');
    print('- Report Data: ${_report.isEmpty ? "Empty" : "Has Data"}');
    print('- Consultations: ${_consultations.length}');
    print('- AI Consultations: ${_aiConsultations.length}');

    // Check if we need to reload data when user becomes available
    if (currentUser != null &&
        !_isLoading &&
        _report.isEmpty &&
        _consultations.isEmpty &&
        _aiConsultations.isEmpty) {
      print(
          '🔄 Triggering data reload because user is available but data is empty');
      Future.microtask(() => _loadData());
    }

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
              Tab(text: 'Doctor Options', icon: Icon(Icons.health_and_safety)),
              Tab(
                  text: 'Doctor Appointments',
                  icon: Icon(Icons.calendar_month)),
              Tab(text: 'AI Consultations', icon: Icon(Icons.psychology)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : currentUser == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "Please log in to access doctor mode",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDoctorOptionsTab(),
                      _buildDoctorAppointmentsTab(),
                      _buildAIConsultationsTab(),
                    ],
                  ),
      ),
    );
  }

  Future<void> _loadData() async {
    print('🔄 Starting _loadData...');

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      print('🔍 LoadData Debug:');
      print(
          '- Current User: ${currentUser != null ? "Available (${currentUser.id})" : "Null"}');

      if (currentUser != null) {
        print('✅ User is available, loading data...');

        // Load data in parallel
        final results = await Future.wait([
          _loadAIReport().catchError((e) {
            print('❌ AI Report Error: $e');
            return null;
          }),
          _loadConsultations(currentUser.id).catchError((e) {
            print('❌ Consultations Error: $e');
            return null;
          }),
          _loadAIConsultations(currentUser.id).catchError((e) {
            print('❌ AI Consultations Error: $e');
            return null;
          }),
        ]);

        print('📊 Data loading completed:');
        print('- AI Report: ${_report.isNotEmpty ? "Loaded" : "Empty"}');
        print('- Consultations: ${_consultations.length} items');
        print('- AI Consultations: ${_aiConsultations.length} items');
      } else {
        print('❌ No current user available');
      }
    } catch (e) {
      print('❌ Error in _loadData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAIReport() async {
    try {
      final userDataProvider =
          Provider.of<UserDataProvider>(context, listen: false);
      final userData = userDataProvider.userData;

      if (userData != null) {
        print('🔄 Loading AI report...');
        final report = await _aiService.generateDoctorReport(userData);
        if (mounted) {
          setState(() {
            _report = report;
          });
        }
        print('✅ AI report loaded successfully');
      } else {
        print('⚠️ No user data available for AI report');
      }
    } catch (e) {
      print('❌ Error loading AI report: $e');
      // Don't throw, just log the error
    }
  }

  Future<void> _loadConsultations(String userId) async {
    try {
      print('🔄 Loading consultations for user: $userId');

      final response = await ApiService.getDoctorConsultations(
        userId: userId,
      );

      print('📡 Consultations API Response: $response');

      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>?;

        if (mounted) {
          setState(() {
            _consultations = data?.cast<Map<String, dynamic>>() ?? [];
          });
        }

        print('✅ CONSULTATIONS LOADED SUCCESSFULLY!');
        print('📋 Found ${_consultations.length} doctor consultations');
      } else {
        print(
            '❌ Failed to load consultations: ${response?['message'] ?? 'Unknown error'}');
        if (mounted) {
          setState(() {
            _consultations = [];
          });
        }
      }
    } catch (e) {
      print('❌ Exception loading consultations: $e');
      if (mounted) {
        setState(() {
          _consultations = [];
        });
      }
      // Don't throw, just log the error
    }
  }

  Future<void> _loadAIConsultations(String userId) async {
    try {
      print('🔄 Loading AI consultations for user: $userId');

      final response = await ApiService.getAIDoctorConsultations(
        userId: userId,
      );

      print('📡 AI Consultations API Response: $response');

      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>?;

        if (mounted) {
          setState(() {
            _aiConsultations = data?.cast<Map<String, dynamic>>() ?? [];
          });
        }

        print('✅ AI CONSULTATIONS LOADED SUCCESSFULLY!');
        print('📋 Found ${_aiConsultations.length} AI consultations');
      } else {
        print(
            '❌ Failed to load AI consultations: ${response?['message'] ?? 'Unknown error'}');
        if (mounted) {
          setState(() {
            _aiConsultations = [];
          });
        }
      }
    } catch (e) {
      print('❌ Exception loading AI consultations: $e');
      if (mounted) {
        setState(() {
          _aiConsultations = [];
        });
      }
      // Don't throw, just log the error
    }
  }

  Future<void> _createAIDoctorConsultation() async {
    if (_symptomsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your symptoms')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Debug: Test endpoints first (remove this in production)
      print('🔍 Testing AI consultation endpoints...');
      await ApiService.testAIConsultationEndpoint();

      final response = await ApiService.createAIDoctorConsultation(
        userId: currentUser.id,
        symptoms: _symptomsController.text.trim(),
        severity: _severity.toInt(),
        duration: _durationController.text.trim().isEmpty
            ? null
            : _durationController.text.trim(),
        additionalNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (response != null && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI consultation completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form fields
        _symptomsController.clear();
        _durationController.clear();
        _notesController.clear();
        setState(() {
          _severity = 5.0;
        });

        // Reload AI consultations
        await _loadAIConsultations(currentUser.id);

        // Switch to AI consultations history tab
        _tabController.animateTo(2);
      } else {
        throw Exception(response?['message'] ?? 'Unknown error');
      }
    } catch (e) {
      print('❌ AI consultation error details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get AI consultation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    String selectedType = 'virtual';
    int duration = 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Book Real Doctor Consultation'),
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
                    DropdownMenuItem(value: 'virtual', child: Text('Virtual')),
                    DropdownMenuItem(
                        value: 'in-person', child: Text('In-Person')),
                    DropdownMenuItem(value: 'phone', child: Text('Phone')),
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
                    labelText: 'Reason for Consultation',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
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
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorOptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor Options Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose Consultation Type",
                    style: TextStyles.heading4,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAiDoctorView = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _showAiDoctorView
                                  ? const Color(
                                      0xFFD4C1F9) // Lighter purple when selected
                                  : const Color(0xFFE3D5FA), // Light purple
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.psychology,
                                  color: _showAiDoctorView
                                      ? Colors.deepPurple
                                      : Colors.purple,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "AI Doctor",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _showAiDoctorView
                                        ? Colors.deepPurple
                                        : Colors.purple[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Get Prescription",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _showAiDoctorView
                                        ? Colors.deepPurple
                                        : Colors.purple[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAiDoctorView = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: !_showAiDoctorView
                                  ? const Color(
                                      0xFFA7EED2) // Lighter green when selected
                                  : const Color(0xFFC7F5E4), // Light green
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person,
                                  color: !_showAiDoctorView
                                      ? Colors.green[700]
                                      : Colors.green,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Real Doctor",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !_showAiDoctorView
                                        ? Colors.green[700]
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Book Appointment",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: !_showAiDoctorView
                                        ? Colors.green[700]
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 20, end: 0),

          const SizedBox(height: 24),

          // Show either AI Doctor form or Real Doctor booking button
          if (_showAiDoctorView)
            _buildAIDoctorRequestForm()
          else
            _buildRealDoctorBookingSection(),

          const SizedBox(height: 24),

          // Previous consultations preview
          if (_showAiDoctorView && _aiConsultations.isNotEmpty)
            _buildPreviousAIPrescriptionsPreview()
          else if (!_showAiDoctorView && _consultations.isNotEmpty)
            _buildUpcomingAppointmentsPreview(),
        ],
      ),
    );
  }

  Widget _buildAIDoctorRequestForm() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "AI Prescription Request",
              style: TextStyles.heading4,
            ),
            const SizedBox(height: 8),
            Text(
              "Fill out your symptoms below and click \"Get AI Prescription\" to receive an instant analysis.",
              style: TextStyles.body2,
            ),
            const SizedBox(height: 20),
            Text(
              "Symptoms",
              style: TextStyles.subtitle2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _symptomsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Describe your symptoms...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Severity (1-10)",
              style: TextStyles.subtitle2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text("1", style: TextStyles.body2),
                Expanded(
                  child: Slider(
                    value: _severity,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _severity.round().toString(),
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() {
                        _severity = value;
                      });
                    },
                  ),
                ),
                Text("10", style: TextStyles.body2),
              ],
            ),
            Center(
              child: Text(
                "${_severity.toInt()}/10",
                style: TextStyles.body2.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Duration",
              style: TextStyles.subtitle2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                hintText: "e.g., 3 days, 1 week",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Additional Notes",
              style: TextStyles.subtitle2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Any additional information...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createAIDoctorConsultation,
                  icon: const Icon(Icons.psychology),
                  label: const Text("Get AI Prescription"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 20, end: 0);
  }

  Widget _buildRealDoctorBookingSection() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Book a Real Doctor Appointment",
              style: TextStyles.heading4,
            ),
            const SizedBox(height: 8),
            Text(
              "Schedule a consultation with a healthcare professional for personalized care.",
              style: TextStyles.body2,
            ),
            const SizedBox(height: 20),

            // Appointment features
            Row(
              children: [
                _buildFeatureItem(Icons.videocam, "Virtual Consultations"),
                const SizedBox(width: 16),
                _buildFeatureItem(Icons.local_hospital, "In-Person Visits"),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildFeatureItem(Icons.security, "Secure & Private"),
                const SizedBox(width: 16),
                _buildFeatureItem(Icons.schedule, "Flexible Scheduling"),
              ],
            ),

            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAddConsultationDialog,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("Book Appointment"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 20, end: 0);
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousAIPrescriptionsPreview() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Previous AI Prescriptions",
                  style: TextStyles.subtitle1
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(2);
                  },
                  child: const Text("See All"),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Show latest 2 AI consultations
            ..._aiConsultations.take(2).map((consultation) =>
                _buildAIConsultationPreviewItem(consultation)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 20, end: 0);
  }

  Widget _buildUpcomingAppointmentsPreview() {
    // Filter to show only upcoming appointments
    final upcomingAppointments = _consultations.where((c) {
      // Fix: Handle null status safely
      final status = c['status'] as String? ?? 'scheduled';

      // Fix: Handle null scheduledDate safely
      final scheduledDateStr = c['scheduledDate'] as String?;
      if (scheduledDateStr == null) return false;

      try {
        final scheduledDate = DateTime.parse(scheduledDateStr);
        return status == 'scheduled' && scheduledDate.isAfter(DateTime.now());
      } catch (e) {
        print('Error parsing scheduledDate: $scheduledDateStr, error: $e');
        return false;
      }
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Upcoming Appointments",
                  style: TextStyles.subtitle1
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(1);
                  },
                  child: const Text("See All"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (upcomingAppointments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "No upcoming appointments",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              // Show latest 2 upcoming appointments
              ...upcomingAppointments.take(2).map(
                  (consultation) => _buildAppointmentPreviewItem(consultation)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 20, end: 0);
  }

  Widget _buildAppointmentPreviewItem(Map<String, dynamic> consultation) {
    final scheduledDate = DateTime.parse(consultation['scheduledDate']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.green, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation['doctorName'] ?? "Doctor",
                      style: TextStyles.body2
                          .copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${DateFormat('MMM d, yyyy').format(scheduledDate)} at ${DateFormat('h:mm a').format(scheduledDate)}",
                      style: TextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
          if (consultation['type'] != null) ...[
            const SizedBox(height: 8),
            Text(
              "Type: ${_capitalizeFirst(consultation['type'])}",
              style: TextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAIConsultationPreviewItem(Map<String, dynamic> consultation) {
    final createdAt = DateTime.parse(consultation['createdAt']);
    final symptoms =
        consultation['symptoms'] as String? ?? 'No symptoms specified';
    final severity = consultation['severity'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology,
                    color: Colors.deepPurple, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI Prescription",
                      style: TextStyles.body2
                          .copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(createdAt),
                      style: TextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$severity/10",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getSeverityColor(severity),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Symptoms: ${symptoms.length > 50 ? '${symptoms.substring(0, 50)}...' : symptoms}",
            style: TextStyles.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAppointmentsTab() {
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
                    'Book your first consultation',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _consultations.length + 1, // +1 for the Add button
              itemBuilder: (context, index) {
                // Add button at the top
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: _showAddConsultationDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("Schedule New Consultation"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: -20, end: 0);
                }

                final consultation = _consultations[index - 1];
                return _buildConsultationCard(consultation);
              },
            ),
    );
  }

  Widget _buildAIConsultationsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          await _loadAIConsultations(currentUser.id);
        }
      },
      child: _aiConsultations.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No AI consultations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try getting your first AI prescription',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _aiConsultations.length + 1, // +1 for the Add button
              itemBuilder: (context, index) {
                // Add button at the top
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _tabController.animateTo(0); // Go to options tab
                        setState(() {
                          _showAiDoctorView = true; // Show AI doctor form
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Get New AI Prescription"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: -20, end: 0);
                }

                final consultation = _aiConsultations[index - 1];
                return _buildAIConsultationCard(consultation);
              },
            ),
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> consultation) {
    // Fix: Handle null scheduledDate safely
    final scheduledDateStr = consultation['scheduledDate'] as String?;
    if (scheduledDateStr == null) {
      // Return an error card or skip this consultation
      return const SizedBox.shrink();
    }

    DateTime scheduledDate;
    try {
      scheduledDate = DateTime.parse(scheduledDateStr);
    } catch (e) {
      print('Error parsing scheduledDate: $scheduledDateStr, error: $e');
      return const SizedBox.shrink();
    }

    final isUpcoming = scheduledDate.isAfter(DateTime.now());
    final status = consultation['status'] as String? ??
        'scheduled'; // Fix: Handle null status

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

    // ...rest of the existing method remains the same
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
                        consultation['doctorName'] as String? ??
                            'Unknown Doctor', // Fix: Handle null
                        style: TextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _capitalizeFirst(consultation['type'] as String? ??
                            'General'), // Fix: Handle null
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
                      '${consultation['duration'] as int? ?? 30} min', // Fix: Handle null
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
                consultation['reason'] as String,
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
                consultation['notes'] as String,
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
                      consultation['id'] as String,
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
                      consultation['id'] as String,
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

  Widget _buildAIConsultationCard(Map<String, dynamic> consultation) {
    final createdAt = DateTime.parse(consultation['createdAt']);
    final aiResponse = consultation['aiResponse'] as String? ?? '';

    // Extract sections from AI response
    final sections = _extractAIResponseSections(aiResponse);

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
                    color: Colors.deepPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Prescription",
                        style: TextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM d, yyyy').format(createdAt),
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "COMPLETED",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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

            // Symptoms and Severity
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Symptoms",
                        style: TextStyles.body2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        consultation['symptoms']?.toString() ?? 'Not specified', // Fix: Convert to string
                        style: TextStyles.body2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Severity",
                      style: TextStyles.body2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${consultation['severity']?.toString() ?? 'N/A'}/10", // Fix: Convert to string
                      style: TextStyles.body2.copyWith(
                        color: _getSeverityColor(consultation['severity'] as int? ?? 0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Duration
            if (consultation['duration'] != null) ...[
              const SizedBox(height: 12),
              Text(
                "Duration",
                style: TextStyles.body2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                consultation['duration']?.toString() ?? '', // Fix: Convert to string
                style: TextStyles.body2,
              ),
            ],

            // Additional Notes
            if (consultation['additionalNotes'] != null &&
                consultation['additionalNotes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Additional Notes",
                style: TextStyles.body2.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                consultation['additionalNotes']?.toString() ?? '', // Fix: Convert to string
                style: TextStyles.body2,
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // AI Response Sections
            if (sections.isNotEmpty) ...[
              Text(
                "AI Analysis & Recommendations",
                style: TextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              for (var entry in sections.entries) ...[
                if (entry.value.isNotEmpty) ...[
                  Text(
                    entry.key,
                    style: TextStyles.body2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getSectionColor(entry.key),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.value,
                    style: TextStyles.body2,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ] else if (aiResponse.isNotEmpty) ...[
              Text(
                "AI Analysis",
                style: TextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                aiResponse,
                style: TextStyles.body2,
              ),
            ],
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to update consultation: ${response?['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
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

  Map<String, String> _extractAIResponseSections(String response) {
    final Map<String, String> sections = {};

    try {
      final sectionNames = [
        'MEDICAL ASSESSMENT',
        'DIAGNOSIS/IMPRESSION',
        'RECOMMENDATIONS',
        'PRESCRIPTION',
        'FOLLOW-UP'
      ];

      for (int i = 0; i < sectionNames.length; i++) {
        final currentSection = sectionNames[i];
        final nextSection =
            i < sectionNames.length - 1 ? sectionNames[i + 1] : null;

        int startIndex = response.indexOf(currentSection);
        if (startIndex != -1) {
          startIndex += currentSection.length;

          int endIndex;
          if (nextSection != null) {
            endIndex = response.indexOf(nextSection, startIndex);
            if (endIndex == -1) endIndex = response.length;
          } else {
            endIndex = response.length;
          }

          String content = response.substring(startIndex, endIndex).trim();
          // Remove any leading ":" or newlines
          content = content.replaceFirst(RegExp(r'^[:\s\n]+'), '').trim();

          sections[currentSection] = content;
        }
      }
    } catch (e) {
      print('Error parsing AI response: $e');
    }

    return sections;
  }

  Color _getSeverityColor(int severity) {
    if (severity <= 3) return Colors.green;
    if (severity <= 6) return Colors.orange;
    return Colors.red;
  }

  Color _getSectionColor(String section) {
    switch (section) {
      case 'MEDICAL ASSESSMENT':
        return Colors.blue;
      case 'DIAGNOSIS/IMPRESSION':
        return Colors.purple;
      case 'RECOMMENDATIONS':
        return Colors.teal;
      case 'PRESCRIPTION':
        return Colors.orange;
      case 'FOLLOW-UP':
        return Colors.indigo;
      default:
        return Colors.black;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text
        .toLowerCase()
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
