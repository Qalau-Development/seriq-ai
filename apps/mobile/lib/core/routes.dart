// ExerciseArgs — аргументы маршрутов /exercise и /session: код упражнения и откуда открыта инструкция
class ExerciseArgs {
  final String id;
  final bool fromSession;

  const ExerciseArgs(this.id, {this.fromSession = false});
}
