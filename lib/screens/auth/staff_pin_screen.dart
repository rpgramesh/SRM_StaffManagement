import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';

class StaffPinScreen extends StatefulWidget {
  final String phoneNumber;
  final ValueChanged<String>? onPinComplete;

  const StaffPinScreen({
    super.key,
    required this.phoneNumber,
    this.onPinComplete,
  });

  @override
  State<StaffPinScreen> createState() => _StaffPinScreenState();
}

class _StaffPinScreenState extends State<StaffPinScreen> {
  static const Duration _debounceDuration = Duration(milliseconds: 100);
  static const Duration _keyboardFlashDuration = Duration(milliseconds: 150);
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

  String _pin = '';
  bool _isLoading = false;
  final int _pinLength = 6;
  final FocusNode _focusNode = FocusNode(debugLabel: 'staff-pin-keypad');
  final Set<String> _hoveredKeys = <String>{};
  final Set<String> _pressedKeys = <String>{};
  final Set<String> _keyboardHighlightedKeys = <String>{};
  final Map<String, Timer> _highlightTimers = <String, Timer>{};

  Timer? _debounceTimer;
  bool _inputLocked = false;

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
    _debounceTimer?.cancel();
    for (final timer in _highlightTimers.values) {
      timer.cancel();
    }
    _focusNode.dispose();
    super.dispose();
  }

  bool _canProcessInput() {
    if (_inputLocked || _isLoading) {
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

  void _onNumberTap(String number) {
    if (!_canProcessInput() || _pin.length >= _pinLength) {
      return;
    }

    setState(() {
      _pin += number;
    });

    // Auto-submit when PIN is complete
    if (_pin.length == _pinLength) {
      if (widget.onPinComplete != null) {
        widget.onPinComplete!(_pin);
      } else {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (!_canProcessInput() || _pin.isEmpty) {
      return;
    }

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final mappedKey = _keyboardMap[event.logicalKey];
    if (mappedKey != null) {
      _flashKey(mappedKey);
      if (_isDigitKey(mappedKey)) {
        _onNumberTap(mappedKey);
      } else if (mappedKey == 'backspace') {
        _onBackspace();
      }
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null && character.isNotEmpty) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _verifyPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final staffInfo =
          await authService.signInStaffWithPin(widget.phoneNumber, _pin);

      if (!mounted) {
        return;
      }

      if (staffInfo != null && staffInfo['user'] != null) {
        // Persist session details for other screens relying on SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final String staffId = (staffInfo['staffId'] ?? '').toString();
        final Map<String, dynamic> staffData =
            Map<String, dynamic>.from(staffInfo['staffData'] ?? {});
        final String name = (staffData['name'] ?? '').toString();
        final String role = (staffInfo['role'] ?? 'staff').toString();
        final String phone =
            (staffData['phone'] ?? widget.phoneNumber).toString();

        if (staffId.isNotEmpty) {
          await prefs.setString('currentStaffId', staffId);
        }
        await prefs.setString('currentStaffName', name);
        await prefs.setString('currentStaffRole', role);
        await prefs.setString('currentStaffPhone', phone);

        if (!mounted) {
          return;
        }

        // Navigate to main app dashboard
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
      } else {
        // Show error and reset PIN
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _pin = '';
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _pin = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _forgotPin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content:
            const Text('Please contact your administrator to reset your PIN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Staff Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _requestFocus,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onFocusChange: (_) => setState(() {}),
            onKeyEvent: _handleKeyEvent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        const Text(
                          'Enter PIN',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your 6-digit PIN to login.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AnimatedContainer(
                          key: const ValueKey('pin-entry-display'),
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _focusNode.hasFocus
                                  ? Colors.blue
                                  : Colors.grey.shade300,
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
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _pinLength,
                                  (index) => Container(
                                    key: ValueKey('pin-dot-$index'),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index < _pin.length
                                          ? Colors.blue
                                          : Colors.grey[300],
                                      border: Border.all(
                                        color: index < _pin.length
                                            ? Colors.blue
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$_pinLength-digit PIN',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_pin.length}/$_pinLength digits',
                                key: const ValueKey('pin-length-label'),
                                style: TextStyle(
                                  color: _pin.length == _pinLength
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tap the keypad or use your keyboard.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: CircularProgressIndicator(),
                          )
                        else ...[
                          TextButton(
                            onPressed: _forgotPin,
                            child: const Text(
                              'Forgot PIN?',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _buildKeypadGrid(),
                          ),
                        ],
                        const SizedBox(height: 32),
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

  Widget _buildKeypadGrid() {
    const actions = <Map<String, String>>[
      {'id': '1', 'label': '1'},
      {'id': '2', 'label': '2'},
      {'id': '3', 'label': '3'},
      {'id': '4', 'label': '4'},
      {'id': '5', 'label': '5'},
      {'id': '6', 'label': '6'},
      {'id': '7', 'label': '7'},
      {'id': '8', 'label': '8'},
      {'id': '9', 'label': '9'},
      {'id': 'empty', 'label': ''},
      {'id': '0', 'label': '0'},
      {'id': 'backspace', 'label': 'DEL'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final buttonWidth = (constraints.maxWidth - (spacing * 2)) / 3;
        final buttonHeight = buttonWidth.clamp(72.0, 96.0);
        final gridHeight = (buttonHeight * 4) + (spacing * 3);

        return SizedBox(
          height: gridHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: buttonWidth / buttonHeight,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              final keyId = action['id']!;

              if (keyId == 'empty') {
                return const SizedBox.shrink();
              }

              return _buildKeypadButton(
                keyId: keyId,
                label: action['label']!,
                enabled: keyId == 'backspace'
                    ? _pin.isNotEmpty
                    : _pin.length < _pinLength,
                isPressed: _pressedKeys.contains(keyId) ||
                    _keyboardHighlightedKeys.contains(keyId),
                isHovered: _hoveredKeys.contains(keyId),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildKeypadButton({
    required String keyId,
    required String label,
    required bool enabled,
    required bool isPressed,
    required bool isHovered,
  }) {
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
      onEnter: (_) {
        setState(() {
          _hoveredKeys.add(keyId);
        });
      },
      onExit: (_) {
        setState(() {
          _hoveredKeys.remove(keyId);
        });
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: keyId == 'backspace' ? 'Delete PIN digit' : 'PIN digit $label',
        child: AnimatedContainer(
          key: ValueKey('pin-key-$keyId'),
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
              onTap: !enabled
                  ? null
                  : () {
                      _requestFocus();
                      if (keyId == 'backspace') {
                        _onBackspace();
                      } else {
                        _onNumberTap(keyId);
                      }
                    },
              onHighlightChanged: (highlighted) {
                setState(() {
                  if (highlighted) {
                    _pressedKeys.add(keyId);
                  } else {
                    _pressedKeys.remove(keyId);
                  }
                });
              },
              child: Center(
                child: keyId == 'backspace'
                    ? Icon(
                        Icons.backspace_outlined,
                        size: 24,
                        color: foregroundColor,
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: foregroundColor,
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
