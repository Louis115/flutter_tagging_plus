// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.17                          // ✓ compiles on old SDKs – remove if you’re already ≥ 2.17

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'configurations.dart';
import 'taggable.dart';

///
/// A re-implementation of the original FlutterTagging that works with
/// flutter_typeahead ≥ 4.8.0 **and** Dart SDK < 2.17 (no super-parameters).
///
class FlutterTagging<T extends Taggable> extends StatefulWidget {
  /// Called every time the value changes (item add / remove).
  final VoidCallback? onChanged;

  /// Called when the trailing “add tags” (+) circle is tapped.
  final VoidCallback? onAddTagsButtonClicked;

  final Color? addButtonColor;
  final bool showAddButton;

  /// Text-field configuration
  final TextFieldConfiguration textFieldConfiguration;

  /// Your async / sync search callback.
  final FutureOr<List<T>> Function(String) findSuggestions;

  /// Vertical gap between field & chips
  final double? marginTop;

  /// Whether the text field itself is visible
  final bool typeAreaVisibility;

  /// Chip & suggestion configuration callbacks
  final ChipConfiguration Function(T) configureChip;
  final SuggestionConfiguration Function(T) configureSuggestion;

  /// Chip-wrap layout
  final WrapConfiguration wrapConfiguration;

  /// Optional “create new” handler
  final T Function(String)? additionCallback;
  final FutureOr<T> Function(T)? onAdded;

  /// Builders for loading / empty / error UI
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final Widget Function(BuildContext, Object?)? errorBuilder;

  /// Custom transition for suggestions box
  final Widget Function(BuildContext, Widget, AnimationController?)?
      transitionBuilder;

  /// ↓ Everything below mirrors the old API – we keep it for source-compat.
  final SuggestionsBoxConfiguration suggestionsBoxConfiguration;

  final Duration animationDuration;
  final double   animationStart;

  final bool hideOnLoading;
  final bool hideOnEmpty;
  final bool hideOnError;

  final Duration debounceDuration;
  final bool enableImmediateSuggestion;

  /// Initially-selected chips
  final List<T> initialItems;

  // ──────────────────────────────────────────────────────────────────
  const FlutterTagging({
    Key? key,                                 // ← old-style key
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
    this.suggestionsBoxConfiguration = const SuggestionsBoxConfiguration(),
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
  }) : super(key: key);                       // ← old-style super call
  // ──────────────────────────────────────────────────────────────────

  @override
  _FlutterTaggingState<T> createState() => _FlutterTaggingState<T>();
}

// ══════════════════════════════════════════════════════════════════
//                           STATE
// ══════════════════════════════════════════════════════════════════
class _FlutterTaggingState<T extends Taggable> extends State<FlutterTagging<T>> {
  late final TextEditingController _textController;
  late final FocusNode             _focusNode;
  T? _additionItem;

  @override
  void initState() {
    super.initState();
    _textController = widget.textFieldConfiguration.controller ?? TextEditingController();
    _focusNode      = widget.textFieldConfiguration.focusNode    ?? FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    // _focusNode is owned by caller when they pass one – don’t dispose here.
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────
  // Helper: reopen overlay after a tiny delay
  void _requestFieldFocus() async {
    _focusNode.unfocus();
    await Future.delayed(const Duration(milliseconds: 1));
    FocusScope.of(context).requestFocus(_focusNode);
  }
  // ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.typeAreaVisibility)
          TypeAheadField<T>(
            // Behaviour
            getImmediateSuggestions: widget.enableImmediateSuggestion,
            debounceDuration       : widget.debounceDuration,
            hideOnEmpty            : widget.hideOnEmpty,
            hideOnError            : widget.hideOnError,
            hideOnLoading          : widget.hideOnLoading,
            // Animation
            animationDuration      : widget.animationDuration,
            animationStart         : widget.animationStart,
            // Suggestions-box params (expanded from old config)
            direction                      : widget.suggestionsBoxConfiguration.direction,
            autoFlipDirection              : widget.suggestionsBoxConfiguration.autoFlipDirection,
            suggestionsBoxVerticalOffset   : widget.suggestionsBoxConfiguration.suggestionsBoxVerticalOffset,
            suggestionsBoxController       : widget.suggestionsBoxConfiguration.suggestionsBoxController,
            suggestionsBoxDecoration       : widget.suggestionsBoxConfiguration.suggestionsBoxDecoration,
            hideSuggestionsOnKeyboardHide  : widget.suggestionsBoxConfiguration.hideSuggestionsOnKeyboardHide,
            keepSuggestionsOnLoading       : widget.suggestionsBoxConfiguration.keepSuggestionsOnLoading,
            keepSuggestionsOnSuggestionSelected
                                           : widget.suggestionsBoxConfiguration.keepSuggestionsOnSuggestionSelected,
            // Misc.
            transitionBuilder : widget.transitionBuilder,
            loadingBuilder    : (c) => widget.loadingBuilder?.call(c) ?? const SizedBox(
                                        height: 3, child: LinearProgressIndicator()),
            noItemsFoundBuilder: widget.emptyBuilder,
            errorBuilder       : widget.errorBuilder,
            textFieldConfiguration: widget.textFieldConfiguration.copyWith(
              controller: _textController,
              focusNode : _focusNode,
              enabled   : widget.textFieldConfiguration.enabled,
            ),
            // Suggestions logic
            suggestionsCallback: (query) async {
              final list = await widget.findSuggestions(query);
              list.removeWhere(widget.initialItems.contains);
              if (widget.additionCallback != null && query.isNotEmpty) {
                final addItem = widget.additionCallback!(query);
                if (!list.contains(addItem) && !widget.initialItems.contains(addItem)) {
                  _additionItem = addItem;
                  list.insert(0, addItem);
                } else {
                  _additionItem = null;
                }
              }
              return list;
            },
            itemBuilder: (context, item) {
              final conf = widget.configureSuggestion(item);
              return ListTile(
                key   : ObjectKey(item),
                title : conf.title,
                subtitle: conf.subtitle,
                leading : conf.leading,
                trailing: InkWell(
                  splashColor : conf.splashColor ?? Theme.of(context).splashColor,
                  borderRadius: conf.splashRadius,
                  onTap: () async {
                    if (widget.onAdded != null) {
                      widget.initialItems.add(await widget.onAdded!(item));
                    } else {
                      widget.initialItems.add(item);
                    }
                    setState(() {});
                    widget.onChanged?.call();
                    _textController.clear();
                    _requestFieldFocus();                     // ← reopen
                  },
                  child: _additionItem == item && conf.additionWidget != null
                         ? conf.additionWidget!
                         : const SizedBox(width: 0),
                ),
              );
            },
            onSuggestionSelected: (sel) {
              if (_additionItem != sel) {
                widget.initialItems.add(sel);
                setState(() {});
                widget.onChanged?.call();
              }
              _textController.clear();
              _requestFieldFocus();                         // ← reopen
            },
          ),

        if (widget.marginTop != null) SizedBox(height: widget.marginTop),

        Wrap(
          direction         : widget.wrapConfiguration.direction,
          alignment         : widget.wrapConfiguration.alignment,
          crossAxisAlignment: widget.wrapConfiguration.crossAxisAlignment,
          runAlignment      : widget.wrapConfiguration.runAlignment,
          spacing           : widget.wrapConfiguration.spacing,
          runSpacing        : widget.wrapConfiguration.runSpacing,
          textDirection     : widget.wrapConfiguration.textDirection,
          verticalDirection : widget.wrapConfiguration.verticalDirection,
          children: [
            ...widget.initialItems.map((item) {
              final conf = widget.configureChip(item);
              return Chip(
                label                      : conf.label,
                avatar                     : conf.avatar,
                shape                      : conf.shape,
                clipBehavior               : conf.clipBehavior,
                backgroundColor            : conf.backgroundColor,
                padding                    : conf.padding,
                labelPadding               : conf.labelPadding,
                labelStyle                 : conf.labelStyle,
                materialTapTargetSize      : conf.materialTapTargetSize,
                elevation                  : conf.elevation,
                shadowColor                : conf.shadowColor,
                deleteIcon                 : conf.deleteIcon,
                deleteIconColor            : conf.deleteIconColor,
                deleteButtonTooltipMessage : conf.deleteButtonTooltipMessage,
                onDeleted: () {
                  widget.initialItems.remove(item);
                  setState(() {});
                  widget.onChanged?.call();
                  _requestFieldFocus();                       // ← reopen
                },
              );
            }),
            if (widget.onAddTagsButtonClicked != null &&
                !widget.typeAreaVisibility &&
                widget.showAddButton)
              _circleButton(
                icon : FontAwesomeIcons.plus,
                color: widget.addButtonColor ?? Colors.black87,
                tooltip: 'Add tags',
                onTap : widget.onAddTagsButtonClicked!,
              ),
          ],
        ),
      ],
    );
  }

  // Helper for the (+) circle
  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required String tooltip,
  }) {
    return Container(
      width: 26, height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        icon     : FaIcon(icon, size: 12, color: Colors.white),
        tooltip  : tooltip,
        onPressed: onTap,
        padding  : EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}
