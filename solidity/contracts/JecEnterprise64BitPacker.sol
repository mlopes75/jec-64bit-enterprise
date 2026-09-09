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
 */
library JecEnterprise64BitPacker {

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTES DO PROTOCOLO (ALFABETOS) - Armazenados como bytes para eficiência
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
    // 1. EMPACOTAMENTO (PACKING) - Protocolo puro
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Empacota metadados e tempo em 64 bits utilizando a letra representativa do século.
     * @dev Esta função valida o século através da string (custo gas adicional). Para maior eficiência,
     *      use packWithIdx passando o índice diretamente.
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
     * @dev Esta é a versão otimizada para gas, pois não processa strings.
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
        // 1. Validações estritas de limites de negócio (Impede que a máscara mascare dados inválidos)
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
    // 2. DESEMPACOTAMENTO (UNPACKING) - Protocolo puro
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Desempacota o payload bruto de 64 bits aplicando máscaras de isolamento estrutural.
     * @return Todos os campos extraídos como uint64, incluindo o índice do século.
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

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. APRESENTAÇÃO (unpackToHumanString) - Camada separada, mais custosa
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Desempacota e retorna a string visual idêntica à saída do ecossistema Dart.
     * @dev Esta função realiza alocações de memória e é mais cara em gas; use apenas para logging ou UI.
     *      O alias é usado literalmente, sem sanitização (compatível com Dart).
     */
    function unpackToHumanString(uint64 packedValue, string memory alias) 
        internal pure returns (string memory) 
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

        // Constrói a string exatamente como no Dart: "$alias.$seculoChar$anoStr$mesChar$diaChar$horaChar$minStr$segStr.$microStr"
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
     * @brief Versão com alias padrão vazio (equivale a "" no Dart).
     * @dev No Dart, alias vazio resulta em string começando com ".".
     *      Aqui, passamos "" explicitamente para manter compatibilidade.
     */
    function unpackToHumanStringDefault(uint64 packedValue) internal pure returns (string memory) {
        return unpackToHumanString(packedValue, "");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. UTILITÁRIO DE EXTRAÇÃO DE HEADER
    // ═══════════════════════════════════════════════════════════════════════════

    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 57) & 0x7F;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. FUNÇÕES INTERNAS DE MAPEAMENTO (Puras e Otimizadas)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Converte índice do século (0-15) para caractere ASCII.
     * @dev Espera-se que idx seja 0..14 para ciclo padrão, ou 15 para 'Y'.
     */
    function _getSeculoChar(uint64 idx) private pure returns (string memory) {
        if (idx == 15) return "Y";
        bytes15 cycle = STANDARD_CYCLE;
        // O elenco para string é seguro, pois cycle[idx] é um byte ASCII.
        return string(abi.encodePacked(cycle[idx]));
    }

    /**
     * @notice Converte string (1 caractere) para índice do século.
     * @dev Rejeita strings vazias ou com comprimento != 1.
     *      Suporta letras maiúsculas e minúsculas ASCII, convertendo minúsculas para maiúsculas.
     *      Letras válidas: Z, A-P (exceto I, O) e Y (exceção).
     */
    function _getSeculoIndex(string memory seculo) private pure returns (uint64) {
        bytes memory seculoBytes = bytes(seculo);
        require(seculoBytes.length == 1, "JEC: Seculo deve ter 1 caractere");

        bytes1 char = seculoBytes[0];
        // Converter minúscula para maiúscula (ASCII)
        if (char >= 'a' && char <= 'z') {
            char = bytes1(uint8(char) - 32);
        }

        if (char == 'Y') return 15;

        bytes15 cycle = STANDARD_CYCLE;
        // Busca linear no alfabeto (15 elementos) – gas aceitável para validação única.
        for (uint64 i = 0; i < 15; i++) {
            if (cycle[i] == char) return i;
        }
        revert("JEC: Seculo fora do alfabeto homologado (Z-P ou Y)");
    }

    function _getMesChar(uint64 mes) private pure returns (string memory) {
        // mes é 1..12, então mes-1 é índice seguro.
        return string(abi.encodePacked(MAP_MES[mes - 1]));
    }

    function _getDiaChar(uint64 dia) private pure returns (string memory) {
        // dia é 1..31, índice seguro.
        return string(abi.encodePacked(MAP_DIA[dia - 1]));
    }

    function _getHoraChar(uint64 hora) private pure returns (string memory) {
        // hora é 0..23, índice seguro.
        return string(abi.encodePacked(MAP_HORA[hora]));
    }

    /**
     * @notice Converte número para string com padding à esquerda com zeros.
     * @dev Usa aritmética para evitar alocações desnecessárias.
     */
    function _padNumber(uint64 num, uint64 length) private pure returns (string memory) {
        string memory str = _uint64ToString(num);
        uint64 strLen = uint64(bytes(str).length);
        if (strLen >= length) return str;

        bytes memory padded = new bytes(length);
        // Preenche com zeros
        for (uint64 i = 0; i < length - strLen; i++) {
            padded[i] = '0';
        }
        // Copia a string original
        for (uint64 i = 0; i < strLen; i++) {
            padded[length - strLen + i] = bytes(str)[i];
        }
        return string(padded);
    }

    /**
     * @notice Converte uint64 para string (sem padding).
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
    // 6. VALIDAÇÃO DE CALENDÁRIO SEMÂNTICO (EVM)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Valida se a data é real (considerando anos bissextos).
     * @dev Usa regras gregorianas: divisível por 4, exceto séculos, mas divisível por 400.
     *      Cálculo do ano absoluto: se século == 15 (Y), base=1900; senão 2000 + seculoIdx*100.
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
