import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/constants/app_constants.dart';
import 'package:nexus_edu/core/services/ai_chat_service.dart';
import 'package:nexus_edu/core/utils/result.dart';

/// Centralized snackbar helpers — single source for error/success styling
/// so screens never inline `SnackBar(content: Text(result['error']))`.
void showErrorSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message.isEmpty ? AppConstants.serverUnreachableMessage : message)),
  );
}

void showSuccessSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

void showSignInSnackBar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      action: SnackBarAction(
        label: 'Sign in',
        onPressed: () => context.push('/login'),
      ),
    ),
  );
}

/// Helper for `Result` — shows error snackbar on Failure, returns true if success.
bool handleResultError<T>(BuildContext context, Result<T> result) {
  if (result is Failure<T>) {
    showErrorSnackBar(context, result.message);
    return false;
  }
  return true;
}

/// Legacy map helper — for pre-migration endpoints returning {'error': ...}.
bool showMapErrorIfAny(BuildContext context, Map<String, dynamic> result) {
  final err = result['error'];
  if (err != null && err.toString().isNotEmpty) {
    showErrorSnackBar(context, err.toString());
    return true;
  }
  return false;
}

/// Ai-specific: routes AiSignInRequiredException to sign-in action, others to error.
void handleAiError(BuildContext context, Object e) {
  if (e is AiSignInRequiredException) {
    showSignInSnackBar(context, e);
  } else {
    showErrorSnackBar(context, e.toString());
  }
}
