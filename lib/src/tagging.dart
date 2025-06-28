import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'configurations.dart';
import 'taggable.dart';

class FlutterTagging<T extends Taggable> extends StatefulWidget {
  const FlutterTagging({
    super.key,
    required this.initialItems,
    required this.findSuggestions,
    required this.configureChip,
    required this.configureSuggestion,
    this.onChanged,
    this.additionCallback,
    this.onAdded,
    this.onAddTagsButtonClicked,
    this.showAddButton = true,
    this.addButtonColor,
    this.textFieldConfiguration = const TextFieldConfiguration(),
    this.wrapConfiguration = const WrapConfiguration(),
    this.suggestionsBoxConfiguration = const SuggestionsBoxConfiguration(),
    this.marginTop,
    this.enableImmediateSuggestion = false,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.typeAreaVisibility = true,
  });

  final List<T> initialItems;
  final FutureOr<List<T>> Function(String) findSuggestions;
  final ChipConfiguration Function(T) configureChip;
  final SuggestionConfiguration Function(T) configureSuggestion;

  final VoidCallback? onChanged;
  final T Function(String)? additionCallback;
  final FutureOr<T> Function(T)? onAdded;

  final VoidCallback? onAddTagsButtonClicked;
  final bool showAddButton;
  final Color? addButtonColor;

  final TextFieldConfiguration textFieldConfiguration;
  final WrapConfiguration wrapConfiguration;
  final SuggestionsBoxConfiguration suggestionsBoxConfiguration;

  final double? marginTop;
  final bool enableImmediateSuggestion;
  final Duration debounceDuration;
  final bool typeAreaVisibility;

  @override
  State<FlutterTagging<T>> createState() => _FlutterTaggingState<T>();
}

class _FlutterTaggingState<T extends Taggable> extends State<FlutterTagging<T>> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ValueNotifier<List<T>> _selected;      // chips live here

  @override
  void initState() {
    super.initState();
    _controller = widget.textFieldConfiguration.controller ?? TextEditingController();
    _focusNode  = widget.textFieldConfiguration.focusNode    ?? FocusNode();
    _selected   = ValueNotifier<List<T>>(List.of(widget.initialItems));
  }

  // ------------- helpers -------------
  void _add(T item) async {
    if (widget.onAdded != null) item = await widget.onAdded!(item);
    if (_selected.value.contains(item)) return;

    _selected.value = List.of(_selected.value)..add(item);
    widget.onChanged?.call();
  }

  void _remove(T item) {
    _selected.value = List.of(_selected.value)..remove(item);
    widget.onChanged?.call();
  }

  // ------------- build -------------
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.typeAreaVisibility)
          TagInput<T>(
            controller: _controller,
            focusNode : _focusNode,
            selected  : _selected,
            findSuggestions      : widget.findSuggestions,
            configureSuggestion  : widget.configureSuggestion,
            suggestionsBoxConfig : widget.suggestionsBoxConfiguration,
            additionCallback     : widget.additionCallback,
            enableImmediate      : widget.enableImmediateSuggestion,
            debounce             : widget.debounceDuration,
            onItemAccepted       : _add,
          ),

        if (widget.marginTop != null) SizedBox(height: widget.marginTop),

        ValueListenableBuilder<List<T>>(
          valueListenable: _selected,
          builder: (_, tags, __) => Wrap(
            alignment         : widget.wrapConfiguration.alignment,
            crossAxisAlignment: widget.wrapConfiguration.crossAxisAlignment,
            runAlignment      : widget.wrapConfiguration.runAlignment,
            runSpacing        : widget.wrapConfiguration.runSpacing,
            spacing           : widget.wrapConfiguration.spacing,
            direction         : widget.wrapConfiguration.direction,
            textDirection     : widget.wrapConfiguration.textDirection,
            verticalDirection : widget.wrapConfiguration.verticalDirection,
            children: [
              ...tags.map((tag) {
                final conf = widget.configureChip(tag);
                return Chip(
                  key            : ObjectKey(tag),
                  label          : conf.label,
                  avatar         : conf.avatar,
                  backgroundColor: conf.backgroundColor,
                  labelStyle     : conf.labelStyle,
                  deleteIconColor: conf.deleteIconColor,
                  onDeleted      : () => _remove(tag),
                );
              }),
              if (widget.onAddTagsButtonClicked != null &&
                  !widget.typeAreaVisibility &&
                  widget.showAddButton)
                _iconCircleButton(
                  icon : FontAwesomeIcons.plus,
                  tooltip: "Add tags",
                  onTap  : widget.onAddTagsButtonClicked!,
                  color  : widget.addButtonColor ?? Colors.black87,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
  }) {
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

  @override
  void dispose() {
    if (widget.textFieldConfiguration.controller == null) _controller.dispose();
    if (widget.textFieldConfiguration.focusNode    == null) _focusNode.dispose();
    _selected.dispose();
    super.dispose();
  }
}

/// ----------  TagInput – keeps its own state, never rebuilt by chips ----------
class TagInput<T extends Taggable> extends StatelessWidget {
  const TagInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.findSuggestions,
    required this.configureSuggestion,
    required this.suggestionsBoxConfig,
    required this.additionCallback,
    required this.enableImmediate,
    required this.debounce,
    required this.onItemAccepted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<List<T>> selected;

  final FutureOr<List<T>> Function(String) findSuggestions;
  final SuggestionConfiguration Function(T) configureSuggestion;
  final SuggestionsBoxConfiguration suggestionsBoxConfig;

  final T Function(String)? additionCallback;
  final bool enableImmediate;
  final Duration debounce;

  final void Function(T) onItemAccepted;

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<T>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        focusNode : focusNode,
        decoration: const InputDecoration(labelText: 'Select Tags'),
      ),
      suggestionsBoxConfiguration: suggestionsBoxConfig,
      getImmediateSuggestions: enableImmediate,
      debounceDuration: debounce,
      suggestionsCallback: (query) async {
        final items = await findSuggestions(query);
        items.removeWhere(selected.value.contains);
        if (additionCallback != null && query.isNotEmpty) {
          final add = additionCallback!(query);
          if (!items.contains(add) && !selected.value.contains(add)) {
            items.insert(0, add);
          }
        }
        return items;
      },
      itemBuilder: (context, item) {
        final conf = configureSuggestion(item);
        return ListTile(
          key     : ObjectKey(item),
          title   : conf.title,
          subtitle: conf.subtitle,
          leading : conf.leading,
        );
      },
      onSuggestionSelected: (item) {
        onItemAccepted(item);
        controller.clear();
        // keep focus, no need to call requestFocus ➜ no overlay flash
      },
    );
  }
}
