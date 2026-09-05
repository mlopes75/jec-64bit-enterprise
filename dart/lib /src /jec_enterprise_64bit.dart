// lib/src/jec_enterprise_64bit.dart

class JecEnterprise64Bit {
  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Tabela Alfa Base: 25 letras (A-Z, sem a letra 'O').
  static const String alphaTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ";

  /// Mês (1..12):
  /// 1..9 = "1".."9", 10 = A, 11 = B, 12 = C
  static const String mapMes = "123456789ABC";

  /// Dia (1..31):
  /// A..N = 1..14, P..Z = 15..25, 1..6 = 26..31
  static const String mapDia = "ABCDEFGHIJKLMNPQRSTUVWXYZ123456";

  /// Hora (0..23):
  /// A..N = 0..13, P..X = 14..23
  static const String mapHora = "ABCDEFGHIJKLMNPQRSTUVWX";

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. EMPACOTAMENTO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Empacota todos os campos em uma estrutura lógica de 64 bits.
  static int pack({
    required int headerBits,
    required String seculo,
    required int ano,
    required int mes,
    required int dia,
    required int hora,
    required int minuto,
    required int segundo,
    required int microssegundos,
  }) {
    if (headerBits < 0 || headerBits > 63) {
      throw ArgumentError.value(
        headerBits,
        'headerBits',
        'Deve estar entre 0 e 63 (6 bits).',
      );
    }

    if (seculo.length != 1) {
      throw ArgumentError.value(
        seculo,
        'seculo',
        'Deve conter exatamente um caractere.',
      );
    }

    final String secUpper = seculo.toUpperCase();
    final int idxSeculo = alphaTable.indexOf(secUpper);

    if (idxSeculo == -1) {
      throw ArgumentError.value(
        seculo,
        'seculo',
        'Código inválido. Use uma letra A-Z, exceto O.',
      );
    }

    if (ano < 0 || ano > 99) {
      throw ArgumentError.value(ano, 'ano', 'Deve estar entre 0 e 99.');
    }

    if (mes < 1 || mes > 12) {
      throw ArgumentError.value(mes, 'mes', 'Deve estar entre 1 e 12.');
    }

    if (dia < 1 || dia > 31) {
      throw ArgumentError.value(dia, 'dia', 'Deve estar entre 1 e 31.');
    }

    if (hora < 0 || hora > 23) {
      throw ArgumentError.value(hora, 'hora', 'Deve estar entre 0 e 23.');
    }

    if (minuto < 0 || minuto > 59) {
      throw ArgumentError.value(minuto, 'minuto', 'Deve estar entre 0 e 59.');
    }

    if (segundo < 0 || segundo > 59) {
      throw ArgumentError.value(segundo, 'segundo', 'Deve estar entre 0 e 59.');
    }

    if (microssegundos < 0 || microssegundos > 999999) {
      throw ArgumentError.value(
        microssegundos,
        'microssegundos',
        'Deve estar entre 0 e 999999.',
      );
    }

    // Validação de data real (anos bissextos e limites do mês)
    final int validationYear = 2000 + ano;
    final DateTime validationDate = DateTime(validationYear, mes, dia);

    if (validationDate.year != validationYear ||
        validationDate.month != mes ||
        validationDate.day != dia) {
      throw ArgumentError('Data inválida: $dia/$mes/$ano.');
    }

    int result = 0;

    // Mascaramento individual garantido por bitwise OR
    result |= (headerBits & 0x3F) << 58;
    result |= (idxSeculo & 0x1F) << 53;
    result |= (ano & 0x7F) << 46;
    result |= (mes & 0x0F) << 42;
    result |= (dia & 0x1F) << 37;
    result |= (hora & 0x1F) << 32;
    result |= (minuto & 0x3F) << 26;
    result |= (segundo & 0x3F) << 20;
    result |= (microssegundos & 0xFFFFF);

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. DESEMPACOTAMENTO PARA STRING HUMANA
  // ═══════════════════════════════════════════════════════════════════════════

  static String unpackToHumanString(
    int packedValue, {
    String alias = "A",
  }) {
    final int idxSeculo = (packedValue >> 53) & 0x1F;
    final int ano = (packedValue >> 46) & 0x7F;
    final int mes = (packedValue >> 42) & 0x0F;
    final int dia = (packedValue >> 37) & 0x1F;
    final int hora = (packedValue >> 32) & 0x1F;
    final int minuto = (packedValue >> 26) & 0x3F;
    final int segundo = (packedValue >> 20) & 0x3F;
    final int microssegundos = packedValue & 0xFFFFF;

    final String charSeculo =
        (idxSeculo >= 0 && idxSeculo < alphaTable.length)
            ? alphaTable[idxSeculo]
            : '?';

    final String strAno = ano.toString().padLeft(2, '0');

    final String strMes =
        (mes >= 1 && mes <= 12) ? mapMes[mes - 1] : '?';

    final String strDia =
        (dia >= 1 && dia <= 31) ? mapDia[dia - 1] : '?';

    final String strHora =
        (hora >= 0 && hora < mapHora.length) ? mapHora[hora] : '?';

    final String strMin =
        (minuto >= 0 && minuto <= 59) ? minuto.toString().padLeft(2, '0') : '??';

    final String strSeg =
        (segundo >= 0 && segundo <= 59) ? segundo.toString().padLeft(2, '0') : '??';

    final String strMcs =
        (microssegundos >= 0 && microssegundos <= 999999)
            ? microssegundos.toString().padLeft(6, '0')
            : '??????';

    final String cleanAlias = alias.trim().isEmpty ? "A" : alias.toUpperCase();

    return "$cleanAlias."
        "$charSeculo"
        "$strAno"
        "$strMes"
        "$strDia"
        "$strHora"
        "$strMin"
        "$strSeg"
        ".$strMcs";
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. DESEMPACOTAMENTO PARA MAP
  // ═══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> unpack(int packedValue) {
    final int idxSeculo = (packedValue >> 53) & 0x1F;

    final String seculo =
        (idxSeculo >= 0 && idxSeculo < alphaTable.length)
            ? alphaTable[idxSeculo]
            : '?';

    return {
      'headerBits': (packedValue >> 58) & 0x3F,
      'seculoIdx': idxSeculo,
      'seculo': seculo,
      'ano': (packedValue >> 46) & 0x7F,
      'mes': (packedValue >> 42) & 0x0F,
      'dia': (packedValue >> 37) & 0x1F,
      'hora': (packedValue >> 32) & 0x1F,
      'minuto': (packedValue >> 26) & 0x3F,
      'segundo': (packedValue >> 20) & 0x3F,
      'microssegundos': packedValue & 0xFFFFF,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. EXTRAÇÃO DO HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extrai os 6 bits superiores do identificador.
  static int extractHeaderBits(int packedValue) {
    return (packedValue >> 58) & 0x3F;
  }
}
