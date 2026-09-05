// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title JecEnterprise64BitPacker
 * @author mlopes75
 * @notice Extensão corporativa de alta performance para o ecossistema JEC (Julia Epoch Compact).
 * @dev Comprime metadados e precisão temporal de microssegundos em exatamente 64 bits (8 bytes) usando bitwise shifts.
 */
library JecEnterprise64BitPacker {
    
    bytes memory constant alphaTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ";
    bytes memory constant jecTable = "ABCDEFGHIJKLMNPQRSTUVWXYZ1234567890";

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
        uint64 clHeader = headerBits & 0x7F;       // 7 bits
        uint64 idxSeculo = seculoIdx & 0x1F;       // 5 bits
        uint64 clAn = ano & 0x7F;                  // 7 bits
        uint64 clMes = mes & 0x0F;                 // 4 bits
        uint64 clDia = dia & 0x1F;                 // 5 bits
        uint64 clHr = hora & 0x1F;                 // 5 bits
        uint64 clMin = minuto & 0x3F;              // 6 bits
        uint64 clSeg = segundo & 0x3F;              // 6 bits
        uint64 clMc = microssegundos & 0xFFFFF;    // 20 bits

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
        seculoIdx = (packedValue >> 52) & 0x1F;
        ano = (packedValue >> 45) & 0x7F;
        mes = (packedValue >> 41) & 0x0F;
        dia = (packedValue >> 36) & 0x1F;
        hora = (packedValue >> 31) & 0x1F;
        minuto = (packedValue >> 25) & 0x3F;
        segundo = (packedValue >> 19) & 0x3F;
        microssegundos = packedValue & 0xFFFFF;
    }

    function extractHeaderBits(uint64 packedValue) internal pure returns (uint64) {
        return (packedValue >> 57) & 0x7F;
    }
}
