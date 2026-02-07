import 'package:flutter/foundation.dart';

/// Network utility for handling retries and timeouts
class NetworkUtils {
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const int maxRetries = 2;

  /// Execute a future with retry logic
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = maxRetries,
    Duration timeout = defaultTimeout,
    String operationName = 'Operation',
  }) async {
    int attempt = 1;

    while (attempt <= maxAttempts) {
      try {
        debugPrint('🔄 $operationName (Attempt $attempt/$maxAttempts)...');

        final result = await operation().timeout(
          timeout,
          onTimeout: () =>
              throw TimeoutException('$operationName timed out after $timeout'),
        );

        debugPrint('✅ $operationName completed successfully');
        return result;
      } catch (e) {
        if (attempt == maxAttempts) {
          debugPrint('❌ $operationName failed after $maxAttempts attempts: $e');
          rethrow;
        }

        debugPrint(
          '⚠️ $operationName attempt $attempt failed: $e. Retrying...',
        );
        attempt++;

        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw Exception('$operationName failed');
  }
}

/// Exception for timeout errors
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
