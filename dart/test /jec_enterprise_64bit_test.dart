import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';
import 'package:test/test.dart';

void main() {
  group('🧪 JEC Enterprise 64-Bit — Teste de Integridade Total', () {
    // ============================================================
    // 1. SIMETRIA E VALIDAÇÃO BÁSICA
    // ============================================================
    group('Validação de Tamanho do Barramento (64 Bits Exatos)', () {
      test('Deve empacotar e desempacotar corretamente com Header de 7 bits', () {
        final BigInt packed = JecEnterprise64Bit.pack(
          headerBits: 99,
          seculo: "Z",
          ano: 26,
          mes: 9,
          dia: 30,
          horaUTC: 23,
          minuto: 53,
          segundo: 14,
          microssegundos: 421983,
        );

        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(99));

        final String humanString = JecEnterprise64Bit.unpackToHumanString(
          packed,
          alias: "LOG",
        );

        expect(humanString, equals("LOG.Z26J0Y5314.421983"));
      });

      test('HeaderBits no limite mínimo (0) deve funcionar', () {
        final BigInt packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 0,
          mes: 1,
          dia: 1,
          horaUTC: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );

        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(0));
        expect(
          JecEnterprise64Bit.unpackToHumanString(packed, alias: "MIN"),
          equals("MIN.Z001AA0000.000000"),
        );
      });

      test('HeaderBits no limite máximo (127) deve funcionar', () {
        final BigInt packed = JecEnterprise64Bit.pack(
          headerBits: 127,
          seculo: "P",
          ano: 99,
          mes: 12,
          dia: 31,
          horaUTC: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );

        expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(127));
      });

      test('HeaderBits fora do limite (128) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 128,
            seculo: "Z",
            ano: 26,
            mes: 1,
            dia: 1,
            horaUTC: 1,
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
            horaUTC: 1,
            minuto: 1,
            segundo: 1,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 2. VALIDAÇÃO DE SÉCULO
    // ============================================================
    group('Validação do Século (Ciclo de 1500 Anos)', () {
      test('Século Z (2000-2099) deve ser válido', () {
        final BigInt packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Z",
          ano: 26,
          mes: 1,
          dia: 1,
          horaUTC: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );
        final decoded = JecEnterprise64Bit.unpack(packed);
        expect(decoded.seculo, equals('Z'));
      });

      test('Século P (3400-3499) deve ser válido (último do ciclo)', () {
        final BigInt packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "P",
          ano: 99,
          mes: 12,
          dia: 31,
          horaUTC: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 999999,
        );
        final decoded = JecEnterprise64Bit.unpack(packed);
        expect(decoded.seculo, equals('P'));
      });

      test('Século Y (1900-1999) deve ser válido (código de exceção)', () {
        final BigInt packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "Y",
          ano: 99,
          mes: 12,
          dia: 31,
          horaUTC: 23,
          minuto: 59,
          segundo: 59,
          microssegundos: 0,
        );
        final decoded = JecEnterprise64Bit.unpack(packed);
        expect(decoded.seculo, equals('Y'));
      });

      test('Século R (fora do ciclo) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "R",
            ano: 0,
            mes: 1,
            dia: 1,
            horaUTC: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Século minúsculo deve ser convertido para maiúsculo', () {
        final BigInt packed = JecEnterprise64Bit.pack(
          headerBits: 0,
          seculo: "k",
          ano: 0,
          mes: 1,
          dia: 1,
          horaUTC: 0,
          minuto: 0,
          segundo: 0,
          microssegundos: 0,
        );
        final decoded = JecEnterprise64Bit.unpack(packed);
        expect(decoded.seculo, equals('K'));
      });

      test('Século I ou O (banidos) deve lançar ArgumentError', () {
        for (final letra in ['I', 'O']) {
          expect(
            () => JecEnterprise64Bit.pack(
              headerBits: 0,
              seculo: letra,
              ano: 0,
              mes: 1,
              dia: 1,
              horaUTC: 0,
              minuto: 0,
              segundo: 0,
              microssegundos: 0,
            ),
            throwsA(isA<ArgumentError>()),
          );
        }
      });
    });

    // ============================================================
    // 3. MAPEAMENTO DE MESES
    // ============================================================
    group('Validação do Mapeamento de Meses', () {
      test('Todos os meses devem mapear corretamente', () {
        const Map<int, String> expected = {
          1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'E', 6: 'F',
          7: 'G', 8: 'H', 9: 'J', 10: 'K', 11: 'L', 12: 'M',
        };

        for (int mes = 1; mes <= 12; mes++) {
          final BigInt packed = JecEnterprise64Bit.pack(
            headerBits: 0,
            seculo: "Z",
            ano: 0,
            mes: mes,
            dia: 1,
            horaUTC: 0,
            minuto: 0,
            segundo: 0,
            microssegundos: 0,
          );
          final human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          // Formato: TEST.Z000X?0000.000000
          // Índices: 0-3 = TEST, 4 = '.', 5 = século, 6-7 = ano,
          //          8 = mês, 9 = dia, 10 = hora
          expect(human[8], equals(expected[mes]));
        }
      });

      test('Mês inválido (0) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 0, dia: 1,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Mês inválido (13) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 13, dia: 1,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 4. MAPEAMENTO DE DIAS
    // ============================================================
    group('Validação do Mapeamento de Dias', () {
      test('Dias 1-24 devem mapear para letras (sem I e O)', () {
        const Map<int, String> expected = {
          1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'E', 6: 'F',
          7: 'G', 8: 'H', 9: 'J', 10: 'K', 11: 'L', 12: 'M',
          13: 'N', 14: 'P', 15: 'Q', 16: 'R', 17: 'S', 18: 'T',
          19: 'U', 20: 'V', 21: 'W', 22: 'X', 23: 'Y', 24: 'Z',
        };

        for (int dia = 1; dia <= 24; dia++) {
          final BigInt packed = JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: dia,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          );
          final human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          // Índice 9 = dia
          expect(human[9], equals(expected[dia]));
        }
      });

      test('Dias 25-31 devem mapear para números (último dígito)', () {
        const Map<int, String> expected = {
          25: '5', 26: '6', 27: '7', 28: '8', 29: '9', 30: '0', 31: '1',
        };

        for (int dia = 25; dia <= 31; dia++) {
          // Usar Março (31 dias) para todos — simplifica
          final BigInt packed = JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 3, dia: dia,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          );
          final human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          expect(human[9], equals(expected[dia]));
        }
      });

      test('Dia inválido (0) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 0,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Dia inválido (32) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 32,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Data inválida (30 de fevereiro) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 2, dia: 30,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('29 de fevereiro em ano não-bissexto deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 26, mes: 2, dia: 29,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('29 de fevereiro em ano bissexto (2024) deve funcionar', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 0, seculo: "Z", ano: 24, mes: 2, dia: 29,
          horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
        );
        final decoded = JecEnterprise64Bit.unpack(packed);
        expect(decoded.dia, equals(29));
        expect(decoded.mes, equals(2));
      });
    });

    // ============================================================
    // 5. MAPEAMENTO DE HORAS UTC
    // ============================================================
    group('Validação do Mapeamento de Horas UTC', () {
      test('Todas as horas UTC (00-23) devem mapear corretamente', () {
        const Map<int, String> expected = {
          0: 'Z', 1: 'A', 2: 'B', 3: 'C', 4: 'D', 5: 'E',
          6: 'F', 7: 'G', 8: 'H', 9: 'J', 10: 'K', 11: 'L',
          12: 'M', 13: 'N', 14: 'P', 15: 'Q', 16: 'R', 17: 'S',
          18: 'T', 19: 'U', 20: 'V', 21: 'W', 22: 'X', 23: 'Y',
        };

        for (int hora = 0; hora < 24; hora++) {
          final BigInt packed = JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
            horaUTC: hora, minuto: 0, segundo: 0, microssegundos: 0,
          );
          final human = JecEnterprise64Bit.unpackToHumanString(packed, alias: "TEST");
          // Índice 10 = hora
          expect(human[10], equals(expected[hora]),
              reason: 'Hora UTC $hora deveria ser ${expected[hora]}');
        }
      });

      test('Hora UTC inválida (24) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
            horaUTC: 24, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Hora UTC inválida (-1) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
            horaUTC: -1, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 6. LIMITES (Boundary Testing)
    // ============================================================
    group('Validação de Limites de Entrada', () {
      test('Ano no limite mínimo (0) deve funcionar', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
          horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
        );
        expect(JecEnterprise64Bit.unpack(packed).ano, equals(0));
      });

      test('Ano no limite máximo (99) deve funcionar', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 0, seculo: "Z", ano: 99, mes: 12, dia: 31,
          horaUTC: 23, minuto: 59, segundo: 59, microssegundos: 999999,
        );
        expect(JecEnterprise64Bit.unpack(packed).ano, equals(99));
      });

      test('Ano fora do limite (100) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 100, mes: 1, dia: 1,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Minuto no limite máximo (59) deve funcionar', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
          horaUTC: 0, minuto: 59, segundo: 0, microssegundos: 0,
        );
        expect(JecEnterprise64Bit.unpack(packed).minuto, equals(59));
      });

      test('Minuto fora do limite (60) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
            horaUTC: 0, minuto: 60, segundo: 0, microssegundos: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Microssegundo no limite máximo (999999) deve funcionar', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
          horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 999999,
        );
        expect(JecEnterprise64Bit.unpack(packed).microssegundos, equals(999999));
      });

      test('Microssegundo fora do limite (1000000) deve lançar ArgumentError', () {
        expect(
          () => JecEnterprise64Bit.pack(
            headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 1000000,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ============================================================
    // 7. ROUND-TRIP
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
          final packed = JecEnterprise64Bit.pack(
            headerBits: tc['header'] as int,
            seculo: tc['seculo'] as String,
            ano: tc['ano'] as int,
            mes: tc['mes'] as int,
            dia: tc['dia'] as int,
            horaUTC: tc['hora'] as int,
            minuto: tc['minuto'] as int,
            segundo: tc['segundo'] as int,
            microssegundos: tc['mcs'] as int,
          );

          final decoded = JecEnterprise64Bit.unpack(packed);

          expect(decoded.headerBits, equals(tc['header']));
          expect(decoded.seculo, equals(tc['seculo']));
          expect(decoded.ano, equals(tc['ano']));
          expect(decoded.mes, equals(tc['mes']));
          expect(decoded.dia, equals(tc['dia']));
          expect(decoded.hora, equals(tc['hora'])); // hora = UTC aqui
          expect(decoded.minuto, equals(tc['minuto']));
          expect(decoded.segundo, equals(tc['segundo']));
          expect(decoded.microssegundos, equals(tc['mcs']));
        }
      });
    });

    // ============================================================
    // 8. DERIVAÇÃO LOCAL (toLocal / toLocalString)
    // ============================================================
    group('Derivação de Hora Local (toLocal)', () {
      late BigInt packedUTC;

      setUp(() {
        // 30/09/2026 às 23:53:14.421983 UTC
        packedUTC = JecEnterprise64Bit.pack(
          headerBits: 99,
          seculo: "Z", ano: 26, mes: 9, dia: 30,
          horaUTC: 23, minuto: 53, segundo: 14, microssegundos: 421983,
        );
      });

      test('Offset +1 (Lisboa) deve fazer rollover de dia e mês', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        final local = JecEnterprise64Bit.toLocal(utc, offset: +1);

        // 30/09 23:53 UTC + 1h = 01/10 00:53 local
        expect(local.seculo, equals('Z'));
        expect(local.ano, equals(26));
        expect(local.mes, equals(10));   // Outubro
        expect(local.dia, equals(1));    // Dia 1
        expect(local.hora, equals(0));   // 00h
        expect(local.minuto, equals(53));
        expect(local.segundo, equals(14));
        expect(local.microssegundos, equals(421983));
      });

      test('Offset -3 (Brasil) deve manter o mesmo dia', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        final local = JecEnterprise64Bit.toLocal(utc, offset: -3);

        // 30/09 23:53 UTC - 3h = 30/09 20:53 local
        expect(local.mes, equals(9));
        expect(local.dia, equals(30));
        expect(local.hora, equals(20));
        expect(local.minuto, equals(53));
        expect(local.microssegundos, equals(421983));
      });

      test('Offset +9 (Tóquio) deve fazer rollover para o próximo dia', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        final local = JecEnterprise64Bit.toLocal(utc, offset: +9);

        // 30/09 23:53 UTC + 9h = 01/10 08:53 local
        expect(local.mes, equals(10));
        expect(local.dia, equals(1));
        expect(local.hora, equals(8));
        expect(local.minuto, equals(53));
      });

      test('Offset 0 deve retornar o mesmo valor UTC', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        final local = JecEnterprise64Bit.toLocal(utc, offset: 0);

        expect(local.mes, equals(utc.mes));
        expect(local.dia, equals(utc.dia));
        expect(local.hora, equals(utc.hora));
        expect(local.microssegundos, equals(utc.microssegundos));
      });

      test('Offset fora do limite (-13) deve lançar ArgumentError', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        expect(
          () => JecEnterprise64Bit.toLocal(utc, offset: -13),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Offset fora do limite (+15) deve lançar ArgumentError', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        expect(
          () => JecEnterprise64Bit.toLocal(utc, offset: +15),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('toLocalString deve retornar a string local correta', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        final str = JecEnterprise64Bit.toLocalString(utc, offset: +1, alias: "LOG");
        expect(str, equals("LOG.Z26KAZ5314.421983"));
      });

      test('toLocalString com offset -3 (Brasil) deve retornar string correta', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        final str = JecEnterprise64Bit.toLocalString(utc, offset: -3, alias: "LOG");
        expect(str, equals("LOG.Z26J0T5314.421983"));
      });

      test('Microssegundos devem ser preservados após toLocal', () {
        final utc = JecEnterprise64Bit.unpack(packedUTC);
        final local = JecEnterprise64Bit.toLocal(utc, offset: +5);
        expect(local.microssegundos, equals(utc.microssegundos));
      });
    });

    // ============================================================
    // 9. ALIAS
    // ============================================================
    group('Validação do Alias', () {
      test('Deve preservar o alias na string visual', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 99, seculo: "Z", ano: 26, mes: 9, dia: 30,
          horaUTC: 23, minuto: 53, segundo: 14, microssegundos: 421983,
        );
        final result = JecEnterprise64Bit.unpackToHumanString(packed, alias: "SERVIDOR01");
        expect(result.startsWith("SERVIDOR01."), isTrue);
        expect(result, equals("SERVIDOR01.Z26J0Y5314.421983"));
      });

      test('Alias vazio deve produzir string começando com "."', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
          horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
        );
        final result = JecEnterprise64Bit.unpackToHumanString(packed, alias: "");
        expect(result.startsWith("."), isTrue);
        expect(result, equals(".Z001AA0000.000000"));
      });

      test('Alias com espaços deve ser preservado (sem sanitização)', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 0, seculo: "Z", ano: 0, mes: 1, dia: 1,
          horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
        );
        final result = JecEnterprise64Bit.unpackToHumanString(packed, alias: "  log  ");
        expect(result.startsWith("  log  ."), isTrue);
      });
    });

    // ============================================================
    // 10. PERFORMANCE
    // ============================================================
    group('Teste de Performance', () {
      test('Deve empacotar e desempacotar 100.000 vezes de forma eficiente', () {
        final stopwatch = Stopwatch()..start();

        const List<String> validCenturies = [
          'Z','A','B','C','D','E','F','G','H','J','K','L','M','N','P'
        ];

        for (int i = 0; i < 100000; i++) {
          final packed = JecEnterprise64Bit.pack(
            headerBits: i % 128,
            seculo: validCenturies[i % 15],
            ano: i % 100,
            mes: (i % 12) + 1,
            dia: (i % 28) + 1,
            horaUTC: i % 24,
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
          reason: 'Tempo excedeu: ${stopwatch.elapsedMilliseconds}ms',
        );
      });
    });

    // ============================================================
    // 11. INTEGRIDADE BINÁRIA
    // ============================================================
    group('Validação de Integridade Binária', () {
      test('Deve produzir valor binário determinístico', () {
        final packed1 = JecEnterprise64Bit.pack(
          headerBits: 99, seculo: "Z", ano: 26, mes: 9, dia: 30,
          horaUTC: 23, minuto: 53, segundo: 14, microssegundos: 421983,
        );
        final packed2 = JecEnterprise64Bit.pack(
          headerBits: 99, seculo: "Z", ano: 26, mes: 9, dia: 30,
          horaUTC: 23, minuto: 53, segundo: 14, microssegundos: 421983,
        );

        expect(packed1, equals(packed2));
        expect(packed1, isNot(equals(BigInt.zero)));
      });

      test('Deve ocupar exatamente 64 bits (8 bytes)', () {
        final packed = JecEnterprise64Bit.pack(
          headerBits: 127, seculo: "P", ano: 99, mes: 12, dia: 31,
          horaUTC: 23, minuto: 59, segundo: 59, microssegundos: 999999,
        );
        final maxUint64 = (BigInt.one << 64) - BigInt.one;
        expect(packed <= maxUint64, isTrue);
        expect(packed >= BigInt.zero, isTrue);
      });

      test('ExtractHeaderBits deve retornar o header correto em todos os limites', () {
        for (final h in [0, 1, 63, 64, 99, 126, 127]) {
          final packed = JecEnterprise64Bit.pack(
            headerBits: h, seculo: "Z", ano: 0, mes: 1, dia: 1,
            horaUTC: 0, minuto: 0, segundo: 0, microssegundos: 0,
          );
          expect(JecEnterprise64Bit.extractHeaderBits(packed), equals(h));
        }
      });
    });
  });
}
