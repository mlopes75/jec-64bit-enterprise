import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';
import 'package:test/test.dart';

void main() {
  group('Validação de Tamanho do Barramento (64 Bits Exactos)', () {
    test('Deve empacotar e desempacotar corretamente com Header de 6 bits', () {
      final int packed = JecEnterprise64BitPacker.pack(
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

      expect(JecEnterprise64BitPacker.extractHeaderBits(packed), equals(42));
      
      final String humanString = JecEnterprise64BitPacker.unpackToHumanString(packed, alias: "LOG");
      expect(humanString, equals("LOG.V26ICW225015.123456"));
    });

    test('HeaderBits de 6 bits deve aplicar máscara 0x3F', () {
      // 64 excede 6 bits (0 a 63), a máscara 0x3F transforma em 0
      final int packed = JecEnterprise64BitPacker.pack(
        headerBits: 64,
        seculo: "V",
        ano: 26,
        mes: 1,
        dia: 1,
        hora: 1,
        minuto: 1,
        segundo: 1,
        microssegundos: 0,
      );

      expect(JecEnterprise64BitPacker.extractHeaderBits(packed), equals(0));
    });
  });
}
