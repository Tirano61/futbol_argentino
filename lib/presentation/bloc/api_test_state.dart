part of 'api_test_bloc.dart';

sealed class ApiTestState {
  const ApiTestState();
}

final class ApiTestInitial extends ApiTestState {
  const ApiTestInitial();
}

final class ApiTestLoading extends ApiTestState {
  const ApiTestLoading();
}

final class ApiTestSuccess extends ApiTestState {
  const ApiTestSuccess(this.result);

  final ApiQueryResult result;
}

final class ApiTestFailure extends ApiTestState {
  const ApiTestFailure(this.failure);

  final ApiFailure failure;
}
