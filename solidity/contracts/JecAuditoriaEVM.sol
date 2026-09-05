// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./JecEnterprise64BitPacker.sol";

/**
 * @title JecAuditoriaEVM
 * @notice Contrato de auditoria on-chain imutável baseado em block.timestamp e JEC 64-Bit.
 * @dev Otimizado para menor consumo de gas no deployment e na execução.
 */
contract JecAuditoriaEVM {
    using JecEnterprise64BitPacker for uint64;

    // ═══════════════════════════════════════════════════════════════════════════
    // CUSTOM ERRORS (Economia substancial de bytecode e gas de erro)
    // ═══════════════════════════════════════════════════════════════════════════
    error JecServidorExcede6Bits();
    error JecMicrossegundosExcede20Bits();
    error JecCheckpointJaExiste(uint64 jecTimestamp);

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTOS & ESTADO
    // ═══════════════════════════════════════════════════════════════════════════
    event CheckpointRegistado(
        uint64 indexed headerBits, 
        uint64 indexed jecTimestamp, 
        address indexed operador
    );

    // Mapeamento otimizado para bool (EVM usa 32 bytes por slot em mappings)
    mapping(uint64 => bool) public checkpoints;

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNÇÃO PRINCIPAL
    // ═══════════════════════════════════════════════════════════════════════════
    function registarCheckpoint(
        uint64 codigoServidor,
        uint64 microssegundos
    ) external returns (uint64 jecTimestamp) {
        if (codigoServidor > 63) revert JecServidorExcede6Bits();
        if (microssegundos > 999_999) revert JecMicrossegundosExcede20Bits();

        (
            uint64 seculoIdx, 
            uint64 ano, 
            uint64 mes, 
            uint64 dia, 
            uint64 hora, 
            uint64 minuto, 
            uint64 segundo
        ) = _converterTimestamp(block.timestamp);

        jecTimestamp = JecEnterprise64BitPacker.pack(
            codigoServidor,
            seculoIdx,
            ano,
            mes,
            dia,
            hora,
            minuto,
            segundo,
            microssegundos
        );

        if (checkpoints[jecTimestamp]) revert JecCheckpointJaExiste(jecTimestamp);
        
        checkpoints[jecTimestamp] = true;
        emit CheckpointRegistado(codigoServidor, jecTimestamp, msg.sender);

        return jecTimestamp;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONSULTAS OFF-CHAIN
    // ═══════════════════════════════════════════════════════════════════════════
    function checkpointExiste(uint64 jecTimestamp) external view returns (bool) {
        return checkpoints[jecTimestamp];
    }

    function converterTimestampPublico(uint256 timestamp) 
        external 
        pure 
        returns (
            uint64 seculoIdx,
            uint64 ano,
            uint64 mes,
            uint64 dia,
            uint64 hora,
            uint64 minuto,
            uint64 segundo
        ) 
    {
        return _converterTimestamp(timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUNÇÕES INTERNAS OTIMIZADAS
    // ═══════════════════════════════════════════════════════════════════════════
    function _converterTimestamp(uint256 timestamp) 
        internal 
        pure 
        returns (
            uint64 seculoIdx,
            uint64 ano,
            uint64 mes,
            uint64 dia,
            uint64 hora,
            uint64 minuto,
            uint64 segundo
        ) 
    {
        uint256 yearFull;
        (yearFull, mes, dia) = _daysToDate(timestamp / 86400);

        ano = uint64(yearFull % 100);
        seculoIdx = uint64((yearFull / 100) % 25);

        uint256 secondsInDay = timestamp % 86400;
        hora = uint64(secondsInDay / 3600);
        minuto = uint64((secondsInDay % 3600) / 60);
        segundo = uint64(secondsInDay % 60);
    }

    /**
     * @dev Algoritmo Fliegel-Van Flandern otimizado em uint256 para evitar mutações de sinal int256.
     */
    function _daysToDate(uint256 _days) internal pure returns (uint256 year, uint64 month, uint64 day) {
        uint256 L = _days + 68569 + 2440588;
        uint256 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        uint256 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        uint256 _month = (80 * L) / 2447;
        uint256 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = _year;
        month = uint64(_month);
        day = uint64(_day);
    }
}
