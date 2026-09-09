// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title JecEnterprise64BitPacker
 * @author mlopes75
 * @notice Biblioteca corporativa de alta performance para o ecossistema JEC (Julia Epoch Compact).
 * @dev Compacta metadados (Header) e precisão temporal em microssegundos em exatamente 64 bits (8 bytes).
 * 
 * ═══════════════════════════════════════════════════════════════════════════════
 *  Layout do Barramento (64 Bits) - Alinhado com a especificação Dart:
 *  [ Header (7b) ][ Século (4b) ][ Ano (7b) ][ Mês (4b) ][ Dia (5b) ][ Hora (5b) ][ Min (6b) ][ Seg (6b) ][ Microssegundos (20b) ]
 *   63........57   56........53   52....46   45....42   41...37   36...32   31...26   25...20   19..................0
 * 
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  🕐 FILOSOFIA DO CICLO DE 1500 ANOS COM EXCEÇÃO HISTÓRICA
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  0..14 = Ciclo padrão de 1500 anos (Séculos Z a P: 2000 a 3499).
 *  15    = Código de Exceção Isolado (0b1111) reservado para o Século 20 ('Y': 1900 a 1999).
 * 
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  📅 MAPEAMENTO CONVENIENTE DOS DIAS (Alinhamento Tangível: Dia 1 = 'A')
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  Dias 1-24: A-Z (Sem I e O, onde 1=A, 2=B, ..., 24=Z).
 *  Dias 25-31: 5,6,7,8,9,0,1 (Mapeamento pelo último dígito).
 * 
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  🔧 SEPARAÇÃO DE RESPONSABILIDADES (OTIMIZAÇÃO DE GAS)
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  - Funções de protocolo (pack, packWithIdx, unpack) : destinadas a contratos on-chain,
 *    com mínimo consumo de gas. Retornam dados brutos (uint64 ou tuplas).
 *  - Funções de apresentação (unpackToHumanString) : para uso off-chain ou em views,
 *    pois envolvem manipulação de strings (caro). Mantidas na mesma biblioteca,
 *    mas documentadas como "off-chain friendly".
 */
library JecEnterprise64BitPacker {

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTES DO PROTOCOLO (ALFABETOS)
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Ciclo padrão de 15 séculos (Exclui o 'Y' pois este virou código de exceção 15)
    bytes15 private constant STANDARD_CYCLE = "ZABCDEFGHJKLMNP";

    /// @notice Mapeamento de meses (1=A, 2=B, ..., 12=M)
    bytes12 private constant MAP_MES = "ABCDEFGHJKLM";

    /// @notice Mapeamento estático de dias (1=A, ..., 24=Z, 25-31 pelo último dígito)
    bytes31 private constant MAP_DIA = "ABCDEFGHJKLMNPQRSTUVWXYZ5678901";

    /// @notice Mapeamento de horas (00=Z, 01=A, ..., 23=Y)
    bytes24 private constant MAP_HORA = "ZABCDEFGHJKLMNPQRSTUVWXY";

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. EMPACOTAMENTO (PACKING) - FUNÇÕES ON-CHAIN
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Empacota metadados e tempo em 64 bits utilizando a letra representativa do século.
     * @param headerBits 7 bits (0-127)
     * @param seculo String de exatamente 1 caractere (Z, A, B, ..., P, ou Y) em ASCII.
     * @param ano 0-99
     * @param mes 1-12
     * @param dia 1-31
     * @param hora 0-23
     * @param minuto 0-59
     * @param segundo 0-59
     * @param microssegundos 0-999999
     * @return uint64 valor empacotado
     */
    function pack(
        uint64 headerBits,
        string memory seculo,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 hora,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) internal pure returns (uint64) {
        uint64 seculoIdx = _getSeculoIndex(seculo);
        return packWithIdx(headerBits, seculoIdx, ano, mes, dia, hora, minuto, segundo, microssegundos);
    }

    /**
     * @notice Empacota usando o índice nativo do século (Proteção Estrita contra estouro de limites).
     */
    function packWithIdx(
        uint64 headerBits,
        uint64 seculoIdx,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 hora,
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
        require(hora <= 23, "JEC: Hora invalida (0-23)");
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
               (hora << 32) |
               (minuto << 26) |
               (segundo << 20) |
               microssegundos;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. DESEMPACOTAMENTO (UNPACKING) - FUNÇÕES ON-CHAIN
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Desempacota o payload bruto de 64 bits aplicando máscaras de isolamento estrutural.
     * @return headerBits 7 bits
     * @return seculoIdx 4 bits (0-15)
     * @return ano 0-99
     * @return mes 1-12
     * @return dia 1-31
     * @return hora 0-23
     * @return minuto 0-59
     * @return segundo 0-59
     * @return microssegundos 0-999999
     */
    function unpack(uint64 packedValue) internal pure returns (
        uint64 headerBits,
        uint64 seculoIdx,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 hora,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) {
        headerBits = (packedValue >> 57) & 0x7F;
        seculoIdx = (packedValue >> 53) & 0x0F;
        ano = (packedValue >> 46) & 0x7F;
        mes = (packedValue >> 42) & 0x0F;
        dia = (packedValue >> 37) & 0x1F;
        hora = (packedValue >> 32) & 0x1F;
        minuto = (packedValue >> 26) & 0x3F;
        segundo = (packedValue >> 20) & 0x3F;
        microssegundos = packedValue & 0xFFFFF;

        // Validação pós-extração para resguardar o domínio contra dados corrompidos
        require(seculoIdx <= 15, "JEC: Bits de seculo corrompidos");
        require(ano <= 99, "JEC: Bits de ano corrompidos");
        require(mes >= 1 && mes <= 12, "JEC: Bits de mes corrompidos");
        require(dia >= 1 && dia <= 31, "JEC: Bits de dia corrompidos");
        require(hora <= 23, "JEC: Bits de hora corrompidos");
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
    // 3. FUNÇÕES DE APRESENTAÇÃO (OFF-CHAIN / VIEW) - USO RESTRITO A STRINGS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Desempacota e retorna a string visual idêntica à saída do ecossistema Dart.
     * @dev Esta função usa manipulação de strings e deve ser usada apenas em funções view ou fora da blockchain.
     *      O alias é usado literalmente, sem sanitização (igual ao Dart).
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
            uint64 hora,
            uint64 minuto,
            uint64 segundo,
            uint64 microssegundos
        ) = unpack(packedValue);

        // Alias é usado exatamente como fornecido (pode ser vazio)
        return string(abi.encodePacked(
            alias, ".",
            _getSeculoChar(seculoIdx),
            _padNumber(ano, 2),
            _getMesChar(mes),
            _getDiaChar(dia),
            _getHoraChar(hora),
            _padNumber(minuto, 2),
            _padNumber(segundo, 2),
            ".", 
            _padNumber(microssegundos, 6)
        ));
    }

    /**
     * @notice Versão com alias vazio (produz string começando com ".").
     */
    function unpackToHumanStringDefault(uint64 packedValue) internal pure returns (string memory) {
        return unpackToHumanString(packedValue, "");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. INTERNAL MAPPING UTILS (COM VALIDAÇÕES DE STRING)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Converte string do século para índice (0-15) com validação rigorosa.
     *      Espera exatamente 1 caractere ASCII.
     *      Letras minúsculas são convertidas para maiúsculas.
     *      'Y' → 15 (exceção), 'Z'→0, 'A'→1, ... 'P'→14.
     * @param seculo String de 1 caractere (sem espaços)
     * @return uint64 índice (0-15)
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
     * @dev Retorna o caractere do século a partir do índice.
     */
    function _getSeculoChar(uint64 idx) private pure returns (string memory) {
        if (idx == 15) return "Y"; // Exceção Século 20
        bytes15 cycle = STANDARD_CYCLE;
        return string(abi.encodePacked(cycle[idx]));
    }

    function _getMesChar(uint64 mes) private pure returns (string memory) {
        return string(abi.encodePacked(MAP_MES[mes - 1]));
    }

    function _getDiaChar(uint64 dia) private pure returns (string memory) {
        return string(abi.encodePacked(MAP_DIA[dia - 1]));
    }

    function _getHoraChar(uint64 hora) private pure returns (string memory) {
        return string(abi.encodePacked(MAP_HORA[hora]));
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
    // 5. VALIDAÇÃO DE CALENDÁRIO SEMÂNTICO
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
