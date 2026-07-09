/// Centralised asset paths for the shell (gray) surface. Native game
/// screens keep their own hardcoded paths — this file is only for
/// files consumed by the loading / offline / push-invite / web veils.
class AssetBook {
  AssetBook._();

  static const String _veilRoot = 'assets/marbledesc_veil';

  static const String verticalBoot = '$_veilRoot/Vertical_Loading_Screen.webp';
  static const String horizontalBoot =
      '$_veilRoot/Horizontal_Loading_Screen.webp';

  static const String verticalOffline =
      '$_veilRoot/Vertical_Nowifi_Screen.webp';
  static const String horizontalOffline =
      '$_veilRoot/Horizontal_Nowifi_Screen.webp';

  static const String verticalInvite =
      '$_veilRoot/Vertical_Notifications_Screen.webp';
  static const String horizontalInvite =
      '$_veilRoot/Horizontal_Notifications_Screen.webp';

  static const List<String> veilBackgrounds = <String>[
    verticalBoot,
    horizontalBoot,
    verticalOffline,
    horizontalOffline,
    verticalInvite,
    horizontalInvite,
  ];
}
