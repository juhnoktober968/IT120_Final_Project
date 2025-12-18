import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'services/history_service.dart';

class SettingsPage extends StatefulWidget {
	const SettingsPage({super.key});

	@override
	State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
	bool _inProgress = false;

	Future<void> _confirmAndClear() async {
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Clear data'),
				content: const Text('This will permanently delete all history stored in Firebase. Continue?'),
				actions: [
					TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
					TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
				],
			),
		);

		if (confirmed == true) await _clearFirebaseData();
	}

	Future<void> _clearFirebaseData() async {
		setState(() => _inProgress = true);
		try {
			final db = FirebaseDatabase.instance;
			await db.ref('records').remove();

			// Clear local history notifier
			HistoryService.instance.recordsNotifier.value = [];

			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase data and local history cleared.')));
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear data: $e')));
		} finally {
			if (mounted) setState(() => _inProgress = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Settings')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					const ListTile(
						title: Text('App Name'),
						subtitle: Text('PH ID Classification'),
						leading: Icon(Icons.info_outline),
					),
					const SizedBox(height: 12),
					Card(
						child: ListTile(
							leading: const Icon(Icons.delete_forever, color: Colors.red),
							title: const Text('Clear App Data'),
							subtitle: const Text('Delete all saved records from Firebase and clear local history'),
							trailing: _inProgress ? const SizedBox(width:24, height:24, child: CircularProgressIndicator(strokeWidth:2)) : null,
							onTap: _inProgress ? null : _confirmAndClear,
						),
					),
				],
			),
		);
	}
}

