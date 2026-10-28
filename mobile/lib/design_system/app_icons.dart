import 'package:flutter/widgets.dart';

abstract final class AppIcons {
  // 승인한 Rounded 400·24 규격을 글꼴에 고정해 호출부마다 모양이 달라지지 않아요.
  static const String _outlined = 'NaruSymbolsRounded';
  static const String _filled = 'NaruSymbolsRoundedFilled';

  static const IconData add = IconData(0xe145, fontFamily: _outlined);
  static const IconData back = IconData(
    0xe2ea,
    fontFamily: _outlined,
    matchTextDirection: true,
  );
  static const IconData arrowDropDown = IconData(0xe5c5, fontFamily: _outlined);
  static const IconData arrowDropUp = IconData(0xe5c7, fontFamily: _outlined);
  static const IconData send = IconData(0xe5d8, fontFamily: _outlined);
  static const IconData calendar = IconData(0xe935, fontFamily: _outlined);
  static const IconData call = IconData(0xf0d4, fontFamily: _outlined);
  static const IconData callEnd = IconData(0xf0bc, fontFamily: _outlined);
  static const IconData check = IconData(0xe668, fontFamily: _outlined);
  static const IconData checkCircle = IconData(0xf0be, fontFamily: _outlined);
  static const IconData chevronLeft = IconData(
    0xe5cb,
    fontFamily: _outlined,
    matchTextDirection: true,
  );
  static const IconData chevronRight = IconData(
    0xe5cc,
    fontFamily: _outlined,
    matchTextDirection: true,
  );
  static const IconData close = IconData(0xe5cd, fontFamily: _outlined);
  static const IconData copy = IconData(0xe14d, fontFamily: _outlined);
  static const IconData delete = IconData(0xe92e, fontFamily: _outlined);
  static const IconData download = IconData(0xf090, fontFamily: _outlined);
  static const IconData file = IconData(0xe66d, fontFamily: _outlined);
  static const IconData edit = IconData(0xf097, fontFamily: _outlined);
  static const IconData graphicEq = IconData(0xe1b8, fontFamily: _outlined);
  static const IconData headphones = IconData(0xf01f, fontFamily: _outlined);
  static const IconData image = IconData(0xe3f4, fontFamily: _outlined);
  static const IconData share = IconData(0xe6b8, fontFamily: _outlined);
  static const IconData keyboardArrowDown = IconData(
    0xe313,
    fontFamily: _outlined,
  );
  static const IconData keyboardArrowUp = IconData(
    0xe316,
    fontFamily: _outlined,
  );
  static const IconData mic = IconData(0xe31d, fontFamily: _outlined);
  static const IconData micOff = IconData(0xe02b, fontFamily: _outlined);
  static const IconData person = IconData(0xf0d3, fontFamily: _outlined);
  static const IconData phoneDisabled = IconData(0xe9cc, fontFamily: _outlined);
  static const IconData phoneInTalk = IconData(0xe61d, fontFamily: _outlined);
  static const IconData phoneMissed = IconData(0xe61f, fontFamily: _outlined);
  static const IconData camera = IconData(0xe412, fontFamily: _outlined);
  static const IconData photoLibrary = IconData(0xe413, fontFamily: _outlined);
  static const IconData pictureInPictureAlt = IconData(
    0xe911,
    fontFamily: _outlined,
  );
  static const IconData refresh = IconData(0xe5d5, fontFamily: _outlined);
  static const IconData replay = IconData(0xe042, fontFamily: _outlined);
  static const IconData reply = IconData(
    0xe15e,
    fontFamily: _outlined,
    matchTextDirection: true,
  );
  static const IconData search = IconData(0xef7a, fontFamily: _outlined);
  static const IconData videocam = IconData(0xe04b, fontFamily: _outlined);
  static const IconData visibility = IconData(0xe8f4, fontFamily: _outlined);
  static const IconData visibilityOff = IconData(0xe8f5, fontFamily: _outlined);
  static const IconData volumeUp = IconData(0xe050, fontFamily: _outlined);

  // 재생·일시정지·정지는 작은 미디어 컨트롤에서도 보이도록 채움형을 써요.
  static const IconData pause = IconData(0xe034, fontFamily: _filled);
  static const IconData play = IconData(0xe037, fontFamily: _filled);
  static const IconData stop = IconData(0xe047, fontFamily: _filled);

  static IconData playback(bool isPlaying) => isPlaying ? pause : play;
}
