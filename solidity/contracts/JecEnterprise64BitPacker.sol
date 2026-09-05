// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title JecEnterprise64BitPacker
 * @author mlopes75
 * @notice Biblioteca corporativa de alta performance para o ecossistema JEC (Julia Epoch Compact).
 * @dev Comprime metadados (Header) e precisão temporal em microssegundos em exatamente 64 bits (8 bytes) usando bitwise shifts.
 * 
 * Divisão do Barramento (64 Bits):
 * [ Header (6b) ][ Século (5b) ][ Ano (7b) ][ Mês (4b) ][ Dia (5b) ][ Hora (5b) ][ Min (6b) ][ Seg (6b) ][ Microssegundos (20b) ]
 *  63........58   57........53   52....46   45....42   41...37   36...32   31...26   25...20   19..................0
 */
library JecEnterprise64BitPacker {
    
    // Alfabeto Puro oficial JEC para o Século (25 letras, sem o 'O')
    bytes memory constant alphaTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ";

    // Tabela Híbrida JEC para os restantes campos temporais (35 Símbolos)
    bytes memory constant jecTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ1234567890";

    /**
     * @notice Empacota metadados do servidor e tempo estruturado em exatamente 64 bits (uint64).
     * @param headerBits 6 bits livres (0 a 63) para metadados ou ID do servidor.
     * @param seculoIdx Índice do século na tabela alfabética JEC (0 a 24).
     * @param ano Valor puro do ano (0 a 99).
     * @param mes Mês do evento (1 a 12).
     * @param dia Dia do evento (1 a 31).
     * @param hora Hora do evento (0 a 23).
     * @param minuto Minuto do evento (0 a 59).
     * @param segundo Segundo do evento (0 a 59).
     * @param microssegundos Fração do segundo em microssegundos (0 a 999.999).
     * @return packedValue O identificador final compactado de 64 bits (uint64).
     */
    function pack(
        uint64 headerBits,
        uint64 seculoIdx,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 hora,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) internal pure returns (uint64 packedValue) {
        // Máscaras binárias cirúrgicas para prevenção de overflow
        uint64 clHeader = headerBits & 0x3F;       // 6 bits (0x3F)
        uint64 idxSeculo = seculoIdx & 0x1F;       // 5 bits (0x1F)
        uint64 clAn = ano & 0x7F;                  // 7 bits (0x7F)
        uint64 clMes = mes & 0x0F;                 // 4 bits (0x0F)
        uint64 clDia = dia & 0x1F;                 // 5 bits (0x1F)
        uint64 clHr = hora & 0x1F;                 // 5 bits (0x1F)
        uint64 clMin = minuto & 0x3F;              // 6 bits (0x3F)
        uint64 clSeg = segundo & 0x3F;              // 6 bits (0x3F)
        uint64 clMc = microssegundos & 0xFFFFF;    // 20 bits (0xFFFFF)

        // Bitwise Shifts para montagem do barramento de 64 bits
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

    /**
     * @notice Desempacota o payload de 64 bits e recupera todos os componentes de tempo e metadados.
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
     * @notice Extrai apenas os 6 bits de cabeçalho do topo em 1 operação de clock.
     * @dev Útil para filtragem/triagem ultra-rápida na Blockchain gastando mínimo Gas.
     */
    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 58) & 0x3F;
    }
}

    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 57) & 0x7F;
    }
}
