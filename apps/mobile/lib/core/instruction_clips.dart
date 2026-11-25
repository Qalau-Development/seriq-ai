// InstructionClip — ролик инструкции: имя файла в assets/instruction и ключ подписи
class InstructionClip {
  final String name;
  final String captionKey;

  const InstructionClip(this.name, this.captionKey);

  String get asset => 'assets/instruction/instruction-$name.mp4';
}

// InstructionClips — правильные и неправильные примеры одного упражнения
class InstructionClips {
  final List<InstructionClip> correct;
  final List<InstructionClip> wrong;

  const InstructionClips({required this.correct, required this.wrong});
}

// instructionClips — ролики «правильно» и «неправильно» к каждому упражнению, как на сайте
const instructionClips = <String, InstructionClips>{
  'E01': InstructionClips(
    correct: [InstructionClip('e01-correct', 'clip_e01_correct')],
    wrong: [
      InstructionClip('e01-wrong-out-of-frame', 'clip_e01_out_of_frame'),
      InstructionClip('e01-wrong-top', 'clip_e01_top'),
      InstructionClip('e01-wrong-not-returned', 'clip_e01_not_returned'),
    ],
  ),
  'E02': InstructionClips(
    correct: [InstructionClip('e02-correct', 'clip_e02_correct')],
    wrong: [
      InstructionClip('e02-wrong-fist-hidden', 'clip_e02_fist_hidden'),
      InstructionClip('e02-wrong-top', 'clip_e02_top'),
    ],
  ),
  'E03': InstructionClips(
    correct: [InstructionClip('e03-correct', 'clip_e03_correct')],
    wrong: [
      InstructionClip('e03-wrong-dropped', 'clip_e03_dropped'),
      InstructionClip('e03-wrong-far', 'clip_e03_far'),
      InstructionClip('e03-wrong-top', 'clip_e03_top'),
    ],
  ),
  'E04': InstructionClips(
    correct: [InstructionClip('e04-correct', 'clip_e04_correct')],
    wrong: [
      InstructionClip('e04-wrong-out-of-frame', 'clip_e04_out_of_frame'),
      InstructionClip('e04-wrong-not-open', 'clip_e04_not_open'),
    ],
  ),
};

// nextClipIndex — следующий ролик по кругу
int nextClipIndex(int current, int total) =>
    total > 0 ? (current + 1) % total : 0;
