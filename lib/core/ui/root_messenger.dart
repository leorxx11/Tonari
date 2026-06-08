import 'package:flutter/material.dart';

/// App-wide messenger for SnackBars that must outlive the page that triggered
/// them — e.g. a background import the user has already navigated away from.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
