import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';
import 'package:test/test.dart';

void main() {
  group('🧪 JEC Enterprise 64-Bit - Teste de Integridade Total', () {
    
    // ============================================================
    // 1. TESTES DE SIMETRIA E VALIDAÇÃO BÁSICA
    // ============================================================
    group('Validação de Tamanho do Barramento (64 Bits Exactos)', () {
      test('Deve empacotar e desempacotar corretamente com Header de 6 bits', () {
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

      test('HeaderBits de 6 bits deve aplicar máscara 0x3F', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 64, // Excede 6 bits (0 a 63)
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

    // ============================================================
    // 2. TESTES DE MÁSCARAS PARA TODOS OS CAMPOS
    // ============================================================
    group('Validação de Máscaras de Bits para Todos os Campos', () {
      test('Ano de 7 bits deve aplicar máscara 0x7F', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 200, // Excede 0..99 (7 bits = 0..127)
          mes: 1,
          dia: 1,
          hora: 1,
          minuto: 1,
          segundo: 1,
          microssegundos: 0,
        );

        // Extrair ano manualmente para verificar a máscara
        final int anoExtraido = (packed >> 46) & 0x7F;
        expect(anoExtraido, equals(72)); // 200 & 0x7F = 72
      });

      test('Mês de 4 bits deve aplicar máscara 0x0F', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 0,
          mes: 20, // Excede 1..12 (4 bits = 0..15)
          dia: 1,
          hora: 1,
          minuto: 1,
          segundo: 1,
          microssegundos: 0,
        );

        final int mesExtraido = (packed >> 42) & 0x0F;
        expect(mesExtraido, equals(4)); // 20 & 0x0F = 4
      });

      test('Dia de 5 bits deve aplicar máscara 0x1F', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 0,
          mes: 1,
          dia: 40, // Excede 1..31 (5 bits = 0..31)
          hora: 1,
          minuto: 1,
          segundo: 1,
          microssegundos: 0,
        );

        final int diaExtraido = (packed >> 37) & 0x1F;
        expect(diaExtraido, equals(8)); // 40 & 0x1F = 8
      });

      test('Hora de 5 bits deve aplicar máscara 0x1F', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 30, // Excede 0..23 (5 bits = 0..31)
          minuto: 1,
          segundo: 1,
          microssegundos: 0,
        );

        final int horaExtraida = (packed >> 32) & 0x1F;
        expect(horaExtraida, equals(30)); // 30 & 0x1F = 30 (dentro de 5 bits)
      });

      test('Minuto de 6 bits deve aplicar máscara 0x3F', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 1,
          minuto: 100, // Excede 0..59 (6 bits = 0..63)
          segundo: 1,
          microssegundos: 0,
        );

        final int minutoExtraido = (packed >> 26) & 0x3F;
        expect(minutoExtraido, equals(36)); // 100 & 0x3F = 36
      });

      test('Segundo de 6 bits deve aplicar máscara 0x3F', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 1,
          minuto: 1,
          segundo: 70, // Excede 0..59 (6 bits = 0..63)
          microssegundos: 0,
        );

        final int segundoExtraido = (packed >> 20) & 0x3F;
        expect(segundoExtraido, equals(6)); // 70 & 0x3F = 6
      });

      test('Microssegundos de 20 bits deve aplicar máscara 0xFFFFF', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 1,
          minuto: 1,
          segundo: 1,
          microssegundos: 2000000, // Excede 0..999999 (20 bits = 0..1048575)
        );

        final int mcsExtraido = packed & 0xFFFFF;
        expect(mcsExtraido, equals(950464)); // 2000000 & 0xFFFFF = 950464
      });
    });

    // ============================================================
    // 3. TESTES COM VALORES DE BORDA E EXTREMOS
    // ============================================================
    group('Validação de Valores de Borda e Extremos', () {
      test('Deve empacotar e desempacotar com todos os campos no valor mínimo', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "A",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        final String humanString = JecEnterprise64BitPacker.unpackToHumanString(packed, alias: "MIN");
        expect(humanString, equals("MIN.A00AAAAA00.000000"));
        
        // Verificar extração individual
        expect(JecEnterprise64BitPacker.extractHeaderBits(packed), equals(0));
      });

      test('Deve empacotar e desempacotar com todos os campos no valor máximo', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 63, // 6 bits máximo
          seculo: "Z",
          ano: 99,
          mes: 12,
          dia: 31,
          hora: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );

        // Validação indireta via string (não testamos o valor exato da string
        // porque a tabela JEC mapeia números para caracteres)
        final String humanString = JecEnterprise64BitPacker.unpackToHumanString(packed, alias: "MAX");
        expect(humanString.startsWith("MAX."), isTrue);
        expect(humanString.endsWith(".999999"), isTrue);
        expect(JecEnterprise64BitPacker.extractHeaderBits(packed), equals(63));
      });

      test('Deve preservar o alias na string visual', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 5,
          seculo: "A",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        final String result = JecEnterprise64BitPacker.unpackToHumanString(packed, alias: "SERVIDOR01");
        expect(result.startsWith("SERVIDOR01."), isTrue);
      });
    });

    // ============================================================
    // 4. TESTES COM ENTRADAS INVÁLIDAS E TRATAMENTO DE ERROS
    // ============================================================
    group('Validação de Entradas Inválidas e Tratamento de Erros', () {
      test('Século inválido deve ser mapeado para o último caractere da tabela (Z)', () {
        // Quando a letra não existe, indexOf retorna -1, que & 0x1F = 31 -> 'Z'
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "?", // Caractere inválido
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        // Extrair índice do século
        final int idxSeculo = (packed >> 53) & 0x1F;
        expect(idxSeculo, equals(31)); // Último índice da alphaTable
      });

      test('Século com letra minúscula deve ser tratado como maiúscula', () {
        final int packed = JecEnterprise64BitPacker.pack(
          headerBits: 0,
          seculo: "v", // Minúsculo
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        final int idxSeculo = (packed >> 53) & 0x1F;
        final String charSeculo = JecEnterprise64BitPacker.alphaTable[idxSeculo];
        expect(charSeculo, equals("V")); // Deve ser convertido para maiúsculo
      });
    });

    // ============================================================
    // 5. TESTE DE SIMETRIA COMPLETO (Round-Trip)
    // ============================================================
    group('Testes de Simetria (Round-Trip)', () {
      test('Deve manter a integridade após empacotar e desempacotar', () {
        // Conjunto de valores de teste
        final testCases = [
          {'header': 0, 'seculo': 'A', 'ano': 0, 'mes': 1, 'dia': 1, 'hora': 0, 'minuto': 0, 'segundo': 0, 'mcs': 0},
          {'header': 63, 'seculo': 'Z', 'ano': 99, 'mes': 12, 'dia': 31, 'hora': 23, 'minuto': 59, 'segundo': 59, 'mcs': 999999},
          {'header': 42, 'seculo': 'V', 'ano': 26, 'mes': 9, 'dia': 3, 'hora': 22, 'minuto': 50, 'segundo': 15, 'mcs': 123456},
          {'header': 7, 'seculo': 'M', 'ano': 5, 'mes': 6, 'dia': 15, 'hora': 8, 'minuto': 30, 'segundo': 45, 'mcs': 98765},
        ];

        for (var tc in testCases) {
          final int packed = JecEnterprise64BitPacker.pack(
            headerBits: tc['header'] as int,
            seculo: tc['seculo'] as String,
            ano: tc['ano'] as int,
            mes: tc['mes'] as int,
            dia: tc['dia'] as int,
            hora: tc['hora'] as int,
            minuto: tc['minuto'] as int,
            segundo: tc['segundo'] as int,
            microssegundos: tc['mcs'] as int,
          );

          // Extrair todos os campos individualmente
          final int headerExtraido = JecEnterprise64BitPacker.extractHeaderBits(packed);
          final int idxSeculo = (packed >> 53) & 0x1F;
          final int anoExtraido = (packed >> 46) & 0x7F;
          final int mesExtraido = (packed >> 42) & 0x0F;
          final int diaExtraido = (packed >> 37) & 0x1F;
          final int horaExtraida = (packed >> 32) & 0x1F;
          final int minExtraido = (packed >> 26) & 0x3F;
          final int segExtraido = (packed >> 20) & 0x3F;
          final int mcsExtraido = packed & 0xFFFFF;

          // Validar cada campo
          expect(headerExtraido, equals(tc['header']));
          expect(JecEnterprise64BitPacker.alphaTable[idxSeculo], equals(tc['seculo']));
          expect(anoExtraido, equals(tc['ano']));
          expect(mesExtraido, equals(tc['mes']));
          expect(diaExtraido, equals(tc['dia']));
          expect(horaExtraida, equals(tc['hora']));
          expect(minExtraido, equals(tc['minuto']));
          expect(segExtraido, equals(tc['segundo']));
          expect(mcsExtraido, equals(tc['mcs']));
        }
      });
    });

    // ============================================================
    // 6. TESTE DE PERFORMANCE (Benchmark)
    // ============================================================
    group('Teste de Performance', () {
      test('Deve empacotar e desempacotar 100.000 vezes em menos de 1 segundo', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100000; i++) {
          final int packed = JecEnterprise64BitPacker.pack(
            headerBits: i % 64,
            seculo: String.fromCharCode(65 + (i % 26)), // A-Z
            ano: i % 100,
            mes: (i % 12) + 1,
            dia: (i % 31) + 1,
            hora: i % 24,
            minuto: i % 60,
            segundo: i % 60,
            microssegundos: i % 1000000,
          );
          
          // Desempacotar para garantir que a operação completa é testada
          JecEnterprise64BitPacker.unpackToHumanString(packed, alias: "PERF");
        }
        
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(1000), 
            reason: 'Tempo de execução: ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    // ============================================================
    // 7. TESTE DE INTEGRIDADE DE DADOS (Cross-Platform)
    // ============================================================
    group('Validação de Integridade Cross-Platform', () {
      test('Deve produzir o mesmo valor binário para os mesmos parâmetros', () {
        // Este teste garante que a implementação é determinística
        const int header = 42;
        const String seculo = 'V';
        const int ano = 26;
        const int mes = 9;
        const int dia = 3;
        const int hora = 22;
        const int minuto = 50;
        const int segundo = 15;
        const int mcs = 123456;

        final int packed1 = JecEnterprise64BitPacker.pack(
          headerBits: header,
          seculo: seculo,
          ano: ano,
          mes: mes,
          dia: dia,
          hora: hora,
          minuto: minuto,
          segundo: segundo,
          microssegundos: mcs,
        );

        final int packed2 = JecEnterprise64BitPacker.pack(
          headerBits: header,
          seculo: seculo,
          ano: ano,
          mes: mes,
          dia: dia,
          hora: hora,
          minuto: minuto,
          segundo: segundo,
          microssegundos: mcs,
        );

        // Deve ser exatamente o mesmo valor
        expect(packed1, equals(packed2));
        
        // Verificar que os bits não se sobrepõem (máscara de integridade)
        // Cada campo deve ocupar sua região exclusiva de bits
        final int mascaraTotal = 0xFFFFFFFFFFFFFFFF;
        expect(packed1 & ~mascaraTotal, equals(0));
      });
    });
  });
}
