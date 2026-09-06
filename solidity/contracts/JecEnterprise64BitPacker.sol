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
 *  Alfabeto JEC (24 letras, sem 'I' e 'O'): A=0, B=1, C=2, D=3, E=4, F=5, G=6, H=7, J=8, K=9, L=10, M=11, N=12, P=13, Q=14
 * 
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  🕐 FILOSOFIA DO CICLO DE 1500 ANOS
 *  ═══════════════════════════════════════════════════════════════════════════════
 * 
 *  O JEC opera em ciclos de 1500 anos (15 séculos × 100 anos).
 *  Séculos válidos: A (2000) até Q (3400)
 * 
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  📅 MAPEAMENTO HÍBRIDO DOS DIAS
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  Dias 1-24: A-Z (sem I e O)
 *  Dias 25-31: 5,6,7,8,9,0,1 (último dígito)
 * 
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  ⏰ MAPEAMENTO HÍBRIDO DAS HORAS
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  Horas 00-23: Z=00, A=01, B=02, C=03, D=04, E=05, F=06, G=07, H=08, J=09,
 *               K=10, L=11, M=12, N=13, P=14, Q=15, R=16, S=17, T=18, U=19,
 *               V=20, W=21, X=22, Y=23
 * ═══════════════════════════════════════════════════════════════════════════════
 */
library JecEnterprise64BitPacker {

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSTANTES
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Alfabeto JEC (24 letras, sem I e O)
    bytes24 private constant ALPHA_TABLE = "ABCDEFGHJKLMNPQRSTUVWXYZ";

    /// @notice Mapeamento de meses (A=Jan, B=Fev, ..., M=Dez)
    bytes12 private constant MAP_MES = "ABCDEFGHJKLM";

    /// @notice Mapeamento de dias (A-Z para 1-24, 5-1 para 25-31)
    bytes31 private constant MAP_DIA = "ABCDEFGHJKLMNPQRSTUVWXYZ123456";

    /// @notice Mapeamento de horas (Z=00, A=01, ..., Y=23)
    bytes24 private constant MAP_HORA = "ZABCDEFGHJKLMNPQRSTUVWXY";

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. EMPACOTAMENTO
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Empacota metadados e tempo em 64 bits.
     * @dev Alinhado com a implementação Dart.
     */
    function pack(
        uint64 headerBits,     // 0 a 127 (7 bits)
        string memory seculo,  // A a Q (0-14)
        uint64 ano,            // 0 a 99 (7 bits)
        uint64 mes,            // 1 a 12 (4 bits)
        uint64 dia,            // 1 a 31 (5 bits)
        uint64 hora,           // 0 a 23 (5 bits)
        uint64 minuto,         // 0 a 59 (6 bits)
        uint64 segundo,        // 0 a 59 (6 bits)
        uint64 microssegundos  // 0 a 999.999 (20 bits)
    ) internal pure returns (uint64) {
        // 1. Validações de tamanho dos campos
        require(headerBits <= 127, "JEC: Header excede 7 bits (max 127)");
        require(ano <= 99, "JEC: Ano excede 7 bits (max 99)");
        require(mes >= 1 && mes <= 12, "JEC: Mes invalido (1-12)");
        require(dia >= 1 && dia <= 31, "JEC: Dia invalido (1-31)");
        require(hora <= 23, "JEC: Hora invalida (0-23)");
        require(minuto <= 59, "JEC: Minuto invalido (0-59)");
        require(segundo <= 59, "JEC: Segundo invalido (0-59)");
        require(microssegundos <= 999_999, "JEC: Microssegundos excede 20 bits");

        // 2. Validação do século
        uint64 seculoIdx = _getSeculoIndex(seculo);
        require(seculoIdx <= 14, "JEC: Seculo invalido (A-Q apenas)");

        // 3. Validação semântica de data
        uint256 anoAbsoluto = 2000 + (uint256(seculoIdx) * 100) + uint256(ano);
        require(_isValidDateAbsoluta(anoAbsoluto, mes, dia), "JEC: Data invalida");

        // 4. Montagem do barramento de 64 bits
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

    /**
     * @notice Empacota usando índice de século (para compatibilidade com contratos)
     */
    function packWithIdx(
        uint64 headerBits,     // 0 a 127 (7 bits)
        uint64 seculoIdx,      // 0 a 14 (4 bits)
        uint64 ano,            // 0 a 99 (7 bits)
        uint64 mes,            // 1 a 12 (4 bits)
        uint64 dia,            // 1 a 31 (5 bits)
        uint64 hora,           // 0 a 23 (5 bits)
        uint64 minuto,         // 0 a 59 (6 bits)
        uint64 segundo,        // 0 a 59 (6 bits)
        uint64 microssegundos  // 0 a 999.999 (20 bits)
    ) internal pure returns (uint64) {
        require(headerBits <= 127, "JEC: Header excede 7 bits");
        require(seculoIdx <= 14, "JEC: Seculo idx invalido (0-14)");
        require(ano <= 99, "JEC: Ano excede 7 bits");
        require(mes >= 1 && mes <= 12, "JEC: Mes invalido");
        require(dia >= 1 && dia <= 31, "JEC: Dia invalido");
        require(hora <= 23, "JEC: Hora invalida");
        require(minuto <= 59, "JEC: Minuto invalido");
        require(segundo <= 59, "JEC: Segundo invalido");
        require(microssegundos <= 999_999, "JEC: Microssegundos excede 20 bits");

        uint256 anoAbsoluto = 2000 + (uint256(seculoIdx) * 100) + uint256(ano);
        require(_isValidDateAbsoluta(anoAbsoluto, mes, dia), "JEC: Data invalida");

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
    // 2. DESEMPACOTAMENTO
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Desempacota o payload de 64 bits recuperando todos os componentes.
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
    }

    /**
     * @notice Desempacota e retorna a string visual (equivalente ao Dart).
     * @param packedValue O payload uint64 empacotado.
     * @param alias Prefixo opcional (ex: "LOG").
     */
    function unpackToHumanString(uint64 packedValue, string memory alias) 
        internal pure returns (string memory) 
    {
        (
            uint64 headerBits,
            uint64 seculoIdx,
            uint64 ano,
            uint64 mes,
            uint64 dia,
            uint64 hora,
            uint64 minuto,
            uint64 segundo,
            uint64 microssegundos
        ) = unpack(packedValue);

        // Extrai caracteres mapeados
        string memory charSeculo = _getSeculoChar(seculoIdx);
        string memory strMes = _getMesChar(mes);
        string memory strDia = _getDiaChar(dia);
        string memory strHora = _getHoraChar(hora);

        // Formata números
        string memory strAno = _padNumber(ano, 2);
        string memory strMin = _padNumber(minuto, 2);
        string memory strSeg = _padNumber(segundo, 2);
        string memory strMcs = _padNumber(microssegundos, 6);

        string memory cleanAlias = bytes(alias).length == 0 ? "A" : alias;

        return string(abi.encodePacked(
            cleanAlias, ".",
            charSeculo,
            strAno,
            strMes,
            strDia,
            strHora,
            strMin,
            strSeg,
            ".", strMcs
        ));
    }

    /**
     * @notice Desempacota e retorna a string visual com alias padrão "A".
     */
    function unpackToHumanStringDefault(uint64 packedValue) 
        internal pure returns (string memory) 
    {
        return unpackToHumanString(packedValue, "A");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. EXTRAÇÃO DE HEADER
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Extrai os 7 bits de cabeçalho (Header).
     */
    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 57) & 0x7F;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. MÉTODOS DE MAPEAMENTO
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Retorna o caractere do século (A-Q).
     */
    function _getSeculoChar(uint64 idx) private pure returns (string memory) {
        bytes24 alpha = ALPHA_TABLE;
        if (idx >= 15) return "?";
        return string(abi.encodePacked(alpha[idx]));
    }

    /**
     * @notice Retorna o índice do século (0-14).
     */
    function _getSeculoIndex(string memory seculo) private pure returns (uint64) {
        bytes1 char = bytes(seculo)[0];
        bytes24 alpha = ALPHA_TABLE;
        
        // Converte para maiúscula se necessário
        if (char >= 'a' && char <= 'z') {
            char = bytes1(uint8(char) - 32);
        }
        
        for (uint64 i = 0; i < 15; i++) {
            if (alpha[i] == char) {
                return i;
            }
        }
        revert("JEC: Seculo nao encontrado no alfabeto");
    }

    /**
     * @notice Retorna o caractere do mês (A-M).
     */
    function _getMesChar(uint64 mes) private pure returns (string memory) {
        bytes12 map = MAP_MES;
        if (mes < 1 || mes > 12) return "?";
        return string(abi.encodePacked(map[mes - 1]));
    }

    /**
     * @notice Retorna o caractere do dia (A-Z ou 5-1).
     */
    function _getDiaChar(uint64 dia) private pure returns (string memory) {
        bytes31 map = MAP_DIA;
        if (dia < 1 || dia > 31) return "?";
        bytes1 char = map[dia - 1];
        return string(abi.encodePacked(char));
    }

    /**
     * @notice Retorna o caractere da hora (Z=00, A=01, ..., Y=23).
     */
    function _getHoraChar(uint64 hora) private pure returns (string memory) {
        bytes24 map = MAP_HORA;
        if (hora > 23) return "?";
        return string(abi.encodePacked(map[hora]));
    }

    /**
     * @notice Formata número com padding de zeros à esquerda.
     */
    function _padNumber(uint64 num, uint64 length) private pure returns (string memory) {
        string memory str = _uint64ToString(num);
        uint64 strLen = uint64(bytes(str).length);
        
        if (strLen >= length) {
            return str;
        }
        
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
     * @notice Converte uint64 para string.
     */
    function _uint64ToString(uint64 value) private pure returns (string memory) {
        if (value == 0) return "0";
        
        uint64 temp = value;
        uint64 digits = 0;
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
    // 5. VALIDAÇÃO DE CALENDÁRIO
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Validação de calendário semântico por ano absoluto gregoriano.
     */
    function _isValidDateAbsoluta(
        uint256 anoAbsoluto,
        uint64 mes,
        uint64 dia
    ) private pure returns (bool) {
        if (anoAbsoluto == 0) return false;
        if (mes < 1 || mes > 12) return false;
        if (dia < 1 || dia > 31) return false;

        if (mes == 2) {
            return dia <= (_isLeapYear(anoAbsoluto) ? 29 : 28);
        }
        
        if (mes == 4 || mes == 6 || mes == 9 || mes == 11) {
            return dia <= 30;
        }

        return dia <= 31;
    }

    /**
     * @dev Avaliação exata de bissexto para a regra gregoriana.
     */
    function _isLeapYear(uint256 year) private pure returns (bool) {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }
}
