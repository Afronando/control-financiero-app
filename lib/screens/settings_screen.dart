import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme_controller.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ApiClient api;
  final ThemeController themeController;
  const SettingsScreen({super.key, required this.api, required this.themeController});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AccountProfile? _account;
  PartnershipStatus? _partnership;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([widget.api.getAccount(), widget.api.getPartnershipStatus()]);
      setState(() {
        _account = results[0] as AccountProfile;
        _partnership = results[1] as PartnershipStatus;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    }
  }

  Future<void> _logout(BuildContext context) async {
    await widget.api.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api, themeController: widget.themeController)),
      (route) => false,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            )
          : (_account == null || _partnership == null)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionLabel('APARIENCIA'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AnimatedBuilder(
                        animation: widget.themeController,
                        builder: (context, _) {
                          return SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode)),
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('Sistema'),
                                icon: Icon(Icons.settings_suggest),
                              ),
                            ],
                            selected: {widget.themeController.mode},
                            onSelectionChanged: (s) => widget.themeController.setMode(s.first),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('CUENTA'),
                  _AccountCard(api: widget.api, account: _account!, onUpdated: _load),
                  const SizedBox(height: 20),
                  _sectionLabel('PRESUPUESTO 50/30/20'),
                  _BudgetPercentagesCard(api: widget.api, account: _account!, onUpdated: _load),
                  const SizedBox(height: 20),
                  _sectionLabel('PRESUPUESTO COMPARTIDO EN PAREJA'),
                  _PartnershipCard(api: widget.api, status: _partnership!, onUpdated: _load),
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Cerrar sesión'),
                      onTap: () => _logout(context),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  final ApiClient api;
  final AccountProfile account;
  final VoidCallback onUpdated;
  const _AccountCard({required this.api, required this.account, required this.onUpdated});

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  Future<void> _editName() async {
    final controller = TextEditingController(text: widget.account.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.api.updateAccount(name: name);
      widget.onUpdated();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña actual'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                try {
                  await widget.api.changePassword(
                    currentPassword: currentController.text,
                    newPassword: newController.text,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } on ApiException catch (e) {
                  setState(() => error = e.message);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(widget.account.name),
            subtitle: Text(widget.account.email),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: _editName,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar contraseña'),
            onTap: _changePassword,
          ),
        ],
      ),
    );
  }
}

class _BudgetPercentagesCard extends StatefulWidget {
  final ApiClient api;
  final AccountProfile account;
  final VoidCallback onUpdated;
  const _BudgetPercentagesCard({required this.api, required this.account, required this.onUpdated});

  @override
  State<_BudgetPercentagesCard> createState() => _BudgetPercentagesCardState();
}

class _BudgetPercentagesCardState extends State<_BudgetPercentagesCard> {
  late double _necesidad;
  late double _deseo;
  late double _futuro;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _necesidad = widget.account.necesidadPct;
    _deseo = widget.account.deseoPct;
    _futuro = widget.account.futuroPct;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateBudgetPercentages(necesidadPct: _necesidad, deseoPct: _deseo, futuroPct: _futuro);
      widget.onUpdated();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(0)}%'),
        Slider(value: value, min: 0, max: 100, divisions: 100, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _necesidad + _deseo + _futuro;
    final valid = (total - 100).abs() <= 0.5;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slider('Necesidades', _necesidad, (v) => setState(() => _necesidad = v)),
            _slider('Deseos', _deseo, (v) => setState(() => _deseo = v)),
            _slider('Futuro', _futuro, (v) => setState(() => _futuro = v)),
            Text(
              'Suma: ${total.toStringAsFixed(0)}%',
              style: TextStyle(
                color: valid ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_saving || !valid) ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnershipCard extends StatefulWidget {
  final ApiClient api;
  final PartnershipStatus status;
  final VoidCallback onUpdated;
  const _PartnershipCard({required this.api, required this.status, required this.onUpdated});

  @override
  State<_PartnershipCard> createState() => _PartnershipCardState();
}

class _PartnershipCardState extends State<_PartnershipCard> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onUpdated();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final s = widget.status;

    Widget content;
    switch (s.state) {
      case 'linked':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vinculado con ${s.partner!.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(s.partner!.email, style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(() => widget.api.unlinkPartnership(s.id!)),
              child: const Text('Dejar de compartir'),
            ),
          ],
        );
        break;
      case 'pending-sent':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitación enviada a ${s.partner!.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Esperando que acepte', style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(() => widget.api.declinePartnership(s.id!)),
              child: const Text('Cancelar invitación'),
            ),
          ],
        );
        break;
      case 'pending-received':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.partner!.name} te invitó', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(s.partner!.email, style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : () => _run(() => widget.api.acceptPartnership(s.id!)),
                  child: const Text('Aceptar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(() => widget.api.declinePartnership(s.id!)),
                  child: const Text('Rechazar'),
                ),
              ],
            ),
          ],
        );
        break;
      case 'code-pending':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu código', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            SelectableText(
              s.code!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text('Compártelo con tu pareja para que se una.', style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(() => widget.api.declinePartnership(s.id!)),
              child: const Text('Cancelar código'),
            ),
          ],
        );
        break;
      default:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vincula tu cuenta con tu pareja para ver los totales juntos.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo de tu pareja'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.api.invitePartner(_emailController.text.trim())),
                child: const Text('Enviar invitación'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('o', style: TextStyle(color: muted, fontSize: 12)),
                ),
                Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(() => widget.api.generatePartnershipCode()),
              child: const Text('Generar un código'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Ingresar con un código'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.api.joinPartnershipByCode(_codeController.text.trim())),
                child: const Text('Unirme'),
              ),
            ),
          ],
        );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
