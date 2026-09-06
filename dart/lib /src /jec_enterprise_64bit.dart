// lib/src/jec_enterprise_64bit.dart

class JecEnterprise64Bit {
  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Alfabeto Limpo JEC: 24 letras (A-Z, sem 'I' e 'O')
  static const String alphaTable = "ABCDEFGHJKLMNPQRSTUVWXYZ";

  /// Mês (1..12):
  /// A=Jan, B=Fev, C=Mar, D=Abr, E=Mai, F=Jun, G=Jul, H=Ago, J=Set, K=Out, L=Nov, M=Dez
  static const String mapMes = "ABCDEFGHJKLM";

  /// Dia (1..31):
  /// A..Z = 1..24, 5..1 = 25..31
  static const String mapDia = "ABCDEFGHJKLMNPQRSTUVWXYZ123456";

  /// Hora (0..23):
  /// Z=00, A=01, B=02, ... Y=23
  static const String mapHora = "ZABCDEFGHJKLMNPQRSTUVWXY";

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
    // Validação: Header (7 bits - 0 a 127)
    if (headerBits < 0 || headerBits > 127) {
      throw ArgumentError.value(
        headerBits,
        'headerBits',
        'Deve estar entre 0 e 127 (7 bits).',
      );
    }

    // Validação: Século
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
        'Código inválido. Use uma letra A-Z, exceto I e O.',
      );
    }

    if (idxSeculo > 14) {
      throw ArgumentError.value(
        seculo,
        'seculo',
        'Século inválido. Use A-Q (0-14) para o ciclo de 1500 anos.',
      );
    }

    // Validação: Ano
    if (ano < 0 || ano > 99) {
      throw ArgumentError.value(ano, 'ano', 'Deve estar entre 0 e 99.');
    }

    // Validação: Mês
    if (mes < 1 || mes > 12) {
      throw ArgumentError.value(mes, 'mes', 'Deve estar entre 1 e 12.');
    }

    // Validação: Dia
    if (dia < 1 || dia > 31) {
      throw ArgumentError.value(dia, 'dia', 'Deve estar entre 1 e 31.');
    }

    // Validação: Hora
    if (hora < 0 || hora > 23) {
      throw ArgumentError.value(hora, 'hora', 'Deve estar entre 0 e 23.');
    }

    // Validação: Minuto
    if (minuto < 0 || minuto > 59) {
      throw ArgumentError.value(minuto, 'minuto', 'Deve estar entre 0 e 59.');
    }

    // Validação: Segundo
    if (segundo < 0 || segundo > 59) {
      throw ArgumentError.value(segundo, 'segundo', 'Deve estar entre 0 e 59.');
    }

    // Validação: Microssegundos
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

    // Empacotamento com os shifts corretos
    // Header: bits 63-57 (7 bits)
    result |= (headerBits & 0x7F) << 57;

    // Século: bits 56-53 (4 bits)
    result |= (idxSeculo & 0x0F) << 53;

    // Ano: bits 52-46 (7 bits)
    result |= (ano & 0x7F) << 46;

    // Mês: bits 45-42 (4 bits)
    result |= (mes & 0x0F) << 42;

    // Dia: bits 41-37 (5 bits)
    result |= (dia & 0x1F) << 37;

    // Hora: bits 36-32 (5 bits)
    result |= (hora & 0x1F) << 32;

    // Minuto: bits 31-26 (6 bits)
    result |= (minuto & 0x3F) << 26;

    // Segundo: bits 25-20 (6 bits)
    result |= (segundo & 0x3F) << 20;

    // Microssegundos: bits 19-0 (20 bits)
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
    final int idxSeculo = (packedValue >> 53) & 0x0F;
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
    final int idxSeculo = (packedValue >> 53) & 0x0F;

    final String seculo =
        (idxSeculo >= 0 && idxSeculo < alphaTable.length)
            ? alphaTable[idxSeculo]
            : '?';

    return {
      'headerBits': (packedValue >> 57) & 0x7F,
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

  /// Extrai os 7 bits superiores do identificador (User Space).
  static int extractHeaderBits(int packedValue) {
    return (packedValue >> 57) & 0x7F;
  }
}
