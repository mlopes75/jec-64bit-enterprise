// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./JecEnterprise64BitPacker.sol";

/**
 * @title JecAuditoriaEVM
 * @author mlopes75
 * @notice Contrato inteligente de teste demonstrando o uso de JEC 64-Bit na EVM.
 */
contract JecAuditoriaEVM {
    using JecEnterprise64BitPacker for uint64;

    // Evento indexado pelo Header (6 bits) e Timestamp completo
    event EventoRegistado(uint64 indexed jecHeader, uint64 jecTimestamp);

    // Mapeamento em storage de chave primária ultra-compacta (8 Bytes / uint64)
    mapping(uint64 => string) public logsDoSistema;

    /**
     * @notice Empacota e grava um registro de auditoria na blockchain gastando o mínimo de Gas.
     */
    function registarCheckpoint(
        uint64 codigoServidor, // 6 bits (0 a 63)
        uint64 seculoIdx,      // Ex: 20 (Para Século XXI -> 'V')
        uint64 ano,            // Ex: 26 (Ano 2026)
        uint64 mes,            // Ex: 9 (Setembro)
        uint64 dia,            // Ex: 3
        uint64 hora,           // Ex: 22
        uint64 minuto,         // Ex: 50
        uint64 segundo,        // Ex: 15
        uint64 microssegundos  // Ex: 123456
    ) external {
        // Gera o payload compacto de 64 bits em memória
        uint64 jecTimestamp = JecEnterprise64BitPacker.pack(
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

        // Gravação em storage de baixo custo
        logsDoSistema[jecTimestamp] = "Checkpoint_NRS_Aprovado";

        // Extração dos 6 bits superiores de metadados
        uint64 headerExtraido = jecTimestamp.extractHeaderBits();

        emit EventoRegistado(headerExtraido, jecTimestamp);
    }

    /**
     * @notice Função de leitura que desempacota um timestamp gravado.
     */
    function lerCheckpoint(uint64 jecTimestamp) external pure returns (
        uint64 header,
        uint64 seculoIdx,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 hora,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) {
        return jecTimestamp.unpack();
    }
}
