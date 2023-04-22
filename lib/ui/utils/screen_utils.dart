// ignore_for_file: constant_identifier_names

import 'package:flutter/cupertino.dart';

enum ScreenType { Wide, Narrow }

class FormFactor {
  static double desktop = 900;
  static double handset = 300;
}

class TUIKitScreenUtils {
  static ScreenType? screenType;

  static ScreenType getFormFactor([BuildContext? context]) {
    if (screenType != null) return screenType!;

    if(context != null){
      double deviceWidth = MediaQuery.of(context).size.width;
      double deviceHeight = MediaQuery.of(context).size.height;

      if (deviceWidth > FormFactor.desktop || deviceWidth > deviceHeight * 1.1) {
        screenType = ScreenType.Wide;
      } else if (deviceWidth > FormFactor.handset) {
        screenType = ScreenType.Narrow;
      }
      return screenType ?? ScreenType.Narrow;
    }else{
      return ScreenType.Narrow;
    }
  }

  static Widget getDeviceWidget({
    required Widget defaultWidget,
    Widget? wideWidget,
    Widget? narrowWidget,
  }) {
    if (screenType == ScreenType.Wide) return wideWidget ?? defaultWidget;
    return narrowWidget ?? defaultWidget;
  }
}
