import 'package:flutter/material.dart';

import '../mint/slate_button.dart';
import '../orbit/asset_book.dart';

/// Shown whenever the device has no reachable connection. Uses the
/// project's dedicated no-wifi artwork (orientation-aware) with a
/// Retry pill overlaid at the bottom. Retry rebuilds whichever
/// screen the caller supplied.
class OfflineVeil extends StatefulWidget {
  const OfflineVeil({super.key, required this.rebuild});

  final WidgetBuilder rebuild;

  @override
  State<OfflineVeil> createState() => _OfflineVeilState();
}

class _OfflineVeilState extends State<OfflineVeil> {
  bool _spinning = false;

  Future<void> _retry() async {
    if (_spinning) return;
    setState(() => _spinning = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.rebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String art =
        landscape ? AssetBook.horizontalOffline : AssetBook.verticalOffline;

    return Scaffold(
      backgroundColor: const Color(0xFF06061A),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            art,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            gaplessPlayback: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.09 : 0.08),
            child: Center(
              child: _spinning
                  ? const SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF29E7FF)),
                      ),
                    )
                  : SlatePillButton(
                      label: 'Retry',
                      compact: landscape,
                      width: landscape ? size.width * 0.36 : size.width * 0.66,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
