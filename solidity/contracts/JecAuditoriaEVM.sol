// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./JecEnterprise64BitPacker.sol";

/**
 * @title JecAuditoriaEVM
 * @author mlopes75
 * @notice Contrato de auditoria on-chain imutável - VERSÃO ULTRA OTIMIZADA
 * @dev Otimizado para mínimo consumo de gas
 * 
 * ═══════════════════════════════════════════════════════════════════════════════
 *  ESPECIFICAÇÕES JEC ENTERPRISE 64-BIT
 *  ═══════════════════════════════════════════════════════════════════════════════
 *  
 *  Header (7 bits): 0-127 (ID do servidor/nó)
 *  Século (4 bits): Z=0 (2000), A=1 (2100), ... P=14 (3400)
 *  Ano (7 bits): 0-99
 *  Mês (4 bits): 1-12
 *  Dia (5 bits): 1-31
 *  Hora (5 bits): 0-23 (Z=00, A=01, ... Y=23)
 *  Minuto (6 bits): 0-59
 *  Segundo (6 bits): 0-59
 *  Microssegundos (20 bits): 0-999.999
 * ═══════════════════════════════════════════════════════════════════════════════
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
            string memory seculo,
            uint64 ano, 
            uint64 mes, 
            uint64 dia, 
            uint64 hora, 
            uint64 minuto, 
            uint64 segundo
        ) = _converterTimestamp(block.timestamp);

        // Empacotamento usando string (Z, A, B, ... P)
        jecTimestamp = JecEnterprise64BitPacker.pack(
            codigoServidor,
            seculo,      // string: "Z", "A", "B", ... "P"
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
            string memory seculo,
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
     * O ciclo de 1500 anos começa em 2000 com Z=0.
     * @param timestamp Unix timestamp em segundos
     * @return seculo String do século (Z, A, B, ... P)
     * @return ano Ano (0-99)
     * @return mes Mês (1-12)
     * @return dia Dia (1-31)
     * @return hora Hora (0-23)
     * @return minuto Minuto (0-59)
     * @return segundo Segundo (0-59)
     */
    function _converterTimestamp(uint256 timestamp) 
        internal 
        pure 
        returns (
            string memory seculo,
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
        // Z=0 (2000), A=1 (2100), B=2 (2200), ... P=14 (3400)
        uint256 seculo = yearFull / 100;
        uint256 seculoIdx;
        
        if (seculo >= 20 && seculo <= 34) {
            seculoIdx = seculo - 20;  // 2000 → 0, 2100 → 1, ... 3400 → 14
        } else {
            // Para anos fora do ciclo (não deveria ocorrer com block.timestamp)
            seculoIdx = 0;
        }
        
        // Converte índice para caractere usando o alfabeto JEC
        bytes24 alpha = "ZABCDEFGHJKLMNPQRSTUVWXY";
        bytes1 char = alpha[seculoIdx];
        seculo = string(abi.encodePacked(char));

        // Extrair hora, minuto, segundo
        uint256 secondsInDay = timestamp % 86400;
        hora = uint64(secondsInDay / 3600);
        minuto = uint64((secondsInDay % 3600) / 60);
        segundo = uint64(secondsInDay % 60);
    }

    /**
     * @dev Algoritmo Fliegel-Van Flandern com uint256 puro (mais barato que int256).
     * @param _days Número de dias desde a época Unix (1 de janeiro de 1970)
     * @return year Ano completo
     * @return month Mês (1-12)
     * @return day Dia (1-31)
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

    function timestampParaStringDefault(uint64 jecTimestamp) 
        external 
        pure 
        returns (string memory) 
    {
        return JecEnterprise64BitPacker.unpackToHumanStringDefault(jecTimestamp);
    }
}
