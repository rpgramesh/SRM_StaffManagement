import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneNumberKeypad extends StatefulWidget {
  const PhoneNumberKeypad({
    super.key,
    required this.digits,
    required this.onChanged,
    this.displayText,
    this.digitCountText,
    this.statusColor,
    this.errorText,
    this.countryCode = '+91',
    this.maxDigits = 10,
    this.enabled = true,
  });

  final String digits;
  final ValueChanged<String> onChanged;
  final String? displayText;
  final String? digitCountText;
  final Color? statusColor;
  final String? errorText;
  final String countryCode;
  final int maxDigits;
  final bool enabled;

  @override
  State<PhoneNumberKeypad> createState() => _PhoneNumberKeypadState();
}

class _PhoneNumberKeypadState extends State<PhoneNumberKeypad> {
  static const Duration _debounceDuration = Duration(milliseconds: 100);
  static const Duration _keyboardFlashDuration = Duration(milliseconds: 150);

  final FocusNode _focusNode = FocusNode(debugLabel: 'phone-number-keypad');
  final Set<String> _hoveredKeys = <String>{};
  final Set<String> _pressedKeys = <String>{};
  final Set<String> _keyboardHighlightedKeys = <String>{};
  final Map<String, Timer> _highlightTimers = <String, Timer>{};

  Timer? _debounceTimer;
  bool _inputLocked = false;

  static const List<_KeypadAction> _actions = <_KeypadAction>[
    _KeypadAction(id: '1', label: '1'),
    _KeypadAction(id: '2', label: '2'),
    _KeypadAction(id: '3', label: '3'),
    _KeypadAction(id: '4', label: '4'),
    _KeypadAction(id: '5', label: '5'),
    _KeypadAction(id: '6', label: '6'),
    _KeypadAction(id: '7', label: '7'),
    _KeypadAction(id: '8', label: '8'),
    _KeypadAction(id: '9', label: '9'),
    _KeypadAction(id: 'clear', label: 'CLR'),
    _KeypadAction(id: '0', label: '0'),
    _KeypadAction(
        id: 'backspace', label: 'DEL', icon: Icons.backspace_outlined),
  ];

  static final Map<LogicalKeyboardKey, String> _keyboardMap =
      <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
    LogicalKeyboardKey.backspace: 'backspace',
    LogicalKeyboardKey.delete: 'backspace',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    _debounceTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  String get _formattedDisplay {
    if (widget.displayText != null) {
      return widget.displayText!;
    }
    final digits = widget.digits;
    if (digits.isEmpty) {
      return '${widget.countryCode} Your phone number';
    }
    if (widget.maxDigits == 10 && widget.countryCode == '+91') {
      if (digits.length <= 5) {
        return '${widget.countryCode} $digits';
      }
      return '${widget.countryCode} ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (widget.maxDigits == 10 && widget.countryCode == '+1') {
      if (digits.length <= 3) {
        return '($digits';
      }
      if (digits.length <= 6) {
        return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
      }
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return '${widget.countryCode} $digits';
  }

  bool _canProcessInput() {
    if (_inputLocked) {
      return false;
    }

    _inputLocked = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _inputLocked = false;
    });
    return true;
  }

  void _requestFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _flashKey(String keyId) {
    _highlightTimers[keyId]?.cancel();
    setState(() {
      _keyboardHighlightedKeys.add(keyId);
    });
    _highlightTimers[keyId] = Timer(_keyboardFlashDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _keyboardHighlightedKeys.remove(keyId);
      });
    });
  }

  bool _isDigitKey(String keyId) => RegExp(r'^\d$').hasMatch(keyId);

  void _activateKey(String keyId) {
    if (!widget.enabled || !_canProcessInput()) {
      return;
    }

    final currentDigits = widget.digits;
    var nextDigits = currentDigits;

    if (_isDigitKey(keyId)) {
      if (currentDigits.length >= widget.maxDigits) {
        return;
      }
      nextDigits = '$currentDigits$keyId';
    } else if (keyId == 'backspace') {
      if (currentDigits.isEmpty) {
        return;
      }
      nextDigits = currentDigits.substring(0, currentDigits.length - 1);
    } else if (keyId == 'clear') {
      if (currentDigits.isEmpty) {
        return;
      }
      nextDigits = '';
    }

    if (nextDigits != currentDigits) {
      widget.onChanged(nextDigits);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final mappedKey = _keyboardMap[event.logicalKey];
    if (mappedKey != null) {
      _flashKey(mappedKey);
      _activateKey(mappedKey);
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null && character.isNotEmpty) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isKeyEnabled(String keyId) {
    if (!widget.enabled) {
      return false;
    }
    if (_isDigitKey(keyId)) {
      return widget.digits.length < widget.maxDigits;
    }
    return widget.digits.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _requestFocus,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onFocusChange: (_) => setState(() {}),
        onKeyEvent: _handleKeyEvent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      _focusNode.hasFocus ? Colors.blue : Colors.grey.shade300,
                  width: _focusNode.hasFocus ? 1.6 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phone Number',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formattedDisplay,
                    key: const ValueKey('phone-number-display'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: widget.digits.isEmpty
                          ? Colors.grey.shade400
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.digitCountText ??
                        '${widget.digits.length}/${widget.maxDigits} digits',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: widget.statusColor ??
                          (widget.digits.length == widget.maxDigits
                              ? Colors.green.shade700
                              : Colors.grey.shade600),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.errorText!,
                      key: const ValueKey('phone-number-error'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tap the keypad or use your keyboard.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final buttonWidth = (constraints.maxWidth - (spacing * 2)) / 3;
                final buttonHeight = buttonWidth.clamp(72.0, 96.0);
                final gridHeight = (buttonHeight * 4) + (spacing * 3);

                return SizedBox(
                  height: gridHeight,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _actions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: buttonWidth / buttonHeight,
                    ),
                    itemBuilder: (context, index) {
                      final action = _actions[index];
                      final enabled = _isKeyEnabled(action.id);

                      return _KeypadButton(
                        key: ValueKey('phone-key-${action.id}'),
                        keyId: action.id,
                        label: action.label,
                        icon: action.icon,
                        enabled: enabled,
                        isHovered: _hoveredKeys.contains(action.id),
                        isPressed: _pressedKeys.contains(action.id) ||
                            _keyboardHighlightedKeys.contains(action.id),
                        onHoverChanged: (isHovered) {
                          setState(() {
                            if (isHovered) {
                              _hoveredKeys.add(action.id);
                            } else {
                              _hoveredKeys.remove(action.id);
                            }
                          });
                        },
                        onPressedChanged: (isPressed) {
                          setState(() {
                            if (isPressed) {
                              _pressedKeys.add(action.id);
                            } else {
                              _pressedKeys.remove(action.id);
                            }
                          });
                        },
                        onTap: () {
                          _requestFocus();
                          _activateKey(action.id);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KeypadAction {
  const _KeypadAction({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final IconData? icon;
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    super.key,
    required this.keyId,
    required this.label,
    required this.enabled,
    required this.isHovered,
    required this.isPressed,
    required this.onHoverChanged,
    required this.onPressedChanged,
    required this.onTap,
    this.icon,
  });

  final String keyId;
  final String label;
  final IconData? icon;
  final bool enabled;
  final bool isHovered;
  final bool isPressed;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<bool> onPressedChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = !enabled
        ? Colors.grey.shade200
        : isPressed
            ? Colors.blue.shade100
            : isHovered
                ? Colors.grey.shade100
                : Colors.white;

    final borderColor = !enabled
        ? Colors.grey.shade300
        : isPressed
            ? Colors.blue.shade400
            : isHovered
                ? Colors.grey.shade400
                : Colors.grey.shade300;

    final foregroundColor = !enabled
        ? Colors.grey.shade400
        : isPressed
            ? Colors.blue.shade800
            : Colors.black87;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: keyId == 'backspace'
            ? 'Delete digit'
            : keyId == 'clear'
                ? 'Clear phone number'
                : 'Digit $label',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isPressed ? 0.05 : 0.03,
                      ),
                      blurRadius: isPressed ? 6 : 14,
                      offset: Offset(0, isPressed ? 2 : 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: enabled ? onTap : null,
              onHighlightChanged: onPressedChanged,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: foregroundColor, size: 24)
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: keyId == 'clear' ? 18 : 28,
                          fontWeight: FontWeight.w700,
                          color: foregroundColor,
                          letterSpacing: keyId == 'clear' ? 1.0 : 0,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
