import 'package:flutter/material.dart';

class DeepLinkEchoScreen extends StatelessWidget {
  final Map<String, String> params;
  final String? rawUrl;

  const DeepLinkEchoScreen({Key? key, required this.params, this.rawUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deep Link Echo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rawUrl != null) ...[
              Text('Raw URL:', style: Theme.of(context).textTheme.titleMedium),
              SelectableText(rawUrl!),
              const SizedBox(height: 16),
            ],
            Text('Parsed Parameters:', style: Theme.of(context).textTheme.titleMedium),
            ...params.entries.map((e) => Text('${e.key}: ${e.value}')),
          ],
        ),
      ),
    );
  }
}
