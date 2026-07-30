import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'router.dart';

class SafeTraceRingtonePlayer {
  static const _channel = MethodChannel('com.safetrace.safetrace/ringtone');

  static Future<void> playRingtone() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('Failed to play ringtone natively: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('Failed to stop ringtone natively: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM: Received background message: ${message.messageId}');
  
  final data = message.data;
  if (data['interrupt'] == 'true') {
    // 1. Play Ringtone looping
    try {
      await SafeTraceRingtonePlayer.playRingtone();
    } catch (e) {
      debugPrint('Failed to play ringtone: $e');
    }
    
    // 2. Start vibrating pattern
    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (canVibrate) {
        Vibration.vibrate(pattern: [0, 1000, 500], repeat: 0);
      }
    } catch (e) {
      debugPrint('Failed to vibrate: $e');
    }

    // 3. Save details in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_panic_uid', data['victim_uid'] ?? '');
      await prefs.setString('active_panic_first_name', data['victim_first_name'] ?? '');
      await prefs.setString('active_panic_last_name', data['victim_last_name'] ?? '');
      await prefs.setString('active_panic_lat', data['victim_lat'] ?? '0.0');
      await prefs.setString('active_panic_lng', data['victim_lng'] ?? '0.0');
      await prefs.setString('active_panic_address', data['victim_address'] ?? '');
    } catch (e) {
      debugPrint('Failed to save panic details: $e');
    }

    // 4. Trigger full screen local notification
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      
      const androidDetails = AndroidNotificationDetails(
        'emergency_alerts_channel',
        'Emergency Alerts',
        channelDescription: 'High priority notifications for emergency panic alerts.',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      const details = NotificationDetails(android: androidDetails);
      
      final name = "${data['victim_first_name']} ${data['victim_last_name']}".trim();
      await localNotifications.show(
        911,
        'EMERGENCY from $name',
        '$name has triggered a panic alert. Tap to see their location.',
        details,
        payload: data['victim_uid'],
      );
    } catch (e) {
      debugPrint('Failed to show full screen intent notification: $e');
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Register background messaging handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationClick(response.payload);
        },
      );

      // Request permissions (for iOS and Android 13+)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('FCM: User granted provisional permission');
      } else {
        debugPrint('FCM: User declined permission');
      }

      // Fetch Token
      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Registration Token: $token');
      }

      // Sync token on login/state changes
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          try {
            String? t = await messaging.getToken();
            if (t != null) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'fcm_token': t,
                'fcmToken': t,
              });
              debugPrint('FCM Token synced to Firestore for user: ${user.uid}');
            }
          } catch (e) {
            debugPrint('Failed to sync FCM Token: $e');
          }
        }
      });

      // Listen for foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('FCM Foreground Message: ${message.notification?.title} - ${message.notification?.body}');
        
        final data = message.data;
        if (data['interrupt'] == 'true') {
          // Play ringtone and vibrate
          try {
            await SafeTraceRingtonePlayer.playRingtone();
          } catch (e) {
            debugPrint('Failed to play ringtone: $e');
          }
          
          try {
            final canVibrate = await Vibration.hasVibrator() ?? false;
            if (canVibrate) {
              Vibration.vibrate(pattern: [0, 1000, 500], repeat: 0);
            }
          } catch (e) {
            debugPrint('Failed to vibrate: $e');
          }
          
          // Save panic details in shared preferences
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('active_panic_uid', data['victim_uid'] ?? '');
            await prefs.setString('active_panic_first_name', data['victim_first_name'] ?? '');
            await prefs.setString('active_panic_last_name', data['victim_last_name'] ?? '');
            await prefs.setString('active_panic_lat', data['victim_lat'] ?? '0.0');
            await prefs.setString('active_panic_lng', data['victim_lng'] ?? '0.0');
            await prefs.setString('active_panic_address', data['victim_address'] ?? '');
          } catch (e) {
            debugPrint('Failed to save panic details: $e');
          }

          // Navigate to panic interrupt screen
          rootNavigatorKey.currentContext?.push('/panic-interrupt');
        }
      });

      // Listen for app-open clicks on notification alerts
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM: Notification opened app with data: ${message.data}');
        final data = message.data;
        if (data['victim_uid'] != null) {
          _handleNotificationClick(data['victim_uid']);
        }
      });
    } catch (e) {
      debugPrint('FCM Initialization Failed gracefully: $e');
    }
  }

  static void _handleNotificationClick(String? victimUid) {
    if (victimUid != null && victimUid.isNotEmpty) {
      // Direct routing using rootNavigatorKey
      rootNavigatorKey.currentContext?.push('/panic-map/$victimUid');
    }
  }
}
