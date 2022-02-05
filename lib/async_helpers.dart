import 'package:tuple/tuple.dart';

Future<Tuple2<T1, T2>> waitConcurrently<T1, T2>(Future<T1> future1, Future<T2> future2) async {
  late T1 result1;
  late T2 result2;

  await Future.wait([future1.then((value) => result1 = value), future2.then((value) => result2 = value)]);

  return Future.value(Tuple2(result1, result2));
}
