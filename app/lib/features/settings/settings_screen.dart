import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export data'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import data'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('See source on GitHub'),
            subtitle: const Text('github.com/aloyuv/didit'),
            onTap: () => launchUrl(
              Uri.parse('https://github.com/aloyuv/didit/'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
