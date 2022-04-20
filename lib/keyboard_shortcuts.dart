library keyboard_shortcuts;

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget? _homeWidget;
List<_KeyBoardShortcuts> _keyBoardShortcuts = [];
Widget? _customGlobal;
String? _customTitle;
IconData? _customIcon;
bool _helperIsOpen = false;
List<Tuple3<Set<LogicalKeyboardKey>, Function(BuildContext context), String>>
    _newGlobal = [];

enum BasicShortCuts {
  creation,
  previousPage,
  nextPage,
  save,
}

// void initShortCuts(
//   Widget homePage, {
//   Set<Set<LogicalKeyboardKey>>? keysToPress,
//   Set<Function(BuildContext context)>? onKeysPressed,
//   Set<String>? helpLabel,
//   Widget? helpGlobal,
//   String? helpTitle,
//   IconData? helpIcon,
// }) async {
//   if (keysToPress != null &&
//       onKeysPressed != null &&
//       helpLabel != null &&
//       keysToPress.length == onKeysPressed.length &&
//       onKeysPressed.length == helpLabel.length) {
//     _newGlobal = [];
//     for (var i = 0; i < keysToPress.length; i++) {
//       _newGlobal.add(Tuple3(keysToPress.elementAt(i),
//           onKeysPressed.elementAt(i), helpLabel.elementAt(i)));
//     }
//   }
//   _homeWidget = homePage;
//   _customGlobal = helpGlobal;
//   _customTitle = helpTitle;
//   _customIcon = helpIcon;
// }

bool _isPressed(
    Set<LogicalKeyboardKey> keysPressed, Set<LogicalKeyboardKey> keysToPress) {
  //when we type shift on chrome flutter's core return two pressed keys : Shift Left && Shift Right. So we need to delete one on the set to run the action
  var rights =
      keysPressed.where((element) => element.debugName!.contains("Right"));
  var lefts =
      keysPressed.where((element) => element.debugName!.contains("Left"));
  var toRemove = [];

  for (final rightElement in rights) {
    var leftElement = lefts.firstWhereOrNull((element) =>
        element.debugName!.split(" ")[0] ==
        rightElement.debugName!.split(" ")[0]);
    if (leftElement != null) {
      var actualKey = keysToPress.where((element) =>
          element.debugName!.split(" ")[0] ==
          rightElement.debugName!.split(" ")[0]);
      if (actualKey != null &&
          actualKey.length > 0 &&
          actualKey.first.debugName!.isNotEmpty)
        actualKey.first.debugName!.contains("Right")
            ? toRemove.add(leftElement)
            : toRemove.add(rightElement);
    }
  }

  keysPressed.removeWhere((e) => toRemove.contains(e));

  return keysPressed.containsAll(keysToPress) &&
      keysPressed.length == keysToPress.length;
}

class Shortcut {
  String label;
  String description;
  VoidCallback callback;
  Set<LogicalKeyboardKey> keysSet;
  Icon icon;
  Shortcut({
    required this.label,
    required this.description,
    required this.callback,
    required this.keysSet,
    required this.icon,
  });
}

class KeyBoardShortcuts extends StatefulWidget {
  final Widget child;

  /// You can use shortCut function with BasicShortCuts to avoid write data by yourself
  final List<Shortcut> shortCuts;

  /// Function when keys are pressed
  // final VoidCallback? onKeysPressed;

  /// Label who will be displayed in helper

  /// Activate when this widget is the first of the page
  final bool globalShortcuts;

  KeyBoardShortcuts({
    required this.shortCuts,
    this.globalShortcuts = false,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  _KeyBoardShortcuts createState() => _KeyBoardShortcuts();
}

class _KeyBoardShortcuts extends State<KeyBoardShortcuts> {
  FocusScopeNode? focusScopeNode;
  ScrollController _controller = ScrollController();
  bool controllerIsReady = false;
  bool listening = false;
  late Key key;
  @override
  void initState() {
    _controller.addListener(() {
      if (_controller.hasClients) setState(() => controllerIsReady = true);
    });
    _attachKeyboardIfDetached();
    key = widget.key ?? UniqueKey();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _detachKeyboardIfAttached();
  }

  void _attachKeyboardIfDetached() {
    if (listening) return;
    _keyBoardShortcuts.add(this);
    RawKeyboard.instance.addListener(listener);
    listening = true;
  }

  void _detachKeyboardIfAttached() {
    if (!listening) return;
    _keyBoardShortcuts.remove(this);
    RawKeyboard.instance.removeListener(listener);
    listening = false;
  }

  void listener(RawKeyEvent v) async {
    if (!mounted || _helperIsOpen) return;

    Set<LogicalKeyboardKey> keysPressed = RawKeyboard.instance.keysPressed;
    if (v.runtimeType == RawKeyDownEvent) {
      widget.shortCuts.forEach(
        (shortcut) {
          if (_isPressed(keysPressed, shortcut.keysSet)) {
            shortcut.callback();
          }
        },
      );
    }

    // when user type keysToPress

    // when user request help menu
    else if (_isPressed(keysPressed,
        {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyH})) {
      List<Widget> activeHelp = [];

      //verify if element is visible or not
      List<_KeyBoardShortcuts> toRemove = [];
      _keyBoardShortcuts.forEach((element) {
        if (VisibilityDetectorController.instance
                .widgetBoundsFor(element.key) ==
            null) {
          element.listening = false;
          toRemove.add(element);
        }
      });

      _keyBoardShortcuts.removeWhere((element) => toRemove.contains(element));
      _keyBoardShortcuts.forEach((element) {
        Widget? elementWidget = _helpWidget(element);
        if (elementWidget != null) activeHelp.add(elementWidget);
      }); // get all custom shortcuts

      bool showGlobalShort =
          _keyBoardShortcuts.any((element) => element.widget.globalShortcuts);

      if (!_helperIsOpen && (activeHelp.isNotEmpty || showGlobalShort)) {
        _helperIsOpen = true;

        await showDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            key: UniqueKey(),
            title: Text(_customTitle ?? 'Keyboard Shortcuts'),
            content: SingleChildScrollView(
                // child: elementWidget
                ),
          ),
        ).then((value) => _helperIsOpen = false);
      }
    } else if (widget.globalShortcuts) {
      if (_homeWidget != null &&
          _isPressed(keysPressed, {LogicalKeyboardKey.home})) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => _homeWidget!),
            (_) => false);
      } else if (_isPressed(keysPressed, {LogicalKeyboardKey.escape})) {
        Navigator.maybePop(context);
      } else if (controllerIsReady &&
              keysPressed.containsAll({LogicalKeyboardKey.pageDown}) ||
          keysPressed.first.keyId == 0x10700000022) {
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: new Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      } else if (controllerIsReady &&
              keysPressed.containsAll({LogicalKeyboardKey.pageUp}) ||
          keysPressed.first.keyId == 0x10700000021) {
        _controller.animateTo(
          _controller.position.minScrollExtent,
          duration: new Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
      for (final newElement in _newGlobal) {
        if (_isPressed(keysPressed, newElement.item1)) {
          newElement.item2(context);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: key,
      child:
          PrimaryScrollController(controller: _controller, child: widget.child),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction == 1)
          _attachKeyboardIfDetached();
        else
          _detachKeyboardIfAttached();
      },
    );
  }
}

String _getKeysToPress(Set<LogicalKeyboardKey>? keysToPress) {
  String text = "";
  if (keysToPress != null) {
    for (final i in keysToPress) text += i.debugName! + " + ";
    text = text.substring(0, text.lastIndexOf(" + "));
  }
  return text;
}

Widget? _helpWidget(_KeyBoardShortcuts widget) {
  return Column(
    children: widget.widget.shortCuts
        .map((e) => ListTile(
              leading: e.icon,
              title: Text(e.label),
              subtitle: Text(_getKeysToPress(e.keysSet)),
            ))
        .toList(),
  );
}

// Set<LogicalKeyboardKey> shortCut(BasicShortCuts basicShortCuts) {
//   switch (basicShortCuts) {
//     case BasicShortCuts.creation:
//       return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyN};
//     case BasicShortCuts.previousPage:
//       return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowLeft};
//     case BasicShortCuts.nextPage:
//       return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowRight};
//     case BasicShortCuts.save:
//       return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyS};
//     default:
//       return {};
//   }
// }
