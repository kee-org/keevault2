import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kdbx/kdbx.dart';

class PredefinedIcons {
  static const icons = <IconData>[
    FontAwesomeIcons.key,
    FontAwesomeIcons.globe,
    FontAwesomeIcons.exclamationTriangle,
    FontAwesomeIcons.server,
    FontAwesomeIcons.thumbtack,
    FontAwesomeIcons.comment,
    FontAwesomeIcons.puzzlePiece,
    FontAwesomeIcons.edit,
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
    FontAwesomeIcons.cog,
    FontAwesomeIcons.clipboard,
    FontAwesomeIcons.paperPlane,
    FontAwesomeIcons.tv,
    FontAwesomeIcons.batteryThreeQuarters,
    FontAwesomeIcons.inbox,
    FontAwesomeIcons.save,
    FontAwesomeIcons.hdd,
    FontAwesomeIcons.dotCircle,
    FontAwesomeIcons.expeditedssl,
    FontAwesomeIcons.terminal,
    FontAwesomeIcons.print,
    FontAwesomeIcons.mapSigns,
    FontAwesomeIcons.flagCheckered,
    FontAwesomeIcons.wrench,
    FontAwesomeIcons.laptop,
    FontAwesomeIcons.fileArchive,
    FontAwesomeIcons.creditCard,
    FontAwesomeIcons.windows,
    FontAwesomeIcons.clock,
    FontAwesomeIcons.search,
    FontAwesomeIcons.flask,
    FontAwesomeIcons.gamepad,
    FontAwesomeIcons.trash,
    FontAwesomeIcons.stickyNote,
    FontAwesomeIcons.times,
    FontAwesomeIcons.questionCircle,
    FontAwesomeIcons.cube,
    FontAwesomeIcons.folder,
    FontAwesomeIcons.folderOpen,
    FontAwesomeIcons.database,
    FontAwesomeIcons.unlockAlt,
    FontAwesomeIcons.lock,
    FontAwesomeIcons.check,
    FontAwesomeIcons.pencilAlt,
    FontAwesomeIcons.image,
    FontAwesomeIcons.bookOpen,
    FontAwesomeIcons.listAlt,
    FontAwesomeIcons.userLock,
    FontAwesomeIcons.utensils,
    FontAwesomeIcons.home,
    FontAwesomeIcons.star,
    FontAwesomeIcons.linux,
    FontAwesomeIcons.feather,
    FontAwesomeIcons.apple,
    FontAwesomeIcons.wikipediaW,
    FontAwesomeIcons.dollarSign,
    FontAwesomeIcons.handshake,
    FontAwesomeIcons.mobileAlt,
  ];

  static IconData iconFor(KdbxIcon icon) {
    return icons[icon.index];
  }

  static IconData iconForGroup(KdbxIcon icon) {
    return icons[icon.index];
  }
}
