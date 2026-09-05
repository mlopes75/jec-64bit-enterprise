import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';
import 'package:test/test.dart';

void main() {
  group('Testes de Consistência JEC Enterprise 64-Bit', () {
    test('Deve empacotar e desempacotar mantendo a string intacta', () {
      final int packed = JecEnterprise64BitPacker.pack(
        headerBits: 42,
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

    test('Deve aplicar máscara binária no User Space para evitar overflow', () {
      final int packed = JecEnterprise64BitPacker.pack(
        headerBits: 128,
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
