part of 'api_test_bloc.dart';

sealed class ApiTestEvent {
  const ApiTestEvent();
}

final class ApiQueryRequested extends ApiTestEvent {
  const ApiQueryRequested();
}
