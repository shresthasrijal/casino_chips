import 'package:flutter/material.dart';
import 'package:aurora_background/aurora_background.dart';
import 'package:aurora_background/star_field.dart';

import 'package:casino_chips/views/lobby/sub_screen/create_lobby.dart';
import 'package:casino_chips/views/lobby/sub_screen/join_lobby.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double screenWidth = 0;
  double screenHeight = 0;
  double textScale = 0;

  @override
  void initState() {
    super.initState();

    // Run after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        screenWidth = size.width;
        screenHeight = size.height;
        textScale = screenWidth / 375;
      });

      debugPrint('Screen width: $screenWidth, height: $screenHeight');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        numberOfWaves: 5,
        backgroundColors: const [
          Color(0xFF050717),
          Color(0xFF0B1026),
          Color(0xFF141B36),
        ],
        waveDurations: const [8, 12, 16, 20, 24],
        waveColors: const [
          [Color(0x33228CE8), Color(0x33228CE8), Color(0x33228CE8)],
          [Color(0x3345FF9B), Color(0x3345FF9B), Color(0x3345FF9B)],
          [Color(0x33B987FF), Color(0x33B987FF), Color(0x33B987FF)],
          [Color(0x3322E88C), Color(0x3322E88C), Color(0x3322E88C)],
          [Color(0x338C22FF), Color(0x338C22FF), Color(0x338C22FF)],
        ],
        waveHeightMultiplier: 0.25,
        baseHeightMultiplier: 0.35,
        waveBlur: 25,
        starFieldConfig: StarFieldConfig(
          starCount: 200,
          maxStarSize: 2.0,
          starColor: Colors.white.withValues(alpha: 0.6),
          seed: 123,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,

              children: [
                const SizedBox(height: 20),
                Text(
                  'CASINO the LAN Game',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24 * textScale,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black.withValues(alpha: 0.4),
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),

                // Create Lobby Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      debugPrint('Create Lobby Button Pressed');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateLobbyScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Create Lobby',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Join Lobby Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => JoinLobbyScreen()),
                      );
                      debugPrint('Join Lobby Button Pressed');
                    },
                    child: const Text(
                      'Join Lobby',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
