part of 'app_rating_cubit.dart';

@immutable
sealed class AppRatingState {}

final class AppRatingInitial extends AppRatingState {}

final class AppRatingReady extends AppRatingState {}
