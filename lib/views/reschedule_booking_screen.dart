  import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  
  import '../app/app_text_styles.dart';
  import '../widgets/liquid_glass_instruction_card.dart';
  import '../app/app_constants.dart';
  
  class RescheduleBookingScreen extends StatefulWidget {
    final String userId;
    final String userName;
    final Map<String, dynamic> booking;
    final String oldDate;
    final String assignedMaliId;
  
    const RescheduleBookingScreen({
      super.key,
      required this.userId,
      required this.userName,
      required this.booking,
      required this.oldDate,
      required this.assignedMaliId,
    });
  
    @override
    State<RescheduleBookingScreen> createState() =>
        _RescheduleBookingScreenState();
  }
  
  class _RescheduleBookingScreenState extends State<RescheduleBookingScreen> {
    DateTime? _selectedDate;
    String? _selectedTimeSlot;
    Map<String, dynamic>? _selectedSlot;
  
    List<Map<String, dynamic>> _assignedMaliSlots = [];
    List<Map<String, dynamic>> _otherMaliSlots = [];
  
    bool _isLoadingSlots = false;
    bool _isSubmitting = false;
    String? _errorMessage;
    final Map<String, Map<String, List<Map<String, dynamic>>>> _slotsCache = {};
    int _slotRequestId = 0;

    void _rescheduleDebug(String message, [Object? data]) {
      try {
        if (data == null) {
          debugPrint('🧪 [RescheduleBooking] $message');
        } else {
          debugPrint(
            '🧪 [RescheduleBooking] $message: '
                '${const JsonEncoder.withIndent('  ').convert(data)}',
          );
        }
      } catch (_) {
        debugPrint('🧪 [RescheduleBooking] $message: $data');
      }
    }

    String _maskedUserId(String value) {
      final clean = value.trim();
      if (clean.length <= 4) return '***';
      return '${clean.substring(0, 3)}***${clean.substring(clean.length - 4)}';
    }

    String _possibleCrmTaskId() {
      final value = widget.booking['taskID'] ??
          widget.booking['taskId'] ??
          widget.booking['crmTaskID'] ??
          widget.booking['crmTaskId'] ??
          widget.booking['CRM_Task_ID'] ??
          widget.booking['zohoTaskId'] ??
          widget.booking['zohoCRMTaskId'] ??
          '';

      return value.toString().trim();
    }

    Map<String, dynamic> _bookingDebugSnapshot() {
      return {
        'userIdMasked': _maskedUserId(widget.userId),
        'oldDate': widget.oldDate,
        'assignedMaliIdFromWidget': widget.assignedMaliId,
        'assignedMaliNameFromBooking': _assignedMaliName(),
        'currentTimeFromBooking': _currentTimeText(),
        'possibleCrmTaskId': _possibleCrmTaskId().isEmpty
            ? 'MISSING'
            : _possibleCrmTaskId(),
        'bookingKeys': widget.booking.keys.map((key) => key.toString()).toList(),
        'importantBookingFields': {
          'taskID': widget.booking['taskID'],
          'taskId': widget.booking['taskId'],
          'crmTaskID': widget.booking['crmTaskID'],
          'crmTaskId': widget.booking['crmTaskId'],
          'dueDate': widget.booking['dueDate'],
          'date': widget.booking['date'],
          'assignedMali': widget.booking['assignedMali'],
          'maaliName': widget.booking['maaliName'],
          'assignedMaali': widget.booking['assignedMaali'],
          'visitTimeSlot1': widget.booking['visitTimeSlot1'],
          'timeSlot': widget.booking['timeSlot'],
          'timeOfVisit': widget.booking['timeOfVisit'],
          'dayTimeSlots': widget.booking['dayTimeSlots'],
        },
      };
    }

    static const String _availabilityTrackerUrl =
        'https://s02o6t55vf.execute-api.ap-south-1.amazonaws.com/fetchAvailabilityTracker';
  
    static const String _rescheduleUrl =
        'https://niarfmavl3.execute-api.ap-south-1.amazonaws.com/bookingsReschedule';
  
    late final List<DateTime> _rescheduleDateOptions;
    DateTime? _parseOldVisitDate(String dateStr) {
      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) return null;
  
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
  
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
  
        return DateTime(year, month, day);
      } catch (_) {
        return null;
      }
    }
  
    DateTime _dateOnly(DateTime date) {
      return DateTime(date.year, date.month, date.day);
    }
  
    bool _isPreponingVisit(DateTime selectedDate) {
      final oldVisitDate = _parseOldVisitDate(widget.oldDate);
      if (oldVisitDate == null) return false;
  
      return _dateOnly(selectedDate).isBefore(_dateOnly(oldVisitDate));
    }
  
    bool _isDateAllowedForReschedule(DateTime selectedDate) {
      final todayOnly = _dateOnly(DateTime.now());
      final selectedDateOnly = _dateOnly(selectedDate);
  
      // Past dates are never allowed.
      if (selectedDateOnly.isBefore(todayOnly)) {
        return false;
      }
  
      // This rule applies ONLY for preponing.
      // If customer is moving visit earlier, selected date must be at least 2 days from today.
      if (_isPreponingVisit(selectedDate)) {
        final minPreponeDate = todayOnly.add(const Duration(days: 2));
        return !selectedDateOnly.isBefore(minPreponeDate);
      }
  
      // Same day as original visit or future/postponing dates are allowed.
      return true;
    }
  
    @override
    void initState() {
      super.initState();
  
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
  
      final oldVisitDate = _parseOldVisitDate(widget.oldDate) ?? todayOnly;
      final oldVisitDateOnly = DateTime(
        oldVisitDate.year,
        oldVisitDate.month,
        oldVisitDate.day,
      );
  
      final startDate = oldVisitDateOnly.subtract(const Duration(days: 3));
      final endDate = oldVisitDateOnly.add(const Duration(days: 5));
  
      final allDates = <DateTime>[];
  
      DateTime current = startDate;
  
      while (!current.isAfter(endDate)) {
        allDates.add(current);
        current = current.add(const Duration(days: 1));
      }
  
      // Optional but recommended:
      // Do not show dates before today because rescheduling to past dates is not useful.
      _rescheduleDateOptions = allDates.where((date) {
        return _isDateAllowedForReschedule(date);
      }).toList();
  
      if (_rescheduleDateOptions.isEmpty) {
        _rescheduleDateOptions = [oldVisitDateOnly];
      }
  
      _selectedDate = _rescheduleDateOptions.first;
      _rescheduleDebug('Screen opened with booking snapshot', _bookingDebugSnapshot());

      _rescheduleDebug('Generated reschedule date options', {
        'today': _formatDateForApi(todayOnly),
        'oldVisitDate': _formatDateForApi(oldVisitDateOnly),
        'dateRangeStart': _formatDateForApi(startDate),
        'dateRangeEnd': _formatDateForApi(endDate),
        'selectedDefaultDate': _formatDateForApi(_selectedDate!),
        'options': _rescheduleDateOptions.map(_formatDateForApi).toList(),
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedDate != null) {
          _fetchAvailableSlots(_selectedDate!);
        }
      });
    }
  
    Map<String, dynamic> _decodeApiResponse(String responseBody) {
      try {
        final decoded = jsonDecode(responseBody);
  
        if (decoded is Map<String, dynamic>) {
          final innerBody = decoded['body'];
  
          if (innerBody is String && innerBody.trim().isNotEmpty) {
            final innerDecoded = jsonDecode(innerBody);
  
            if (innerDecoded is Map<String, dynamic>) {
              return innerDecoded;
            }
          }
  
          return decoded;
        }
      } catch (e) {
        debugPrint('❌ API decode error: $e');
      }
  
      return {};
    }
  
    String _formatDateForApi(DateTime date) {
      return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString().substring(2)}";
    }
  
    String _dayName(DateTime date) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
  
      return days[date.weekday - 1];
    }
  
    String _shortDayLabel(DateTime date) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final tomorrowOnly = todayOnly.add(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);
  
      if (dateOnly.isAtSameMomentAs(todayOnly)) return 'Today';
      if (dateOnly.isAtSameMomentAs(tomorrowOnly)) return 'Tomorrow';
  
      return _dayName(date);
    }
  
    String _dateTabTitle(DateTime date) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
  
      return '${date.day} ${months[date.month - 1]}';
    }
  
    String _currentTimeText() {
      try {
        final slots = widget.booking['dayTimeSlots'] as List?;
        if (slots != null && slots.isNotEmpty && slots.first is Map) {
          return (slots.first['timeSlot'] ?? 'N/A').toString();
        }
      } catch (_) {}
  
      return (widget.booking['visitTimeSlot1'] ??
          widget.booking['timeSlot'] ??
          widget.booking['timeOfVisit'] ??
          'N/A')
          .toString();
    }
  
    String _assignedMaliName() {
      return (widget.booking['assignedMali'] ??
          widget.booking['maaliName'] ??
          widget.booking['assignedMaali'] ??
          '')
          .toString()
          .trim();
    }
  
    int _getAvailabilityCount(dynamic row, String day) {
      if (row is! Map) return 0;
  
      final value = row[day];
  
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
  
      return int.tryParse(value.toString()) ?? 0;
    }
  
    int _slotSortMinutes(String slot) {
      final clean = slot.trim().toUpperCase();
  
      try {
        final parsed = TimeOfDay(
          hour: int.parse(clean.split(':').first),
          minute: int.parse(clean.split(':')[1].split(' ').first),
        );
  
        final isPm = clean.contains('PM');
        final isAm = clean.contains('AM');
  
        int hour = parsed.hour;
  
        if (isPm && hour != 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
  
        return hour * 60 + parsed.minute;
      } catch (_) {
        return 99999;
      }
    }
  
    bool _isSlotAllowedForReschedule(String slot) {
      final minutes = _slotSortMinutes(slot);
  
      // Show only slots from 12:00 PM to 4:00 PM.
      // 12 PM = 720 minutes, 4 PM = 960 minutes.
      return minutes >= 12 * 60 && minutes <= 16 * 60;
    }
  
    List<Map<String, dynamic>> _sortSlots(List<Map<String, dynamic>> slots) {
      final sorted = List<Map<String, dynamic>>.from(slots);
  
      sorted.sort((a, b) {
        final aSlot = (a['slot'] ?? '').toString();
        final bSlot = (b['slot'] ?? '').toString();
  
        return _slotSortMinutes(aSlot).compareTo(_slotSortMinutes(bSlot));
      });
  
      return sorted;
    }
  
    String _normalizeMaaliSearchName(String name) {
      final clean = name.trim().toLowerCase();
  
      final aliases = {
        'yogendra': 'yogender',
      };
  
      return aliases[clean] ?? clean;
    }

    Future<void> _fetchAvailableSlots(DateTime date) async {
      if (!mounted) return;

      final selectedDateForApi = _formatDateForApi(date);
      _rescheduleDebug('Fetching slots started', {
        'selectedDateForApi': selectedDateForApi,
        'assignedMaliId': widget.assignedMaliId,
        'assignedMaliName': _assignedMaliName(),
      });
      // Important: cache by exact date, not weekday.
      final cacheKey = selectedDateForApi;

      final cached = _slotsCache[cacheKey];
      if (cached != null) {
        setState(() {
          _errorMessage = null;
          _selectedTimeSlot = null;
          _selectedSlot = null;
          _assignedMaliSlots = cached['assigned'] ?? [];
          _otherMaliSlots = cached['other'] ?? [];
          _isLoadingSlots = false;
        });
        return;
      }

      final requestId = ++_slotRequestId;

      setState(() {
        _isLoadingSlots = true;
        _errorMessage = null;
        _selectedTimeSlot = null;
        _selectedSlot = null;
        _assignedMaliSlots = [];
        _otherMaliSlots = [];
      });

      try {
        final assignedMaliName = _assignedMaliName().trim();

        final payload = <String, dynamic>{
          "action": "fetchRescheduleSlots",
          "date": selectedDateForApi,
          "assignedMaliId": widget.assignedMaliId,
          "assignedMaliName": assignedMaliName,
        };

        _rescheduleDebug('Fetch slots payload', payload);

        final slotsResponse = await http.post(
          Uri.parse(_rescheduleUrl),
          body: jsonEncode(payload),
          headers: {'Content-Type': 'application/json'},
        );

        if (requestId != _slotRequestId) return;

        _rescheduleDebug('Fetch slots raw response', {
          'statusCode': slotsResponse.statusCode,
          'body': slotsResponse.body,
        });

        final responseData = _decodeApiResponse(slotsResponse.body);
        _rescheduleDebug('Fetch slots decoded response', responseData);
        if (slotsResponse.statusCode != 200 || responseData['success'] != true) {
          throw Exception(
            responseData['message']?.toString() ??
                'Unable to fetch availability',
          );
        }

        final assignedSlots = <Map<String, dynamic>>[];
        final otherSlots = <Map<String, dynamic>>[];

        final rawAssigned = responseData['assignedMaliSlots'];

        if (rawAssigned is List) {
          for (final item in rawAssigned) {
            if (item is! Map) continue;

            final itemMap = Map<String, dynamic>.from(item);

            final slot = (itemMap['slot'] ?? '').toString().trim();

            if (slot.isEmpty) continue;
            if (!_isSlotAllowedForReschedule(slot)) continue;

            assignedSlots.add({
              'slot': slot,
              'available': true,
              'maaliId': (itemMap['maaliId'] ?? widget.assignedMaliId).toString(),
              'maaliName': (itemMap['maaliName'] ?? assignedMaliName).toString(),
              'availableCount': itemMap['availableCount'] ?? 1,
              'isAssignedMaali': true,
            });
          }
        }

        final rawOther = responseData['otherMaliSlots'];

        if (rawOther is List) {
          for (final item in rawOther) {
            if (item is! Map) continue;

            final itemMap = Map<String, dynamic>.from(item);

            final slot = (itemMap['slot'] ?? '').toString().trim();

            if (slot.isEmpty) continue;
            if (!_isSlotAllowedForReschedule(slot)) continue;

            final availableMaaliCount =
                int.tryParse((itemMap['availableMaaliCount'] ?? 0).toString()) ?? 0;

            if (availableMaaliCount <= 0) continue;

            otherSlots.add({
              'slot': slot,
              'available': true,
              'availableMaaliCount': availableMaaliCount,
              'maaliId': '',
              'maaliName': '',
              'isAssignedMaali': false,
            });
          }
        }

        if (requestId != _slotRequestId) return;

        final sortedAssigned = _sortSlots(assignedSlots);
        final sortedOther = _sortSlots(otherSlots);
        _rescheduleDebug('Slots parsed for UI', {
          'date': selectedDateForApi,
          'assignedSlotsCount': sortedAssigned.length,
          'otherSlotsCount': sortedOther.length,
          'assignedSlots': sortedAssigned,
          'otherSlots': sortedOther,
        });
        _slotsCache[cacheKey] = {
          'assigned': sortedAssigned,
          'other': sortedOther,
        };

        if (!mounted) return;

        setState(() {
          _assignedMaliSlots = sortedAssigned;
          _otherMaliSlots = sortedOther;
        });
      } catch (e) {
        _rescheduleDebug('Fetch slots error', {
          'error': e.toString(),
          'date': selectedDateForApi,
        });

        if (!mounted) return;

        setState(() {
          _errorMessage = 'Unable to fetch availability. Please try again.';
        });
      } finally {
        if (mounted && requestId == _slotRequestId) {
          setState(() {
            _isLoadingSlots = false;
          });
        }
      }
    }
  
    Future<void> _submitReschedule() async {
      if (_selectedDate == null ||
          _selectedTimeSlot == null ||
          _selectedSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both date and time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
  
      if (!_isDateAllowedForReschedule(_selectedDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can prepone a visit only up to 2 days in advance',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
  
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
  
      try {
        final oldDateStr = widget.oldDate;
        final newDateStr = _formatDateForApi(_selectedDate!);
        final visitDay = _dayName(_selectedDate!);
        final possibleCrmTaskId = _possibleCrmTaskId();

        _rescheduleDebug('Submit started', {
          'oldDate': oldDateStr,
          'newDate': newDateStr,
          'newTime': _selectedTimeSlot,
          'visitDay1': visitDay,
          'possibleCrmTaskId': possibleCrmTaskId.isEmpty ? 'MISSING' : possibleCrmTaskId,
          'selectedSlot': _selectedSlot,
          'bookingSnapshot': _bookingDebugSnapshot(),
        });
        final isAssignedMaali = _selectedSlot!['isAssignedMaali'] == true;
  
        final selectedMaaliId = (_selectedSlot!['maaliId'] ?? '')
            .toString()
            .trim();
  
        final selectedMaaliName = (_selectedSlot!['maaliName'] ?? '')
            .toString()
            .trim();
  
        final payload = <String, dynamic>{
          "userID": widget.userId,
          "dueDate": oldDateStr,
          "newDate": newDateStr,
          "newTime": _selectedTimeSlot,
          "visitDay1": visitDay,
          "isAssignedMaali": isAssignedMaali,
          "autoAssignMaali": !isAssignedMaali,
  
          // This tells Lambda that request came from customer app/frontend
          "rescheduleSource": "customer_app",
          "requestedBy": "user",
        };
  
        if (isAssignedMaali) {
          payload["assignedMaliId"] = selectedMaaliId.isNotEmpty
              ? selectedMaaliId
              : widget.assignedMaliId;
  
          payload["assignedMaliName"] = selectedMaaliName.isNotEmpty
              ? selectedMaaliName
              : _assignedMaliName();
  
          payload["maaliName"] = selectedMaaliName.isNotEmpty
              ? selectedMaaliName
              : _assignedMaliName();
        }
  
        debugPrint('🔄 Reschedule payload: ${jsonEncode(payload)}');
  
        final response = await http.post(
          Uri.parse(_rescheduleUrl),
          body: jsonEncode(payload),
          headers: {'Content-Type': 'application/json'},
        );
  
        debugPrint('📥 Reschedule response status: ${response.statusCode}');
        debugPrint('📥 Reschedule response body: ${response.body}');
  
        if (response.statusCode == 200) {
          final responseData = _decodeApiResponse(response.body);
  
          final success = responseData['success'] == true;
          final dbUpdated = responseData['dbUpdated'] == true;
          final crmTaskSynced = responseData['crmTaskSynced'] == true;
  
          if (!mounted) return;
  
          if (success && dbUpdated && crmTaskSynced) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Booking rescheduled successfully! Assigned Maali: ${responseData['assignedMali'] ?? selectedMaaliName}",
                ),
                backgroundColor: Colors.green,
              ),
            );
  
            Navigator.pop(context, true);
            return;
          }
  
          if (success && dbUpdated && !crmTaskSynced) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  responseData['message']?.toString() ??
                      'Booking rescheduled, but CRM sync is pending.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
  
            Navigator.pop(context, true);
            return;
          }
  
          setState(() {
            _errorMessage =
                responseData['message']?.toString() ?? 'Failed to reschedule booking.';
          });
  
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          if (!mounted) return;

          final responseData = _decodeApiResponse(response.body);

          final serverMessage = responseData['message']?.toString().trim();

          final cleanMessage = serverMessage != null && serverMessage.isNotEmpty
              ? serverMessage
              : 'This slot is no longer available. Please select another slot.';

          setState(() {
            _errorMessage = cleanMessage;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(cleanMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Reschedule error: $e');
  
        if (!mounted) return;
  
        setState(() {
          _errorMessage = 'Network error. Please try again.';
        });
  
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Network error. Please check your connection and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  
    void _selectDate(DateTime date) {
      setState(() {
        _selectedDate = date;
      });
  
      _fetchAvailableSlots(date);
    }
  
    void _selectSlot(Map<String, dynamic> slot) {
      setState(() {
        _selectedSlot = slot;
        _selectedTimeSlot = (slot['slot'] ?? '').toString();
      });
    }
  
    Widget _buildTopInfoCard() {
      final assignedMaliName = _assignedMaliName();
  
      return LiquidGlassInstructionCard(
        radius: 26,
        minHeight: 0,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Visit',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 14),
            _infoRow(Icons.calendar_today_rounded, widget.oldDate),
            const SizedBox(height: 10),
            _infoRow(Icons.access_time_rounded, _currentTimeText()),
            if (assignedMaliName.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoRow(
                Icons.person_pin_circle_rounded,
                'Assigned Maali: $assignedMaliName',
              ),
            ],
          ],
        ),
      );
    }
  
    Widget _infoRow(IconData icon, String text) {
      return Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB72B).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFFFFB72B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
    }
  
    Widget _buildDateTabs() {
      return SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: _rescheduleDateOptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final date = _rescheduleDateOptions[index];
  
            final isSelected = _selectedDate != null &&
                DateTime(
                  _selectedDate!.year,
                  _selectedDate!.month,
                  _selectedDate!.day,
                ).isAtSameMomentAs(
                  DateTime(date.year, date.month, date.day),
                );
  
            return GestureDetector(
              onTap: () => _selectDate(date),
              child: SizedBox(
                width: 82,
                child: LiquidGlassInstructionCard(
                  radius: 24,
                  minHeight: 88,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dateTabTitle(date),
                        maxLines: 1,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? const Color(0xFFFFB72B)
                              : AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _shortDayLabel(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFFFFB72B)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  
    Widget _buildSlotChip({
      required Map<String, dynamic> slot,
      required bool isAssignedSection,
    }) {
      final slotValue = (slot['slot'] ?? '').toString();
  
      final isSelected = _selectedSlot != null &&
          (_selectedSlot!['slot'] ?? '').toString() == slotValue &&
          (_selectedSlot!['isAssignedMaali'] == true) == isAssignedSection;
  
      final maaliName = (slot['maaliName'] ?? '').toString();
      final count = slot['availableMaaliCount'];
  
      String subtitle = '';
  
      if (isAssignedSection) {
        subtitle = maaliName.isEmpty ? 'Assigned maali' : maaliName;
      } else if (count != null) {
        subtitle = '$count maali available';
      } else if (maaliName.isNotEmpty) {
        subtitle = maaliName;
      }
  
      return GestureDetector(
        onTap: () {
          final selected = Map<String, dynamic>.from(slot);
          selected['isAssignedMaali'] = isAssignedSection;
          _selectSlot(selected);
        },
        child: SizedBox(
          width: 108,
          child: LiquidGlassInstructionCard(
            radius: 20,
            minHeight: 74,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slotValue,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: isSelected
                        ? const Color(0xFFFFB72B)
                        : AppColors.primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.tiny.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
  
    Widget _buildSlotGroup({
      required String title,
      required String subtitle,
      required List<Map<String, dynamic>> slots,
      required bool isAssignedSection,
    }) {
      if (slots.isEmpty) {
        return LiquidGlassInstructionCard(
          radius: 22,
          minHeight: 0,
          padding: const EdgeInsets.all(14),
          child: Text(
            isAssignedSection
                ? 'No slot available with assigned maali for this date.'
                : 'No other maali slots available for this date.',
            style: AppTextStyles.body.copyWith(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
  
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: slots
                .map(
                  (slot) => _buildSlotChip(
                slot: slot,
                isAssignedSection: isAssignedSection,
              ),
            )
                .toList(),
          ),
        ],
      );
    }
  
    Widget _buildSlotLoadingSkeleton() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Checking available slots...',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This usually takes a few seconds.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(6, (_) {
              return SizedBox(
                width: 108,
                child: LiquidGlassInstructionCard(
                  radius: 20,
                  minHeight: 74,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 54,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Container(
                        width: 70,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      );
    }
  
    Widget _buildSlotsContent() {
      if (_isLoadingSlots) {
        return _buildSlotLoadingSkeleton();
      }
  
      if (_errorMessage != null) {
        return LiquidGlassInstructionCard(
          radius: 22,
          minHeight: 0,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }
  
      if (_assignedMaliSlots.isEmpty && _otherMaliSlots.isEmpty) {
        return LiquidGlassInstructionCard(
          radius: 22,
          minHeight: 0,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No slots available for this date',
              style: AppTextStyles.body.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
  
      final assignedMaliName = _assignedMaliName();
  
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlotGroup(
            title: assignedMaliName.isEmpty
                ? 'Slots with assigned maali'
                : 'Slots with $assignedMaliName',
            subtitle: 'Choose this if you want the same maali.',
            slots: _assignedMaliSlots,
            isAssignedSection: true,
          ),
          const SizedBox(height: 26),
          _buildSlotGroup(
            title: 'Other available slots',
            subtitle: 'These slots may assign any available maali automatically.',
            slots: _otherMaliSlots,
            isAssignedSection: false,
          ),
        ],
      );
    }
  
    Widget _buildBottomInfo() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: LiquidGlassInstructionCard(
          radius: 22,
          minHeight: 0,
          padding: const EdgeInsets.all(14),
          child: Text(
            'Your maali will arrive within the selected time slot. If you choose another available slot, a different maali may be assigned.',
            style: AppTextStyles.caption.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    }
  
    @override
    Widget build(BuildContext context) {
      final canSubmit =
          _selectedDate != null && _selectedSlot != null && !_isSubmitting;
  
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          centerTitle: true,
          title: Text(
            'Reschedule Visit',
            style: AppTextStyles.cardTitle.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryColor,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    _buildTopInfoCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Select New Date',
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDateTabs(),
                    const SizedBox(height: 24),
                    _buildSlotsContent(),
                  ],
                ),
              ),
              _buildBottomInfo(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                child: LiquidGlassInstructionCard(
                  radius: 30,
                  minHeight: 68,
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: canSubmit ? _submitReschedule : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB72B),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                          : const Text(
                        'Confirm & Reschedule',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }