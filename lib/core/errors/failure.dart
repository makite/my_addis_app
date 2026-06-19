import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// Represents a failure in the application.
@freezed
sealed class Failure with _$Failure {
  const factory Failure.server({
    required String message,
    int? statusCode,
  }) = ServerFailure;

  const factory Failure.cache({
    required String message,
  }) = CacheFailure;

  const factory Failure.network({
    required String message,
  }) = NetworkFailure;

  const factory Failure.unexpected({
    required String message,
  }) = UnexpectedFailure;
}
