import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:tv_channel_widget/src/model/tv_channle.dart';

typedef ItemBuilder = Widget Function(
    BuildContext context, int index, TvChannel channel);
typedef ShowBuilder = Widget Function(BuildContext context, ShowItem show);
typedef PlaceholderBuilder = Widget Function(
    BuildContext context, DateTime slotStart);

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

  const ChannelWidget({
    Key? key,
    required this.itemCount,
    required this.channelLoader,
    required this.channelBuilder,
    required this.showsBuilder,
    required this.placeholderBuilder,
    this.channelWidth = 150.0,
    this.itemHeight = 100.0,
    this.verticalPadding = 10.0,
    this.timerRowHeight = 20.0,
    this.pixelsPerMinute = 2.0,
    required this.durationPerScrollExtension,
    this.moveToCurrentTime = false,
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

  final Map<int, TvChannel> _loadedChannels = {};
  final Map<String, Widget> _memoizedShowWidgets = {};

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
                  controller: _channelListController,
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
                  child: Stack(
                    children: [
                      SizedBox(
                        width: getCalculatedWidth(_visibleSlotCount * 30),
                        child: ListView.builder(
                          controller: _showListController,
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

  Future<TvChannel> _loadChannel(int index) async {
    if (_loadedChannels.containsKey(index)) return _loadedChannels[index]!;
    final channel = await widget.channelLoader(index);
    _loadedChannels[index] = channel;
    return channel;
  }

  Widget _buildChannelRow(TvChannel channel) {
    final timelineStart = _baseTime;
    final timelineEnd =
        timelineStart.add(Duration(minutes: _visibleSlotCount * 30));

    return StreamBuilder<List<dynamic>>(
      stream: channel.showItemsStream,
      builder: (context, snapshot) {
        final sortedShows = [...(snapshot.data ?? channel.showItems)]
          ..sort((a, b) => a.showStartTime.compareTo(b.showStartTime));

        List<Widget> children = [];
        DateTime current = timelineStart;

        for (final show in sortedShows) {
          if (show.showEndTime.isBefore(timelineStart) ||
              show.showStartTime.isAfter(timelineEnd)) {
            continue;
          }

          if (show.showStartTime.isAfter(current)) {
            _addPlaceholdersInChunks(
                children: children, from: current, to: show.showStartTime);
            current = show.showStartTime;
          }

          final duration =
              show.showEndTime.difference(show.showStartTime).inMinutes;
          final key = show.showID;

          _memoizedShowWidgets.putIfAbsent(
              key, () => widget.showsBuilder(context, show));

          children.add(SizedBox(
            width: getCalculatedWidth(duration),
            height: widget.itemHeight,
            child: _memoizedShowWidgets[key]!,
          ));

          current = show.showEndTime;
        }

        if (current.isBefore(timelineEnd)) {
          _addPlaceholdersInChunks(
              children: children, from: current, to: timelineEnd);
        }

        return Row(children: children);
      },
    );
  }

  void _addPlaceholdersInChunks({
    required List<Widget> children,
    required DateTime from,
    required DateTime to,
  }) {
    DateTime current = from;
    while (current.isBefore(to)) {
      final next = current.add(const Duration(minutes: 30));
      final chunkEnd = next.isBefore(to) ? next : to;
      final chunkDuration = chunkEnd.difference(current).inMinutes;

      children.add(SizedBox(
        width: getCalculatedWidth(chunkDuration),
        height: widget.itemHeight,
        child: widget.placeholderBuilder(context, current),
      ));

      current = chunkEnd;
    }
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

  const ChannelRow({
    super.key,
    required this.channel,
    required this.itemHeight,
    required this.getCalculatedWidth,
    required this.showsBuilder,
    required this.placeholderBuilder,
    required this.baseTime,
    required this.visibleSlotCount,
  });

  @override
  State<ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<ChannelRow>
    with AutomaticKeepAliveClientMixin {
  final Map<String, Widget> _memoizedShowWidgets = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final timelineStart = widget.baseTime;
    final timelineEnd = timelineStart.add(Duration(
      minutes: widget.visibleSlotCount * 30,
    ));

    return StreamBuilder<List<ShowItem>>(
      stream: widget.channel.showItemsStream,
      builder: (context, snapshot) {
        final sortedShows = [...(snapshot.data ?? widget.channel.showItems)]
          ..sort((a, b) => a.showStartTime.compareTo(b.showStartTime));

        List<Widget> children = [];
        DateTime current = timelineStart;

        for (final show in sortedShows) {
          if (show.showEndTime.isBefore(timelineStart) ||
              show.showStartTime.isAfter(timelineEnd)) {
            continue;
          }

          if (show.showStartTime.isAfter(current)) {
            _addPlaceholders(children, current, show.showStartTime);
            current = show.showStartTime;
          }

          final duration =
              show.showEndTime.difference(show.showStartTime).inMinutes;
          final key = show.showID;

          _memoizedShowWidgets.putIfAbsent(
              key, () => widget.showsBuilder(context, show));

          children.add(SizedBox(
            width: widget.getCalculatedWidth(duration),
            height: widget.itemHeight,
            child: _memoizedShowWidgets[key]!,
          ));

          current = show.showEndTime;
        }

        if (current.isBefore(timelineEnd)) {
          _addPlaceholders(children, current, timelineEnd);
        }

        return Row(children: children);
      },
    );
  }

  void _addPlaceholders(List<Widget> children, DateTime from, DateTime to) {
    DateTime current = from;
    while (current.isBefore(to)) {
      final next = current.add(const Duration(minutes: 30));
      final chunkEnd = next.isBefore(to) ? next : to;
      final chunkDuration = chunkEnd.difference(current).inMinutes;

      children.add(SizedBox(
        width: widget.getCalculatedWidth(chunkDuration),
        height: widget.itemHeight,
        child: widget.placeholderBuilder(context, current),
      ));

      current = chunkEnd;
    }
  }
}
