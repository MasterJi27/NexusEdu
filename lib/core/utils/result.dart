enum FailureKind { network, auth, server, quota, unknown }

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  final FailureKind kind;
  const Failure(this.message, {this.error, this.kind = FailureKind.unknown});
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  String get messageOrEmpty => this is Failure<T> ? (this as Failure<T>).message : '';
}
