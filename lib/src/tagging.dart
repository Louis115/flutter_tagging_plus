// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'configurations.dart';
import 'taggable.dart';

/// A customizable tagging widget supporting suggestions and chip display.
class FlutterTagging<T extends Taggable> extends StatefulWidget {
  final VoidCallback? onChanged;
  final VoidCallback? onAddTagsButtonClicked;
  final Color? addButtonColor;
  final bool showAddButton;
  final TextFieldConfiguration textFieldConfiguration;
  final FutureOr<List<T>> Function(String) findSuggestions;
  final double? marginTop;
  final bool typeAreaVisibility;
  final ChipConfiguration Function(T) configureChip;
  final SuggestionConfiguration Function(T) configureSuggestion;
  final WrapConfiguration wrapConfiguration;
  final T Function(String)? additionCallback;
  final FutureOr<T> Function(T)? onAdded;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final Widget Function(BuildContext, Object?)? errorBuilder;
  final Widget Function(BuildContext, Widget, AnimationController?)? transitionBuilder;
  final SuggestionsBoxDecoration suggestionsBoxDecoration;
  final double suggestionsBoxVerticalOffset;
  final bool autoFlipDirection;
  final AxisDirection direction;
  final bool hideSuggestionsOnKeyboardHide;
  final bool keepSuggestionsOnLoading;
  final bool keepSuggestionsOnSuggestionSelected;
  final Duration animationDuration;
  final double animationStart;
  final bool hideOnLoading;
  final bool hideOnEmpty;
  final bool hideOnError;
  final Duration debounceDuration;
  final bool enableImmediateSuggestion;
  final List<T> initialItems;

  FlutterTagging({
    Key? key,
    required this.initialItems,
    required this.findSuggestions,
    required this.configureChip,
    required this.configureSuggestion,
    this.marginTop,
    this.typeAreaVisibility = true,
    this.enableImmediateSuggestion = false,
    this.onChanged,
    this.additionCallback,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.wrapConfiguration = const WrapConfiguration(),
    this.textFieldConfiguration = const TextFieldConfiguration(),
    this.suggestionsBoxDecoration = const SuggestionsBoxDecoration(),
    this.suggestionsBoxVerticalOffset = 0.0,
    this.autoFlipDirection = true,
    this.direction = AxisDirection.down,
    this.hideSuggestionsOnKeyboardHide = true,
    this.keepSuggestionsOnLoading = false,
    this.keepSuggestionsOnSuggestionSelected = false,
    this.transitionBuilder,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.hideOnEmpty = false,
    this.hideOnError = false,
    this.hideOnLoading = false,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationStart = 0.25,
    this.onAdded,
    this.onAddTagsButtonClicked,
    this.addButtonColor,
    this.showAddButton = true,
  }) : super(key: key);

  @override
  _FlutterTaggingState<T> createState() => _FlutterTaggingState<T>();
}

class _FlutterTaggingState<T extends Taggable> extends State<FlutterTagging<T>> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  T? _additionItem;

  @override
  void initState() {
    super.initState();
    _textController = widget.textFieldConfiguration.controller ?? TextEditingController();
    _focusNode = widget.textFieldConfiguration.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.typeAreaVisibility)
          TypeAheadField<T>(
            getImmediateSuggestions: widget.enableImmediateSuggestion,
            debounceDuration: widget.debounceDuration,
            hideOnEmpty: widget.hideOnEmpty,
            hideOnError: widget.hideOnError,
            hideOnLoading: widget.hideOnLoading,
            animationStart: widget.animationStart,
            animationDuration: widget.animationDuration,
            suggestionsBoxDecoration: widget.suggestionsBoxDecoration,
            suggestionsBoxVerticalOffset: widget.suggestionsBoxVerticalOffset,
            autoFlipDirection: widget.autoFlipDirection,
            direction: widget.direction,
            hideSuggestionsOnKeyboardHide: widget.hideSuggestionsOnKeyboardHide,
            keepSuggestionsOnLoading: widget.keepSuggestionsOnLoading,
            keepSuggestionsOnSuggestionSelected: widget.keepSuggestionsOnSuggestionSelected,
            transitionBuilder: widget.transitionBuilder,
            loadingBuilder: (context) => widget.loadingBuilder?.call(context) ?? const SizedBox(height: 3.0, child: LinearProgressIndicator()),
            noItemsFoundBuilder: widget.emptyBuilder,
            errorBuilder: widget.errorBuilder,
            textFieldConfiguration: widget.textFieldConfiguration.copyWith(
              focusNode: _focusNode,
              controller: _textController,
            ),
            suggestionsCallback: (query) async {
              final suggestions = await widget.findSuggestions(query);
              suggestions.removeWhere(widget.initialItems.contains);
              if (widget.additionCallback != null && query.isNotEmpty) {
                final additionItem = widget.additionCallback!(query);
                if (!suggestions.contains(additionItem) && !widget.initialItems.contains(additionItem)) {
                  _additionItem = additionItem;
                  suggestions.insert(0, additionItem);
                } else {
                  _additionItem = null;
                }
              }
              return suggestions;
            },
            itemBuilder: (context, item) {
              final conf = widget.configureSuggestion(item);
              return ListTile(
                key: ObjectKey(item),
                title: conf.title,
                subtitle: conf.subtitle,
                leading: conf.leading,
                trailing: InkWell(
                  splashColor: conf.splashColor ?? Theme.of(context).splashColor,
                  borderRadius: conf.splashRadius,
                  onTap: () async {
                    final selected = widget.onAdded != null ? await widget.onAdded!(item) : item;
                    widget.initialItems.add(selected);
                    setState(() {});
                    widget.onChanged?.call();
                    _textController.clear();
                    _refocus();
                  },
                  child: conf.additionWidget != null && _additionItem == item ? conf.additionWidget! : const SizedBox(width: 0),
                ),
              );
            },
            onSuggestionSelected: (suggestion) {
              if (_additionItem != suggestion) {
                widget.initialItems.add(suggestion);
                setState(() {});
                widget.onChanged?.call();
              }
              _textController.clear();
              _refocus();
            },
          ),
        SizedBox(height: widget.marginTop),
        Wrap(
          alignment: widget.wrapConfiguration.alignment,
          crossAxisAlignment: widget.wrapConfiguration.crossAxisAlignment,
          runAlignment: widget.wrapConfiguration.runAlignment,
          runSpacing: widget.wrapConfiguration.runSpacing,
          spacing: widget.wrapConfiguration.spacing,
          direction: widget.wrapConfiguration.direction,
          textDirection: widget.wrapConfiguration.textDirection,
          verticalDirection: widget.wrapConfiguration.verticalDirection,
          children: [
            ...widget.initialItems.map((item) {
              final conf = widget.configureChip(item);
              return Chip(
                label: conf.label,
                shape: conf.shape,
                avatar: conf.avatar,
                backgroundColor: conf.backgroundColor,
                clipBehavior: conf.clipBehavior,
                deleteButtonTooltipMessage: conf.deleteButtonTooltipMessage,
                deleteIcon: conf.deleteIcon,
                deleteIconColor: conf.deleteIconColor,
                elevation: conf.elevation,
                labelPadding: conf.labelPadding,
                labelStyle: conf.labelStyle,
                materialTapTargetSize: conf.materialTapTargetSize,
                padding: conf.padding,
                shadowColor: conf.shadowColor,
                onDeleted: () {
                  widget.initialItems.remove(item);
                  setState(() {});
                  widget.onChanged?.call();
                  _refocus();
                },
              );
            }).toList(),
            if (widget.onAddTagsButtonClicked != null && !widget.typeAreaVisibility && widget.showAddButton)
              _iconCircleButton(
                icon: FontAwesomeIcons.plus,
                tooltip: "Add tags",
                onTap: widget.onAddTagsButtonClicked!,
                color: widget.addButtonColor ?? Colors.black87,
              ),
          ],
        ),
      ],
    );
  }

  void _refocus() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Widget _iconCircleButton({required IconData icon, required String tooltip, required VoidCallback onTap, required Color color}) {
    return Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: FaIcon(icon, size: 12, color: Colors.white),
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}
