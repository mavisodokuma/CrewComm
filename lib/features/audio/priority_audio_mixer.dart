import 'dart:async';

class PriorityAudioMixer {
  final _duckingController = StreamController<double>.broadcast();
  double _crewVolume = 1;

  Stream<double> get crewVolumeChanges => _duckingController.stream;
  double get crewVolume => _crewVolume;

  void setAdminBroadcastActive(bool isActive) {
    _crewVolume = isActive ? 0.25 : 1;
    _duckingController.add(_crewVolume);
  }

  void dispose() {
    _duckingController.close();
  }
}
