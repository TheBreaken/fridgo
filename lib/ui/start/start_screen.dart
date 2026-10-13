import 'package:flutter/material.dart';
import 'package:fridgo/l10n/app_localizations.dart';

class StartScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).appTitle)),
    );
  }
}
