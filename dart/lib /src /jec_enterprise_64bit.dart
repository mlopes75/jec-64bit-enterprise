/// Classe de dados estruturada que representa o protocolo desempacotado.
class JecDecoded {
  final int headerBits;
  final String seculo;
  final int ano;
  final int mes;
  final int dia;
  final int hora;
  final int minuto;
  final int segundo;
  final int microssegundos;

  const JecDecoded({
    required this.headerBits,
    required this.seculo,
    required this.ano,
    required this.mes,
    required this.dia,
    required this.hora,
    required this.minuto,
    required this.segundo,
    required this.microssegundos,
  });

  @override
  bool operator ==(Object other) =>
      other is JecDecoded &&
      headerBits == other.headerBits &&
      seculo == other.seculo &&
      ano == other.ano &&
      mes == other.mes &&
      dia == other.dia &&
      hora == other.hora &&
      minuto == other.minuto &&
      segundo == other.segundo &&
      microssegundos == other.microssegundos;

  @override
  int get hashCode => Object.hash(
        headerBits,
        seculo,
        ano,
        mes,
        dia,
        hora,
        minuto,
        segundo,
        microssegundos,
      );

  @override
  String toString() {
    return 'JecDecoded(headerBits: $headerBits, seculo: $seculo, '
        'ano: $ano, mes: $mes, dia: $dia, hora: $hora, '
        'minuto: $minuto, segundo: $segundo, microssegundos: $microssegundos)';
  }
}

/// Implementação robusta, multi-plataforma e altamente documentada do protocolo JecEnterprise 64-Bit.
class JecEnterprise64Bit {
  // --- ALFABETOS E CONVERSÕES (0..14 ciclo padrão, 15 código de exceção 'Y') ---
  static const List<String> _standardCycle = [
    'Z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P'
  ];

  static const List<String> _hoursMap = [
    'Z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M',
    'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y'
  ];

  static const List<String> _monthsMap = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M'
  ];

  static const List<String> _daysMap = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M',
    'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    '5', '6', '7', '8', '9', '0', '1'
  ];

  // --- TABELA DE ESPECIFICAÇÃO DO BIT LAYOUT (CONSTANTES DE SHIFT) ---
  static const int _shiftHeader         = 57;
  static const int _shiftSeculo         = 53;
  static const int _shiftAno            = 46;
  static const int _shiftMes            = 42;
  static const int _shiftDia            = 37;
  static const int _shiftHora           = 32;
  static const int _shiftMinuto         = 26;
  static const int _shiftSegundo        = 20;
  static const int _shiftMicrossegundos = 0;

  // --- MÁSCARAS DE HARDWARE ---
  static final BigInt _mask7Bits  = BigInt.from(0x7F);
  static final BigInt _mask6Bits  = BigInt.from(0x3F);
  static final BigInt _mask5Bits  = BigInt.from(0x1F);
  static final BigInt _mask4Bits  = BigInt.from(0x0F);
  static final BigInt _mask20Bits = BigInt.from(0xFFFFF);

  // --- FRONTEIRAS MATEMÁTICAS ---
  static final BigInt _twoPow64  = BigInt.one << 64;
  static final BigInt _maxUint64 = _twoPow64 - BigInt.one;

  // --- VALIDAÇÕES DE SEGURANÇA ---
  static void _checkRange(String name, int value, int min, int max) {
    if (value < min || value > max) {
      throw ArgumentError('$name inválido: $value. Esperado entre $min e $max.');
    }
  }

  static void _validateUint64(BigInt value) {
    if (value < BigInt.zero || value > _maxUint64) {
      throw ArgumentError('Valor fora do intervalo uint64: $value');
    }
  }

  static void _validateDate(String seculoLetter, int ano, int mes, int dia) {
    final cleanSeculo = seculoLetter.toUpperCase();
    final int centuryBase;

    if (cleanSeculo == 'Y') {
      centuryBase = 1900;
    } else {
      final index = _standardCycle.indexOf(cleanSeculo);
      if (index == -1) {
        throw ArgumentError('Século inválido para validação de data: $seculoLetter');
      }
      centuryBase = 2000 + (index * 100);
    }

    final int fullYear = centuryBase + ano;
    final date = DateTime(fullYear, mes, dia);

    if (date.year != fullYear || date.month != mes || date.day != dia) {
      throw ArgumentError('Data inválida: $dia/$mes/$fullYear (Inexistente no calendário)');
    }
  }

  // --- INTERRUPTORES DE FLUXO DO SÉCULO ---
  static int _packCentury(String seculoLetter) {
    final cleanLetter = seculoLetter.toUpperCase();
    if (cleanLetter == 'Y') return 0b1111;

    final index = _standardCycle.indexOf(cleanLetter);
    if (index == -1) {
      throw ArgumentError('Século inválido para o ciclo padrão: $seculoLetter');
    }
    return index;
  }

  static String _unpackCentury(int centuryBits) {
    if (centuryBits == 0b1111) return 'Y';
    if (centuryBits < 0 || centuryBits >= _standardCycle.length) {
      throw ArgumentError('Bits de século inválidos ou corrompidos: $centuryBits');
    }
    return _standardCycle[centuryBits];
  }

  // --- FLUXO DE CODIFICAÇÃO (PACKING) ---
  static BigInt pack({
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
    _checkRange('headerBits', headerBits, 0, 127);
    _checkRange('ano', ano, 0, 99);
    _checkRange('mes', mes, 1, 12);
    _checkRange('dia', dia, 1, 31);
    _checkRange('hora', hora, 0, 23);
    _checkRange('minuto', minuto, 0, 59);
    _checkRange('segundo', segundo, 0, 59);
    _checkRange('microssegundos', microssegundos, 0, 999999);

    _validateDate(seculo, ano, mes, dia);

    final int seculoPacked = _packCentury(seculo);
    BigInt result = BigInt.zero;

    result |= (BigInt.from(headerBits) & _mask7Bits) << _shiftHeader;
    result |= (BigInt.from(seculoPacked) & _mask4Bits) << _shiftSeculo;
    result |= (BigInt.from(ano) & _mask7Bits) << _shiftAno;
    result |= (BigInt.from(mes) & _mask4Bits) << _shiftMes;
    result |= (BigInt.from(dia) & _mask5Bits) << _shiftDia;
    result |= (BigInt.from(hora) & _mask5Bits) << _shiftHora;
    result |= (BigInt.from(minuto) & _mask6Bits) << _shiftMinuto;
    result |= (BigInt.from(segundo) & _mask6Bits) << _shiftSegundo;
    result |= (BigInt.from(microssegundos) & _mask20Bits) << _shiftMicrossegundos;

    return result;
  }

  // --- FLUXO DE DECODIFICAÇÃO (UNPACKING) ---
  static JecDecoded unpack(BigInt packed) {
    _validateUint64(packed);

    int headerBits = ((packed >> _shiftHeader) & _mask7Bits).toInt();
    int seculoBits = ((packed >> _shiftSeculo) & _mask4Bits).toInt();
    int ano        = ((packed >> _shiftAno) & _mask7Bits).toInt();
    int mes        = ((packed >> _shiftMes) & _mask4Bits).toInt();
    int dia        = ((packed >> _shiftDia) & _mask5Bits).toInt();
    int hora       = ((packed >> _shiftHora) & _mask5Bits).toInt();
    int minuto     = ((packed >> _shiftMinuto) & _mask6Bits).toInt();
    int segundo    = ((packed >> _shiftSegundo) & _mask6Bits).toInt();
    int microssegundos = ((packed >> _shiftMicrossegundos) & _mask20Bits).toInt();

    _checkRange('ano', ano, 0, 99);
    _checkRange('mes', mes, 1, 12);
    _checkRange('dia', dia, 1, 31);
    _checkRange('hora', hora, 0, 23);
    _checkRange('minuto', minuto, 0, 59);
    _checkRange('segundo', segundo, 0, 59);
    _checkRange('microssegundos', microssegundos, 0, 999999);

    final String seculo = _unpackCentury(seculoBits);
    _validateDate(seculo, ano, mes, dia);

    return JecDecoded(
      headerBits: headerBits,
      seculo: seculo,
      ano: ano,
      mes: mes,
      dia: dia,
      hora: hora,
      minuto: minuto,
      segundo: segundo,
      microssegundos: microssegundos,
    );
  }

  // --- FLUXO DE APRESENTAÇÃO ---
  static String toHumanString(JecDecoded decoded, {required String alias}) {
    String seculoChar = decoded.seculo;
    String anoStr     = decoded.ano.toString().padLeft(2, '0');
    String mesChar    = _monthsMap[decoded.mes - 1];
    String diaChar    = _daysMap[decoded.dia - 1];
    String horaChar   = _hoursMap[decoded.hora];
    String minStr     = decoded.minuto.toString().padLeft(2, '0');
    String segStr     = decoded.segundo.toString().padLeft(2, '0');
    String microStr   = decoded.microssegundos.toString().padLeft(6, '0');

    return "$alias.$seculoChar$anoStr$mesChar$diaChar$horaChar$minStr$segStr.$microStr";
  }

  static String unpackToHumanString(BigInt packed, {required String alias}) {
    final decoded = unpack(packed);
    return toHumanString(decoded, alias: alias);
  }
}
