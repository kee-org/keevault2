import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/link.dart';

import '../config/app.dart';
import '../config/platform.dart';
import '../cubit/autofill_cubit.dart';
import 'logger.dart';

ListQueue<OutputEvent> _outputEventBuffer = ListQueue();
int _bufferSize = 20;
bool _initialized = false;

class LogConsole extends StatefulWidget {
  LogConsole({super.key}) : assert(_initialized, 'Please call LogConsole.init() first.');

  static void init({int bufferSize = 20}) {
    if (_initialized) return;

    _bufferSize = bufferSize;
    _initialized = true;

    Logger.addOutputListener((event) {
      if (_outputEventBuffer.length == bufferSize) {
        _outputEventBuffer.removeFirst();
      }
      _outputEventBuffer.add(event);
    });
  }

  @override
  LogConsoleState createState() => LogConsoleState();
}

class RenderedEvent {
  final int id;
  final Level level;
  final TextSpan span;
  final String lowerCaseText;

  RenderedEvent(this.id, this.level, this.span, this.lowerCaseText);
}

class LogConsoleState extends State<LogConsole> {
  late OutputCallback _callback;

  final ListQueue<RenderedEvent> _renderedBuffer = ListQueue();
  List<RenderedEvent> _filteredBuffer = [];

  final _scrollController = ScrollController();
  final _filterController = TextEditingController();
  bool _autofillDebugEnabled = false;

  Level _filterLevel = Level.debug;
  double _logFontSize = 12;

  var _currentId = 0;
  bool _scrollListenerEnabled = true;

  bool _followBottom = true;
  bool sharing = false;

  @override
  void initState() {
    super.initState();

    _callback = (e) {
      if (_renderedBuffer.length == _bufferSize) {
        _renderedBuffer.removeFirst();
      }
      _renderedBuffer.add(_renderEvent(e));
      _refreshFilter();
    };

    _autofillDebugEnabled = Settings.getValue<bool>('autofillServiceDebugEnabled') ?? false;

    Logger.addOutputListener(_callback);

    _scrollController.addListener(() {
      if (!_scrollListenerEnabled) return;
      var scrolledToBottom = _scrollController.offset >= _scrollController.position.maxScrollExtent;
      setState(() {
        _followBottom = scrolledToBottom;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _renderedBuffer.clear();
    for (var event in _outputEventBuffer) {
      _renderedBuffer.add(_renderEvent(event));
    }
    _refreshFilter();
  }

  void _refreshFilter() {
    var newFilteredBuffer = _renderedBuffer.where((it) {
      var logLevelMatches = it.level.index >= _filterLevel.index;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        var filterText = _filterController.text.toLowerCase();
        return it.lowerCaseText.contains(filterText);
      } else {
        return true;
      }
    }).toList();
    setState(() {
      _filteredBuffer = newFilteredBuffer;
    });

    if (_followBottom) {
      Future.delayed(Duration.zero, _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: widget.key,
      appBar: AppBar(title: const Text('Application logs')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildTopBar(dark),
            Expanded(
              child: _buildLogContent(dark),
            ),
            _buildBottomBar(dark),
          ],
        ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _followBottom ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: FloatingActionButton(
            mini: true,
            clipBehavior: Clip.antiAlias,
            onPressed: _scrollToBottom,
            child: Icon(
              Icons.arrow_downward,
              color: dark ? Colors.white : Colors.lightBlue[900],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent(bool dark) {
    return Container(
      color: dark ? Colors.black : Colors.grey[150],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1600,
          child: ListView.builder(
            shrinkWrap: true,
            controller: _scrollController,
            itemBuilder: (context, index) {
              var logEntry = _filteredBuffer[index];
              return Text.rich(
                logEntry.span,
                key: Key(logEntry.id.toString()),
                style: TextStyle(fontSize: _logFontSize),
              );
            },
            itemCount: _filteredBuffer.length,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool dark) {
    return LogBar(
      dark: dark,
      child: Column(
        children: [
          const Row(children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                    'Sharing technical logs can help to fix problems. Share to yourself (Cloud storage/email) and then read the instructions that appear.'),
              ),
            ),
          ]),
          Row(children: [
            Expanded(
              child: ListTile(
                title: Text('Enable Autofill logging'),
                subtitle: Text(
                    'Keep this option disabled unless you are actively investigating a problem with Autofill into other apps/websites. The preview below never shows Autofill logs.'),
                leading: Switch(
                  value: _autofillDebugEnabled,
                  onChanged: (bool? value) async {
                    if (value != null) {
                      final afc = BlocProvider.of<AutofillCubit>(context);
                      await Settings.setValue<bool>('autofillServiceDebugEnabled', value);
                      await afc.setDebugEnabledPreference(value);
                      setState(() {
                        _autofillDebugEnabled = value;
                      });
                    }
                  },
                ),
                visualDensity: VisualDensity.compact,
                titleAlignment: ListTileTitleAlignment.top,
                isThreeLine: true,
                onTap: () async {
                  final afc = BlocProvider.of<AutofillCubit>(context);
                  await Settings.setValue<bool>('autofillServiceDebugEnabled', !_autofillDebugEnabled);
                  await afc.setDebugEnabledPreference(!_autofillDebugEnabled);
                  setState(() {
                    _autofillDebugEnabled = !_autofillDebugEnabled;
                  });
                },
              ),
            ),
          ]),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.delete,
                  ),
                  label: const Text('Delete'),
                  onPressed: clearLogs,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: OutlinedButton.icon(
                  icon: sharing
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: sharing ? null : startShareLogs,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.zoom_in),
                onPressed: () {
                  setState(() {
                    _logFontSize++;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.zoom_out),
                onPressed: () {
                  setState(() {
                    _logFontSize--;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> clearLogs() async {
    //TODO:f: track async loading progress
    await deleteAutofillLogs();
    _renderedBuffer.clear();
    _outputEventBuffer.clear();
    _refreshFilter();
    setState(() {});
  }

  void startShareLogs() async {
    final box = context.findRenderObject() as RenderBox?;

    setState(() {
      sharing = true;
    });
    try {
      final future1 = getAutofillLogs();
      final future2 = getDiagnosticInfo();

      final encoder = ZipEncoder();
      final archive = Archive();

      var content = _outputEventBuffer.map((e) => e.lines.join('\n')).join('\n');
      final logFile = ArchiveFile.string('log.txt', content);
      archive.addFile(logFile);

      final diagnosticInfo = await future2;
      final infoFile = ArchiveFile.string('diagnostics.txt', diagnosticInfo);
      archive.addFile(infoFile);

      final autofillLogFiles = await future1;
      for (var f in autofillLogFiles) {
        archive.addFile(f);
      }

      // encoder generates a uint8List so no idea why it returns as a list of ints
      final encoded = encoder.encode(archive) as Uint8List;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/keevault_logs.zip');
      await file.create(recursive: true);
      await file.writeAsBytes(encoded, flush: true);
      try {
        final xFile = XFile(file.path, mimeType: 'application/zip');
        final shareResult = await Share.shareXFiles(
          [xFile],
          subject: 'Kee Vault logs',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
        if (shareResult.status == ShareResultStatus.success) {
          await showDialog<dynamic>(
              barrierDismissible: false,
              context: AppConfig.navigatorKey.currentContext!,
              routeSettings: RouteSettings(name: '/dialog/alert/sharesuccess'),
              builder: (context) {
                return AlertDialog(
                  insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  scrollable: true,
                  title: Text('Finished sharing to your chosen destination'),
                  content: getShareInstructions(),
                  actions: <Widget>[
                    TextButton(
                      child: Text('DONE'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              });
        }
      } finally {
        await file.delete();
      }
    } on Exception catch (e, st) {
      l.e('Error preparing or sharing log files... oh the irony!', error: e, stackTrace: st);
    } finally {
      setState(() {
        sharing = false;
      });
    }
  }

  Future<void> deleteAutofillLogs() async {
    final rootDir = await getStorageDirectory();
    final directory = Directory('${rootDir.path}/logs');
    if (!await directory.exists()) {
      return;
    }
    final allFiles = directory.listSync();
    var fileList = allFiles.whereType<File>().where((item) => item.path.contains('autofill-')).toList(growable: false);

    if (fileList.isEmpty) {
      return;
    }
    await Future.wait([
      for (var file in fileList) file.delete(),
    ]);
  }

  Future<List<ArchiveFile>> getAutofillLogs() async {
    final rootDir = await getStorageDirectory();
    final directory = Directory('${rootDir.path}/logs');
    if (!await directory.exists()) {
      return [];
    }
    final allFiles = directory.listSync();
    List<ArchiveFile> archiveFiles = [];
    var fileList = allFiles
        .whereType<File>()
        .map((item) => item.path)
        .where((item) => item.contains('autofill-'))
        .toList(growable: false);

    if (fileList.isEmpty) {
      return [];
    }
    var statResults = await Future.wait([
      for (var path in fileList) FileStat.stat(path),
    ]);

    var dates = <String, DateTime>{
      for (var i = 0; i < fileList.length; i += 1) fileList[i]: statResults[i].changed,
    };

    fileList.sort((a, b) => dates[a]!.compareTo(dates[b]!));

    final files = fileList.map((e) => File(e)).take(5).toList();

    for (var file in files) {
      var filename = path.relative(file.path, from: directory.path);
      final fileStream = InputFileStream(file.path);
      final af = ArchiveFile.stream(filename, fileStream);
      af.lastModTime = dates[file.path]!.millisecondsSinceEpoch ~/ 1000;
      archiveFiles.add(af);
    }
    return archiveFiles;
  }

//TODO:f: deduplicate
  getStorageDirectory() async {
    const autoFillMethodChannel = MethodChannel('com.keevault.keevault/autofill');
    if (KeeVaultPlatform.isIOS) {
      final path = await autoFillMethodChannel.invokeMethod('getAppGroupDirectory');
      return Directory(path);
    }
    final directory = await getApplicationSupportDirectory();
    return directory;
  }

  Widget _buildBottomBar(bool dark) {
    return LogBar(
      dark: dark,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Expanded(
              child: TextField(
                style: const TextStyle(fontSize: 20),
                controller: _filterController,
                onChanged: (s) => _refreshFilter(),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Filter log output',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 20),
            DropdownButton<Level>(
              value: _filterLevel,
              items: const [
                DropdownMenuItem(
                  value: Level.trace,
                  child: Text('TRACE'),
                ),
                DropdownMenuItem(
                  value: Level.debug,
                  child: Text('DEBUG'),
                ),
                DropdownMenuItem(
                  value: Level.info,
                  child: Text('INFO'),
                ),
                DropdownMenuItem(
                  value: Level.warning,
                  child: Text('WARNING'),
                ),
                DropdownMenuItem(
                  value: Level.error,
                  child: Text('ERROR'),
                ),
                DropdownMenuItem(
                  value: Level.fatal,
                  child: Text('FATAL'),
                )
              ],
              onChanged: (value) {
                _filterLevel = value ?? Level.info;
                _refreshFilter();
              },
            )
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() async {
    _scrollListenerEnabled = false;

    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    _scrollListenerEnabled = true;
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var text = event.lines.join('\n');
    return RenderedEvent(
      _currentId++,
      event.level,
      TextSpan(children: event.lines.map((line) => createSpan(line, event.level)).toList()),
      text.toLowerCase(),
    );
  }

  @override
  void dispose() {
    Logger.removeOutputListener(_callback);
    super.dispose();
  }

  TextSpan createSpan(String text, Level level) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: colorForLevel(level),
      ),
    );
  }

  colorForLevel(Level level) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (level) {
      case Level.fatal:
        return dark ? Colors.pink[300] : Colors.pink[700];
      case Level.error:
        return dark ? Colors.red[300] : Colors.red[700];
      case Level.warning:
        return dark ? Colors.orange[300] : Colors.orange[700];
      case Level.info:
        return dark ? Colors.blue[300] : Colors.blue[700];
      case Level.debug:
        return dark ? Colors.green[300] : Colors.green[700];
      default:
        return dark ? Colors.grey[300] : Colors.grey[700];
    }
  }

  Future<String> getDiagnosticInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.deviceInfo;

    return '''Diagnostic data:

Platform info:
${packageInfo.data}

Device info:
${deviceInfo.data}
''';
  }

  Widget getShareInstructions() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Text(
              'We need to be able to associate these logs with a description of the issue you are experiencing so please:'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
          child: Link(
            uri: Uri.parse('https://forum.kee.pm/'),
            target: LinkTarget.blank,
            builder: (context, followLink) {
              return InkWell(
                onTap: followLink,
                child: Text(
                  '1) Log in to the community forum',
                  style: theme.textTheme.titleMedium!.copyWith(
                      color: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                      fontWeight: FontWeight.w800),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
              '2) Post to a relevant existing topic or start a new one describing why you are sharing these logs',
              style: theme.textTheme.titleMedium!),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Link(
            uri: Uri.parse('https://forum.kee.pm/new-message?username=luckyrat&title=Kee%20Vault%20logs'),
            target: LinkTarget.blank,
            builder: (context, followLink) {
              return InkWell(
                onTap: followLink,
                child: Text(
                  '3) Send a new private message to luckyrat',
                  style: theme.textTheme.titleMedium!.copyWith(
                      color: theme.brightness == Brightness.light ? theme.primaryColor : Colors.white,
                      fontWeight: FontWeight.w800),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8.0, 0, 8.0),
          child: Text(
              'a) Click on the Upload button in the message box toolbar, find the Zip file, upload it and then send the message',
              style: theme.textTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0.0, 0, 8.0),
          child: Text(
              'b) We will use your username to match the topic you were contributing to but feel free to provide more details, especially if you have multiple ongoing conversation topics',
              style: theme.textTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
              'We have been extra careful to avoid including any personal information in the application logs but the nature of unexpected application problems is that occasionally unexpected things happen! If we do ever come across anything potentially sensitive we will delete it as soon as possible and notify you. We also encourage you to search through the contents of the files in the zip archive if you desire additional peace of mind before uploading the file.'),
        ),
      ],
    );
  }
}

class LogBar extends StatelessWidget {
  final bool dark;
  final Widget child;

  const LogBar({super.key, required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
