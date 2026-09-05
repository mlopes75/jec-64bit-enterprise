// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title JecEnterprise64BitPacker
 * @author mlopes75
 * @notice Biblioteca corporativa de alta performance para o ecossistema JEC (Julia Epoch Compact).
 * @dev Compacta metadados (Header) e precisão temporal em microssegundos em exatamente 64 bits (8 bytes).
 * 
 * Layout do Barramento (64 Bits):
 * [ Header (6b) ][ Século (5b) ][ Ano (7b) ][ Mês (4b) ][ Dia (5b) ][ Hora (5b) ][ Min (6b) ][ Seg (6b) ][ Microssegundos (20b) ]
 *  63........58   57........53   52....46   45....42   41...37   36...32   31...26   25...20   19..................0
 */
library JecEnterprise64BitPacker {

    /**
     * @notice Empacota metadados e tempo estruturado em exatamente 64 bits (uint64).
     * @dev Executa validações estritas (require) para evitar corrupção silenciosa por mascaramento.
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
    ) internal pure returns (uint64 packedValue) {
        // 1. Validações estritas de limites
        require(headerBits <= 63, "JEC: Header excede 6 bits");
        require(seculoIdx <= 31, "JEC: Seculo excede 5 bits");
        require(ano <= 99, "JEC: Ano excede 7 bits");
        require(mes >= 1 && mes <= 12, "JEC: Mes invalido");
        require(dia >= 1 && dia <= 31, "JEC: Dia invalido");
        require(hora <= 23, "JEC: Hora invalida");
        require(minuto <= 59, "JEC: Minuto invalido");
        require(segundo <= 59, "JEC: Segundo invalido");
        require(microssegundos <= 999_999, "JEC: Microssegundos excede 20 bits");

        // 2. Montagem do barramento via Shifts
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
     * @notice Extrai apenas os 6 bits de cabeçalho do topo.
     */
    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 58) & 0x3F;
    }
}
