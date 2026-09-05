// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./JecEnterprise64BitPacker.sol";

/**
 * @title JecAuditoriaEVM
 * @author mlopes75
 * @notice Contrato de auditoria on-chain imutável baseado em block.timestamp e JEC 64-Bit.
 * @dev Utiliza o JEC Enterprise 64-Bit para compactar timestamp + metadados em 64 bits.
 */
contract JecAuditoriaEVM {
    using JecEnterprise64BitPacker for uint64;

    // ═══════════════════════════════════════════════════════════════════════════
    // ERROS CUSTOMIZADOS (Economia de Gas)
    // ═══════════════════════════════════════════════════════════════════════════
    error JecServidorExcede6Bits();
    error JecMicrossegundosExcede20Bits();
    error JecCheckpointJaExiste(uint64 jecTimestamp);

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. EVENTOS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Evento emitido quando um checkpoint é registrado.
     * @param headerBits ID do nó/servidor (6 bits)
     * @param jecTimestamp Timestamp JEC compactado em 64 bits
     * @param operador Endereço que registrou o checkpoint
     */
    event CheckpointRegistado(
        uint64 indexed headerBits, 
        uint64 indexed jecTimestamp, 
        address indexed operador
    );

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. ESTADO
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Mapeamento de existência de checkpoints armazenados.
     * @dev Na EVM, mappings alocam slots individuais de 32 bytes por chave.
     *      Uso de bool é o padrão mais eficiente e idiomático.
     */
    mapping(uint64 => bool) public checkpoints;

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. FUNÇÃO PRINCIPAL
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Registra um checkpoint de auditoria amarrado estritamente ao block.timestamp da EVM.
     * @param codigoServidor ID do nó/servidor (0 a 63 → 6 bits)
     * @param microssegundos Offset do relógio local (0 a 999.999 → 20 bits)
     * @return jecTimestamp O timestamp JEC empacotado em 64 bits
     */
    function registarCheckpoint(
        uint64 codigoServidor,
        uint64 microssegundos
    ) external returns (uint64 jecTimestamp) {
        // 1. Validação de entrada via Custom Errors
        if (codigoServidor > 63) revert JecServidorExcede6Bits();
        if (microssegundos > 999_999) revert JecMicrossegundosExcede20Bits();

        // 2. Extração do tempo a partir de block.timestamp
        (
            uint64 seculoIdx, 
            uint64 ano, 
            uint64 mes, 
            uint64 dia, 
            uint64 hora, 
            uint64 minuto, 
            uint64 segundo
        ) = _converterTimestamp(block.timestamp);

        // 3. Empacotamento em barramento de 64 bits (ciclo 0)
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

        // 4. Prevenção de colisão de chaves
        if (checkpoints[jecTimestamp]) revert JecCheckpointJaExiste(jecTimestamp);

        // 5. Armazenamento da existência do checkpoint
        checkpoints[jecTimestamp] = true;

        // 6. Emissão do evento
        emit CheckpointRegistado(codigoServidor, jecTimestamp, msg.sender);

        return jecTimestamp;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. FUNÇÕES DE CONSULTA
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Verifica se um checkpoint existe.
     * @param jecTimestamp Timestamp JEC compactado em 64 bits
     * @return bool true se existe, false caso contrário
     */
    function checkpointExiste(uint64 jecTimestamp) external view returns (bool) {
        return checkpoints[jecTimestamp];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. FUNÇÕES DE SUPORTE E CONSULTA OFF-CHAIN
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Wrapper público para expor a conversão interna a testes e dApps.
     */
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
    // 6. FUNÇÕES INTERNAS (Conversão de Timestamp)
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
        
        // 🎯 CICLO DE 2500 ANOS: (século) % 25
        uint256 seculo = yearFull / 100;
        seculoIdx = uint64(seculo % 25);

        uint256 secondsInDay = timestamp % 86400;
        hora = uint64(secondsInDay / 3600);
        minuto = uint64((secondsInDay % 3600) / 60);
        segundo = uint64(secondsInDay % 60);
    }

    /**
     * @dev Algoritmo Fliegel-Van Flandern O(1) para conversão de dias Unix em data Gregoriana.
     */
    function _daysToDate(uint256 _days) internal pure returns (uint256 year, uint64 month, uint64 day) {
        int256 __days = int256(_days);

        int256 L = __days + 68569 + 2440588;
        int256 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int256 _month = (80 * L) / 2447;
        int256 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint256(_year);
        month = uint64(uint256(_month));
        day = uint64(uint256(_day));
    }
}
