// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title JecEnterprise64BitPacker
 * @author mlopes75
 * @notice Biblioteca corporativa de alta performance para o ecossistema JEC (Julia Epoch Compact).
 * @dev Compacta metadados (Header) e precisão temporal em microssegundos em exatamente 64 bits (8 bytes).
 * 
 * ═══════════════════════════════════════════════════════════════════════════════
 *  Layout do Barramento (64 Bits):
 *  [ Header (6b) ][ Século (5b) ][ Ano (7b) ][ Mês (4b) ][ Dia (5b) ][ Hora (5b) ][ Min (6b) ][ Seg (6b) ][ Microssegundos (20b) ]
 *   63........58   57........53   52....46   45....42   41...37   36...32   31...26   25...20   19..................0
 * 
 *  Alfabeto JEC (25 letras, sem 'O'): A=0, B=1, ..., V=20, W=21, X=22, Y=23, Z=24
 * ═══════════════════════════════════════════════════════════════════════════════
 *  🕐 FILOSOFIA DO CICLO DE 2500 ANOS
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 *  O JEC opera em ciclos de 2500 anos (25 séculos × 100 anos).
 *  Ao final de um ciclo, o índice de século reinicia (efeito "odômetro"),
 *  assim como um relógio Unix eventualmente dará overflow.
 * 
 *  Isso é uma DECISÃO DE DESIGN DELIBERADA, não uma limitação:
 *  - O sistema é dimensionado para a escala de tempo de infraestrutura humana atual
 *  - O contrato JecAuditoriaEVM nunca produzirá timestamps além do ciclo vigente
 *  - Para aplicações que precisem sobrevivir a múltiplos ciclos, use packComCiclo()
 * 
 * ═══════════════════════════════════════════════════════════════════════════════
 */
library JecEnterprise64BitPacker {

    /**
     * @notice Empacota metadados e tempo em 64 bits, assumindo o ciclo vigente (0-2499 d.C.).
     * @dev Este é o método padrão para uso com JecAuditoriaEVM e block.timestamp.
     *      O ciclo 0 cobre todo o período relevante para a infraestrutura atual.
     *      Para múltiplos ciclos, use packComCiclo().
     */
    function pack(
        uint64 headerBits,     // 0 a 63 (6 bits)
        uint64 seculoIdx,      // 0 a 24 (5 bits)
        uint64 ano,            // 0 a 99 (7 bits)
        uint64 mes,            // 1 a 12 (4 bits)
        uint64 dia,            // 1 a 31 (5 bits)
        uint64 hora,           // 0 a 23 (5 bits)
        uint64 minuto,         // 0 a 59 (6 bits)
        uint64 segundo,        // 0 a 59 (6 bits)
        uint64 microssegundos  // 0 a 999.999 (20 bits)
    ) internal pure returns (uint64) {
        return packComCiclo(
            headerBits,
            seculoIdx,
            ano,
            0, // Ciclo 0 por padrão (Era Atual)
            mes,
            dia,
            hora,
            minuto,
            segundo,
            microssegundos
        );
    }

    /**
     * @notice Empacota metadados e tempo informando explicitamente o ciclo de 2500 anos.
     * @param ciclo Índice da época de 2500 anos (0 = 0-2499 d.C., 1 = 2500-4999 d.C., etc.)
     * @dev O ciclo NÃO é armazenado no payload de 64 bits — é usado APENAS para validação semântica.
     *      Isso significa que o formato permanece inalterado para todos os ciclos.
     */
    function packComCiclo(
        uint64 headerBits,
        uint64 seculoIdx,      // 0 a 24 (5 bits)
        uint64 ano,            // 0 a 99 (7 bits)
        uint64 ciclo,          // Número do ciclo de 2500 anos
        uint64 mes,            // 1 a 12 (4 bits)
        uint64 dia,            // 1 a 31 (5 bits)
        uint64 hora,           // 0 a 23 (5 bits)
        uint64 minuto,         // 0 a 59 (6 bits)
        uint64 segundo,        // 0 a 59 (6 bits)
        uint64 microssegundos  // 0 a 999.999 (20 bits)
    ) internal pure returns (uint64 packedValue) {
        // 1. Validações de tamanho dos campos
        require(headerBits <= 63, "JEC: Header excede 6 bits");
        require(seculoIdx <= 24, "JEC: Seculo excede alfabeto JEC (max 24)");
        require(ano <= 99, "JEC: Ano excede 7 bits");
        require(mes >= 1 && mes <= 12, "JEC: Mes invalido");
        require(dia >= 1 && dia <= 31, "JEC: Dia invalido");
        require(hora <= 23, "JEC: Hora invalida");
        require(minuto <= 59, "JEC: Minuto invalido");
        require(segundo <= 59, "JEC: Segundo invalido");
        require(microssegundos <= 999_999, "JEC: Microssegundos excede 20 bits");

        // 2. Validação semântica exata via reconstrução do ano absoluto
        uint256 anoAbsoluto = (uint256(ciclo) * 2500) + (uint256(seculoIdx) * 100) + uint256(ano);
        require(_isValidDateAbsoluta(anoAbsoluto, mes, dia), "JEC: Data invalida");

        // 3. Montagem do barramento de 64 bits (o ciclo é omitido do payload)
        return (headerBits << 58) |
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
     * @notice Desempacota o payload de 64 bits recuperando todos os componentes individuais.
     * @param packedValue O payload uint64 empacotado.
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
        headerBits = (packedValue >> 58) & 0x3F;
        seculoIdx = (packedValue >> 53) & 0x1F;
        ano = (packedValue >> 46) & 0x7F;
        mes = (packedValue >> 42) & 0x0F;
        dia = (packedValue >> 37) & 0x1F;
        hora = (packedValue >> 32) & 0x1F;
        minuto = (packedValue >> 26) & 0x3F;
        segundo = (packedValue >> 20) & 0x3F;
        microssegundos = packedValue & 0xFFFFF;
    }

    /**
     * @notice Extrai apenas os 6 bits de cabeçalho (Header) do topo sem desempacotar o tempo.
     * @param packedValue O payload uint64 empacotado.
     */
    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 58) & 0x3F;
    }

    /**
     * @dev Validação de calendário semântico por ano absoluto gregoriano.
     * @param anoAbsoluto Ano completo (ex: 2024, 4500, 5000)
     * @param mes Mês (1-12)
     * @param dia Dia (1-31)
     * @return true se a data é válida no calendário gregoriano
     */
    function _isValidDateAbsoluta(
        uint256 anoAbsoluto,
        uint64 mes,
        uint64 dia
    ) internal pure returns (bool) {
        if (anoAbsoluto == 0) {
            return false;
        }

        if (mes == 2) {
            return dia <= (_isLeapYear(anoAbsoluto) ? 29 : 28);
        }
        
        if (mes == 4 || mes == 6 || mes == 9 || mes == 11) {
            return dia <= 30;
        }

        return dia <= 31;
    }

    /**
     * @dev Avaliação exata de bissexto para a regra gregoriana (4 / 100 / 400).
     */
    function _isLeapYear(uint256 year) internal pure returns (bool) {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }
}
