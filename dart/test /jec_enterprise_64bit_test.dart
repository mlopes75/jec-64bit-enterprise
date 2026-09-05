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

  test('Deve preservar corretamente o header quando o bit 63 está ativo', () {
  final packed = JecEnterprise64Bit.pack(
    headerBits: 63,
    seculo: 'Z',
    ano: 99,
    mes: 12,
    dia: 31,
    hora: 23,
    minuto: 59,
    segundo: 59,
    microssegundos: 999999,
  );

  expect(
    JecEnterprise64Bit.extractHeaderBits(packed),
    equals(63),
  );

  final data = JecEnterprise64Bit.unpack(packed);

  expect(data['headerBits'], equals(63));
  expect(data['ano'], equals(99));
  expect(data['hora'], equals(23));
});
}
