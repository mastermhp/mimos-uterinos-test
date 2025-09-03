import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:math'; // Added missing import for pow and sqrt
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/services/ai_service.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:menstrual_health_ai/widgets/animated_gradient_button.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AIService _aiService = AIService();
  bool _isLoading = true;
  List<dynamic> _reports = [];
  Map<String, dynamic>? _selectedReport;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        print('❌ No current user found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get reports from API
      final response = await ApiService.getUserReports(userId: currentUser.id);

      if (response != null &&
          response['success'] == true &&
          response['data'] != null) {
        final reportsList = response['data'] as List<dynamic>;

        // Debug the report data
        print('✅ Loaded ${reportsList.length} reports');
        for (var report in reportsList) {
          print('📊 Report: ${report['title']}');
        }

        setState(() {
          _reports = reportsList;
          _isLoading = false;
        });
      } else {
        print('⚠️ Failed to get reports or no reports available');
        setState(() {
          _reports = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading reports: $e');
      setState(() {
        _reports = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _generateNewReport() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get user cycles from API directly to ensure data consistency
      final cyclesResponse = await ApiService.getCycles(userId: currentUser.id);

      if (cyclesResponse == null || cyclesResponse['success'] != true) {
        print('❌ Failed to fetch cycles for report generation');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch cycle data for report'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Extract cycles data
      final cyclesList = cyclesResponse['data'] as List<dynamic>;

      // Calculate metrics
      final now = DateTime.now();
      int totalCycles = cyclesList.length;
      int avgCycleLength = _calculateAverageCycleLengthFromCycles(cyclesList);
      String cycleRegularity = _determineCycleRegularity(cyclesList);

      // Format dates
      final startDate = DateTime(now.year, now.month - 1, now.day);
      final endDate = now;

      // Build the report object
      final report = {
        "userId": currentUser.id,
        "title": "Health Report - ${DateFormat('M/d/yyyy').format(now)}",
        "type": "monthly_summary",
        "dateRange": {
          "start": startDate.toIso8601String(),
          "end": endDate.toIso8601String()
        },
        "data": {
          "totalCycles": totalCycles,
          "averageCycleLength": avgCycleLength,
          "commonSymptoms": _extractCommonSymptoms(cyclesList),
          "cycleRegularity": cycleRegularity,
          "lastPeriodDate": _getLastPeriodDate(cyclesList)
        },
        "insights": _generateInsightsFromCycles(
            cyclesList, avgCycleLength, cycleRegularity)
      };

      print('📊 Sending report data: $report');

      // Send report to API
      final response = await ApiService.createReport(reportData: report);

      if (response != null && response['success'] == true) {
        print('✅ Report created successfully');

        // Reload reports to show the new one
        await _loadReports();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New report generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ Failed to create report');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error generating report: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper methods for report generation

  int _calculateAverageCycleLengthFromCycles(List<dynamic> cycles) {
    if (cycles.isEmpty) return 28;

    int sum = 0;
    int count = 0;

    for (final cycle in cycles) {
      if (cycle['cycleLength'] != null) {
        sum += cycle['cycleLength'] as int;
        count++;
      }
    }

    return count > 0 ? (sum ~/ count) : 28;
  }

  String _determineCycleRegularity(List<dynamic> cycles) {
    if (cycles.length < 2) return "unknown";

    // Calculate variance in cycle lengths
    List<int> cycleLengths = [];
    for (final cycle in cycles) {
      if (cycle['cycleLength'] != null) {
        cycleLengths.add(cycle['cycleLength'] as int);
      }
    }

    if (cycleLengths.length < 2) return "unknown";

    // Calculate standard deviation
    double mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    double variance = cycleLengths
            .map((length) => pow(length - mean, 2))
            .reduce((a, b) => a + b) /
        cycleLengths.length;
    double stdDev = sqrt(variance);

    // Determine regularity
    if (stdDev <= 2) {
      return "very regular";
    } else if (stdDev <= 4) {
      return "regular";
    } else {
      return "irregular";
    }
  }

  List<String> _extractCommonSymptoms(List<dynamic> cycles) {
    // Count symptom occurrences
    Map<String, int> symptomCounts = {};

    for (final cycle in cycles) {
      if (cycle['symptoms'] != null && cycle['symptoms'] is List) {
        for (final symptom in cycle['symptoms']) {
          if (symptom is Map && symptom['name'] != null) {
            String name = symptom['name'];
            symptomCounts[name] = (symptomCounts[name] ?? 0) + 1;
          }
        }
      }
    }

    // Sort by frequency
    List<MapEntry<String, int>> sortedSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return the most common symptoms (up to 3)
    return sortedSymptoms.take(3).map((e) => e.key).toList();
  }

  String _getLastPeriodDate(List<dynamic> cycles) {
    if (cycles.isEmpty) {
      return DateTime.now().toIso8601String();
    }

    // Sort cycles by startDate descending
    cycles.sort((a, b) {
      String dateA = a['startDate'] ?? '';
      String dateB = b['startDate'] ?? '';
      return dateB.compareTo(dateA);
    });

    // Get the most recent one
    return cycles.first['startDate'] ?? DateTime.now().toIso8601String();
  }

  List<String> _generateInsightsFromCycles(
      List<dynamic> cycles, int avgCycleLength, String regularity) {
    final insights = <String>[];

    // Add cycle length insight
    insights.add(
        "Your average cycle length is $avgCycleLength days, which is within normal range.");

    // Add tracking insight
    insights.add("You've tracked ${cycles.length} cycles so far.");

    // Add symptom insight
    List<String> commonSymptoms = _extractCommonSymptoms(cycles);
    if (commonSymptoms.isEmpty) {
      insights.add("No symptoms have been logged yet.");
    } else {
      insights.add(
          "Your most common symptoms include: ${commonSymptoms.join(", ")}.");
    }

    // Add regularity insight
    if (regularity == "very regular") {
      insights.add("Your cycles appear to be very regular.");
    } else if (regularity == "regular") {
      insights.add("Your cycles appear to be somewhat regular.");
    } else if (regularity == "irregular") {
      insights.add("Your cycles appear to be irregular.");
    } else {
      insights.add("More data is needed to determine cycle regularity.");
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedReport != null ? "Report Details" : "Health Reports",
          style: const TextStyle(color: Colors.black87), // Added const
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _selectedReport != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    _selectedReport = null;
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _selectedReport != null
              ? _buildReportDetails()
              : _buildReportsList(),
    );
  }

  Widget _buildReportsList() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8F4FF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Generate Report Button
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton(
                onPressed: _generateNewReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Generate New Report",
                      style: TextStyles.subtitle1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Your Reports Title
            Text(
              "Your Health Reports",
              style: TextStyles.heading2.copyWith(
                color: const Color(0xFF1F2937),
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Reports List
            Expanded(
              child: _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.insert_chart_outlined,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No reports available yet",
                            style: TextStyles.heading3.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Generate your first report to see insights!",
                            style: TextStyles.body1.copyWith(
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFC75385),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedReport = report;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Row
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFC75385)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.analytics_outlined,
                                            color: Color(0xFFC75385),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                report['title'] ??
                                                    'Health Report',
                                                style: TextStyles.subtitle1
                                                    .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF1F2937),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDate(
                                                    report['createdAt']),
                                                style:
                                                    TextStyles.caption.copyWith(
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFC75385)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Color(0xFFC75385),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Stats Row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3F2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFDC2626)
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.timeline,
                                                      color: Color(0xFFDC2626),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "${report['data']?['totalCycles'] ?? 0}",
                                                      style: TextStyles.heading3
                                                          .copyWith(
                                                        color: const Color(
                                                            0xFFDC2626),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  "Cycles Tracked",
                                                  style: TextStyles.caption
                                                      .copyWith(
                                                    color:
                                                        const Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFF6B7280)
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.calendar_month,
                                                      color: Color(0xFF374151),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "${report['data']?['averageCycleLength'] ?? 28}",
                                                      style: TextStyles.heading3
                                                          .copyWith(
                                                        color: const Color(
                                                            0xFF374151),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  "Avg Days",
                                                  style: TextStyles.caption
                                                      .copyWith(
                                                    color:
                                                        const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Regularity Tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF059669)
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified,
                                            color: Color(0xFF059669),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${report['data']?['cycleRegularity'] ?? 'Unknown'} cycles",
                                            style: TextStyles.caption.copyWith(
                                              color: const Color(0xFF059669),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportDetails() {
    if (_selectedReport == null) return const SizedBox();

    final report = _selectedReport!;
    final insights = report['insights'] as List<dynamic>? ?? [];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8F4FF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Header Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC75385),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC75385).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.analytics_outlined,
                            color: Color(0xFFC75385),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report['title'] ?? 'Health Report',
                                style: TextStyles.heading3.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Generated on ${_formatDate(report['createdAt'])}",
                                style: TextStyles.body2.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Key Metrics Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC75385),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC75385).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.bar_chart,
                            color: Color(0xFFC75385),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Key Metrics",
                          style: TextStyles.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFDC2626).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.timeline,
                                  color: Color(0xFFDC2626),
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${report['data']?['totalCycles'] ?? 0}",
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Cycles Tracked",
                                  style: TextStyles.body2.copyWith(
                                    color: const Color(0xFFDC2626),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF6B7280).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  color: Color(0xFF374151),
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${report['data']?['averageCycleLength'] ?? 28}",
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Avg Cycle Length",
                                  style: TextStyles.body2.copyWith(
                                    color: const Color(0xFF6B7280),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // AI Insights Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFC75385),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC75385).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.psychology,
                            color: Color(0xFFC75385),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "AI Insights",
                          style: TextStyles.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (insights.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "No insights available for this report.",
                                style: TextStyles.body1.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...insights.map<Widget>((insight) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F4FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFC75385).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC75385),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.lightbulb,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  insight.toString(),
                                  style: TextStyles.body1.copyWith(
                                    color: const Color(0xFF374151),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('M/d/yyyy').format(date);
    } catch (e) {
      print('❌ Error formatting date: $e');
      return '';
    }
  }
}
