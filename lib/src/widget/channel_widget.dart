import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:tv_channel_widget/src/model/tv_channle.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:flutter_touch_ripple/flutter_touch_ripple.dart';

typedef ItemBuilder = Widget Function(
    BuildContext context, int index, TvChannel channel);
typedef ShowBuilder = Widget Function(BuildContext context, ShowItem show,
    bool isSelect, String channelID, bool startCutOff);
typedef PlaceholderBuilder = Widget Function(BuildContext context,
    DateTime slotStart, bool isSelect, String channelID, bool startCutOff);

typedef SlotsComputedCallback = void Function(
    String channelID, List<EPGSlot> slots);

typedef SelectedSlotCallback = void Function(
    EPGSlot slot, int index, int method);

final GlobalKey rippleKey = GlobalKey();

class ChannelWidget extends StatefulWidget {
  final int itemCount;
  final Future<TvChannel> Function(int index) channelLoader;
  final void Function(DateTime newDate)? onDateChanged;
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
  final SelectedChannel selectedChannel;
  final SlotsComputedCallback? onSlotsComputed;
  final SelectedSlotCallback onSelectSlot;
  final void Function(int rowIndex, List<TouchRippleController> controllers)?
      onControllersInitialized;
  final bool capToInitialWindow;
  const ChannelWidget({
    super.key,
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
    this.onDateChanged,
    required this.onSelectSlot,
    this.onControllersInitialized,
    this.capToInitialWindow = true,
  });

  @override
  State<ChannelWidget> createState() => ChannelWidgetState();
}

class ChannelWidgetState extends State<ChannelWidget> {
  late final LinkedScrollControllerGroup _horizontalGroup;
  late final ScrollController _timelineController;
  late final ScrollController _showsScrollController;

  late final LinkedScrollControllerGroup _verticalGroup;
  late final ScrollController _channelListController;
  late final ScrollController _showListController;

  late final ListController channelListController;
  late final ListController showListController;

  ScrollController get verticalController => _channelListController;
  ScrollController get horizontalController => _showsScrollController;
  late final void Function(
          int rowIndex, List<TouchRippleController> controllers)?
      onControllersInitialized;

  late DateTime baseTime;

  DateTime _currentVisibleDate = DateTime.now();
  DateTime get exposedBaseTime => baseTime;

  static const int _initialVisibleSlots = 48;
  int _visibleSlotCount = _initialVisibleSlots;

  //final TouchRippleController rippleController = TouchRippleController();
  //final Map<int, List<TouchRippleController>> _rowControllers = {};
  final Map<int, List<EPGSlot>> slotsPerRow = {};
  late final int _slotsPerScrollExtension;

  void onEnter() {
    /*
    final sel = widget.selectedChannel;
    final keys = _rowControllers[sel.channelIndex];
    final slog = widget.selectedChannel.slotIndex;
    //final slot =
    if (slog < 0 || slog >= _visibleSlotCount) return;

    if (keys == null) return;
    _triggerRippleAt(
        sel.channelIndex, sel.slotIndex, Size(200, widget.itemHeight));
        */
  }

/*
  void _triggerRippleAt(int row, int slot, Size size) {
    debugPrint('-->Triggering ripple at row: $row, slot: $slot');
    final ctrl = _rowControllers[row]![slot];

    // a new key every single time
    final key = 'ripple-$row-$slot-${DateTime.now().microsecondsSinceEpoch}';

    // build the effect once
    final ctx = ctrl.context;
    final center = Offset(size.width / 2, size.height / 2);
    final fx = TouchRippleSpreadingEffect(
      context: ctx,
      callback: () {
        print('Ripple effect completed');
      },
      isRejectable: false,
      baseOffset: center,
      behavior: ctx.tapBehavior,
    );
    fx.addListener(() {
      //final p = fx.spreadPercent; // 0.0 → 1.0 over your spreadDuration
      //print('Ripple spread at ${(p * 100).toStringAsFixed(1)}%');
    });

    // attach & start — no detach needed!
    ctrl.attachByKey(key, fx);
    fx.start();
    final slots = slotsPerRow[row];
    if (slots != null && slot < slots.length) {
      final selectedSlot = slots[slot];
      widget.onSelectSlot(selectedSlot, slot, 0);
    }
    debugPrint('Fired ripple at $key');
  }
*/
  @override
  void didUpdateWidget(covariant ChannelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the channel list has changed
    if (widget.itemCount != oldWidget.itemCount) {
      // Clear caches
      _channelCache.clear();
      _futureCache.clear();

      // Reset scroll positions.
      // Using addPostFrameCallback ensures that the controllers are attached.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_channelListController.hasClients) {
          _channelListController.jumpTo(0.0);
        }
        if (_showListController.hasClients) {
          _showListController.jumpTo(0.0);
        }
        if (_timelineController.hasClients) {
          _timelineController.jumpTo(0.0);
        }
      });
    }
  }

  Timer? _timeRolloverCheckTimer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    baseTime = DateTime(
        now.year, now.month, now.day, now.hour, now.minute >= 30 ? 30 : 0);
    channelListController = ListController();
    showListController = ListController();
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
    _timeRolloverCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final roundedMinutes = now.minute >= 30 ? 30 : 0;
      final newBase =
          DateTime(now.year, now.month, now.day, now.hour, roundedMinutes);

      if (!isSameMoment(baseTime, newBase)) {
        setState(() {
          baseTime = newBase;
          _currentVisibleDate = newBase;
        });

        if (widget.moveToCurrentTime) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentTime();
          });
        }

        widget.onDateChanged?.call(newBase);
      }
    });
    _visibleSlotCount = _initialVisibleSlots;
  }

  bool isSameMoment(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final diffMin = now.difference(baseTime).inMinutes;
    final scrollPosition = widget.pixelsPerMinute * diffMin;
    _timelineController.jumpTo(scrollPosition);
    _showsScrollController.jumpTo(scrollPosition);
  }

  void _onTimelineScroll() {
    final currentScroll = _timelineController.offset;
    final maxScroll = _timelineController.position.maxScrollExtent;

    // only auto‐extend if the user _allows_ it
    if (!widget.capToInitialWindow && currentScroll > maxScroll - 300) {
      setState(() {
        _visibleSlotCount += _slotsPerScrollExtension;
      });
    }

    // update header date as before…
    final minutesOffset = currentScroll / widget.pixelsPerMinute;
    final scrolledTime = baseTime.add(Duration(minutes: minutesOffset.round()));
    if (!isSameDay(scrolledTime, _currentVisibleDate)) {
      setState(() => _currentVisibleDate = scrolledTime);
    }
    widget.onDateChanged?.call(scrolledTime);
  }
/*
  void _onTimelineScroll() {
    final currentScroll = _timelineController.offset;
    final maxScroll = _timelineController.position.maxScrollExtent;

    if (currentScroll > maxScroll - 300) {
      setState(() {
        _visibleSlotCount += _slotsPerScrollExtension;
      });
    }

    final minutesOffset = currentScroll / widget.pixelsPerMinute;
    final scrolledTime = baseTime.add(Duration(minutes: minutesOffset.round()));
    if (!isSameDay(scrolledTime, _currentVisibleDate)) {
      setState(() {
        _currentVisibleDate = scrolledTime;
      });
    }
    widget.onDateChanged?.call(scrolledTime);
  }
  */

  @override
  void dispose() {
    _timeRolloverCheckTimer?.cancel();
    _timelineController.dispose();
    _showsScrollController.dispose();
    _channelListController.dispose();
    _showListController.dispose();
    channelListController.dispose();
    super.dispose();
  }

  double getCalculatedWidth(int minutes) => widget.pixelsPerMinute * minutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Timeline Header

        Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    Colors.grey.withAlpha(60), // Or another color you prefer.
                width: 0.8, // Adjust the thickness as needed.
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: widget.channelWidth,
                child: Container(
                  height: widget.timerRowHeight,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    DateFormat('EEE, MMM d').format(_currentVisibleDate),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: widget.timerRowHeight,
                  child: SuperListView.builder(
                    addRepaintBoundaries: true,
                    addAutomaticKeepAlives: true,
                    delayPopulatingCacheArea: true,
                    cacheExtent: 100,
                    controller: _timelineController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _visibleSlotCount,
                    itemBuilder: (context, index) {
                      final time = baseTime.add(Duration(minutes: index * 30));
                      return SizedBox(
                        width: getCalculatedWidth(30),
                        child: Text(
                          DateFormat('hh:mm a').format(time),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.normal),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Grid
        Expanded(
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Colors.grey.withAlpha(60),
                      width: 0.8,
                    ),
                  ),
                ),
                width: widget.channelWidth,
                child: SuperListView.builder(
                  cacheExtent: 100,
                  addRepaintBoundaries: true,
                  addAutomaticKeepAlives: true,
                  delayPopulatingCacheArea: true,
                  controller: _channelListController,
                  listController: channelListController,
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
              TouchRippleStyle(
                rippleColor: Colors.black.withAlpha(50),
                rippleBorderRadius: BorderRadius.circular(4),
                overlapBehavior: TouchRippleOverlapBehavior.overlappable,
                cancelBehavior: TouchRippleCancelBehavior.none,
                onlyMainButton: false,

                //tapBehavior: TouchRippleBehavior(...),
                child: Expanded(
                  child: SingleChildScrollView(
                    controller: _showsScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: getCalculatedWidth(_visibleSlotCount * 60),
                          child: SuperListView.builder(
                            cacheExtent: 100,
                            listController: showListController,
                            addRepaintBoundaries: true,
                            addAutomaticKeepAlives: true,
                            delayPopulatingCacheArea: true,
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
                                      rowIndex: index,
                                      key: ValueKey(
                                          "${snapshot.data!.channelID}_${snapshot.data!.showItems.length}"),
                                      channel: snapshot.data!,
                                      //onSlotsComputed: widget.onSlotsComputed,
                                      onSlotsComputed: (channelId, slots) {
                                        slotsPerRow[index] = slots;
                                        widget.onSlotsComputed
                                            ?.call(channelId, slots);
                                      },
                                      selectedChannel: widget.selectedChannel,
                                      itemHeight: widget.itemHeight,
                                      getCalculatedWidth: getCalculatedWidth,
                                      showsBuilder: widget.showsBuilder,
                                      onSelectSlot: widget.onSelectSlot,
                                      onControllersInitialized:
                                          widget.onControllersInitialized,
                                      placeholderBuilder:
                                          widget.placeholderBuilder,
                                      baseTime: baseTime,
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
              )
            ],
          ),
        ),
      ],
    );
  }

  final LruCache<int, TvChannel> _channelCache = LruCache(50); // adjust size
  final LruCache<int, Future<TvChannel>> _futureCache = LruCache(50);

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
    final minutes = now.difference(baseTime).inMinutes;
    final offset = getCalculatedWidth(minutes);

    const double lineWidth = 1.5;
    const double ballDiameter = 8.0;
    final double ballRadius = ballDiameter / 2;

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: SizedBox(
          width: offset,
          // height is inherited from Positioned (top:0, bottom:0)
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1) gradient fill up to now
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(2),
                        Colors.white.withAlpha(20),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),

              // 2) red vertical line at the right edge of the gradient
              Positioned(
                right: -lineWidth / 2,
                top: 0,
                bottom: 0,
                child: Container(
                  width: lineWidth,
                  color: Colors.redAccent.withAlpha(90),
                ),
              ),

              // 3) little ball sitting on top of that line
              Positioned(
                right: -ballRadius,
                top: -ballRadius,
                child: Container(
                  width: ballDiameter,
                  height: ballDiameter,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(90),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withAlpha(90),
                        blurRadius: 0,
                        spreadRadius: 0,
                      )
                    ],
                  ),
                ),
              ),
            ],
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
  final SelectedChannel selectedChannel;
  final SlotsComputedCallback? onSlotsComputed;
  final void Function(EPGSlot slot, int index, int method) onSelectSlot;
  final int rowIndex;
  final void Function(int rowIndex, List<TouchRippleController> controllers)?
      onControllersInitialized;

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
    required this.onSelectSlot,
    required this.rowIndex,
    this.onControllersInitialized,
  });

  @override
  State<ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<ChannelRow>
// with AutomaticKeepAliveClientMixin
{
  //@override
  /// bool get wantKeepAlive => true;
  ///
  ///
  ///
  List<EPGSlot>? cachedSlots;
  DateTime? _cachedTimelineStart;
  DateTime? _cachedTimelineEnd;
  int _lastShowHash = 0;
  late final List<TouchRippleController> _controllers;
  int _hashShows(List<ShowItem> shows) {
    return Object.hashAll(
      shows.map((s) => Object.hash(s.showID, s.showStartTime, s.showEndTime)),
    );
  }

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.visibleSlotCount,
      (_) => TouchRippleController(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControllersInitialized?.call(widget.rowIndex, _controllers);
    });
  }

  @override
  void didUpdateWidget(ChannelRow old) {
    super.didUpdateWidget(old);
    if (old.visibleSlotCount != widget.visibleSlotCount) {
      final newCount = widget.visibleSlotCount;
      final oldCount = _controllers.length;

      if (newCount > oldCount) {
        // add extra controllers
        _controllers.addAll(
          List.generate(newCount - oldCount, (_) => TouchRippleController()),
        );
      } else if (newCount < oldCount) {
        // dispose the extras and trim the list
        for (var i = newCount; i < oldCount; i++) {
          _controllers[i].dispose();
        }
        _controllers.removeRange(newCount, oldCount);
      }

      // re-notify parent in case it caches them
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onControllersInitialized?.call(widget.rowIndex, _controllers);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timelineStart = widget.baseTime;
    final timelineEnd = timelineStart.add(Duration(
      minutes: widget.visibleSlotCount * 30,
    ));

    final shows = widget.channel.showItems;
    final currentHash = _hashShows(shows);

    if (cachedSlots == null ||
        _cachedTimelineStart != timelineStart ||
        _cachedTimelineEnd != timelineEnd ||
        _lastShowHash != currentHash) {
      cachedSlots = generateEPGSlots(shows, timelineStart, timelineEnd);
      _cachedTimelineStart = timelineStart;
      _cachedTimelineEnd = timelineEnd;
      _lastShowHash = currentHash;
      widget.onSlotsComputed?.call(widget.channel.channelID, cachedSlots!);
    }

    bool cutoffApplied = false;

    return Row(
      children: cachedSlots!.asMap().entries.map((entry) {
        final ctrl = _controllers[entry.key];
        final slotIndex = entry.key;
        final slot = entry.value;
        final isSelected =
            widget.selectedChannel.channelID == widget.channel.channelID &&
                widget.selectedChannel.slotIndex ==
                    cachedSlots!.indexOf(entry.value);

        bool startCutOff = false;
        if (!cutoffApplied && entry.value.start.isBefore(DateTime.now())) {
          startCutOff = true;
          cutoffApplied = true;
        }

        return RepaintBoundary(
          child: TouchRipple(
            rippleBorderRadius: BorderRadius.circular(4),
            controller: ctrl,
            onTap: () => widget.onSelectSlot(slot, slotIndex, 1),
            child: SizedBox(
              width: widget.getCalculatedWidth(entry.value.duration),
              height: widget.itemHeight,
              child: entry.value.isPlaceholder
                  ? widget.placeholderBuilder(context, entry.value.start,
                      isSelected, widget.channel.channelID, startCutOff)
                  : widget.showsBuilder(context, entry.value.show!, isSelected,
                      widget.channel.channelID, startCutOff),
            ),
          ),
        );
      }).toList(),
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
        slots.addAll(_createPlaceholderSlots(
            current,
            show.showStartTime,
            widget.channel.channelID,
            widget.channel.serviceProvider,
            widget.channel.epgid));
      }

      // Add show slot
      slots.add(EPGSlot(
        id: show.showID,
        epgid: show.epgid,
        serviceProvider: show.serviceProvider,
        channelID: show.channelID,
        start: show.showStartTime,
        end: show.showEndTime,
        channelName: widget.channel.channelName,
        show: show,
      ));

      current = show.showEndTime;
    }

    // Add remaining placeholders after last show
    if (current.isBefore(timelineEnd)) {
      slots.addAll(_createPlaceholderSlots(
        current,
        timelineEnd,
        widget.channel.channelID,
        widget.channel.serviceProvider,
        widget.channel.epgid,
      ));
    }

    return slots;
  }

  List<EPGSlot> _createPlaceholderSlots(DateTime start, DateTime end,
      String channelID, String serviceProvider, String epgid) {
    List<EPGSlot> placeholders = [];
    DateTime current = start;

    while (current.isBefore(end)) {
      final next = current.add(const Duration(hours: 1));
      final slotEnd = next.isBefore(end) ? next : end;

      placeholders.add(EPGSlot(
        epgid: epgid,
        channelID: channelID,
        serviceProvider: serviceProvider,
        id: 'placeholder_${current.millisecondsSinceEpoch}',
        channelName: widget.channel.channelName,
        start: current,
        end: slotEnd,
        isPlaceholder: true,
      ));

      current = slotEnd;
    }

    return placeholders;
  }
}
