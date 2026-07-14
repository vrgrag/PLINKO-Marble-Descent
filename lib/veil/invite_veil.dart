import 'package:flutter/material.dart';

import '../bridge/insight.dart';
import '../mint/slate_button.dart';
import '../nexus/identity.dart';
import '../orbit/asset_book.dart';
import '../relays/local_store.dart';
import '../relays/net_probe.dart';
import '../relays/push_relay.dart';
import 'web_veil.dart';

/// Push opt-in promo shown once (or after the cooldown expires) before
/// the WebView is opened. Accept fires the OS permission dialog; Skip
/// arms the cooldown. Either action forwards the user to the WebView.
class InviteVeil extends StatefulWidget {
  const InviteVeil({
    super.key,
    required this.store,
    required this.pushRelay,
    required this.netProbe,
    required this.destination,
  });

  final LocalStore store;
  final PushRelay pushRelay;
  final NetProbe netProbe;
  final String destination;

  @override
  State<InviteVeil> createState() => _InviteVeilState();
}

class _InviteVeilState extends State<InviteVeil> {
  @override
  void initState() {
    super.initState();
    Insight.screen('push_invite');
  }

  Future<void> _accept(BuildContext context) async {
    Insight.event('push_invite_accept');
    final bool granted = await widget.pushRelay.askPermission();
    Insight.tag('notif_permission', granted ? 'granted' : 'denied');
    Insight.event(granted ? 'push_granted' : 'push_denied');
    if (!granted) {
      await widget.store.writeInviteMute(_cooldownDeadline());
    }
    if (context.mounted) _forward(context);
  }

  Future<void> _skip(BuildContext context) async {
    Insight.event('push_invite_skip');
    Insight.tag('notif_permission', 'skipped');
    await widget.store.writeInviteMute(_cooldownDeadline());
    if (context.mounted) _forward(context);
  }

  int _cooldownDeadline() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
      MarbleIdentity.inviteSkipCooldown;

  void _forward(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebVeil(
          destination: widget.destination,
          store: widget.store,
          pushRelay: widget.pushRelay,
          netProbe: widget.netProbe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String art =
        landscape ? AssetBook.horizontalInvite : AssetBook.verticalInvite;

    final Widget actionColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SlatePillButton(
          label: 'Accept',
          compact: landscape,
          width: landscape ? size.width * 0.36 : size.width * 0.72,
          onTap: () => _accept(context),
        ),
        SizedBox(height: landscape ? 10 : 16),
        SlateGhostButton(
          label: 'Skip',
          compact: landscape,
          width: landscape ? size.width * 0.28 : size.width * 0.56,
          onTap: () => _skip(context),
        ),
      ],
    );

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
                colors: <Color>[Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          Positioned(
            left: size.width * 0.08,
            right: size.width * 0.08,
            bottom: size.height * (landscape ? 0.06 : 0.08),
            child: actionColumn,
          ),
        ],
      ),
    );
  }
}
