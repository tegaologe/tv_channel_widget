import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:tv_channel_widget/src/model/tv_channle.dart';

typedef ItemBuilder = Widget Function(
    BuildContext context, int index, TvChannel channel);
typedef ShowBuilder = Widget Function(BuildContext context, ShowItem show,
    bool isSelect, String channelID, bool startCutOff);
typedef PlaceholderBuilder = Widget Function(BuildContext context,
    DateTime slotStart, bool isSelect, String channelID, bool startCutOff);

typedef SlotsComputedCallback = void Function(
    String channelID, List<EPGSlot> slots);

class ChannelWidget extends StatefulWidget {
  final int itemCount;
  final Future<TvChannel> Function(int index) channelLoader;
  final ItemBuilder channelBuilder;
  final ShowBuilder showsBuilder;
  final PlaceholderBuilder placeholderBuilder;
  final double channelWidth;
  final double itemHeight;
  final double verticalPadding;
  final double timerRowHeight;
  final double pixelsPerMinute;
  final Duration durationPerScrollExtension;
  final bool moveToCurrentTime;
  final ValueNotifier<SelectedChannel> selectedChannel;
  final SlotsComputedCallback? onSlotsComputed;

  const ChannelWidget({
    Key? key,
    required this.itemCount,
    required this.channelLoader,
    required this.channelBuilder,
    required this.showsBuilder,
    required this.placeholderBuilder,
    required this.selectedChannel,
    this.channelWidth = 150.0,
    this.itemHeight = 100.0,
    this.verticalPadding = 10.0,
    this.timerRowHeight = 20.0,
    this.pixelsPerMinute = 2.0,
    required this.durationPerScrollExtension,
    this.moveToCurrentTime = false,
    this.onSlotsComputed,
  }) : super(key: key);

  @override
  State<ChannelWidget> createState() => _ChannelWidgetState();
}

class _ChannelWidgetState extends State<ChannelWidget> {
  late final LinkedScrollControllerGroup _horizontalGroup;
  late final ScrollController _timelineController;
  late final ScrollController _showsScrollController;

  late final LinkedScrollControllerGroup _verticalGroup;
  late final ScrollController _channelListController;
  late final ScrollController _showListController;

  late final DateTime _baseTime;
  DateTime _currentVisibleDate = DateTime.now();
  int _visibleSlotCount = 48;
  late final int _slotsPerScrollExtension;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseTime = DateTime(
        now.year, now.month, now.day, now.hour, now.minute >= 30 ? 30 : 0);

    _horizontalGroup = LinkedScrollControllerGroup();
    _timelineController = _horizontalGroup.addAndGet();
    _showsScrollController = _horizontalGroup.addAndGet();

    _verticalGroup = LinkedScrollControllerGroup();
    _channelListController = _verticalGroup.addAndGet();
    _showListController = _verticalGroup.addAndGet();

    _slotsPerScrollExtension =
        widget.durationPerScrollExtension.inMinutes ~/ 30;

    _timelineController.addListener(_onTimelineScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.moveToCurrentTime) _scrollToCurrentTime();
    });
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final diffMin = now.difference(_baseTime).inMinutes;
    final scrollPosition = widget.pixelsPerMinute * diffMin;
    _timelineController.jumpTo(scrollPosition);
    _showsScrollController.jumpTo(scrollPosition);
  }

  void _onTimelineScroll() {
    final currentScroll = _timelineController.offset;
    final maxScroll = _timelineController.position.maxScrollExtent;

    if (currentScroll > maxScroll - 300) {
      setState(() {
        _visibleSlotCount += _slotsPerScrollExtension;
      });
    }

    final minutesOffset = currentScroll / widget.pixelsPerMinute;
    final scrolledTime =
        _baseTime.add(Duration(minutes: minutesOffset.round()));
    if (!isSameDay(scrolledTime, _currentVisibleDate)) {
      setState(() {
        _currentVisibleDate = scrolledTime;
      });
    }
  }

  @override
  void dispose() {
    _timelineController.dispose();
    _showsScrollController.dispose();
    _channelListController.dispose();
    _showListController.dispose();
    super.dispose();
  }

  double getCalculatedWidth(int minutes) => widget.pixelsPerMinute * minutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Timeline Header
        Row(
          children: [
            SizedBox(
              width: widget.channelWidth,
              child: Container(
                height: widget.timerRowHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  DateFormat('EEE, MMM d').format(_currentVisibleDate),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: widget.timerRowHeight,
                child: ListView.builder(
                  controller: _timelineController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _visibleSlotCount,
                  itemBuilder: (context, index) {
                    final time = _baseTime.add(Duration(minutes: index * 30));
                    return SizedBox(
                      width: getCalculatedWidth(30),
                      child: Text(
                        DateFormat('hh:mm a').format(time),
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // Main Grid
        Expanded(
          child: Row(
            children: [
              // Channel Labels
              SizedBox(
                width: widget.channelWidth,
                child: ListView.builder(
                  cacheExtent: 3000,
                  controller: _channelListController,
                  itemCount: widget.itemCount,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return FutureBuilder<TvChannel>(
                      future: _loadChannel(index),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return SizedBox(
                            height: widget.itemHeight,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        }
                        return SizedBox(
                          height: widget.itemHeight,
                          child: widget.channelBuilder(
                              context, index, snapshot.data!),
                        );
                      },
                    );
                  },
                ),
              ),

              // Shows Grid with Now Indicator
              Expanded(
                child: SingleChildScrollView(
                  controller: _showsScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: getCalculatedWidth(_visibleSlotCount * 30),
                        child: ListView.builder(
                          cacheExtent: 3000,
                          controller: _showListController,
                          physics: const ClampingScrollPhysics(),
                          itemCount: widget.itemCount,
                          itemBuilder: (context, index) {
                            return FutureBuilder<TvChannel>(
                              future: _loadChannel(index),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return SizedBox(
                                    height: widget.itemHeight,
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }
                                return SizedBox(
                                  height: widget.itemHeight,
                                  child: ChannelRow(
                                    channel: snapshot.data!,
                                    onSlotsComputed: widget.onSlotsComputed,
                                    selectedChannel: widget.selectedChannel,
                                    itemHeight: widget.itemHeight,
                                    getCalculatedWidth: getCalculatedWidth,
                                    showsBuilder: widget.showsBuilder,
                                    placeholderBuilder:
                                        widget.placeholderBuilder,
                                    baseTime: _baseTime,
                                    visibleSlotCount: _visibleSlotCount,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      _buildNowIndicatorOverlay(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  final LruCache<int, TvChannel> _channelCache = LruCache(300); // adjust size
  final LruCache<int, Future<TvChannel>> _futureCache = LruCache(300);

  Future<TvChannel> _loadChannel(int index) {
    final cachedChannel = _channelCache.get(index);
    if (cachedChannel != null) return Future.value(cachedChannel);

    final cachedFuture = _futureCache.get(index);
    if (cachedFuture != null) return cachedFuture;

    final future = widget.channelLoader(index).then((channel) {
      _channelCache.put(index, channel);
      return channel;
    });

    _futureCache.put(index, future);
    return future;
  }

  Widget _buildNowIndicatorOverlay() {
    final now = DateTime.now();
    final minutes = now.difference(_baseTime).inMinutes;
    final offset = getCalculatedWidth(minutes);

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: offset,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            border: Border(
              right: BorderSide(
                color: Colors.redAccent.withAlpha(90), // red line
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class ChannelRow extends StatefulWidget {
  final TvChannel channel;
  final double itemHeight;
  final double Function(int minutes) getCalculatedWidth;
  final ShowBuilder showsBuilder;
  final PlaceholderBuilder placeholderBuilder;
  final DateTime baseTime;
  final int visibleSlotCount;
  final ValueNotifier<SelectedChannel> selectedChannel;
  final SlotsComputedCallback? onSlotsComputed;

  const ChannelRow({
    super.key,
    required this.channel,
    required this.itemHeight,
    required this.getCalculatedWidth,
    required this.showsBuilder,
    required this.placeholderBuilder,
    required this.baseTime,
    required this.visibleSlotCount,
    required this.selectedChannel,
    this.onSlotsComputed,
  });

  @override
  State<ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<ChannelRow> {
  // with AutomaticKeepAliveClientMixin {
  @override
  // bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // super.build(context);

    final timelineStart = widget.baseTime;
    final timelineEnd = timelineStart.add(Duration(
      minutes: widget.visibleSlotCount * 30,
    ));

    return StreamBuilder<List<ShowItem>>(
      stream: widget.channel.showItemsStream,
      builder: (context, snapshot) {
        final shows = snapshot.data ?? widget.channel.showItems;
        final slots = generateEPGSlots(shows, timelineStart, timelineEnd);
        widget.onSlotsComputed?.call(widget.channel.channelID, slots);
        return ValueListenableBuilder<SelectedChannel>(
          valueListenable: widget.selectedChannel,
          builder: (context, selected, _) {
            bool cutoffApplied = false;
            return Row(
              children: slots.map((slot) {
                final isSelected =
                    selected.channelID == widget.channel.channelID &&
                        selected.slotIndex == slots.indexOf(slot);

                bool startCutOff = false;
                if (!cutoffApplied && slot.start.isBefore(DateTime.now())) {
                  startCutOff = true;
                  cutoffApplied = true;
                }

                return RepaintBoundary(
                  child: GestureDetector(
                    onTap: () {
                      widget.selectedChannel.value = selected.copyWith(
                        slotIndex: slots.indexOf(slot),
                        channelID: widget.channel.channelID,
                      );
                    },
                    child: SizedBox(
                      width: widget.getCalculatedWidth(slot.duration),
                      height: widget.itemHeight,
                      child: slot.isPlaceholder
                          ? widget.placeholderBuilder(context, slot.start,
                              isSelected, widget.channel.channelID, startCutOff)
                          : widget.showsBuilder(context, slot.show!, isSelected,
                              widget.channel.channelID, startCutOff),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  List<EPGSlot> generateEPGSlots(
      List<ShowItem> shows, DateTime timelineStart, DateTime timelineEnd) {
    List<EPGSlot> slots = [];
    DateTime current = timelineStart;

    // Sort shows by start time
    shows.sort((a, b) => a.showStartTime.compareTo(b.showStartTime));

    for (final show in shows) {
      if (show.showEndTime.isBefore(timelineStart)) continue;
      if (show.showStartTime.isAfter(timelineEnd)) break;

      // Add placeholder before show if there's a gap
      if (show.showStartTime.isAfter(current)) {
        slots.addAll(_createPlaceholderSlots(current, show.showStartTime));
      }

      // Add show slot
      slots.add(EPGSlot(
        id: show.showID,
        start: show.showStartTime,
        end: show.showEndTime,
        show: show,
      ));

      current = show.showEndTime;
    }

    // Add remaining placeholders after last show
    if (current.isBefore(timelineEnd)) {
      slots.addAll(_createPlaceholderSlots(current, timelineEnd));
    }

    return slots;
  }

  List<EPGSlot> _createPlaceholderSlots(DateTime start, DateTime end) {
    List<EPGSlot> placeholders = [];
    DateTime current = start;

    while (current.isBefore(end)) {
      final next = current.add(const Duration(minutes: 30));
      final slotEnd = next.isBefore(end) ? next : end;

      placeholders.add(EPGSlot(
        id: 'placeholder_${current.millisecondsSinceEpoch}',
        start: current,
        end: slotEnd,
        isPlaceholder: true,
      ));

      current = slotEnd;
    }

    return placeholders;
  }
}
