import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startRadioForegroundTask() {
  FlutterForegroundTask.setTaskHandler(RadioForegroundTaskHandler());
}

class ForegroundRadioService {
  void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'crewcomm_radio',
        channelName: 'CrewComm Radio',
        channelDescription: 'Keeps live production audio available.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> start() async {
    await FlutterForegroundTask.startService(
      serviceTypes: const <ForegroundServiceTypes>[
        ForegroundServiceTypes.microphone,
        ForegroundServiceTypes.connectedDevice,
      ],
      notificationTitle: 'CrewComm is live',
      notificationText: 'Listening for production radio traffic',
      notificationIcon: const NotificationIcon(
        metaDataName: 'crewcomm_notification_icon',
      ),
      callback: startRadioForegroundTask,
    );
  }
}

class RadioForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain(<String, Object>{
      'type': 'radio.heartbeat',
      'timestamp': timestamp.toIso8601String(),
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}
}
