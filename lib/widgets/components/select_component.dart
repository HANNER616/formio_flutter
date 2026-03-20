/// A Flutter widget that renders a dropdown menu based on a Form.io "select" component.
///
/// Supports label, placeholder, required validation, default value,
/// dynamic value lists from static JSON, and searchable dropdown
/// when widget is set to "choicesjs" or searchEnabled is true.

import 'package:flutter/material.dart';

import '../../models/component.dart';
import '../shared/field_label.dart';
import '../shared/input_decoration_utils.dart';

class SelectComponent extends StatelessWidget {
  /// The Form.io component definition.
  final ComponentModel component;

  /// The currently selected value.
  final dynamic value;

  /// Callback triggered when the user selects an option.
  final ValueChanged<dynamic> onChanged;

  /// Optional field number to display before the label
  final int? fieldNumber;

  const SelectComponent({
    Key? key,
    required this.component,
    required this.value,
    required this.onChanged,
    this.fieldNumber,
  }) : super(key: key);

  /// Whether the field is marked as required.
  bool get _isRequired => component.required;

  /// Placeholder shown when no value is selected.
  String? get _placeholder => component.raw['placeholder'];

  /// Retrieves the description text if available in the raw JSON.
  String? get _description => component.raw['description'];

  /// Retrieves the tooltip text if available in the raw JSON.
  String? get _tooltip => component.raw['tooltip'];

  /// Whether this select should use a searchable dropdown.
  bool get _isSearchable {
    final widget = component.raw['widget']?.toString().toLowerCase();
    final searchEnabled = component.raw['searchEnabled'];
    return widget == 'choicesjs' || searchEnabled == true;
  }

  /// Returns the list of available options, supporting both
  /// `data.values` (dataSrc: "values") and `data.json` (dataSrc: "json").
  List<Map<String, dynamic>> get _values {
    final data = component.raw['data'];
    if (data == null) return [];

    final dataSrc = component.raw['dataSrc']?.toString() ?? 'values';

    // For JSON data source, read from data.json
    if (dataSrc == 'json') {
      final jsonData = data['json'];
      if (jsonData is List && jsonData.isNotEmpty) {
        return List<Map<String, dynamic>>.from(jsonData);
      }
    }

    // Default: read from data.values
    final values = data['values'];
    if (values is List && values.isNotEmpty) {
      return List<Map<String, dynamic>>.from(values);
    }

    return [];
  }

  /// Finds the label for the currently selected value.
  String? _selectedLabel() {
    if (value == null) return null;
    for (final option in _values) {
      if (option['value']?.toString() == value.toString()) {
        return option['label']?.toString();
      }
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value.toString().isNotEmpty;

    return FormField<dynamic>(
      initialValue: value,
      validator: (_) {
        if (_isRequired && (value == null || value.toString().isEmpty)) {
          return '${component.label} is required.';
        }
        return null;
      },
      builder: (FormFieldState<dynamic> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FieldLabel(
              label: component.label,
              isRequired: _isRequired,
              showClearButton: true,
              hasContent: hasValue,
              onClear: () {
                onChanged(null);
                field.didChange(null);
              },
              number: fieldNumber,
              description: _description,
              tooltip: _tooltip,
            ),
            if (_isSearchable)
              _SearchableSelect(
                componentKey: component.key,
                placeholder: _placeholder ?? 'Select an option...',
                values: _values,
                value: value,
                selectedLabel: _selectedLabel(),
                errorText: field.errorText,
                onChanged: (newValue) {
                  onChanged(newValue);
                  field.didChange(newValue);
                },
              )
            else
              _PlainDropdown(
                componentKey: component.key,
                placeholder: _placeholder ?? 'Select an option...',
                values: _values,
                value: value,
                errorText: field.errorText,
                onChanged: (newValue) {
                  onChanged(newValue);
                  field.didChange(newValue);
                },
              ),
          ],
        );
      },
    );
  }
}

/// Standard dropdown without search.
class _PlainDropdown extends StatelessWidget {
  final String componentKey;
  final String placeholder;
  final List<Map<String, dynamic>> values;
  final dynamic value;
  final String? errorText;
  final ValueChanged<dynamic> onChanged;

  const _PlainDropdown({
    required this.componentKey,
    required this.placeholder,
    required this.values,
    required this.value,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      key: ValueKey(componentKey),
      decoration: InputDecorationUtils.createDropdownDecoration(
        context,
        hintText: placeholder,
        errorText: errorText,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          isExpanded: true,
          isDense: true,
          hint: Text(
            placeholder,
            style: TextStyle(
              color: Theme.of(context).hintColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          value: value,
          onChanged: onChanged,
          icon: const SizedBox.shrink(),
          items: values.map((option) {
            final label = option['label']?.toString() ?? '';
            final val = option['value'];
            return DropdownMenuItem<dynamic>(
              value: val,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Searchable select that opens a dialog with a search field.
class _SearchableSelect extends StatelessWidget {
  final String componentKey;
  final String placeholder;
  final List<Map<String, dynamic>> values;
  final dynamic value;
  final String? selectedLabel;
  final String? errorText;
  final ValueChanged<dynamic> onChanged;

  const _SearchableSelect({
    required this.componentKey,
    required this.placeholder,
    required this.values,
    required this.value,
    required this.selectedLabel,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value.toString().isNotEmpty;

    return InkWell(
      onTap: () => _showSearchDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        key: ValueKey(componentKey),
        decoration: InputDecorationUtils.createDropdownDecoration(
          context,
          hintText: placeholder,
          errorText: errorText,
        ),
        child: Text(
          hasValue ? (selectedLabel ?? value.toString()) : placeholder,
          style: hasValue
              ? Theme.of(context).textTheme.bodyMedium
              : TextStyle(
                  color: Theme.of(context).hintColor.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => _SearchDialog(
        title: placeholder,
        values: values,
        selectedValue: value,
      ),
    );

    // null means dialog was dismissed without selection — don't change value
    if (result != null) {
      // Use a sentinel to distinguish "cleared" from "dismissed"
      if (result == _SearchDialog._clearSentinel) {
        onChanged(null);
      } else {
        onChanged(result);
      }
    }
  }
}

/// Full-screen-ish dialog with search field and filterable option list.
class _SearchDialog extends StatefulWidget {
  static const _clearSentinel = '__clear__';

  final String title;
  final List<Map<String, dynamic>> values;
  final dynamic selectedValue;

  const _SearchDialog({
    required this.title,
    required this.values,
    required this.selectedValue,
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late TextEditingController _searchController;
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = widget.values;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.values;
      } else {
        final lower = query.toLowerCase();
        _filtered = widget.values.where((option) {
          final label = option['label']?.toString().toLowerCase() ?? '';
          return label.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Options list
          Flexible(
            child: _filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No results found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final option = _filtered[index];
                      final label = option['label']?.toString() ?? '';
                      final val = option['value'];
                      final isSelected =
                          widget.selectedValue?.toString() == val?.toString();

                      return ListTile(
                        title: Text(
                          label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20)
                            : null,
                        onTap: () => Navigator.of(context).pop(val),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
