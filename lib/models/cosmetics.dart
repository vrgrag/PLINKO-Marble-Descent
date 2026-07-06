import 'package:flutter/material.dart';

class BallSkin {
  final String id;
  final String name;
  final int price;
  final Color tint;
  final double tintStrength;

  const BallSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.tint,
    this.tintStrength = 0.35,
  });
}

class WallSkin {
  final String id;
  final String name;
  final int price;
  final Color tint;
  final double tintStrength;

  const WallSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.tint,
    this.tintStrength = 0.5,
  });
}

class Cosmetics {
  static const List<BallSkin> ballSkins = [
    BallSkin(
      id: 'ball_default',
      name: 'Aqua Marble',
      price: 0,
      tint: Colors.transparent,
      tintStrength: 0.0,
    ),
    BallSkin(
      id: 'ball_pink',
      name: 'Neon Rose',
      price: 100,
      tint: Color(0xFFFF3EA5),
      tintStrength: 0.45,
    ),
    BallSkin(
      id: 'ball_gold',
      name: 'Solar Flare',
      price: 250,
      tint: Color(0xFFFFC93C),
      tintStrength: 0.5,
    ),
    BallSkin(
      id: 'ball_violet',
      name: 'Ultraviolet',
      price: 500,
      tint: Color(0xFF9D4EDD),
      tintStrength: 0.5,
    ),
    BallSkin(
      id: 'ball_emerald',
      name: 'Emerald Core',
      price: 900,
      tint: Color(0xFF32E1B4),
      tintStrength: 0.5,
    ),
  ];

  static const List<WallSkin> wallSkins = [
    WallSkin(
      id: 'wall_default',
      name: 'Cyan Circuit',
      price: 0,
      tint: Colors.transparent,
      tintStrength: 0.0,
    ),
    WallSkin(
      id: 'wall_magenta',
      name: 'Magenta Grid',
      price: 150,
      tint: Color(0xFFFF2FA6),
      tintStrength: 0.4,
    ),
    WallSkin(
      id: 'wall_lime',
      name: 'Lime Pulse',
      price: 300,
      tint: Color(0xFF9CFF3E),
      tintStrength: 0.45,
    ),
    WallSkin(
      id: 'wall_orange',
      name: 'Solar Rails',
      price: 650,
      tint: Color(0xFFFF7A29),
      tintStrength: 0.5,
    ),
  ];

  static BallSkin ballById(String id) =>
      ballSkins.firstWhere((s) => s.id == id, orElse: () => ballSkins.first);

  static WallSkin wallById(String id) =>
      wallSkins.firstWhere((s) => s.id == id, orElse: () => wallSkins.first);

  static const List<String> backgrounds = [
    'assets/bg1_asset.webp',
    'assets/bg2_asset.webp',
    'assets/bg3_asset.webp',
  ];
}
