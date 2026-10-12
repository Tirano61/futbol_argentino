import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/text/text_normalizer.dart';

void main() {
  test('minúsculas y sin acentos', () {
    expect(TextNormalizer.normalize('Vélez Sarsfield'), 'velez sarsfield');
    expect(TextNormalizer.normalize('Güemes'), 'guemes');
    expect(TextNormalizer.normalize('Tristán Suárez'), 'tristan suarez');
    expect(TextNormalizer.normalize('ÑUÑOA'), 'nunoa');
  });

  test('apóstrofos y puntos se quitan sin separar', () {
    expect(TextNormalizer.normalize("Newell's Old Boys"), 'newells old boys');
    expect(TextNormalizer.normalize('Newell’s'), 'newells');
    expect(TextNormalizer.normalize('Estudiantes L.P.'), 'estudiantes lp');
  });

  test('otros signos y espacios repetidos separan palabras', () {
    expect(
      TextNormalizer.normalize('  Gimnasia y Esgrima (LP) - Mendoza '),
      'gimnasia y esgrima lp mendoza',
    );
    expect(TextNormalizer.normalize('River-PI'), 'river pi');
  });

  test('palabras', () {
    expect(TextNormalizer.words(' San  Martín '), ['san', 'martin']);
    expect(TextNormalizer.words('  '), isEmpty);
    expect(TextNormalizer.words('¡!'), isEmpty);
  });
}
