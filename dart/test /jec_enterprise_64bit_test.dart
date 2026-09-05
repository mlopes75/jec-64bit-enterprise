import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';
import 'package:test/test.dart';

void main() {
  group('Validação de Tamanho do Barramento (64 Bits Exactos)', () {
    test('Deve empacotar e desempacotar corretamente com Header de 6 bits', () {
      final int packed = JecEnterprise64Bit.pack(
        headerBits: 42, // Valor válido (0 a 63)
        seculo: "V",
        ano: 26,
        mes: 9,
        dia: 3,
        hora: 22,
        minuto: 50,
        segundo: 15,
        microssegundos: 123456,
      );

      expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(42));
      
      final String humanString = JecEnterprise64Bit.unpackToHumanString(
        packed, 
        alias: "LOG",
      );
      
      // Mês 9 = '9', Dia 3 = 'C', Hora 22 = 'W'
      expect(humanString, equals("LOG.V269CW5015.123456"));
    });

    test('HeaderBits fora do limite (0..63) deve lançar ArgumentError', () {
      expect(
        () => JecEnterprise64Bit.pack(
          headerBits: 64, // Fora do intervalo válido
          seculo: "V",
          ano: 26,
          mes: 1,
          dia: 1,
          hora: 1,
          minuto: 1,
          segundo: 1,
          microssegundos: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
