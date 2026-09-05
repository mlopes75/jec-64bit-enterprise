import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';
import 'package:test/test.dart';

void main() {
  group('🧪 JEC Enterprise 64-Bit - Teste de Integridade Total', () {
    
    // ============================================================
    // 1. TESTES DE SIMETRIA E VALIDAÇÃO BÁSICA
    // ============================================================
    group('Validação de Tamanho do Barramento (64 Bits Exactos)', () {
      test('Deve empacotar e desempacotar corretamente com Header de 6 bits', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 42,
          seculo: "V",
          ano: 26,
          mes: 9,
          dia: 3,
          hora: 22, // Posição 22 no mapHora de 24 caracteres = 'X'
          minuto: 50,
          segundo: 15,
          microssegundos: 123456,
        );

        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(42));
        
        final String humanString = JecEnterprise64Bit.unpackToHumanString(
          packed, 
          alias: "LOG",
        );
        
        // Mês 9 = '9', Dia 3 = 'C', Hora 22 = 'X'
        expect(humanString, equals("LOG.V269CX5015.123456"));
      });

      test('HeaderBits fora do limite (0..63) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 64, // Excede 0..63
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

    // ============================================================
    // 2. TESTES DE VALIDAÇÃO DE LIMITES E EXCEÇÕES (Boundary Testing)
    // ============================================================
    group('Validação de Limites de Entrada e Tratamento de Exceções', () {
      test('Ano acima de 99 deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "A",
            ano: 200,
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

      test('Mês fora do intervalo 1..12 deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "A",
            ano: 0,
            mes: 20,
            dia: 1,
            hora: 1,
            minuto: 1,
            segundo: 1,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Dia fora do intervalo 1..31 deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "A",
            ano: 0,
            mes: 1,
            dia: 40,
            hora: 1,
            minuto: 1,
            segundo: 1,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Hora fora do intervalo 0..23 deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "A",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: 24, // Limite superior excedido
            minuto: 1,
            segundo: 1,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Microssegundos acima de 999999 deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "A",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: 1,
            minuto: 1,
            segundo: 1,
            microssegundos: 2000000,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 3. TESTES COM VALORES DE BORDA E EXTREMOS
    // ============================================================
    group('Validação de Valores de Borda e Extremos', () {
      test('Deve empacotar e desempacotar com todos os campos no valor mínimo', () {
        final int packed = JecEnterprise64Bit.pack(
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

        final String humanString = JecEnterprise64Bit.unpackToHumanString(packed, alias: "MIN");
        expect(humanString, equals("MIN.A001AA0000.000000"));
        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(0));
      });

      test('Deve empacotar e desempacotar com todos os campos no valor máximo', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 63,
          seculo: "Z",
          ano: 99,
          mes: 12,
          dia: 31,
          hora: 23, // Valida o mapeamento correto da hora 23 = 'Y'
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );

        final String humanString = JecEnterprise64Bit.unpackToHumanString(packed, alias: "MAX");
        expect(humanString.startsWith("MAX."), isTrue);
        expect(humanString.endsWith(".999999"), isTrue);
        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(63));
      });

      test('Deve preservar o alias na string visual', () {
        final int packed = JecEnterprise64Bit.pack(
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

        final String result = JecEnterprise64Bit.unpackToHumanString(packed, alias: "SERVIDOR01");
        expect(result.startsWith("SERVIDOR01."), isTrue);
      });
    });

    // ============================================================
    // 4. TESTES COM ENTRADAS INVÁLIDAS E TRATAMENTO DE ERROS
    // ============================================================
    group('Validação de Entradas Inválidas e Sanitização', () {
      test('Século fora da tabela alfa (A-Z exceto O) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "?",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Século em letra minúscula deve ser tratado e convertido para maiúscula', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "v",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        final int idxSeculo = (packed >> 53) & 0x1F;
        final String charSeculo = JecEnterprise64Bit.alphaTable[idxSeculo];
        expect(charSeculo, equals("V"));
      });
    });

    // ============================================================
    // 5. TESTE DE SIMETRIA COMPLETO (Round-Trip)
    // ============================================================
    group('Testes de Simetria (Round-Trip)', () {
      test('Deve manter a integridade após empacotar e desempacotar múltiplos cenários', () {
        final testCases = [
          {'header': 0, 'seculo': 'A', 'ano': 0, 'mes': 1, 'dia': 1, 'hora': 0, 'minuto': 0, 'segundo': 0, 'mcs': 0},
          {'header': 63, 'seculo': 'Z', 'ano': 99, 'mes': 12, 'dia': 31, 'hora': 23, 'minuto': 59, 'segundo': 59, 'mcs': 999999},
          {'header': 42, 'seculo': 'V', 'ano': 26, 'mes': 9, 'dia': 3, 'hora': 22, 'minuto': 50, 'segundo': 15, 'mcs': 123456},
          {'header': 7, 'seculo': 'M', 'ano': 5, 'mes': 6, 'dia': 15, 'hora': 8, 'minuto': 30, 'segundo': 45, 'mcs': 98765},
        ];

        for (var tc in testCases) {
          final int packed = JecEnterprise64Bit.pack(
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

          final int headerExtraido = JecEnterprise64Bit.extractHeaderBits(packed);
          final int idxSeculo = (packed >> 53) & 0x1F;
          final int anoExtraido = (packed >> 46) & 0x7F;
          final int mesExtraido = (packed >> 42) & 0x0F;
          final int diaExtraido = (packed >> 37) & 0x1F;
          final int horaExtraida = (packed >> 32) & 0x1F;
          final int minExtraido = (packed >> 26) & 0x3F;
          final int segExtraido = (packed >> 20) & 0x3F;
          final int mcsExtraido = packed & 0xFFFFF;

          expect(headerExtraido, equals(tc['header']));
          expect(JecEnterprise64Bit.alphaTable[idxSeculo], equals(tc['seculo']));
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
      test('Deve empacotar e desempacotar 100.000 vezes de forma eficiente', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100000; i++) {
          final int packed = JecEnterprise64Bit.pack(
            headerBits: i % 64,
            seculo: JecEnterprise64Bit.alphaTable[
              i % JecEnterprise64Bit.alphaTable.length
            ], // Garante que a letra 'O' nunca é gerada
            ano: i % 100,
            mes: (i % 12) + 1,
            dia: (i % 28) + 1, // Limita ao dia 28 para evitar datas inexistentes em fev/meses de 30 dias
            hora: i % 24,
            minuto: i % 60,
            segundo: i % 60,
            microssegundos: i % 1000000,
          );
          
          JecEnterprise64Bit.unpackToHumanString(packed, alias: "PERF");
        }
        
        stopwatch.stop();
        // Limite ajustado para 5000ms para evitar falhas falsas em pipelines de CI/CD
        expect(
          stopwatch.elapsedMilliseconds, 
          lessThan(5000), 
          reason: 'Tempo de execução excedeu o limite tolerável: ${stopwatch.elapsedMilliseconds}ms',
        );
      });
    });

    // ============================================================
    // 7. TESTE DE INTEGRIDADE DE DADOS (Cross-Platform)
    // ============================================================
    group('Validação de Integridade Cross-Platform', () {
      test('Deve produzir valor binário determinístico para a mesma entrada', () {
        const int header = 42;
        const String seculo = 'V';
        const int ano = 26;
        const int mes = 9;
        const int dia = 3;
        const int hora = 22;
        const int minuto = 50;
        const int segundo = 15;
        const int mcs = 123456;

        final int packed1 = JecEnterprise64Bit.pack(
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

        final int packed2 = JecEnterprise64Bit.pack(
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

        expect(packed1, equals(packed2));
      });
    });
  });
}
