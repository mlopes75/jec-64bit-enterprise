/// Classe utilitária responsável pela compressão extrema de marcas temporais
/// utilizando máscaras binárias e operações bitwise em blocos nativos de 64 bits.
class JecEnterprise64BitPacker {
  // Alfabeto Puro oficial JEC para o Século (25 letras, sem o 'O')
  static const String alphaTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ";

  // Tabela Híbrida JEC para os restantes campos de tempo (35 Símbolos)
  static const String jecTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ1234567890";

  /// 1. EMPACOTAMENTO: Une os metadados e o tempo cirúrgico em exatamente 64 bits (8 Bytes).
  /// Aloca os 7 bits mais significativos (do topo) livres para uso customizado do Data Center.
  static int pack({
    required int headerBits,       // 7 bits livres (0 a 127) para metadados/Servidor
    required String seculo,        // 5 bits (25 letras do alfabeto JEC)
    required int ano,             // 7 bits puros (suporta anos de 0 a 99)
    required int mes,             // 4 bits (1 a 12)
    required int dia,             // 5 bits (1 a 31)
    required int hora,            // 5 bits (0 a 23)
    required int minuto,          // 6 bits (0 a 59)
    required int segundo,         // 6 bits (0 a 59)
    required int microssegundos,  // 20 bits (0 a 999.999)
  }) {
    // Aplicação rigorosa das máscaras binárias para proteção do barramento
    int clHeader = headerBits & 0x7F; 
    int idxSeculo = alphaTable.indexOf(seculo.toUpperCase()) & 0x1F; 
    int clAn = ano & 0x7F; 
    int clMes = mes & 0x0F; 
    int clDia = dia & 0x1F; 
    int clHr = hora & 0x1F; 
    int clMin = minuto & 0x3F; 
    int clSeg = segundo & 0x3F; 
    int clMc = microssegundos & 0xFFFFF; 

    // Montagem binária por deslocamento (Bitwise Shift)
    // Soma exata: 7 + 5 + 7 + 4 + 5 + 5 + 6 + 6 + 20 = 64 BITS
    return (clHeader << 57) |
           (idxSeculo << 52) |
           (clAn << 45) |
           (clMes << 41) |
           (clDia << 36) |
           (clHr << 31) |
           (clMin << 25) |
           (clSeg << 19) |
           clMc;
  }

  /// 2. RECONSTRUÇÃO: Desempacota os 64 bits e reconstrói a String JEC com os pontos
  static String unpackToHumanString(int packedValue, {String alias = "A"}) {
    int idxSeculo = (packedValue >> 52) & 0x1F;
    int ano = (packedValue >> 45) & 0x7F;
    int mes = (packedValue >> 41) & 0x0F;
    int dia = (packedValue >> 36) & 0x1F;
    int hora = (packedValue >> 31) & 0x1F;
    int minuto = (packedValue >> 25) & 0x3F;
    int segundo = (packedValue >> 19) & 0x3F;
    int mcs = packedValue & 0xFFFFF;

    // Recuperação dos caracteres visuais a partir das tabelas JEC
    String charSeculo = alphaTable[idxSeculo];
    String strAno = ano.toString().padLeft(2, '0');
    
    String strMes = jecTable[mes - 1];
    String strDia = jecTable[dia - 1];
    String strHora = jecTable[hora];
    String strMin = jecTable[minuto];
    String strSeg = jecTable[segundo];
    String strMcs = mcs.toString().padLeft(6, '0');

    // Injeta os pontos separadores para exibição humana
    return "${alias.toUpperCase()}.$charSeculo$strAno$strMes$strDia$strHora$strMin$strSeg.$strMcs";
  }

  /// 3. EXTRAÇÃO DE CABEÇALHO: Puxa os 7 bits de metadados do topo em 1 ciclo de clock
  static int extractHeaderBits(int packedValue) {
    return (packedValue >> 57) & 0x7F;
  }
}
