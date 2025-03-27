import 'dart:core';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tv_channel_widget/src/model/tv_channle.dart';
import 'package:tv_channel_widget/src/utils/utils.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

/// A callback function that takes in a `BuildContext` and an `int` index and returns a `Widget`.
typedef ItemBuilder = Widget Function(BuildContext context, int index);

/// A callback function that takes in a `BuildContext` and a `ShowItem` object and returns a `Widget`.
typedef ShowBuilder = Widget Function(BuildContext context, ShowItem show);

/// Renders a Channel widget with there shows.
class ChannelWidget extends StatefulWidget {
  /// Creates a new `ChannelWidget`.
  ///
  /// The [channelShows] parameter determines the appearance of the [ShowList]. It ensures that all shows
  /// are displayed in a particular order.
  /// The [channelBuilder] parameter specifies a widget to display for each header item.
  /// The [showsBuilder] parameter specifies a widget to display for each show item.
  /// The [showTime] parameter determines whether to show the time above the widget. Defaults to `false`.
  /// The [moveToCurrentTime] parameter determines whether to move the widget to the current date and time. Defaults to `false`.
  /// The [channelWidth] parameter specifies the width of the header. Defaults to `150.0`.
  /// The [itemHeight] parameter specifies the height of each item. Defaults to `150.0`.
  /// The [verticalPadding] parameter specifies the vertical padding. Defaults to `10`.
  /// The [timerRowHeight] parameter specifies the height of the timer row. Defaults to `20`.
  /// The [disableHorizontalScroll] parameter determines the scroll behavior for horizontal scrolling. Defaults to `false`.
  ChannelWidget({
    Key? key,
    required this.channelShows,
    required this.channelBuilder,
    required this.showsBuilder,
    this.showTime = false,
    this.moveToCurrentTime = false,
    this.channelWidth = 150.0,
    this.itemHeight = 100.0,
    this.verticalPadding = 10,
    this.timerRowHeight = 20,
    this.disableHorizontalScroll = false,
  }) : super(key: key) {
    // Assert that there are no conflicting show times in the channelShows list
    final conflictingShows = _getConflictingShows(channelShows);
    assert(conflictingShows.isEmpty,
        'Conflicting show times found: $conflictingShows');
    final missingTimesShows = _findMissingTime(channelShows);
    assert(missingTimesShows == null,
        'Missing show times found:  $missingTimesShows');
  }

  /// Determines how the [ChannelWidget] should look.
  final List<TvChannel> channelShows;

  /// Determines To show time above the widget.
  /// Defaults to false
  final bool showTime;

  /// Move widget to current date and time.
  /// Defaults to false
  final bool moveToCurrentTime;

  /// Determines To width of header.
  /// Defaults to 150
  final double channelWidth;

  /// Display a widget for header item
  final ItemBuilder channelBuilder;

  /// Display a widget for shows item
  final ShowBuilder showsBuilder;

  /// Determines vertical padding
  final double verticalPadding;

  /// Determines height for timer row
  /// Defaults to 20 px
  final double timerRowHeight;

  /// Determines height for timer row
  /// Defaults to 150 px
  final double itemHeight;

  /// Determines scroll behavior for horizontal scroll
  /// Defaults to false
  final bool disableHorizontalScroll;

  @override
  State<ChannelWidget> createState() => _ChannelWidgetState();

  /// Finds all show items that have conflicting start and end times in the given list of TV channels.
  ///
  /// A show item is considered to be in conflict if it overlaps with another show item in the same TV channel.
  /// This can include show items that start or end at the same time, or show items that are completely contained within
  /// another show item.
  ///
  /// Returns a list of all show items that have conflicting start and end times.
  List<ShowItem> _getConflictingShows(List<TvChannel> showsList) {
    List<ShowItem> conflictingShows = [];
    // Create a map to store the show times for each channel
    Map<TvChannel, List<ShowItem>> channelShowMap = {};
    for (var channel in showsList) {
      channelShowMap[channel] = channel.showItems;
    }

    // Iterate over the map and check for conflicting show times
    mainLoop:
    for (var channel in channelShowMap.keys) {
      for (int i = 0; i < channelShowMap[channel]!.length; i++) {
        ShowItem show = channelShowMap[channel]![i];
        for (int j = i + 1; j < channelShowMap[channel]!.length; j++) {
          ShowItem comparisonShow = channelShowMap[channel]![j];
          // Check if the show and comparison show overlap
          if ((show.showStartTime.isAfter(comparisonShow.showStartTime) &&
                  show.showStartTime.isBefore(comparisonShow.showEndTime)) ||
              (show.showEndTime.isAfter(comparisonShow.showStartTime) &&
                  show.showEndTime.isBefore(comparisonShow.showEndTime)) ||
              (show.showStartTime.isBefore(comparisonShow.showStartTime) &&
                  show.showEndTime.isAfter(comparisonShow.showEndTime))) {
            conflictingShows.add(show);
            conflictingShows.add(comparisonShow);
            break mainLoop;
          }
        }
      }
    }
    return conflictingShows;
  }

  String? _findMissingTime(List<TvChannel> showsList) {
    // List<Duration> missingTime = [];

    // Loop through each TV channel
    parentLoop:
    for (TvChannel channel in showsList) {
      // Get the list of shows for the current TV channel
      List<ShowItem> shows = channel.showItems;

      // Sort the list of shows by start time
      shows.sort((a, b) => a.showStartTime.compareTo(b.showStartTime));

      // Get the start and end times of the first show
      DateTime startTime = shows[0].showStartTime;
      DateTime endTime = shows[0].showEndTime;

      // Loop through the rest of the shows in the list
      for (int i = 1; i < shows.length; i++) {
        // Get the start and end times of the current show
        DateTime showStartTime = shows[i].showStartTime;
        DateTime showEndTime = shows[i].showEndTime;

        // If the start time of the current show is after the end time of the previous show,
        // add the duration between the two times to the missing time list
        if (showStartTime.isAfter(endTime)) {
          return '''Missing time found in ${channel.channelName} Channel for ${showStartTime.difference(endTime).inMinutes.abs()} Min
            Please check your list and verify start and end time of ShowItem.
            Ex
            Show one Start time is 8 PM and end time is 9 PM'
            Show two start time Should start with 9 PM';
          ''';
        }

        // Update the start and end times for the next iteration
        startTime = showStartTime;
        endTime = showEndTime;
      }
    }

    return null;
  }
}

class _ChannelWidgetState extends State<ChannelWidget> {
  late final LinkedScrollControllerGroup _horizontalScrollGroup;
  late final ScrollController _timelineController;
  late final ScrollController _showsController;

  final _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _horizontalScrollGroup = LinkedScrollControllerGroup();
    _timelineController = _horizontalScrollGroup.addAndGet();
    _showsController = _horizontalScrollGroup.addAndGet();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.moveToCurrentTime) {
        _scrollToCurrentTime();
      }
    });
  }

  @override
  void dispose() {
    _timelineController.dispose();
    _showsController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fixed Header Row (Channels + Timeline)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channels Title
            SizedBox(
              width: widget.channelWidth,
              child: const Text(
                'Channels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            // Timeline with synchronized horizontal scroll
            Expanded(
              child: SizedBox(
                height: widget.timerRowHeight,
                child: SingleChildScrollView(
                  controller: _timelineController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: buildTimerRow(),
                ),
              ),
            ),
          ],
        ),
        // Content Area (Channels + Shows)
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel List
                SizedBox(
                  width: widget.channelWidth,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.channelShows.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: widget.verticalPadding),
                        child: SizedBox(
                          height: widget.itemHeight,
                          child: widget.channelBuilder(context, index),
                        ),
                      );
                    },
                  ),
                ),
                // Shows Content with synchronized horizontal scroll
                Expanded(
                  child: SingleChildScrollView(
                    controller: _showsController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      children: widget.channelShows
                          .map((channel) => buildChannelRows(channel))
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Row buildChannelRows(TvChannel channels) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buildShows(channels.showItems),
    );
  }

  List<Widget> buildShows(List<ShowItem> shows) {
    return List.generate(shows.length, (index) {
      final showLengthInMin = _getShowsLengthInMin(shows[index]);
      return Padding(
        padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
        child: SizedBox(
          height: widget.itemHeight,
          width: getCalculatedWidth(showLengthInMin),
          child: widget.showsBuilder(context, shows[index]),
        ),
      );
    });
  }

  Widget buildTimerRow() {
    final totalWidth = _calculateTotalTimelineWidth();
    return SizedBox(
      width: totalWidth,
      child: Row(
        children: _getTimeSlots().map((time) {
          return SizedBox(
            width: getCalculatedWidth(30),
            child: Text(
              time,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
      ),
    );
  }

  double getCalculatedWidth(int showMins) {
    final screenWidget = MediaQuery.of(context).size;
    final restWidth = screenWidget.width * 0.8;
    final perMinWidth = restWidth / 60;
    return (perMinWidth * showMins);
  }

  double _calculateTotalTimelineWidth() {
    final timeSlots = _getTimeSlots();
    return timeSlots.length * getCalculatedWidth(30);
  }

  int _getShowsLengthInMin(ShowItem showItem) {
    return Utils.getDateDiffInMin(showItem.showStartTime, showItem.showEndTime);
  }

  List<String> _getTimeSlots() {
    final timeFormat = DateFormat('HH:mm');
    final timeSlots = <String>[];
    var time = DateTime.now().subtract(Duration(
        hours: DateTime.now().hour,
        minutes: DateTime.now().minute,
        seconds: DateTime.now().second));

    for (var i = 1; i < 48; i++) {
      timeSlots.add(timeFormat.format(time));
      time = time.add(const Duration(minutes: 30));
    }
    return timeSlots;
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final minutesSinceMidnight = now.difference(midnight).inMinutes;

    final scrollPosition = getCalculatedWidth(minutesSinceMidnight);

    _timelineController.jumpTo(scrollPosition);
    _showsController.jumpTo(scrollPosition);
  }
}
