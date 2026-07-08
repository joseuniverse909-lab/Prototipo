class ZonePriorityService {
  static double calculateScore({
    required double speedMetersPerSecond,
    required int laps,
  }) {
    return speedMetersPerSecond + (laps * 0.35);
  }

  static bool challengerWins({
    required double currentBestSpeed,
    required int currentLaps,
    required double challengerSpeed,
    required int challengerLaps,
  }) {
    final currentScore = calculateScore(
      speedMetersPerSecond: currentBestSpeed,
      laps: currentLaps,
    );
    final challengerScore = calculateScore(
      speedMetersPerSecond: challengerSpeed,
      laps: challengerLaps,
    );

    return challengerScore > currentScore;
  }
}
