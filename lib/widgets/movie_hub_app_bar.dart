import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import 'movie_hub_icon.dart';

/// The home toolbar's visual treatment; navigation stays with its caller.
class MovieHubAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MovieHubAppBar({super.key, required this.accountAction});

  final Widget accountAction;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: CinemaPalette.headerBackground,
        foregroundColor: CinemaPalette.appBarText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: preferredSize.height,
        leadingWidth: 64,
        titleSpacing: 8,
        centerTitle: true,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: CinemaPalette.homeHeaderGradient),
        ),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: _ToolbarControl(
            child: Builder(
              builder: (context) => IconButton(
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 22),
              ),
            ),
          ),
        ),
        title: const _MovieHubWordmark(),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: _ToolbarControl(child: accountAction),
          ),
        ],
      );
}

class _ToolbarControl extends StatelessWidget {
  const _ToolbarControl({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: CinemaPalette.headerControl,
          border: Border.all(color: CinemaPalette.headerBorder),
          borderRadius: BorderRadius.circular(15),
        ),
        child: SizedBox(width: 48, height: 48, child: child),
      );
}

class _MovieHubWordmark extends StatelessWidget {
  const _MovieHubWordmark();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Movie Hub Downloader',
        header: true,
        excludeSemantics: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: CinemaPalette.gold.withValues(alpha: .35)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [CinemaPalette.headerControl, CinemaPalette.wine],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(1),
                  child: MovieHubIcon(size: 32),
                ),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: 'MOVIE ',
                          style: TextStyle(color: CinemaPalette.gold)),
                      TextSpan(
                          text: 'HUB',
                          style: TextStyle(color: CinemaPalette.appBarText)),
                    ]),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('DOWNLOADER',
                      style: TextStyle(
                        color: CinemaPalette.appBarText,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.2,
                        height: 1.1,
                      )),
                ],
              ),
            ],
          ),
        ),
      );
}
