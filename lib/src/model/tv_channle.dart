class TvChannel {
  final String channelID;
  final String channelName;
  final String serviceProvider;
  final String channelLogoBase64;
  final List<ShowItem> showItems;
  final String streamIcon;
  final String epgid;

  TvChannel({
    required this.channelID,
    required this.channelName,
    required this.showItems,
    required this.channelLogoBase64,
    required this.streamIcon,
    required this.serviceProvider,
    required this.epgid,
  });
}

/// List of show for a channel
class ShowItem {
  final String showID;
  final String channelID;
  final String serviceProvider;

  /// String that shows Show Name
  final String showName;

  /// DateTime that will identify as the start time of the show
  final DateTime showStartTime;

  /// DateTime that will identify as the end time of the show
  final DateTime showEndTime;

  final String epgid;

  ShowItem({
    required this.channelID,
    required this.showID,
    required this.showName,
    required this.showStartTime,
    required this.showEndTime,
    required this.serviceProvider,
    required this.epgid,
  });
  factory ShowItem.fromMap(Map<String, dynamic> map) => ShowItem(
        channelID: map['channelID'] as String,
        showID: map['showID'] as String,
        showName: map['showName'] as String,
        showStartTime: DateTime.parse(map['showStartTime'] as String),
        showEndTime: DateTime.parse(map['showEndTime'] as String),
        serviceProvider: map['serviceProvider'] as String,
        epgid: map['epgid'] as String,
      );

  Map<String, dynamic> toMap() => {
        'channelID': channelID,
        'showID': showID,
        'showName': showName,
        'showStartTime': showStartTime.toIso8601String(),
        'showEndTime': showEndTime.toIso8601String(),
        'serviceProvider': serviceProvider,
        'epgid': epgid,
      };

  @override
  String toString() {
    return ' ShowName :$showName StartTime :$showStartTime EndTime :$showEndTime';
  }
}

class EPGSlot {
  final String id;
  final String channelID;
  final DateTime start;
  final DateTime end;
  final ShowItem? show;
  final bool isPlaceholder;
  final String serviceProvider;
  final String epgid;

  EPGSlot({
    required this.id,
    required this.channelID,
    required this.start,
    required this.end,
    this.show,
    this.isPlaceholder = false,
    required this.serviceProvider,
    required this.epgid,
  });

  int get duration => end.difference(start).inMinutes;
  DateTime get centerTime => start.add(end.difference(start) ~/ 2);
}

class SelectedChannel {
  String channelID;
  int channelIndex;
  int slotIndex;
  String serviceProvider;
  String epgid;
  String channelName;

  SelectedChannel(
      {required this.channelID,
      required this.channelName,
      required this.channelIndex,
      required this.serviceProvider,
      required this.slotIndex,
      required this.epgid});

  SelectedChannel copyWith({
    String? channelID,
    String? channelName,
    int? channelIndex,
    int? slotIndex,
    String? serviceProvider,
    String? epgid,
  }) {
    return SelectedChannel(
      channelID: channelID ?? this.channelID,
      channelIndex: channelIndex ?? this.channelIndex,
      slotIndex: slotIndex ?? this.slotIndex,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      epgid: epgid ?? this.epgid,
      channelName: channelName ?? this.channelID,
    );
  }
}

class LruCache<K, V> {
  final int capacity;
  final _cache = <K, V>{};
  final _usageOrder = <K>[];

  LruCache(this.capacity);

  V? get(K key) {
    if (_cache.containsKey(key)) {
      _usageOrder.remove(key);
      _usageOrder.insert(0, key);
      return _cache[key];
    }
    return null;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _usageOrder.remove(key);
    } else if (_cache.length >= capacity) {
      final oldest = _usageOrder.removeLast();
      _cache.remove(oldest);
    }
    _cache[key] = value;
    _usageOrder.insert(0, key);
  }

  void clear() {
    _cache.clear();
    _usageOrder.clear();
  }
}
