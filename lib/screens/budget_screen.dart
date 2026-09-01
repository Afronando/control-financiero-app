import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../constants.dart';
import '../widgets/animated_money.dart';
import '../widgets/category_badge.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/glass.dart';

class BudgetScreen extends StatefulWidget {
  final ApiClient api;
  final int? year;
  final int? month;
  const BudgetScreen({super.key, required this.api, this.year, this.month});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetCategoryLine>? _lines;
  List<CategoryOption>? _archived;
  String? _error;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final lines = await widget.api.getBudget(year: widget.year, month: widget.month);
      setState(() => _lines = lines);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    }
  }

  Future<void> _loadArchived() async {
    try {
      final archived = await widget.api.getCategories(archived: true);
      setState(() => _archived = archived);
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  String _money(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  Future<void> _editEstimated(BudgetCategoryLine line) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _EditCategoryDialog(line: line),
    );
    if (result == null) return;
    setState(() {
      final idx = _lines!.indexOf(line);
      _lines![idx] = BudgetCategoryLine(
        categoryId: line.categoryId,
        name: line.name,
        emoji: line.emoji,
        group: line.group,
        estimated: result.estimated,
        actual: line.actual,
        alertThresholdPct: result.alertThresholdPct,
      );
    });
    try {
      await widget.api.setBudgetEstimated(line.categoryId, result.estimated, year: widget.year, month: widget.month);
      if (result.alertThresholdPct != line.alertThresholdPct) {
        await widget.api.setBudgetAlertThreshold(line.categoryId, result.alertThresholdPct, year: widget.year, month: widget.month);
      }
    } on ApiException {
      _load();
    }
  }

  Future<void> _addCategory() async {
    final result = await showGlassSheet<bool>(context: context, builder: (_) => _AddCategorySheet(api: widget.api));
    if (result == true) {
      _load();
      if (mounted) AppToast.success(context, 'Categoría creada');
    }
  }

  Future<void> _archive(BudgetCategoryLine line) async {
    try {
      await widget.api.setCategoryArchived(line.categoryId, true);
      _load();
      if (mounted) AppToast.success(context, 'Categoría archivada');
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  Future<void> _restore(CategoryOption c) async {
    try {
      await widget.api.setCategoryArchived(c.id, false);
      _load();
      _loadArchived();
      if (mounted) AppToast.success(context, 'Categoría restaurada');
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Presupuesto'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.close : Icons.archive_outlined),
            tooltip: 'Archivadas',
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              if (_showArchived) _loadArchived();
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: PressableScale(
        onTap: _addCategory,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppGradients.accent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: AppGradients.purple.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white),
              SizedBox(width: 6),
              Text('Categoría', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: TextStyle(color: muted)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : _lines == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(onRefresh: _load, child: _buildGrouped()),
          ),
        ),
      ),
    );
  }

  Widget _buildGrouped() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final error = Theme.of(context).colorScheme.error;
    final trackBg = Theme.of(context).colorScheme.surfaceContainerHighest;

    final groups = <String, List<BudgetCategoryLine>>{};
    for (final l in _lines!) {
      (groups[l.group] ??= []).add(l);
    }
    const order = ['necesidad', 'deseo', 'futuro', 'deuda'];
    var globalIndex = 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_showArchived) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Categorías archivadas', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (_archived == null)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else if (_archived!.isEmpty)
                  Text('No tienes categorías archivadas.', style: TextStyle(color: muted, fontSize: 13))
                else
                  for (final c in _archived!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CategoryBadge(categoryId: c.id, iconValue: c.emoji, size: 32),
                      title: Text(c.name),
                      trailing: TextButton(onPressed: () => _restore(c), child: const Text('Restaurar')),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final g in order)
          if (groups[g] != null && groups[g]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 8),
              child: Text(groupLabels[g] ?? g, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final line in groups[g]!)
              FadeSlideIn(
                index: globalIndex++,
                child: GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () => _editEstimated(line),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CategoryBadge(categoryId: line.categoryId, iconValue: line.emoji, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(line.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Row(
                                  children: [
                                    AnimatedMoney(
                                      value: line.actual,
                                      style: TextStyle(
                                        color: line.actual > line.estimated && line.estimated > 0 ? error : muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      ' / ${_money(line.estimated)}',
                                      style: TextStyle(
                                        color: line.actual > line.estimated && line.estimated > 0 ? error : muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit, size: 14, color: muted.withValues(alpha: 0.6)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: line.estimated > 0 ? (line.actual / line.estimated).clamp(0, 1).toDouble() : 0,
                                ),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (context, animatedPct, _) {
                                  final over = line.actual > line.estimated && line.estimated > 0;
                                  return Stack(
                                    children: [
                                      Container(height: 6, color: trackBg),
                                      FractionallySizedBox(
                                        widthFactor: animatedPct,
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(gradient: over ? null : AppGradients.accent, color: over ? error : null),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.archive_outlined, size: 18, color: muted),
                        tooltip: 'Archivar',
                        onPressed: () => _archive(line),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        const SizedBox(height: 60),
      ],
    );
  }
}

class _EditResult {
  final double estimated;
  final int alertThresholdPct;
  _EditResult(this.estimated, this.alertThresholdPct);
}

class _EditCategoryDialog extends StatefulWidget {
  final BudgetCategoryLine line;
  const _EditCategoryDialog({required this.line});

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late final _controller = TextEditingController(text: widget.line.estimated.toStringAsFixed(2));
  late double _threshold = widget.line.alertThresholdPct.toDouble();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [categoryIcon(widget.line.emoji, size: 18), const SizedBox(width: 8), Text(widget.line.name)],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Presupuesto mensual'),
          ),
          const SizedBox(height: 12),
          Text('Alerta al ${_threshold.round()}% del presupuesto', style: const TextStyle(fontSize: 13)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: AppGradients.purple, thumbColor: AppGradients.purple),
            child: Slider(
              value: _threshold,
              min: 50,
              max: 95,
              divisions: 45,
              onChanged: (v) => setState(() => _threshold = v),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final v = double.tryParse(_controller.text.replaceAll(',', '.'));
            if (v == null || v < 0) return;
            Navigator.pop(context, _EditResult(v, _threshold.round()));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _AddCategorySheet extends StatefulWidget {
  final ApiClient api;
  const _AddCategorySheet({required this.api});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  String _group = 'necesidad';
  String _icon = 'Tag';
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingresa un nombre');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.addCategory(name: name, group: _group, emoji: _icon);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nueva categoría', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre'), autofocus: true),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'necesidad', label: Text('Necesidad')),
              ButtonSegment(value: 'deseo', label: Text('Deseo')),
              ButtonSegment(value: 'futuro', label: Text('Futuro')),
            ],
            selected: {_group},
            onSelectionChanged: (s) => setState(() => _group = s.first),
          ),
          const SizedBox(height: 12),
          const Text('Ícono', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
              itemCount: lucideIconNames.length,
              itemBuilder: (context, i) {
                final name = lucideIconNames[i];
                final selected = name == _icon;
                return InkWell(
                  onTap: () => setState(() => _icon = name),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? AppGradients.purple.withValues(alpha: 0.25) : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: selected ? Border.all(color: AppGradients.purple, width: 1.5) : null,
                    ),
                    alignment: Alignment.center,
                    child: categoryIcon(name, size: 18),
                  ),
                );
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          GradientButton(label: 'Crear categoría', loading: _saving, onPressed: _saving ? null : _submit),
        ],
      ),
    );
  }
}
