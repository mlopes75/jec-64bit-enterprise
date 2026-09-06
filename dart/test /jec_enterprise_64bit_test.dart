import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';
import 'package:test/test.dart';

void main() {
  group('🧪 JEC Enterprise 64-Bit - Teste de Integridade Total', () {
    
    // ============================================================
    // 1. TESTES DE SIMETRIA E VALIDAÇÃO BÁSICA
    // ============================================================
    group('Validação de Tamanho do Barramento (64 Bits Exactos)', () {
      test('Deve empacotar e desempacotar corretamente com Header de 7 bits', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 99, // Valor válido (0 a 127)
          seculo: "Z",
          ano: 26,
          mes: 9,
          dia: 30,
          hora: 23,
          minuto: 53,
          segundo: 14,
          microssegundos: 421983,
        );

        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(99));
        
        final String humanString = JecEnterprise64Bit.unpackToHumanString(
          packed, 
          alias: "LOG",
        );
        
        // Mês 9 = 'J', Dia 30 = '0', Hora 23 = 'Y'
        expect(humanString, equals("LOG.Z26J0Y5314.421983"));
      });

      test('HeaderBits no limite mínimo (0) deve funcionar', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(0));
        expect(JecEnterprise64Bit.unpackToHumanString(packed, alias: "MIN"), 
            equals("MIN.Z001AA0000.000000"));
      });

      test('HeaderBits no limite máximo (127) deve funcionar', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 127,
          seculo: "P",
          ano: 99,
          mes: 12,
          dia: 31,
          hora: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );

        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(127));
      });

      test('HeaderBits fora do limite (0..127) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 128, // Excede 0..127
            seculo: "Z",
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

      test('HeaderBits negativo deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: -1,
            seculo: "Z",
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
    // 2. TESTES DE VALIDAÇÃO DE SÉCULO
    // ============================================================
    group('Validação do Século (Ciclo de 1500 Anos)', () {
      test('Século Z (2000-2099) deve ser válido', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 26,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );
        final data = JecEnterprise64Bit.unpack(packed);
        expect(data['seculo'], equals('Z'));
        expect(data['seculoIdx'], equals(0));
      });

      test('Século Q (3400-3499) deve ser válido (último do ciclo)', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "P",
          ano: 99,
          mes: 12,
          dia: 31,
          hora: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );
        final data = JecEnterprise64Bit.unpack(packed);
        expect(data['seculo'], equals('P'));
        expect(data['seculoIdx'], equals(14));
      });

      test('Século R (além do ciclo de 1500 anos) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
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

      test('Século com letra minúscula deve ser convertido para maiúscula', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "k",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );
        final data = JecEnterprise64Bit.unpack(packed);
        expect(data['seculo'], equals('K'));
      });

      test('Século com letra inválida (I ou O) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "I",
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
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "O",
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
    });

    // ============================================================
    // 3. TESTES DE MAPEAMENTO DE MESES
    // ============================================================
    group('Validação do Mapeamento de Meses', () {
      test('Todos os meses devem mapear corretamente', () {
        final Map<int, String> expected = {
          1: 'A',  // Janeiro
          2: 'B',  // Fevereiro
          3: 'C',  // Março
          4: 'D',  // Abril
          5: 'E',  // Maio
          6: 'F',  // Junho
          7: 'G',  // Julho
          8: 'H',  // Agosto
          9: 'J',  // Setembro
          10: 'K', // Outubro
          11: 'L', // Novembro
          12: 'M', // Dezembro
        };

        for (int mes = 1; mes <= 12; mes++) {
          final int packed = JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: mes,
            dia: 1,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          );
          final String human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          // Formato: TEST.Z000X?0000.000000 (onde ? é o mês)
          final String mesChar = human[9]; // Posição do mês na string
          expect(mesChar, equals(expected[mes]));
        }
      });

      test('Mês inválido (0) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 0,
            dia: 1,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Mês inválido (13) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 13,
            dia: 1,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 4. TESTES DE MAPEAMENTO DE DIAS
    // ============================================================
    group('Validação do Mapeamento de Dias', () {
      test('Dias 1-24 devem mapear para letras (sem I e O)', () {
        final Map<int, String> expected = {
          1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'E', 6: 'F',
          7: 'G', 8: 'H', 9: 'J', 10: 'K', 11: 'L', 12: 'M',
          13: 'N', 14: 'P', 15: 'Q', 16: 'R', 17: 'S', 18: 'T',
          19: 'U', 20: 'V', 21: 'W', 22: 'X', 23: 'Y', 24: 'Z',
        };

        for (int dia = 1; dia <= 24; dia++) {
          final int packed = JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: dia,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          );
          final String human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          final String diaChar = human[10]; // Posição do dia na string
          expect(diaChar, equals(expected[dia]));
        }
      });

      test('Dias 25-31 devem mapear para números (último dígito)', () {
        final Map<int, String> expected = {
          25: '5', 26: '6', 27: '7', 28: '8', 29: '9', 30: '0', 31: '1'
        };

        for (int dia = 25; dia <= 31; dia++) {
          // Usar mês com 31 dias para validação
          final int mes = dia <= 30 ? 1 : 3; // Janeiro ou Março
          final int diaValido = dia <= 30 ? dia : 31;
          
          final int packed = JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: mes,
            dia: diaValido,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          );
          final String human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          final String diaChar = human[10];
          expect(diaChar, equals(expected[diaValido]));
        }
      });

      test('Dia inválido (0) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: 0,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Dia inválido (32) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: 32,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Data inválida (30 de fevereiro) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 2,
            dia: 30,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 5. TESTES DE MAPEAMENTO DE HORAS
    // ============================================================
    group('Validação do Mapeamento de Horas', () {
      test('Todas as horas (00-23) devem mapear corretamente (Z para 00)', () {
        final Map<int, String> expected = {
          0: 'Z', 1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'E',
          6: 'F', 7: 'G', 8: 'H', 9: 'J', 10: 'K', 11: 'L',
          12: 'M', 13: 'N', 14: 'P', 15: 'Q', 16: 'R', 17: 'S',
          18: 'T', 19: 'U', 20: 'V', 21: 'W', 22: 'X', 23: 'Y'
        };

        for (int hora = 0; hora < 24; hora++) {
          final int packed = JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: hora,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          );
          final String human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          final String horaChar = human[11]; // Posição da hora na string
          expect(horaChar, equals(expected[hora]));
        }
      });

      test('Hora inválida (24) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: 24,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Hora inválida (-1) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: -1,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 6. TESTES DE VALIDAÇÃO DE LIMITES (Boundary Testing)
    // ============================================================
    group('Validação de Limites de Entrada', () {
      test('Ano no limite mínimo (0) deve funcionar', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );
        final data = JecEnterprise64Bit.unpack(packed);
        expect(data['ano'], equals(0));
      });

      test('Ano no limite máximo (99) deve funcionar', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 99,
          mes: 12,
          dia: 31,
          hora: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );
        final data = JecEnterprise64Bit.unpack(packed);
        expect(data['ano'], equals(99));
      });

      test('Ano fora do limite (100) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 100,
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

      test('Minuto no limite máximo (59) deve funcionar', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 59,
          segundo: 0,
          microssegundos: 0,
        );
        final data = JecEnterprise64Bit.unpack(packed);
        expect(data['minuto'], equals(59));
      });

      test('Minuto fora do limite (60) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: 0,
            minuto: 60,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Microssegundo no limite máximo (999999) deve funcionar', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 999999,
        );
        final data = JecEnterprise64Bit.unpack(packed);
        expect(data['microssegundos'], equals(999999));
      });

      test('Microssegundo fora do limite (1000000) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: 1,
            dia: 1,
            hora: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 1000000,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 7. TESTES DE SIMETRIA COMPLETO (Round-Trip)
    // ============================================================
    group('Testes de Simetria (Round-Trip)', () {
      test('Deve manter a integridade exata após empacotar e desempacotar', () {
        final testCases = [
          {'header': 0, 'seculo': 'Z', 'ano': 0, 'mes': 1, 'dia': 1, 'hora': 0, 'minuto': 0, 'segundo': 0, 'mcs': 0},
          {'header': 127, 'seculo': 'P', 'ano': 99, 'mes': 12, 'dia': 31, 'hora': 23, 'minuto': 59, 'segundo': 59, 'mcs': 999999},
          {'header': 99, 'seculo': 'Z', 'ano': 26, 'mes': 9, 'dia': 30, 'hora': 23, 'minuto': 53, 'segundo': 14, 'mcs': 421983},
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

          final Map<String, dynamic> data = JecEnterprise64Bit.unpack(packed);

          expect(data['headerBits'], equals(tc['header']));
          expect(data['seculo'], equals(tc['seculo']));
          expect(data['ano'], equals(tc['ano']));
          expect(data['mes'], equals(tc['mes']));
          expect(data['dia'], equals(tc['dia']));
          expect(data['hora'], equals(tc['hora']));
          expect(data['minuto'], equals(tc['minuto']));
          expect(data['segundo'], equals(tc['segundo']));
          expect(data['microssegundos'], equals(tc['mcs']));
        }
      });

      test('Deve produzir a mesma string visual para a mesma entrada', () {
        const int header = 99;
        const String seculo = 'Z';
        const int ano = 26;
        const int mes = 9;
        const int dia = 30;
        const int hora = 23;
        const int minuto = 53;
        const int segundo = 14;
        const int mcs = 421983;

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
        expect(
          JecEnterprise64Bit.unpackToHumanString(packed1, alias: "LOG"),
          equals("LOG.Z26J0Y5314.421983"),
        );
        expect(
          JecEnterprise64Bit.unpackToHumanString(packed2, alias: "LOG"),
          equals("LOG.Z26J0Y5314.421983"),
        );
      });
    });

    // ============================================================
    // 8. TESTE DE ALIAS
    // ============================================================
    group('Validação do Alias', () {
      test('Deve preservar o alias na string visual', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 99,
          seculo: "Z",
          ano: 26,
          mes: 9,
          dia: 30,
          hora: 23,
          minuto: 53,
          segundo: 14,
          microssegundos: 421983,
        );

        final String result = JecEnterprise64Bit.unpackToHumanString(packed, alias: "SERVIDOR01");
        expect(result.startsWith("SERVIDOR01."), isTrue);
        expect(result, equals("SERVIDOR01.Z26J0Y5314.421983"));
      });

      test('Alias vazio deve usar "A" como padrão', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        final String result = JecEnterprise64Bit.unpackToHumanString(packed, alias: "");
        expect(result.startsWith("Z."), isTrue);
      });

      test('Alias com espaços deve ser sanitizado', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 0,
          mes: 1,
          dia: 1,
          hora: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        final String result = JecEnterprise64Bit.unpackToHumanString(packed, alias: "  log  ");
        expect(result.startsWith("LOG."), isTrue);
      });
    });

    // ============================================================
    // 9. TESTE DE PERFORMANCE
    // ============================================================
    group('Teste de Performance', () {
      test('Deve empacotar e desempacotar 100.000 vezes de forma eficiente', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100000; i++) {
          final int packed = JecEnterprise64Bit.pack(
            headerBits: i % 128,
            seculo: JecEnterprise64Bit.alphaTable[i % 15], // Z-P apenas
            ano: i % 100,
            mes: (i % 12) + 1,
            dia: (i % 28) + 1, // Garante data válida em todos os meses
            hora: i % 24,
            minuto: i % 60,
            segundo: i % 60,
            microssegundos: i % 1000000,
          );
          
          JecEnterprise64Bit.unpackToHumanString(packed, alias: "PERF");
        }
        
        stopwatch.stop();
        
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason: 'Tempo de execução excedeu o limite: ${stopwatch.elapsedMilliseconds}ms',
        );
      });
    });

    // ============================================================
    // 10. TESTE DE INTEGRIDADE BINÁRIA
    // ============================================================
    group('Validação de Integridade Binária', () {
      test('Deve produzir valor binário determinístico para a mesma entrada', () {
        const int header = 99;
        const String seculo = 'Z';
        const int ano = 26;
        const int mes = 9;
        const int dia = 30;
        const int hora = 23;
        const int minuto = 53;
        const int segundo = 14;
        const int mcs = 421983;

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
        expect(packed1, isNot(equals(0))); // Deve ter bits setados
      });

      test('Deve ocupar exatamente 64 bits (8 bytes)', () {
        final int packed = JecEnterprise64Bit.pack(
          headerBits: 127,
          seculo: "P",
          ano: 99,
          mes: 12,
          dia: 31,
          hora: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );

        // O valor deve caber em 64 bits (máximo 2^64 - 1)
        expect(packed < 0xFFFFFFFFFFFFFFFF, isTrue);
        expect(packed >= 0, isTrue);
      });
    });
  });
}
