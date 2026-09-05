class JecEnterprise64BitPacker {
  static const String alphaTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ";
  static const String jecTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ1234567890";

  /// 1. EMPACOTAMENTO: Exactamente 64 BITS
  static int pack({
    required int headerBits,       // 6 bits livres (0 a 63) -> Máscara 0x3F
    required String seculo,        // 5 bits -> Máscara 0x1F
    required int ano,             // 7 bits (0 a 99) -> Máscara 0x7F
    required int mes,             // 4 bits (1 a 12) -> Máscara 0x0F
    required int dia,             // 5 bits (1 a 31) -> Máscara 0x1F
    required int hora,            // 5 bits (0 a 23) -> Máscara 0x1F
    required int minuto,          // 6 bits (0 a 59) -> Máscara 0x3F
    required int segundo,         // 6 bits (0 a 59) -> Máscara 0x3F
    required int microssegundos,  // 20 bits (0 a 999.999) -> Máscara 0xFFFFF
  }) {
    int clHeader = headerBits & 0x3F; // 6 bits
    int idxSeculo = alphaTable.indexOf(seculo.toUpperCase()) & 0x1F; // 5 bits
    int clAn = ano & 0x7F; // 7 bits
    int clMes = mes & 0x0F; // 4 bits
    int clDia = dia & 0x1F; // 5 bits
    int clHr = hora & 0x1F; // 5 bits
    int clMin = minuto & 0x3F; // 6 bits
    int clSeg = segundo & 0x3F; // 6 bits
    int clMc = microssegundos & 0xFFFFF; // 20 bits

    // Shifts corrigidos para barramento de 64 bits:
    // (58, 53, 46, 42, 37, 32, 26, 20, 0)
    return (clHeader << 58) |
           (idxSeculo << 53) |
           (clAn << 46) |
           (clMes << 42) |
           (clDia << 37) |
           (clHr << 32) |
           (clMin << 26) |
           (clSeg << 20) |
           clMc;
  }

  /// 2. RECONSTRUÇÃO: Deslocamentos ajustados
  static String unpackToHumanString(int packedValue, {String alias = "A"}) {
    int idxSeculo = (packedValue >> 53) & 0x1F;
    int ano = (packedValue >> 46) & 0x7F;
    int mes = (packedValue >> 42) & 0x0F;
    int dia = (packedValue >> 37) & 0x1F;
    int hora = (packedValue >> 32) & 0x1F;
    int minuto = (packedValue >> 26) & 0x3F;
    int segundo = (packedValue >> 20) & 0x3F;
    int mcs = packedValue & 0xFFFFF;

    String charSeculo = alphaTable[idxSeculo];
    String strAno = ano.toString().padLeft(2, '0');
    
    String strMes = jecTable[mes - 1];
    String strDia = jecTable[dia - 1];
    String strHora = jecTable[hora];
    String strMin = jecTable[minuto];
    String strSeg = jecTable[segundo];
    String strMcs = mcs.toString().padLeft(6, '0');

    return "${alias.toUpperCase()}.$charSeculo$strAno$strMes$strDia$strHora$strMin$strSeg.$strMcs";
  }

  /// 3. EXTRAÇÃO DO HEADER: Puxa os 6 bits superiores
  static int extractHeaderBits(int packedValue) {
    return (packedValue >> 58) & 0x3F;
  }
}
