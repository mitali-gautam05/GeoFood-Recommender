import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class CityAutocompleteField extends StatefulWidget {
  final String initialValue;
  final TextEditingController? controller;   // ← optional external controller
  final ValueChanged<String> onCitySelected;
  final String hintText;
  final InputDecoration? decoration;

  const CityAutocompleteField({
    super.key,
    this.initialValue = '',
    this.controller,
    required this.onCitySelected,
    this.hintText = 'Search city…',
    this.decoration,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  late final TextEditingController _controller;
  bool _ownsController = false;   // track if WE created it (so we dispose it)

  final FocusNode _focus = FocusNode();
  final LayerLink _layerLink = LayerLink();

  Timer? _debounce;
  List<String> _suggestions = [];
  OverlayEntry? _overlay;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      if (widget.initialValue.isNotEmpty) {
        _controller.text = widget.initialValue;
      }
    } else {
      _controller = TextEditingController(text: widget.initialValue);
      _ownsController = true;
    }
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_ownsController) _controller.dispose();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _removeOverlay();
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(value));
  }

  Future<void> _fetch(String query) async {
    try {
      final results = await ApiClient.searchCities(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
      if (results.isNotEmpty && _focus.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(String city) {
    _controller.text = city;
    _removeOverlay();
    _focus.unfocus();
    widget.onCitySelected(city);
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (_) => _buildDropdown());
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildDropdown() {
    return Positioned(
      width: 0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final city = _suggestions[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _select(city),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.location_city_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(city,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: _onChanged,
        onSubmitted: (v) {
          if (_suggestions.length == 1) {
            _select(_suggestions.first);
          } else if (_suggestions.isEmpty) {
            // Accept whatever was typed
            widget.onCitySelected(v.trim());
          }
        },
        decoration: (widget.decoration ??
                InputDecoration(hintText: widget.hintText))
            .copyWith(
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _removeOverlay();
                        setState(() => _suggestions = []);
                      },
                    )
                  : const Icon(Icons.search, size: 20),
        ),
      ),
    );
  }
}