import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/app_settings_cubit.dart';
import 'package:keevault/generated/l10n.dart';

class IntroVaultSummaryWidget extends StatefulWidget {
  const IntroVaultSummaryWidget({
    Key? key,
    required this.theme,
  }) : super(key: key);

  final ThemeData theme;

  @override
  State<IntroVaultSummaryWidget> createState() => _IntroVaultSummaryWidgetState();
}

class _IntroVaultSummaryWidgetState extends State<IntroVaultSummaryWidget> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1100),
    vsync: this,
  )..value = 1;
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.ease,
  );
  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return SizeTransition(
      sizeFactor: _animation,
      axis: Axis.vertical,
      axisAlignment: 1,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 1.5,
          sigmaY: 1.5,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.theme.canvasColor.withOpacity(0.75),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: RichText(
                          text: TextSpan(
                            style: widget.theme.textTheme.titleLarge,
                            children: [
                              WidgetSpan(
                                child: Icon(
                                  Icons.north_outlined,
                                  size: 32,
                                ),
                              ),
                              TextSpan(text: str.introFilter),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: RichText(
                            textAlign: TextAlign.right,
                            text: TextSpan(
                              style: widget.theme.textTheme.titleLarge,
                              children: [
                                WidgetSpan(
                                  child: Icon(
                                    Icons.north_outlined,
                                    size: 32,
                                  ),
                                ),
                                TextSpan(
                                  text: str.introSortYourEntries,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: widget.theme.textTheme.titleLarge,
                            children: [
                              WidgetSpan(
                                child: Icon(
                                  Icons.south_outlined,
                                  size: 32,
                                ),
                                alignment: PlaceholderAlignment.middle,
                              ),
                              TextSpan(
                                text: str.yourPasswordEntries,
                              ),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        child: Text(str.gotIt),
                        onPressed: () async {
                          final appSettings = BlocProvider.of<AppSettingsCubit>(context);
                          await _controller.reverse();
                          await appSettings.completeIntroShownVaultSummary();
                        },
                      )
                    ],
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
