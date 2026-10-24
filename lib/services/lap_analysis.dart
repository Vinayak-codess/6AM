import '../models/lap.dart';

class LapHighlights {
  const LapHighlights({this.longestIndex, this.shortestIndex});

  final int? longestIndex;
  final int? shortestIndex;
}

LapHighlights computeLapHighlights(List<Lap> laps) {
  if (laps.length < 2) {
    return const LapHighlights();
  }
  var longest = 0;
  var shortest = 0;
  for (var i = 1; i < laps.length; i++) {
    if (laps[i].duration > laps[longest].duration) {
      longest = i;
    }
    if (laps[i].duration < laps[shortest].duration) {
      shortest = i;
    }
  }
  if (longest == shortest) {
    return const LapHighlights();
  }
  return LapHighlights(longestIndex: longest, shortestIndex: shortest);
}
