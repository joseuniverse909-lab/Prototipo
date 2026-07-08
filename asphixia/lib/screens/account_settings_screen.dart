import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _photoController;
  bool _isSaving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? '');
    _photoController = TextEditingController(text: _user?.photoURL ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = _user;
    if (user == null) return;

    setState(() => _isSaving = true);
    await user.updateDisplayName(_nameController.text.trim());
    await user.updatePhotoURL(_photoController.text.trim());
    await user.reload();

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta actualizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final photoUrl = _photoController.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
            child: photoUrl.isEmpty ? const Icon(Icons.person, size: 48) : null,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre de jugador',
            prefixIcon: Icon(Icons.badge),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _photoController,
          decoration: const InputDecoration(
            labelText: 'URL de foto de perfil',
            prefixIcon: Icon(Icons.image),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.email),
          title: const Text('Correo'),
          subtitle: Text(user?.email ?? 'Sin correo'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
