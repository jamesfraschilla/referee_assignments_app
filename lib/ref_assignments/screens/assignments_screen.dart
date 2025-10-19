import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../store.dart';
import '../widgets/assignment_card.dart';
import 'assignment_detail_screen.dart';

class RefereeAssignmentsScreen extends StatefulWidget {
  const RefereeAssignmentsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final Future<void> Function() onToggleTheme;

  @override
  State<RefereeAssignmentsScreen> createState() =>
      _RefereeAssignmentsScreenState();
}

class _RefereeAssignmentsScreenState extends State<RefereeAssignmentsScreen> {
  late final RefereeAssignmentsStore _store;
  String? _snackbarMessage;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _store = RefereeAssignmentsStore()..addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.loadInitial();
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _store.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final state = _store.state;
    if (!mounted) return;
    if (state.error != null &&
        state.status != RefereeAssignmentsStatus.loading) {
      setState(() {
        _snackbarMessage ??= 'Failed to fetch latest assignments.';
      });
    } else {
      setState(() {
        _snackbarMessage = null;
      });
    }
  }

  Future<void> _refresh() => _store.refresh();

  @override
  Widget build(BuildContext context) {
    final state = _store.state;
    final theme = Theme.of(context);
    if (_snackbarMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _snackbarMessage == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_snackbarMessage!)));
        _snackbarMessage = null;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NBA Referee Assignments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isRefreshing ? null : _refresh,
            icon: state.isRefreshing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: widget.isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onPressed: () async {
              await widget.onToggleTheme();
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(theme, state)),
    );
  }

  Widget _buildBody(ThemeData theme, RefereeAssignmentsState state) {
    if (state.status == RefereeAssignmentsStatus.loading && state.day == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == RefereeAssignmentsStatus.error) {
      return _ErrorState(onRetry: _refresh);
    }

    final day = state.day;
    if (day == null || day.games.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(child: Text('No games posted for today yet.')),
          ],
        ),
      );
    }

    final lastUpdatedLabel = DateFormat.yMMMMd().add_jm().format(
      day.fetchedAt.toLocal(),
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: day.games.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Updated $lastUpdatedLabel',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            );
          }
          final assignment = day.games[index - 1];
          return AssignmentCard(
            assignment: assignment,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssignmentDetailScreen(
                    assignment: assignment,
                    assignmentDate: day.date,
                  ),
                ),
              ).then((_) => SystemChrome.setPreferredOrientations(
                    const [DeviceOrientation.portraitUp],
                  ));
            },
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Unable to load assignments at the moment.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
