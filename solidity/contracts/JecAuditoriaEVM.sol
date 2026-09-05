// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./JecEnterprise64BitPacker.sol";

/**
 * @title JecAuditoriaEVM
 * @notice Contrato de auditoria on-chain imutável baseado em block.timestamp e JEC 64-Bit.
 * @dev Utiliza o JEC Enterprise 64-Bit para compactar timestamp + metadados em 64 bits.
 */
contract JecAuditoriaEVM {
    using JecEnterprise64BitPacker for uint64;

    // Evento otimizado: indexa o Header e grava o Payload JEC de 64 bits
    event CheckpointRegistado(
        uint64 indexed headerBits, 
        uint64 indexed jecTimestamp, 
        address indexed operador
    );

    // Mapeamento de estado: JEC Timestamp (uint64) => Status (1 = Ativo)
    mapping(uint64 => uint8) public checkpoints;

    /**
     * @notice Registra um checkpoint de auditoria amarrado estritamente ao block.timestamp da EVM.
     * @param codigoServidor ID do nó/servidor (0 a 63 -> 6 bits).
     * @param microssegundos Offset do relógio local (0 a 999.999 -> 20 bits).
     * @return jecTimestamp O timestamp JEC empacotado em 64 bits.
     */
    function registarCheckpoint(
        uint64 codigoServidor,
        uint64 microssegundos
    ) external returns (uint64 jecTimestamp) {
        require(codigoServidor <= 63, "JEC: Servidor ID excede 6 bits");
        require(microssegundos <= 999999, "JEC: Microssegundos excedem 20 bits");

        // 1. Extração matemática determinística (Sem loops, O(1) Gas)
        (uint64 seculoIdx, uint64 ano, uint64 mes, uint64 dia, uint64 hora, uint64 minuto, uint64 segundo) = _converterTimestamp(block.timestamp);

        // 2. Empacotamento em barramento de 64 bits
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

        // 3. Prevenção de colisão de chaves
        require(checkpoints[jecTimestamp] == 0, "JEC: Checkpoint ja existe neste microsegundo");

        // 4. Armazenamento ultra-compacto
        checkpoints[jecTimestamp] = 1;

        // 5. Emissão do evento
        emit CheckpointRegistado(codigoServidor, jecTimestamp, msg.sender);

        return jecTimestamp;
    }

    /**
     * @notice Converte um timestamp UNIX em componentes JEC de forma pura e sem loops.
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
        uint256 yearFull;
        (yearFull, mes, dia) = _daysToDate(timestamp / 86400);

        // Ano no formato de 2 dígitos (0-99)
        ano = uint64(yearFull % 100);

        // Mapeamento do Século 21 (Anos 2000-2099): 'V' representa o índice 20 na alphaTable (sem a letra 'O')
        if (yearFull >= 2000 && yearFull <= 2099) {
            seculoIdx = 20; // 'V'
        } else if (yearFull >= 2100 && yearFull <= 2199) {
            seculoIdx = 21; // 'W'
        } else {
            seculoIdx = 0;  // Fallback para 'A'
        }

        // Horário
        uint256 secondsInDay = timestamp % 86400;
        hora = uint64(secondsInDay / 3600);
        minuto = uint64((secondsInDay % 3600) / 60);
        segundo = uint64(secondsInDay % 60);
    }

    /**
     * @dev Algoritmo constante O(1) de conversão de Dias Epoch para Data (Ano, Mês, Dia).
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

    function obterCheckpoint(uint64 jecTimestamp) external view returns (uint8) {
        return checkpoints[jecTimestamp];
    }

    function checkpointExiste(uint64 jecTimestamp) external view returns (bool) {
        return checkpoints[jecTimestamp] == 1;
    }
}
