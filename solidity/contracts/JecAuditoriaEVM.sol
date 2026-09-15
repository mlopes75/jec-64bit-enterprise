// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title JecEnterprise64BitPacker
 * @author mlopes75
 * @notice Biblioteca corporativa de alta performance para o ecossistema JEC (Julia Epoch Compact).
 * @dev Compacta metadados (Header) e precisão temporal em microssegundos em exatamente 64 bits (8 bytes).
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  Layout do Barramento (64 Bits) — Alinhado com a especificação Dart:
 *  [ Header (7b) ][ Século (4b) ][ Ano (7b) ][ Mês (4b) ][ Dia (5b) ][ Hora (5b) ][ Min (6b) ][ Seg (6b) ][ Microssegundos (20b) ]
 *   63........57   56........53   52....46   45....42   41...37   36...32   31...26   25...20   19..................0
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  🕐 FILOSOFIA DO CICLO DE 1500 ANOS COM EXCEÇÃO HISTÓRICA
 * ═══════════════════════════════════════════════════════════════════════════════
 *  Índice (0-based) | Letra | Século
 *       0           |   Z   | 2000–2099
 *       1           |   A   | 2100–2199
 *       ...
 *      12           |   M   | 3200–3299
 *      14           |   P   | 3400–3499 (fecho do ciclo)
 *      15           |   Y   | 1900–1999 (CÓDIGO DE EXCEÇÃO — 0b1111)
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  📅 MAPEAMENTO DOS DIAS (Índice 0-based: Dia 1 = índice 0 = 'A')
 * ═══════════════════════════════════════════════════════════════════════════════
 *  Dias 1–24: A–Z (sem I e O)
 *  Dias 25–31: 5,6,7,8,9,0,1 (último dígito)
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  🕐 MAPEAMENTO DAS HORAS UTC (Índice 0-based: hora 0 = índice 0 = 'Z')
 * ═══════════════════════════════════════════════════════════════════════════════
 *  Índice | Letra | Hora UTC
 *    0    |   Z   |    0
 *    1    |   A   |    1
 *   ...
 *   12    |   M   |   12
 *   ...
 *   23    |   Y   |   23
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  🌍 SEMÂNTICA UTC E DERIVAÇÃO LOCAL
 * ═══════════════════════════════════════════════════════════════════════════════
 *  O campo Hora armazena **UTC 0**. A derivação para hora local NÃO é feita
 *  on-chain (seria proibitivamente caro em gás para rollover de calendário).
 *  A conversão para hora local é responsabilidade da camada Dart/backend,
 *  via `JecEnterprise64Bit.toLocal(decoded, offset)`.
 *
 *  Isso garante que um instante físico corresponde a exatamente uma string JEC,
 *  eliminando colisões entre fusos horários.
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  🔧 SEPARAÇÃO DE RESPONSABILIDADES (OTIMIZAÇÃO DE GAS)
 * ═══════════════════════════════════════════════════════════════════════════════
 *  - Funções de protocolo (pack, packWithIdx, unpack): destinadas a contratos
 *    on-chain, com mínimo consumo de gas. Retornam dados brutos (uint64 ou tuplas).
 *  - Funções de apresentação (unpackToHumanString): para uso off-chain ou em views,
 *    pois envolvem manipulação de strings (caro). Mantidas na mesma biblioteca,
 *    mas documentadas como "off-chain friendly".
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  ⚠️ NOTA SOBRE O BIT 63 (SIGNED vs UNSIGNED)
 * ═══════════════════════════════════════════════════════════════════════════════
 *  Em Solidity, `uint64` é unsigned — a ordenação binária é a canônica.
 *  Em Dart/SQL, `int`/`BIGINT` são signed (complemento de dois) — JECs com
 *  header >= 64 tornam-se negativos, invertendo a ordem.
 *
 *  A função `compareJec` abaixo documenta explicitamente que o Solidity está
 *  alinhado com a ordem canônica (uint64), servindo de referência para portes.
 *  No Dart, a equivalência é obtida via `a.toUnsigned(64).compareTo(b.toUnsigned(64))`.
 */
library JecEnterprise64BitPacker {

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTES DO PROTOCOLO (ALFABETOS)
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Ciclo padrão de 15 séculos (exclui 'Y' pois este virou código de exceção 15).
    ///         Índice 0 = 'Z' (2000–2099), índice 14 = 'P' (3400–3499).
    bytes15 internal constant STANDARD_CYCLE = "ZABCDEFGHJKLMNP";

    /// @notice Mapeamento de meses (índice 0 = Janeiro = 'A', ..., índice 11 = Dezembro = 'M').
    bytes12 private constant MAP_MES = "ABCDEFGHJKLM";

    /// @notice Mapeamento de dias (índice 0 = dia 1 = 'A', ..., índice 23 = dia 24 = 'Z',
    ///         índice 24 = dia 25 = '5', ..., índice 30 = dia 31 = '1').
    bytes31 private constant MAP_DIA = "ABCDEFGHJKLMNPQRSTUVWXYZ5678901";

    /// @notice Mapeamento de horas UTC (índice 0 = hora 0 = 'Z', ..., índice 23 = hora 23 = 'Y').
    bytes24 private constant MAP_HORA = "ZABCDEFGHJKLMNPQRSTUVWXY";

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. EMPACOTAMENTO (PACKING) — FUNÇÕES ON-CHAIN
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Empacota metadados e tempo em 64 bits utilizando a letra representativa do século.
     * @dev Conveniência off-chain. Para uso on-chain, prefira `packWithIdx` (mais barato).
     * @param headerBits 7 bits (0–127)
     * @param seculo String de exatamente 1 caractere (Z, A, B, ..., P, ou Y) em ASCII.
     * @param ano 0–99
     * @param mes 1–12
     * @param dia 1–31
     * @param horaUTC 0–23 (UTC — hora local é derivada off-chain)
     * @param minuto 0–59
     * @param segundo 0–59
     * @param microssegundos 0–999999
     * @return uint64 valor empacotado
     */
    function pack(
        uint64 headerBits,
        string memory seculo,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 horaUTC,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) internal pure returns (uint64) {
        uint64 seculoIdx = _getSeculoIndex(seculo);
        return packWithIdx(
            headerBits, seculoIdx, ano, mes, dia,
            horaUTC, minuto, segundo, microssegundos
        );
    }

    /**
     * @notice Empacota usando o índice nativo do século (proteção estrita contra estouro).
     * @dev Caminho preferencial para uso on-chain — evita manipulação de string.
     */
    function packWithIdx(
        uint64 headerBits,
        uint64 seculoIdx,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 horaUTC,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) internal pure returns (uint64) {
        // 1. Validações estritas de limites de negócio
        require(headerBits <= 127, "JEC: Header excede 7 bits");
        require(seculoIdx <= 15, "JEC: Seculo idx invalido (max 15)");
        require(ano <= 99, "JEC: Ano excede 7 bits (max 99)");
        require(mes >= 1 && mes <= 12, "JEC: Mes invalido (1-12)");
        require(dia >= 1 && dia <= 31, "JEC: Dia invalido (1-31)");
        require(horaUTC <= 23, "JEC: Hora UTC invalida (0-23)");
        require(minuto <= 59, "JEC: Minuto invalido (0-59)");
        require(segundo <= 59, "JEC: Segundo invalido (0-59)");
        require(microssegundos <= 999_999, "JEC: Microssegundos excede limite");

        // 2. Validação semântica e real do calendário
        _validateDate(seculoIdx, ano, mes, dia);

        // 3. Montagem segura orientada ao barramento de 64 bits
        return (headerBits << 57) |
               (seculoIdx << 53) |
               (ano << 46) |
               (mes << 42) |
               (dia << 37) |
               (horaUTC << 32) |
               (minuto << 26) |
               (segundo << 20) |
               microssegundos;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. DESEMPACOTAMENTO (UNPACKING) — FUNÇÕES ON-CHAIN
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Desempacota o payload bruto de 64 bits aplicando máscaras de isolamento estrutural.
     * @return headerBits 7 bits
     * @return seculoIdx 4 bits (0–15)
     * @return ano 0–99
     * @return mes 1–12
     * @return dia 1–31
     * @return horaUTC 0–23 (UTC)
     * @return minuto 0–59
     * @return segundo 0–59
     * @return microssegundos 0–999999
     */
    function unpack(uint64 packedValue) internal pure returns (
        uint64 headerBits,
        uint64 seculoIdx,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 horaUTC,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) {
        headerBits = (packedValue >> 57) & 0x7F;
        seculoIdx  = (packedValue >> 53) & 0x0F;
        ano        = (packedValue >> 46) & 0x7F;
        mes        = (packedValue >> 42) & 0x0F;
        dia        = (packedValue >> 37) & 0x1F;
        horaUTC    = (packedValue >> 32) & 0x1F;
        minuto     = (packedValue >> 26) & 0x3F;
        segundo    = (packedValue >> 20) & 0x3F;
        microssegundos = packedValue & 0xFFFFF;

        // Validação pós-extração para resguardar o domínio contra dados corrompidos
        require(seculoIdx <= 15, "JEC: Bits de seculo corrompidos");
        require(ano <= 99, "JEC: Bits de ano corrompidos");
        require(mes >= 1 && mes <= 12, "JEC: Bits de mes corrompidos");
        require(dia >= 1 && dia <= 31, "JEC: Bits de dia corrompidos");
        require(horaUTC <= 23, "JEC: Bits de hora UTC corrompidos");
        require(minuto <= 59, "JEC: Bits de minuto corrompidos");
        require(segundo <= 59, "JEC: Bits de segundo corrompidos");
        require(microssegundos <= 999_999, "JEC: Bits de microssegundos corrompidos");

        _validateDate(seculoIdx, ano, mes, dia);
    }

    /**
     * @notice Extrai apenas os bits de cabeçalho (7 bits superiores).
     */
    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 57) & 0x7F;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. COMPARAÇÃO CANÔNICA (ALINHAMENTO SIGNED/UNSIGNED)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Compara dois JECs de forma canônica (uint64 unsigned).
     * @dev Em Solidity, `uint64` já é unsigned — a ordenação binária é a canônica.
     *      Esta função existe para documentar explicitamente a equivalência com
     *      `compareJec` do Dart:
     *
     *          int compareJec(int a, int b) =>
     *              a.toUnsigned(64).compareTo(b.toUnsigned(64));
     *
     *      Em SQL (BIGINT signed), a equivalência é obtida via:
     *          ORDER BY jec & 0x7FFFFFFFFFFFFFFF
     *
     * @return -1 se a < b, 0 se a == b, 1 se a > b
     */
    function compareJec(uint64 a, uint64 b) internal pure returns (int8) {
        if (a < b) return -1;
        if (a > b) return 1;
        return 0;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. VERSÃO DA SPEC
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Retorna a versão da spec JEC implementada por esta biblioteca.
     * @dev Útil para auditoria e para detecção de incompatibilidades cross-platform.
     */
    function specVersion() internal pure returns (string memory) {
        return "1.0.0";
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. FUNÇÕES DE APRESENTAÇÃO (OFF-CHAIN / VIEW) — USO RESTRITO A STRINGS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Desempacota e retorna a string visual idêntica à saída do ecossistema Dart.
     * @dev Esta função usa manipulação de strings e deve ser usada apenas em funções view
     *      ou fora da blockchain. O alias é usado literalmente, sem sanitização (igual ao Dart).
     *
     *      Exemplo de saída: "LOG.Z26J0Y5314.421983"
     */
    function unpackToHumanString(uint64 packedValue, string memory alias)
        internal
        pure
        returns (string memory)
    {
        (
            ,
            uint64 seculoIdx,
            uint64 ano,
            uint64 mes,
            uint64 dia,
            uint64 horaUTC,
            uint64 minuto,
            uint64 segundo,
            uint64 microssegundos
        ) = unpack(packedValue);

        return string(abi.encodePacked(
            alias, ".",
            _getSeculoChar(seculoIdx),
            _padNumber(ano, 2),
            _getMesChar(mes),
            _getDiaChar(dia),
            _getHoraChar(horaUTC),
            _padNumber(minuto, 2),
            _padNumber(segundo, 2),
            ".",
            _padNumber(microssegundos, 6)
        ));
    }

    /**
     * @notice Versão com alias vazio (produz string começando com ".").
     */
    function unpackToHumanStringDefault(uint64 packedValue)
        internal
        pure
        returns (string memory)
    {
        return unpackToHumanString(packedValue, "");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 6. INTERNAL MAPPING UTILS (COM VALIDAÇÕES DE STRING)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Converte string do século para índice (0–15) com validação rigorosa.
     *      Espera exatamente 1 caractere ASCII.
     *      Letras minúsculas são convertidas para maiúsculas.
     *      'Y' → 15 (exceção), 'Z' → 0, 'A' → 1, ..., 'P' → 14.
     * @param seculo String de 1 caractere (sem espaços)
     * @return uint64 índice (0–15)
     */
    function _getSeculoIndex(string memory seculo) private pure returns (uint64) {
        bytes memory seculoBytes = bytes(seculo);
        require(seculoBytes.length == 1, "JEC: Seculo deve ter 1 caractere");

        bytes1 char = seculoBytes[0];
        // Converter minúsculo para maiúsculo (ASCII)
        if (char >= 'a' && char <= 'z') {
            char = bytes1(uint8(char) - 32);
        }

        if (char == 'Y') return 15; // Código de exceção explícito para o Século 20

        bytes15 cycle = STANDARD_CYCLE;
        for (uint64 i = 0; i < 15; i++) {
            if (cycle[i] == char) return i;
        }
        revert("JEC: Seculo fora do alfabeto homologado (Z-P ou Y)");
    }

    /**
     * @dev Retorna o caractere do século a partir do índice (0-based).
     */
    function _getSeculoChar(uint64 idx) private pure returns (string memory) {
        if (idx == 15) return "Y"; // Exceção Século 20
        return string(abi.encodePacked(STANDARD_CYCLE[idx]));
    }

    function _getMesChar(uint64 mes) private pure returns (string memory) {
        return string(abi.encodePacked(MAP_MES[mes - 1]));
    }

    function _getDiaChar(uint64 dia) private pure returns (string memory) {
        return string(abi.encodePacked(MAP_DIA[dia - 1]));
    }

    function _getHoraChar(uint64 horaUTC) private pure returns (string memory) {
        return string(abi.encodePacked(MAP_HORA[horaUTC]));
    }

    /**
     * @dev Converte uint64 para string com padding de zeros à esquerda.
     */
    function _padNumber(uint64 num, uint64 length) private pure returns (string memory) {
        string memory str = _uint64ToString(num);
        uint64 strLen = uint64(bytes(str).length);
        if (strLen >= length) return str;

        bytes memory padded = new bytes(length);
        for (uint64 i = 0; i < length - strLen; i++) {
            padded[i] = '0';
        }
        for (uint64 i = 0; i < strLen; i++) {
            padded[length - strLen + i] = bytes(str)[i];
        }
        return string(padded);
    }

    /**
     * @dev Converte uint64 para string (sem zeros à esquerda).
     */
    function _uint64ToString(uint64 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint64 temp = value;
        uint64 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint64 index = digits;
        temp = value;
        while (temp != 0) {
            buffer[--index] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 7. VALIDAÇÃO DE CALENDÁRIO SEMÂNTICO
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Valida se a data (mês/dia) existe no calendário (com suporte a anos bissextos).
     *      Usa aritmética uint256 pura (sem dependência de bibliotecas).
     */
    function _validateDate(uint64 seculoIdx, uint64 ano, uint64 mes, uint64 dia) private pure {
        uint256 centuryBase = seculoIdx == 15 ? 1900 : 2000 + (uint256(seculoIdx) * 100);
        uint256 anoAbsoluto = centuryBase + ano;

        if (mes == 2) {
            bool isLeap = (anoAbsoluto % 4 == 0 && anoAbsoluto % 100 != 0) || (anoAbsoluto % 400 == 0);
            require(dia <= (isLeap ? 29 : 28), "JEC: Fevereiro excede limite de dias");
        } else if (mes == 4 || mes == 6 || mes == 9 || mes == 11) {
            require(dia <= 30, "JEC: Mes de 30 dias excedido");
        } else {
            require(dia <= 31, "JEC: Mes de 31 dias excedido");
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTRATO JecAuditoriaEVM (VERSÃO ULTRA OTIMIZADA)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * @title JecAuditoriaEVM
 * @author mlopes75
 * @notice Contrato de auditoria on-chain imutável — VERSÃO ULTRA OTIMIZADA
 * @dev Otimizado para mínimo consumo de gas.
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 *  ESPECIFICAÇÕES JEC ENTERPRISE 64-BIT
 * ═══════════════════════════════════════════════════════════════════════════════
 *
 *  Header (7 bits): 0–127 (ID do servidor/nó)
 *  Século (4 bits): Z=0 (2000), A=1 (2100), ... P=14 (3400), Y=15 (1900 — exceção)
 *  Ano (7 bits): 0–99
 *  Mês (4 bits): 1–12
 *  Dia (5 bits): 1–31
 *  Hora UTC (5 bits): 0–23 (Z=00, A=01, ... Y=23)
 *  Minuto (6 bits): 0–59
 *  Segundo (6 bits): 0–59
 *  Microssegundos (20 bits): 0–999.999
 * ═══════════════════════════════════════════════════════════════════════════════
 */
contract JecAuditoriaEVM {
    using JecEnterprise64BitPacker for uint64;

    // ═══════════════════════════════════════════════════════════════════════════
    // CUSTOM ERRORS (Sem parâmetros para máximo savings)
    // ═══════════════════════════════════════════════════════════════════════════
    error JecServidorExcede7Bits();
    error JecMicrossegundosExcede20Bits();
    error JecCheckpointJaExiste();

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTOS (Indexados para busca eficiente)
    // ═══════════════════════════════════════════════════════════════════════════
    event CheckpointRegistado(
        uint64 indexed headerBits,
        uint64 indexed jecTimestamp,
        address indexed operador
    );

    // ═══════════════════════════════════════════════════════════════════════════
    // ESTADO (Otimizado para mínimo de slots)
    // ═══════════════════════════════════════════════════════════════════════════

    /// @dev Mapeamento de checkpoints (1 slot por chave)
    mapping(uint64 => bool) public checkpoints;

    /// @dev Contador total (1 slot)
    uint256 public totalCheckpoints;

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNÇÃO PRINCIPAL (Otimizada)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Registra checkpoint com mínimo de gas.
     * @param codigoServidor 0–127 (7 bits)
     * @param microssegundos 0–999999 (20 bits)
     */
    function registarCheckpoint(
        uint64 codigoServidor,
        uint64 microssegundos
    ) external returns (uint64 jecTimestamp) {
        // Validações com custom errors (sem parâmetros = mais barato)
        if (codigoServidor > 127) revert JecServidorExcede7Bits();
        if (microssegundos > 999_999) revert JecMicrossegundosExcede20Bits();

        // Extração do timestamp (hora em UTC)
        (
            string memory seculo,
            uint64 ano,
            uint64 mes,
            uint64 dia,
            uint64 horaUTC,
            uint64 minuto,
            uint64 segundo
        ) = _converterTimestamp(block.timestamp);

        // Empacotamento usando string (Z, A, B, ... P)
        jecTimestamp = JecEnterprise64BitPacker.pack(
            codigoServidor,
            seculo,
            ano,
            mes,
            dia,
            horaUTC,
            minuto,
            segundo,
            microssegundos
        );

        // Prevenção de duplicata (com custom error sem parâmetros)
        if (checkpoints[jecTimestamp]) revert JecCheckpointJaExiste();

        // Armazenamento
        checkpoints[jecTimestamp] = true;
        unchecked { totalCheckpoints++; }

        // Evento
        emit CheckpointRegistado(codigoServidor, jecTimestamp, msg.sender);

        return jecTimestamp;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNÇÕES DE CONSULTA (View/Pure = zero gas)
    // ═══════════════════════════════════════════════════════════════════════════

    function checkpointExiste(uint64 jecTimestamp) external view returns (bool) {
        return checkpoints[jecTimestamp];
    }

    function getTotalCheckpoints() external view returns (uint256) {
        return totalCheckpoints;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONVERSÃO DE TIMESTAMP (Otimizada para chamadas externas)
    // ═══════════════════════════════════════════════════════════════════════════

    function converterTimestampPublico(uint256 timestamp)
        external
        pure
        returns (
            string memory seculo,
            uint64 ano,
            uint64 mes,
            uint64 dia,
            uint64 horaUTC,
            uint64 minuto,
            uint64 segundo
        )
    {
        return _converterTimestamp(timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNÇÃO INTERNA (Core da conversão — otimizada)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Converte timestamp Unix para componentes JEC em UTC.
     *      O ciclo de 1500 anos começa em 2000 com Z=0.
     *
     *      ⚠️ IMPORTANTE: O timestamp Unix JÁ É UTC por definição.
     *      Portanto, `horaUTC` é a hora extraída diretamente do timestamp.
     *      Não há conversão de fuso aqui — a derivação de hora local
     *      é responsabilidade da camada Dart/backend.
     *
     * @param timestamp Unix timestamp em segundos (UTC)
     * @return seculo String do século (Z, A, B, ... P)
     * @return ano Ano (0–99)
     * @return mes Mês (1–12)
     * @return dia Dia (1–31)
     * @return horaUTC Hora UTC (0–23)
     * @return minuto Minuto (0–59)
     * @return segundo Segundo (0–59)
     */
    function _converterTimestamp(uint256 timestamp)
        internal
        pure
        returns (
            string memory seculo,
            uint64 ano,
            uint64 mes,
            uint64 dia,
            uint64 horaUTC,
            uint64 minuto,
            uint64 segundo
        )
    {
        // Obter data a partir dos dias
        uint256 yearFull;
        (yearFull, mes, dia) = _daysToDate(timestamp / 86400);

        // Extrair ano (0–99)
        ano = uint64(yearFull % 100);

        // Mapeamento para ciclo de 1500 anos (2000–3499)
        uint256 seculoNum = yearFull / 100;
        uint256 seculoIdx;

        if (seculoNum >= 20 && seculoNum <= 34) {
            seculoIdx = seculoNum - 20;
        } else {
            seculoIdx = 0; // Fallback seguro (não deve ocorrer com block.timestamp)
        }

        // Converte índice para caractere usando o alfabeto do ciclo padrão.
        // ⚠️ Usar STANDARD_CYCLE (não MAP_HORA) — a string deve ter 15 chars,
        //    e o índice do século vai até 14.
        bytes15 cycle = JecEnterprise64BitPacker.STANDARD_CYCLE;
        bytes1 char = cycle[seculoIdx];
        seculo = string(abi.encodePacked(char));

        // Extrair hora, minuto, segundo (UTC — timestamp Unix já é UTC)
        uint256 secondsInDay = timestamp % 86400;
        horaUTC = uint64(secondsInDay / 3600);
        minuto = uint64((secondsInDay % 3600) / 60);
        segundo = uint64(secondsInDay % 60);
    }

    /**
     * @dev Algoritmo Fliegel-Van Flandern com uint256 puro (mais barato que int256).
     * @param _days Número de dias desde a época Unix (1 de janeiro de 1970)
     * @return year Ano completo
     * @return month Mês (1–12)
     * @return day Dia (1–31)
     */
    function _daysToDate(uint256 _days) internal pure returns (uint256 year, uint64 month, uint64 day) {
        uint256 z = _days + 719468;
        uint256 era = z / 146097;
        uint256 doe = z - era * 146097;
        uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        uint256 y = yoe + era * 400;
        uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        uint256 mp = (5 * doy + 2) / 153;
        uint256 d = doy - (153 * mp + 2) / 5 + 1;
        uint256 m = mp + (mp < 10 ? 3 : 9);
        year = y + (m <= 2 ? 1 : 0);
        month = uint64(m);
        day = uint64(d);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNÇÃO PARA STRING VISUAL (Off-chain)
    // ═══════════════════════════════════════════════════════════════════════════

    function timestampParaString(uint64 jecTimestamp, string memory alias)
        external
        pure
        returns (string memory)
    {
        return JecEnterprise64BitPacker.unpackToHumanString(jecTimestamp, alias);
    }

    function timestampParaStringDefault(uint64 jecTimestamp)
        external
        pure
        returns (string memory)
    {
        return JecEnterprise64BitPacker.unpackToHumanStringDefault(jecTimestamp);
    }
}
