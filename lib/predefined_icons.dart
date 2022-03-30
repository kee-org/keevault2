import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kdbx/kdbx.dart';

class PredefinedIcons {
  static const icons = <IconData>[
    FontAwesomeIcons.key,
    FontAwesomeIcons.globe,
    FontAwesomeIcons.triangleExclamation,
    FontAwesomeIcons.server,
    FontAwesomeIcons.thumbtack,
    FontAwesomeIcons.comment,
    FontAwesomeIcons.puzzlePiece,
    FontAwesomeIcons.penToSquare,
    FontAwesomeIcons.cloud,
    FontAwesomeIcons.addressCard,
    FontAwesomeIcons.paperclip,
    FontAwesomeIcons.camera,
    FontAwesomeIcons.wifi,
    FontAwesomeIcons.link,
    FontAwesomeIcons.plug,
    FontAwesomeIcons.barcode,
    FontAwesomeIcons.certificate,
    FontAwesomeIcons.compactDisc,
    FontAwesomeIcons.desktop,
    FontAwesomeIcons.envelopeOpen,
    FontAwesomeIcons.gear,
    FontAwesomeIcons.clipboard,
    FontAwesomeIcons.paperPlane,
    FontAwesomeIcons.tv,
    FontAwesomeIcons.batteryThreeQuarters,
    FontAwesomeIcons.inbox,
    FontAwesomeIcons.floppyDisk,
    FontAwesomeIcons.hardDrive,
    FontAwesomeIcons.circleDot,
    FontAwesomeIcons.expeditedssl,
    FontAwesomeIcons.terminal,
    FontAwesomeIcons.print,
    FontAwesomeIcons.signsPost,
    FontAwesomeIcons.flagCheckered,
    FontAwesomeIcons.wrench,
    FontAwesomeIcons.laptop,
    FontAwesomeIcons.fileZipper,
    FontAwesomeIcons.creditCard,
    FontAwesomeIcons.windows,
    FontAwesomeIcons.clock,
    FontAwesomeIcons.magnifyingGlass,
    FontAwesomeIcons.flask,
    FontAwesomeIcons.gamepad,
    FontAwesomeIcons.trash,
    FontAwesomeIcons.noteSticky,
    FontAwesomeIcons.xmark,
    FontAwesomeIcons.circleQuestion,
    FontAwesomeIcons.cube,
    FontAwesomeIcons.folder,
    FontAwesomeIcons.folderOpen,
    FontAwesomeIcons.database,
    FontAwesomeIcons.unlockKeyhole,
    FontAwesomeIcons.lock,
    FontAwesomeIcons.check,
    FontAwesomeIcons.pencil,
    FontAwesomeIcons.image,
    FontAwesomeIcons.bookOpen,
    FontAwesomeIcons.rectangleList,
    FontAwesomeIcons.userLock,
    FontAwesomeIcons.utensils,
    FontAwesomeIcons.house,
    FontAwesomeIcons.star,
    FontAwesomeIcons.linux,
    FontAwesomeIcons.feather,
    FontAwesomeIcons.apple,
    FontAwesomeIcons.wikipediaW,
    FontAwesomeIcons.dollarSign,
    FontAwesomeIcons.handshake,
    FontAwesomeIcons.mobileScreen, //Button
  ];

  static IconData iconFor(KdbxIcon icon) {
    return icons[icon.index];
  }

  static IconData iconForGroup(KdbxIcon icon) {
    return icons[icon.index];
  }
}
