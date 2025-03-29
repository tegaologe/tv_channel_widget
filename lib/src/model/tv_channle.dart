/// List of all channels
class TvChannel {
  final String channelID;
  final String channelName;
  final String channelLogoBase64;
  final List<ShowItem> showItems;
  final dynamic imageStream;
  final dynamic showItemsStream;

  TvChannel({
    required this.channelID,
    required this.channelName,
    required this.showItems,
    required this.channelLogoBase64,
    this.imageStream,
    this.showItemsStream,
  });
}

/// List of show for a channel
class ShowItem {
  final String showID;

  /// String that shows Show Name
  final String showName;

  /// DateTime that will identify as the start time of the show
  final DateTime showStartTime;

  /// DateTime that will identify as the end time of the show
  final DateTime showEndTime;

  ShowItem({
    required this.showID,
    required this.showName,
    required this.showStartTime,
    required this.showEndTime,
  });

  @override
  String toString() {
    return ' ShowName :$showName StartTime :$showStartTime EndTime :$showEndTime';
  }
}

class EPGSlot {
  final String id;
  final DateTime start;
  final DateTime end;
  final ShowItem? show;
  final bool isPlaceholder;

  EPGSlot({
    required this.id,
    required this.start,
    required this.end,
    this.show,
    this.isPlaceholder = false,
  });

  int get duration => end.difference(start).inMinutes;
}

class SelectedChannel {
  String channelID;
  int channelIndex;
  int slotIndex; // Changed from showIndex to slotIndex

  SelectedChannel({
    required this.channelID,
    required this.channelIndex,
    required this.slotIndex,
  });
}
