// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./JecEnterprise64BitPacker.sol";

/**
 * @title JecAuditoriaEVM
 * @author mlopes75
 * @notice Contrato de auditoria on-chain imutável - VERSÃO ULTRA OTIMIZADA
 * @dev Otimizado para mínimo consumo de gas
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
     * @param codigoServidor 0-127 (7 bits)
     * @param microssegundos 0-999999 (20 bits)
     */
    function registarCheckpoint(
        uint64 codigoServidor,
        uint64 microssegundos
    ) external returns (uint64 jecTimestamp) {
        // Validações com custom errors (sem parâmetros = mais barato)
        if (codigoServidor > 127) revert JecServidorExcede7Bits();
        if (microssegundos > 999_999) revert JecMicrossegundosExcede20Bits();

        // Extração do timestamp
        (
            uint64 seculoIdx, 
            uint64 ano, 
            uint64 mes, 
            uint64 dia, 
            uint64 hora, 
            uint64 minuto, 
            uint64 segundo
        ) = _converterTimestamp(block.timestamp);

        // Empacotamento
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

        // Prevenção de duplicata (com custom error sem parâmetros)
        if (checkpoints[jecTimestamp]) revert JecCheckpointJaExiste();
        
        // Armazenamento
        checkpoints[jecTimestamp] = true;
        unchecked { totalCheckpoints++; } // Economiza gas

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
    // FUNÇÃO INTERNA (Core da conversão - otimizada)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @dev Converte timestamp Unix para componentes JEC.
     * O ciclo de 1500 anos começa em 2000.
     */
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
        // Obter data a partir dos dias
        uint256 yearFull;
        (yearFull, mes, dia) = _daysToDate(timestamp / 86400);

        // Extrair ano (0-99)
        ano = uint64(yearFull % 100);
        
        // 🎯 Mapeamento para ciclo de 1500 anos (2000-3499)
        // Usando assembly para operação matemática mais barata
        uint256 seculo = yearFull / 100;
        assembly {
            // if (seculo >= 20) { seculoIdx = (seculo - 20) % 15 } else { seculoIdx = 0 }
            let diff := sub(seculo, 20)
            let isAfter := gt(diff, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            // Se diff for negativo (seculo < 20), é 0, senão diff % 15
            let modVal := mod(diff, 15)
            seculoIdx := mul(isAfter, modVal)
        }

        // Extrair hora, minuto, segundo
        uint256 secondsInDay = timestamp % 86400;
        hora = uint64(secondsInDay / 3600);
        minuto = uint64((secondsInDay % 3600) / 60);
        segundo = uint64(secondsInDay % 60);
    }

    /**
     * @dev Algoritmo Fliegel-Van Flandern com uint256 puro (mais barato que int256).
     */
    function _daysToDate(uint256 _days) internal pure returns (uint256 year, uint64 month, uint64 day) {
        uint256 z = _days + 719468;
        uint256 era = (z >= 0 ? z : z - 146096) / 146097;
        uint256 doe = z - era * 146097;
        uint256 yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365;
        uint256 y = yoe + era * 400;
        uint256 doy = doe - (365*yoe + yoe/4 - yoe/100);
        uint256 mp = (5*doy + 2)/153;
        uint256 d = doy - (153*mp + 2)/5 + 1;
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
}
