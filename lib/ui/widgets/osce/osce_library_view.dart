import 'package:auto_route/auto_route.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/osces/osce_library_repository.dart';
import 'package:flashcards/data/repositories/utils/user_claims.dart';
import 'package:flashcards/domain/models/osce/osce_folder/osce_library.dart';
import 'package:flashcards/domain/models/osce/simple_osce/simple_osce.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/error_screen.dart';
import 'package:flashcards/ui/widgets/osce/osce_list_shimmer.dart';
import 'package:flashcards/ui/widgets/osce/osce_ui_card.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flashcards/data/repositories/progress/progress_repository.dart';
import 'package:flashcards/domain/models/progress/osce_progress.dart';
import 'package:flashcards/ui/widgets/progress/osce_arms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// OSCE stations by speciality folder, with a random station button for
/// every folder and for all stations.
class OsceLibraryView extends StatefulWidget {
  const OsceLibraryView({super.key});

  @override
  State<OsceLibraryView> createState() => OsceLibraryViewState();
}

class OsceLibraryViewState extends State<OsceLibraryView> {
  OsceLibrary? _library;
  Object? _error;
  bool _hasOsce = false;

  /// Open folders, from the top level down.
  final _openFolders = <String>[];

  String? get _currentFolder => _openFolders.isEmpty ? null : _openFolders.last;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    final repo = context.read<OsceLibraryRepository>();
    final results = await Future.wait([
      repo.getLibrary(refresh: refresh),
      UserClaims.current().then((c) => c.hasOsce).catchError((_) => false),
    ]);
    if (!mounted) return;
    final result = results[0] as Result<OsceLibrary>;
    setState(() {
      _hasOsce = results[1] as bool;
      switch (result) {
        case Ok(:final value):
          _library = value;
          _error = null;
          // A folder that was deleted meanwhile is closed.
          _openFolders.removeWhere((id) => value.folder(id) == null);
        case Error(:final error):
          _error = error;
      }
    });
  }

  void _open(String folderId) => setState(() => _openFolders.add(folderId));

  void _back() => setState(() => _openFolders.removeLast());

  Future<void> _openStation(SimpleOsce osce) async {
    final canOpen = osce.isPaid ? await ensureOsceAccess(context) : true;
    if (canOpen && mounted) {
      context.router.push(OsceRoute(simpleOsce: osce));
    }
  }

  Future<void> _randomStation() async {
    final library = _library!;
    final station = library.randomStation(_currentFolder, hasAccess: _hasOsce);
    if (station != null) return _openStation(station);

    final hasPaid = library
        .allStationsUnder(_currentFolder)
        .any((s) => s.isPaid);
    if (hasPaid) {
      // Only premium stations here: offer the subscription.
      final unlocked = await ensureOsceAccess(context);
      if (!unlocked || !mounted) return;
      final paid = library.randomStation(_currentFolder, hasAccess: true);
      if (paid != null) await _openStation(paid);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('There are no stations here yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    if (library == null) {
      if (_error != null) {
        return ErrorScreen(
          errorMessage: extractErrorMessage(_error!),
          onReload: () => load(refresh: true),
        );
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalScreenPadding),
        child: OsceListShimmer(),
      );
    }

    final folderId = _currentFolder;
    final folders = library.subfolders(folderId);
    final stations = library.stationsIn(folderId);
    final total = library.allStationsUnder(folderId).length;

    return PopScope(
      canPop: _openFolders.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _openFolders.isNotEmpty) _back();
      },
      child: RefreshIndicator(
        onRefresh: () => load(refresh: true),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalScreenPadding,
            8,
            horizontalScreenPadding,
            32,
          ),
          children: [
            if (folderId != null)
              _FolderHeader(
                path: library.path(folderId).map((f) => f.name).toList(),
                onBack: _back,
              ),
            if (folderId == null)
              OsceGymStrip(
                load: () async {
                  final result = await context
                      .read<ProgressRepository>()
                      .getOsceStats();
                  return result is Ok<OsceProgressStats> ? result.value : null;
                },
              ),
            _RandomButton(
              total: total,
              inFolder: folderId != null,
              onPressed: total == 0 ? null : _randomStation,
            ),
            const SizedBox(height: 16),
            for (final folder in folders)
              _FolderTile(
                name: folder.name,
                stationCount: library.allStationsUnder(folder.id).length,
                subfolderCount: library.subfolders(folder.id).length,
                onTap: () => _open(folder.id),
              ),
            if (folders.isNotEmpty && stations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Text(
                  folderId == null ? 'Other stations' : 'Stations',
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            for (final station in stations)
              OscesUiCard(simpleOsce: station, hasOsce: _hasOsce),
            if (folders.isEmpty && stations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  folderId == null
                      ? 'No OSCE stations yet.'
                      : 'This folder is empty.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FolderHeader extends StatelessWidget {
  final List<String> path;
  final VoidCallback onBack;

  const _FolderHeader({required this.path, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path.last,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (path.length > 1)
                  Text(
                    path.take(path.length - 1).join(' / '),
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RandomButton extends StatelessWidget {
  final int total;
  final bool inFolder;
  final VoidCallback? onPressed;

  const _RandomButton({
    required this.total,
    required this.inFolder,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.colors.primaryContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onPressed,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.shuffle, color: context.colors.onPrimaryContainer),
        title: Text(
          'Random station',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.colors.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          inFolder
              ? 'From the $total stations in this folder'
              : 'From all $total stations',
          style: TextStyle(color: context.colors.onPrimaryContainer),
        ),
        trailing: Icon(
          Icons.play_arrow,
          color: context.colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final String name;
  final int stationCount;
  final int subfolderCount;
  final VoidCallback onTap;

  const _FolderTile({
    required this.name,
    required this.stationCount,
    required this.subfolderCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      '$stationCount ${stationCount == 1 ? 'station' : 'stations'}',
      if (subfolderCount > 0)
        '$subfolderCount ${subfolderCount == 1 ? 'folder' : 'folders'}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.folder, color: context.colors.primary, size: 30),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(details),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
