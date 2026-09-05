import 'dart:async';
import 'dart:io';
import 'salesiq_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesiq_mobilisten/salesiq_mobilisten.dart';

class SalesIQService {
  SalesIQService._();

  static final SalesIQService instance = SalesIQService._();

  // ============================================================
  // LOCAL KEYS
  // ============================================================

  static const String _registeredVisitorPrefsKey =
      'salesiq_registered_visitor_id';

  // ============================================================
  // SDK STATE
  // ============================================================

  bool _isInitialized = false;

  Future<void>? _initializationFuture;

  String? _registeredVisitorId;

  String? _visitorInformationStartedFor;

  bool _supportLaunchInProgress = false;

  bool get isInitialized => _isInitialized;

  // ============================================================
  // INITIALIZE SALESIQ
  // ============================================================

  Future<void> initialize() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Future<void>.value();
    }

    if (_isInitialized) {
      return Future<void>.value();
    }

    /*
     * If multiple parts of the application request SalesIQ
     * initialization at the same time, they will all share
     * the same Future.
     */
    _initializationFuture ??= _initializeInternal();

    return _initializationFuture!;
  }

  Future<void> _initializeInternal() async {
    final String appKey;
    final String accessKey;

    // ============================================================
    // SALESIQ CLIENT KEYS
    // ============================================================

    if (Platform.isAndroid) {
      appKey = 'W3OqHW0sbHNmwcW59ALJpESBZHwFatKP6GHuTNgddR%2FonGyP8cVmmjVsopNOEnwD_in';
      accessKey = '0z5aM0izOBmK9hJK7ev6Q9uQhkCc5yeQjHBgpfSCrLVocR0vWzxTE0Bqgbo0Bo4TzcBdNLK9cetFzmoumG7%2FfyM2YiewW1AaxC%2FXmsm8v%2FwZ1kPEDj5x0Q91D0lDhdWWTDOUAM1Ose3FKRkiJo82rw%3D%3D';
    } else {
      appKey = 'PASTE_YOUR_IOS_APP_KEY_HERE';
      accessKey = 'PASTE_YOUR_IOS_ACCESS_KEY_HERE';
    }

    debugPrint(
      '🔑 SalesIQ platform: '
          '${Platform.isAndroid ? 'Android' : 'iOS'}',
    );

    debugPrint(
      '🔑 SalesIQ app key available: ${appKey.trim().isNotEmpty}',
    );

    debugPrint(
      '🔑 SalesIQ access key available: ${accessKey.trim().isNotEmpty}',
    );

    if (appKey.trim().isEmpty ||
        accessKey.trim().isEmpty ||
        appKey.contains('PASTE_YOUR_') ||
        accessKey.contains('PASTE_YOUR_')) {
      _initializationFuture = null;

      throw StateError(
        'SalesIQ App Key or Access Key has not been configured.',
      );
    }

    try {
      final configuration = SalesIQConfiguration(
        appKey: appKey,
        accessKey: accessKey,
      );

      await ZohoSalesIQ.initialize(
        configuration,
      );

      ZohoSalesIQ.launcher.show(
        VisibilityMode.never,
      );

      _runDetachedOperation(
        label: 'conversation visibility',
        operation: ZohoSalesIQ.setConversationVisibility(
          true,
        ),
      );

      _isInitialized = true;

      debugPrint(
        '✅ SalesIQ initialized successfully',
      );
    } catch (error, stackTrace) {
      _isInitialized = false;
      _initializationFuture = null;

      debugPrint(
        '❌ SalesIQ initialization failed: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  // ============================================================
  // OPEN SUPPORT
  // ============================================================

  Future<void> openSupport() async {
    /*
     * Protect against double tapping.
     */
    if (_supportLaunchInProgress) {
      debugPrint(
        'ℹ️ SalesIQ support launch already in progress',
      );

      return;
    }

    _supportLaunchInProgress = true;

    try {
      // ----------------------------------------------------------
      // STEP 1: Ensure SDK is initialized
      // ----------------------------------------------------------

      await initialize();

      final prefs = await SharedPreferences.getInstance();

      // ----------------------------------------------------------
      // STEP 2: Resolve logged-in GoldDust customer
      // ----------------------------------------------------------

      final userId = _firstNonEmpty([
        prefs.getString('userId'),
        prefs.getString('userID'),
        prefs.getString('maaliUserId'),
      ]);

      final phone = _firstNonEmpty([
        prefs.getString('userPhone'),
        prefs.getString('bookingPhone'),
        prefs.getString('phoneNumber'),
      ]);

      final userName = _firstNonEmpty([
        prefs.getString('userName'),
        prefs.getString('customerName'),
        prefs.getString('fullName'),
      ]);

      final email = _firstNonEmpty([
        prefs.getString('email'),
        prefs.getString('userEmail'),
      ]);

      if (userId.isEmpty) {
        throw StateError(
          'Logged-in customer ID was not found.',
        );
      }

      debugPrint(
        'ℹ️ Opening SalesIQ for customer: $userId',
      );

      // ----------------------------------------------------------
      // STEP 3: Remove old obsolete locally cached chat ID
      // ----------------------------------------------------------

      /*
       * Older versions of this service stored chat IDs such as
       * "3" locally. We no longer use those IDs.
       */
      await prefs.remove(
        'salesiq_last_chat_id_$userId',
      );

      // ----------------------------------------------------------
      // STEP 4: Restore previously registered visitor
      // ----------------------------------------------------------

      final persistedRegisteredVisitorId =
          prefs.getString(_registeredVisitorPrefsKey)?.trim() ?? '';

      /*
       * Flutter hot restart/reload resets Dart variables but
       * Mobilisten's native registration may still exist.
       *
       * Therefore restore our Dart state from SharedPreferences.
       */
      if (_registeredVisitorId == null &&
          persistedRegisteredVisitorId == userId) {
        _registeredVisitorId = userId;

        debugPrint(
          '✅ Restored existing SalesIQ visitor registration: '
              '$userId',
        );
      }

      // ----------------------------------------------------------
      // STEP 5: Register visitor only when necessary
      // ----------------------------------------------------------

      if (_registeredVisitorId != userId) {
        await _registerVisitor(
          prefs: prefs,
          userId: userId,
        );
      }

      // ----------------------------------------------------------
      // STEP 6: Update visitor information
      // ----------------------------------------------------------

      /*
       * Do NOT wait for these before opening chat.
       *
       * We previously saw some setVisitor... Futures remain
       * pending even though the data reached SalesIQ.
       */
      unawaited(
        _updateVisitorInformationAfterLaunch(
          userId: userId,
          phone: phone,
          userName: userName,
          email: email,
        ),
      );

      // ----------------------------------------------------------
      // STEP 7: Open current conversation or new chat
      // ----------------------------------------------------------

      /*
       * Don't await the native chat window in HomeView.
       *
       * Some SalesIQ UI Futures remain alive until the native
       * activity closes.
       */
      unawaited(
        _openBestSupportConversation(),
      );
    } catch (error, stackTrace) {
      _supportLaunchInProgress = false;

      debugPrint(
        '❌ SalesIQ support preparation failed: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      /*
       * Genuine preparation errors should reach HomeView so the
       * customer receives the "Unable to open support" message.
       */
      rethrow;
    }
  }

  // ============================================================
  // REGISTER VISITOR
  // ============================================================

  Future<void> _registerVisitor({
    required SharedPreferences prefs,
    required String userId,
  }) async {
    try {
      debugPrint(
        'ℹ️ Registering SalesIQ visitor: $userId',
      );

      await ZohoSalesIQ.registerVisitor(
        userId,
      ).timeout(
        const Duration(seconds: 15),
      );

      _registeredVisitorId = userId;

      _visitorInformationStartedFor = null;

      await prefs.setString(
        _registeredVisitorPrefsKey,
        userId,
      );

      debugPrint(
        '✅ SalesIQ visitor registered: $userId',
      );

      /*
       * Give native Mobilisten a short time to switch from
       * anonymous visitor state to registered visitor state.
       */
      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );
    } on TimeoutException catch (error) {
      /*
       * This can happen after a Flutter restart when the native
       * SDK already retains the registration but its callback
       * does not return to the newly-created Dart isolate.
       *
       * Continue rather than blocking customer support.
       */
      debugPrint(
        '⚠️ SalesIQ registerVisitor timeout: $error',
      );

      _registeredVisitorId = userId;

      await prefs.setString(
        _registeredVisitorPrefsKey,
        userId,
      );

      debugPrint(
        'ℹ️ Continuing with existing/native SalesIQ visitor: '
            '$userId',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        '❌ SalesIQ visitor registration platform error: '
            'code=${error.code}, message=${error.message}',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  // ============================================================
  // OPEN CHAT
  // ============================================================

  Future<void> _openBestSupportConversation() async {
    try {
      debugPrint(
        'ℹ️ Looking for an active SalesIQ conversation...',
      );

      String? activeChatId;

      try {
        /*
         * Ask SalesIQ directly every time.
         *
         * Never use a permanently saved/local chat ID.
         */
        final chats = await ZohoSalesIQ.getChats().timeout(
          const Duration(seconds: 8),
        );

        debugPrint(
          'ℹ️ SalesIQ conversations found: ${chats.length}',
        );

        /*
         * Prefer a currently active conversation.
         *
         * Possible active statuses include:
         * open
         * connected
         * waiting
         */
        for (final chat in chats) {
          final rawId = chat.id.toString().trim();

          final status =
          chat.status.toString().trim().toLowerCase();

          debugPrint(
            'ℹ️ SalesIQ chat => '
                'id=$rawId, '
                'status=$status, '
                'question=${chat.question}',
          );

          if (rawId.isEmpty || rawId == 'null') {
            continue;
          }

          final isActive =
              status.contains('open') ||
                  status.contains('connected') ||
                  status.contains('waiting');

          if (isActive) {
            activeChatId = rawId;

            break;
          }
        }
      } on TimeoutException catch (error) {
        /*
         * Failure to retrieve old chats must NOT prevent the
         * customer from contacting support.
         */
        debugPrint(
          '⚠️ SalesIQ getChats timeout: $error',
        );
      } on PlatformException catch (error, stackTrace) {
        /*
         * For example, past conversations may be disabled.
         * In this case we'll simply open a fresh chat.
         */
        debugPrint(
          '⚠️ SalesIQ getChats platform error: '
              'code=${error.code}, message=${error.message}',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );
      } catch (error, stackTrace) {
        debugPrint(
          '⚠️ SalesIQ getChats failed: $error',
        );

        debugPrintStack(
          stackTrace: stackTrace,
        );
      }

      // ----------------------------------------------------------
      // ACTIVE CHAT EXISTS
      // ----------------------------------------------------------

      if (activeChatId != null &&
          activeChatId.trim().isNotEmpty) {
        debugPrint(
          '✅ Opening active SalesIQ chat: $activeChatId',
        );

        _launchExistingChat(
          activeChatId,
        );

        return;
      }

      // ----------------------------------------------------------
      // NO ACTIVE CHAT
      // ----------------------------------------------------------

      /*
       * Previous conversations may exist but if they are closed
       * or missed we do NOT reopen them automatically.
       *
       * Starting Support now creates a fresh support request.
       */
      debugPrint(
        'ℹ️ No active SalesIQ chat found. '
            'Opening a new conversation.',
      );

      _launchNewChat();
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Unable to determine SalesIQ conversation: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      /*
       * Last-resort fallback:
       * Always try to give the customer a new chat.
       */
      _launchNewChat();
    }
  }

  // ============================================================
  // LAUNCH EXISTING CHAT
  // ============================================================

  void _launchExistingChat(
      String chatId,
      ) {
    try {
      /*
       * Do not await this Future.
       *
       * The native method can remain pending while the chat
       * Activity is on screen.
       */
      final future = ZohoSalesIQ.openChatWithID(
        chatId,
      );

      unawaited(
        future.then<void>(
              (_) {
            debugPrint(
              'ℹ️ Existing SalesIQ chat lifecycle completed: '
                  '$chatId',
            );
          },
          onError: (
              Object error,
              StackTrace stackTrace,
              ) {
            debugPrint(
              '⚠️ Existing SalesIQ chat lifecycle error: '
                  '$error',
            );

            debugPrintStack(
              stackTrace: stackTrace,
            );
          },
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Failed to launch existing SalesIQ chat: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _launchNewChat();

      return;
    }

    /*
     * Release the tap lock after native UI has had time to launch.
     *
     * We deliberately do NOT wait for the chat Activity to close.
     */
    _releaseSupportLaunchLock();
  }

  // ============================================================
  // LAUNCH NEW CHAT
  // ============================================================

  void _launchNewChat() {
    try {
      final future = ZohoSalesIQ.openNewChat();

      unawaited(
        future.then<void>(
              (_) {
            debugPrint(
              'ℹ️ New SalesIQ chat lifecycle completed',
            );
          },
          onError: (
              Object error,
              StackTrace stackTrace,
              ) {
            debugPrint(
              '⚠️ New SalesIQ chat lifecycle error: $error',
            );

            debugPrintStack(
              stackTrace: stackTrace,
            );
          },
        ),
      );

      debugPrint(
        '✅ Requested new SalesIQ chat window',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Failed to request new SalesIQ chat: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }

    _releaseSupportLaunchLock();
  }

  // ============================================================
  // RELEASE TAP LOCK
  // ============================================================

  void _releaseSupportLaunchLock() {
    Future<void>.delayed(
      const Duration(milliseconds: 1200),
          () {
        _supportLaunchInProgress = false;

        debugPrint(
          'ℹ️ SalesIQ support launch lock released',
        );
      },
    );
  }

  // ============================================================
  // CUSTOMER INFORMATION
  // ============================================================

  Future<void> _updateVisitorInformationAfterLaunch({
    required String userId,
    required String phone,
    required String userName,
    required String email,
  }) async {
    /*
     * Avoid repeatedly sending the same information whenever
     * Support is tapped.
     */
    if (_visitorInformationStartedFor == userId) {
      return;
    }

    _visitorInformationStartedFor = userId;

    /*
     * Let Mobilisten finish registering/opening first.
     */
    await Future<void>.delayed(
      const Duration(seconds: 2),
    );

    if (_registeredVisitorId != userId) {
      return;
    }

    // ----------------------------------------------------------
    // NAME
    // ----------------------------------------------------------

    if (userName.isNotEmpty) {
      _runDetachedOperation(
        label: 'visitor name',
        operation: ZohoSalesIQ.setVisitorName(
          userName,
        ),
      );
    }

    // ----------------------------------------------------------
    // PHONE
    // ----------------------------------------------------------

    if (phone.isNotEmpty) {
      _runDetachedOperation(
        label: 'visitor contact number',
        operation: ZohoSalesIQ.setVisitorContactNumber(
          _normalizeIndianPhone(
            phone,
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // EMAIL
    // ----------------------------------------------------------

    if (email.isNotEmpty) {
      _runDetachedOperation(
        label: 'visitor email',
        operation: ZohoSalesIQ.setVisitorEmail(
          email,
        ),
      );
    }

    // ----------------------------------------------------------
    // GOLDDUST USER ID
    // ----------------------------------------------------------

    _runDetachedOperation(
      label: 'GoldDust user ID',
      operation: ZohoSalesIQ.setVisitorAddInfo(
        'GoldDust User ID',
        userId,
      ),
    );

    // ----------------------------------------------------------
    // APP PLATFORM
    // ----------------------------------------------------------

    _runDetachedOperation(
      label: 'app platform',
      operation: ZohoSalesIQ.setVisitorAddInfo(
        'App Platform',
        Platform.isAndroid ? 'Android' : 'iOS',
      ),
    );

    debugPrint(
      '✅ SalesIQ visitor-information updates started: '
          'userId=$userId, '
          'phoneAvailable=${phone.isNotEmpty}, '
          'nameAvailable=${userName.isNotEmpty}, '
          'emailAvailable=${email.isNotEmpty}',
    );
  }

  // ============================================================
  // DETACHED SDK OPERATION
  // ============================================================

  void _runDetachedOperation({
    required String label,
    required Future<dynamic> operation,
  }) {
    unawaited(
      operation.then<void>(
            (_) {
          debugPrint(
            '✅ SalesIQ $label updated',
          );
        },
        onError: (
            Object error,
            StackTrace stackTrace,
            ) {
          /*
           * These updates should never stop the customer from
           * accessing Support.
           */
          debugPrint(
            '⚠️ SalesIQ $label update failed: $error',
          );

          debugPrintStack(
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logoutCustomer() async {
    _supportLaunchInProgress = false;

    _visitorInformationStartedFor = null;

    final prefs = await SharedPreferences.getInstance();

    /*
     * Remove the locally remembered registration regardless
     * of whether native unregister succeeds.
     */
    await prefs.remove(
      _registeredVisitorPrefsKey,
    );

    if (!_isInitialized) {
      _registeredVisitorId = null;

      return;
    }

    try {
      await ZohoSalesIQ.unregisterVisitor().timeout(
        const Duration(seconds: 15),
      );

      debugPrint(
        '✅ SalesIQ visitor unregistered',
      );
    } on TimeoutException catch (error) {
      debugPrint(
        '⚠️ SalesIQ unregisterVisitor timeout: $error',
      );
    } catch (error, stackTrace) {
      /*
       * A SalesIQ logout failure must never block normal
       * GoldDust logout.
       */
      debugPrint(
        '⚠️ SalesIQ visitor logout failed: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _registeredVisitorId = null;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _firstNonEmpty(
      List<String?> values,
      ) {
    for (final value in values) {
      final text = value?.trim() ?? '';

      if (text.isNotEmpty &&
          text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  String _normalizeIndianPhone(
      String phone,
      ) {
    final digits = phone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.length == 10) {
      return '+91$digits';
    }

    if (digits.length == 12 &&
        digits.startsWith('91')) {
      return '+$digits';
    }

    return phone.trim();
  }
}