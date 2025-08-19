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
      
      if (response != null && response['success'] == true && response['data'] != null) {
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
        "insights": _generateInsightsFromCycles(cyclesList, avgCycleLength, cycleRegularity)
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
    double variance = cycleLengths.map((length) => pow(length - mean, 2)).reduce((a, b) => a + b) / cycleLengths.length;
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
  
  List<String> _generateInsightsFromCycles(List<dynamic> cycles, int avgCycleLength, String regularity) {
    final insights = <String>[];
    
    // Add cycle length insight
    insights.add("Your average cycle length is $avgCycleLength days, which is within normal range.");
    
    // Add tracking insight
    insights.add("You've tracked ${cycles.length} cycles so far.");
    
    // Add symptom insight
    List<String> commonSymptoms = _extractCommonSymptoms(cycles);
    if (commonSymptoms.isEmpty) {
      insights.add("No symptoms have been logged yet.");
    } else {
      insights.add("Your most common symptoms include: ${commonSymptoms.join(", ")}.");
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedGradientButton(
            text: "Generate New Report",
            onPressed: _generateNewReport,
            gradientColors: const [
              Colors.orange,
              Colors.deepOrange,
            ],
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: -10, end: 0),
          
          const SizedBox(height: 24),
          
          Text(
            "Your Reports",
            style: TextStyles.heading3,
          )
          .animate()
          .fadeIn(duration: 600.ms, delay: 100.ms)
          .slideY(begin: -10, end: 0),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: _reports.isEmpty
                ? Center(
                    child: Text(
                      "No reports available yet. Generate your first report!",
                      style: TextStyles.body1,
                      textAlign: TextAlign.center,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 800.ms, delay: 200.ms)
                : ListView.builder(
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            print('📊 Selected report: ${report['title']}');
                            setState(() {
                              _selectedReport = report;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report['title'] ?? 'Health Report',
                                  style: TextStyles.subtitle1.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(report['createdAt']),
                                  style: TextStyles.body2.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildReportTag(
                                      "${report['data']?['totalCycles'] ?? 0} cycles",
                                      Colors.pink.shade100,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildReportTag(
                                      "${report['data']?['averageCycleLength'] ?? 28} day avg",
                                      Colors.purple.shade100,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 800.ms, delay: 200.ms + (index * 100).ms)
                      .slideY(begin: 20, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetails() {
    if (_selectedReport == null) return const SizedBox();
    
    final report = _selectedReport!;
    final insights = report['insights'] as List<dynamic>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    report['title'] ?? 'Health Report',
                    style: TextStyles.heading3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Generated on ${_formatDate(report['createdAt'])}",
                    style: TextStyles.body2.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: 20, end: 0),
          
          const SizedBox(height: 24),
          
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
                    "Key Metrics",
                    style: TextStyles.heading3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        "${report['data']?['totalCycles'] ?? 0}",
                        "Cycles Tracked",
                        Colors.pink,
                      ),
                      _buildMetricItem(
                        "${report['data']?['averageCycleLength'] ?? 28}",
                        "Avg Cycle Length",
                        Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms, delay: 100.ms)
          .slideY(begin: 20, end: 0),
          
          const SizedBox(height: 24),
          
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
                    "AI Insights",
                    style: TextStyles.heading3,
                  ),
                  const SizedBox(height: 16),
                  if (insights.isEmpty)
                    Text(
                      "No insights available for this report.",
                      style: TextStyles.body1,
                    )
                  else
                    ...insights.map<Widget>((insight) { // Added explicit type <Widget>
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: Colors.pink,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                insight.toString(),
                                style: TextStyles.body1,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms, delay: 200.ms)
          .slideY(begin: 20, end: 0),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyles.body2,
        ),
      ],
    );
  }

  Widget _buildReportTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyles.caption,
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